#include "live2d_instance.h"

#include <Rendering/D3D11/CubismDeviceInfo_D3D11.hpp>
#include <Rendering/D3D11/CubismRenderer_D3D11.hpp>
#include <flutter/texture_registrar.h>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "live2d_log.h"

using Microsoft::WRL::ComPtr;

namespace pet_live2d {
namespace {

constexpr int kMinTarget = 16;
constexpr int kMaxTarget = 4096;
constexpr int kRetireFrames = 60;

bool TraceEnabled() {
  static const bool enabled = []() {
    const char* value = std::getenv("PET_LIVE2D_TRACE");
    return value && std::strcmp(value, "1") == 0;
  }();
  return enabled;
}

/// Copies [texture] into a staging texture and writes it as a 32-bit BMP.
///
/// Purely diagnostic: when "the pet shows nothing" it is the difference between
/// "we drew nothing" and "the engine did not composite what we drew".
void DumpTextureToBmp(ID3D11Device* device, ID3D11DeviceContext* context,
                      ID3D11Texture2D* texture, int width, int height,
                      const std::wstring& path) {
  D3D11_TEXTURE2D_DESC desc = {};
  texture->GetDesc(&desc);
  desc.Usage = D3D11_USAGE_STAGING;
  desc.BindFlags = 0;
  desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  desc.MiscFlags = 0;

  ComPtr<ID3D11Texture2D> staging;
  if (FAILED(device->CreateTexture2D(&desc, nullptr, staging.GetAddressOf()))) {
    return;
  }
  context->CopyResource(staging.Get(), texture);

  D3D11_MAPPED_SUBRESOURCE mapped = {};
  if (FAILED(context->Map(staging.Get(), 0, D3D11_MAP_READ, 0, &mapped))) {
    return;
  }

  const int row_bytes = width * 4;
  std::vector<unsigned char> pixels(static_cast<size_t>(row_bytes) * height);
  for (int y = 0; y < height; ++y) {
    std::memcpy(pixels.data() + static_cast<size_t>(y) * row_bytes,
                static_cast<const unsigned char*>(mapped.pData) +
                    static_cast<size_t>(y) * mapped.RowPitch,
                static_cast<size_t>(row_bytes));
  }
  context->Unmap(staging.Get(), 0);

  FILE* file = nullptr;
  if (_wfopen_s(&file, path.c_str(), L"wb") != 0 || !file) return;

  const int image_size = row_bytes * height;
  const int file_size = 54 + image_size;
  const int pixel_offset = 54;
  const int header_size = 40;
  const short planes = 1;
  const short bits_per_pixel = 32;
  unsigned char header[54] = {};
  header[0] = 'B';
  header[1] = 'M';
  std::memcpy(header + 2, &file_size, 4);
  std::memcpy(header + 10, &pixel_offset, 4);
  std::memcpy(header + 14, &header_size, 4);
  std::memcpy(header + 18, &width, 4);
  std::memcpy(header + 22, &height, 4);
  std::memcpy(header + 26, &planes, 2);
  std::memcpy(header + 28, &bits_per_pixel, 2);
  std::memcpy(header + 34, &image_size, 4);
  fwrite(header, 1, sizeof(header), file);
  // BMP rows are bottom-up; D3D row 0 is the top.
  for (int y = height - 1; y >= 0; --y) {
    fwrite(pixels.data() + static_cast<size_t>(y) * row_bytes, 1, row_bytes,
           file);
  }
  fclose(file);
}

}  // namespace

/// The render target handed to Flutter as a GPU surface. `descriptor` is what
/// the engine reads (via an atomic pointer, so a swap is safe).
struct Live2DInstance::RenderTarget {
  ~RenderTarget() {
    if (shared_handle) CloseHandle(shared_handle);
  }

  Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
  Microsoft::WRL::ComPtr<ID3D11RenderTargetView> render_target_view;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> depth_texture;
  Microsoft::WRL::ComPtr<ID3D11DepthStencilView> depth_view;
  HANDLE shared_handle = nullptr;
  FlutterDesktopGpuSurfaceDescriptor descriptor = {};
};

Live2DInstance::Live2DInstance(std::string pet_id, ID3D11Device* device,
                               ID3D11DeviceContext* context,
                               flutter::TextureRegistrar* texture_registrar)
    : pet_id_(std::move(pet_id)),
      device_(device),
      context_(context),
      texture_registrar_(texture_registrar) {
  // A small placeholder target: the Dart side reports the real box on the first
  // build and SetBoxSize swaps this for a correctly sized one.
  active_target_ = CreateRenderTarget(kMinTarget, kMinTarget);
  if (!active_target_) return;
  target_width_ = kMinTarget;
  target_height_ = kMinTarget;
  active_descriptor_.store(&active_target_->descriptor,
                           std::memory_order_release);

  // One registration for the instance's whole life: the engine holds a raw
  // pointer to this TextureVariant (see PATCHES.md Patch 4 in the vendored
  // plugin), so it must never be replaced while the instance lives.
  texture_ = std::make_unique<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
      kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
      [this](size_t /*requested_width*/, size_t /*requested_height*/) {
        return ObtainSurfaceDescriptor();
      }));
  if (RegisterTexture() < 0) {
    active_target_.reset();
    active_descriptor_.store(nullptr, std::memory_order_release);
  }
}

Live2DInstance::~Live2DInstance() {
  model_.reset();
  texture_manager_.reset();
  UnregisterTexture();

  // Everything the engine may still be pointing at is intentionally leaked until
  // process exit: the TextureVariant, and - crucially - the render targets (their
  // descriptors). Freeing a target the engine still holds is an access violation,
  // which is exactly what the vendored plugin hit and documented in its
  // PATCHES.md Patch 4 ("disposeView ... hands the view to that queue instead of
  // destroying it", "ShutdownRuntime ... intentionally leaking them until process
  // exit rather than racing the engine"). With a session recreate per resize that
  // is a few hundred KB per resize - correctness first.
  texture_.release();
  active_descriptor_.store(nullptr, std::memory_order_release);

  static std::mutex leaked_mutex;
  static std::vector<std::shared_ptr<RenderTarget>> leaked_targets;
  std::lock_guard<std::mutex> lock(leaked_mutex);
  if (active_target_) leaked_targets.push_back(std::move(active_target_));
  for (auto& entry : retired_targets_) {
    leaked_targets.push_back(std::move(entry.first));
  }
  retired_targets_.clear();
}

std::shared_ptr<Live2DInstance::RenderTarget> Live2DInstance::CreateRenderTarget(
    int width, int height) {
  auto target = std::make_shared<RenderTarget>();

  D3D11_TEXTURE2D_DESC texture_desc = {};
  texture_desc.Width = static_cast<UINT>(width);
  texture_desc.Height = static_cast<UINT>(height);
  texture_desc.MipLevels = 1;
  texture_desc.ArraySize = 1;
  texture_desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  texture_desc.SampleDesc.Count = 1;
  texture_desc.Usage = D3D11_USAGE_DEFAULT;
  texture_desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
  texture_desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;
  if (FAILED(device_->CreateTexture2D(&texture_desc, nullptr,
                                      target->texture.GetAddressOf()))) {
    return nullptr;
  }
  if (FAILED(device_->CreateRenderTargetView(
          target->texture.Get(), nullptr,
          target->render_target_view.GetAddressOf()))) {
    return nullptr;
  }

  ComPtr<IDXGIResource> shared_resource;
  if (FAILED(target->texture.As(&shared_resource)) ||
      FAILED(shared_resource->GetSharedHandle(&target->shared_handle))) {
    return nullptr;
  }

  D3D11_TEXTURE2D_DESC depth_desc = {};
  depth_desc.Width = static_cast<UINT>(width);
  depth_desc.Height = static_cast<UINT>(height);
  depth_desc.MipLevels = 1;
  depth_desc.ArraySize = 1;
  depth_desc.Format = DXGI_FORMAT_D24_UNORM_S8_UINT;
  depth_desc.SampleDesc.Count = 1;
  depth_desc.Usage = D3D11_USAGE_DEFAULT;
  depth_desc.BindFlags = D3D11_BIND_DEPTH_STENCIL;
  if (FAILED(device_->CreateTexture2D(&depth_desc, nullptr,
                                      target->depth_texture.GetAddressOf()))) {
    return nullptr;
  }
  if (FAILED(device_->CreateDepthStencilView(
          target->depth_texture.Get(), nullptr,
          target->depth_view.GetAddressOf()))) {
    return nullptr;
  }

  // The whole texture is visible; the engine scales it into the widget's box.
  target->descriptor.struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
  target->descriptor.handle = target->shared_handle;
  target->descriptor.width = static_cast<size_t>(width);
  target->descriptor.height = static_cast<size_t>(height);
  target->descriptor.visible_width = static_cast<size_t>(width);
  target->descriptor.visible_height = static_cast<size_t>(height);
  return target;
}

int64_t Live2DInstance::RegisterTexture() {
  if (!texture_ || !texture_registrar_) return -1;
  const int64_t id = texture_registrar_->RegisterTexture(texture_.get());
  if (id < 0) return -1;
  texture_id_.store(id);
  texture_registered_.store(true, std::memory_order_release);
  return id;
}

void Live2DInstance::UnregisterTexture() {
  if (!texture_registered_.exchange(false, std::memory_order_acq_rel)) return;
  const int64_t id = texture_id_.exchange(-1);
  if (id >= 0 && texture_registrar_) {
    texture_registrar_->UnregisterTexture(id);
  }
}

const FlutterDesktopGpuSurfaceDescriptor*
Live2DInstance::ObtainSurfaceDescriptor() {
  return active_descriptor_.load(std::memory_order_acquire);
}

std::shared_ptr<Live2DInstance::RenderTarget> Live2DInstance::target() const {
  std::lock_guard<std::mutex> lock(target_mutex_);
  return active_target_;
}

int Live2DInstance::width() const {
  std::lock_guard<std::mutex> lock(target_mutex_);
  return target_width_;
}

int Live2DInstance::height() const {
  std::lock_guard<std::mutex> lock(target_mutex_);
  return target_height_;
}

void Live2DInstance::SetBoxSize(int width, int height) {
  const int box_w = std::clamp(width, kMinTarget, kMaxTarget);
  const int box_h = std::clamp(height, kMinTarget, kMaxTarget);

  int target_w = 0;
  int target_h = 0;
  {
    std::lock_guard<std::mutex> lock(target_mutex_);
    box_width_ = box_w;
    box_height_ = box_h;
    target_w = target_width_;
    target_h = target_height_;
  }

  // The render target is EXACTLY the widget's pixel size (1:1). That is the
  // invariant the vendored plugin kept, and it is what makes resizing crop-free:
  // the engine never has to scale this texture at all. Any headroom here (a
  // larger target, rounded up) leaves the engine scaling it, and the leftover
  // gets clipped by the pet's box - which is exactly what "cropped instead of
  // scaled" was.
  const int wanted_w = box_w;
  const int wanted_h = box_h;
  if (wanted_w == target_w && wanted_h == target_h) return;

  auto replacement = CreateRenderTarget(wanted_w, wanted_h);
  if (!replacement) {
    LogLine("[l2d] target rebuild FAILED pet=" + pet_id_ + " " +
            std::to_string(wanted_w) + "x" + std::to_string(wanted_h));
    return;
  }

  {
    std::lock_guard<std::mutex> lock(target_mutex_);
    if (active_target_) retired_targets_.emplace_back(active_target_, 0);
    active_target_ = replacement;
    target_width_ = wanted_w;
    target_height_ = wanted_h;
  }
  // Only the descriptor changes - the texture stays registered and the engine
  // re-reads it every frame. That is the behaviour the vendored plugin relied on
  // (see its PATCHES.md Patch 4: "resizing replaces the render target, and the
  // engine may still hold the previous descriptor", which is why retired targets
  // are kept alive for 60 frames). Re-registering here instead caused a flicker
  // window and, worse, destroyed the TextureVariant the engine holds a raw
  // pointer to.
  active_descriptor_.store(&replacement->descriptor,
                           std::memory_order_release);
  dump_next_frame_ = true;
  LogLine("[l2d] target pet=" + pet_id_ + " " + std::to_string(wanted_w) + "x" +
          std::to_string(wanted_h) + " box=" + std::to_string(box_w) + "x" +
          std::to_string(box_h));
}

void Live2DInstance::RetireOldTargets() {
  std::lock_guard<std::mutex> lock(target_mutex_);
  for (auto& entry : retired_targets_) ++entry.second;
  retired_targets_.erase(
      std::remove_if(retired_targets_.begin(), retired_targets_.end(),
                     [](const auto& entry) { return entry.second > kRetireFrames; }),
      retired_targets_.end());
}

void Live2DInstance::LoadModel(const std::string& model_dir,
                               const std::string& model_file, float fit_scale,
                               float fit_offset_x, float fit_offset_y,
                               float breath_scale) {
  if (!device_) return;
  model_loaded_ = false;
  texture_manager_ = std::make_unique<Live2DTextureManager>(device_.Get());
  model_ = std::make_unique<Live2DModel>(texture_manager_.get());
  // Must be set before LoadAssets(): its SetupModel() is what creates the breath.
  model_->SetBreathScale(breath_scale);
  model_->LoadAssets(model_dir.c_str(), model_file.c_str());
  if (!model_->IsLoaded()) {
    LogLine("[l2d] load FAILED pet=" + pet_id_ +
            " path=" + model_dir + model_file);
    model_.reset();
    texture_manager_.reset();
    return;
  }
  LogLine("[l2d] loaded pet=" + pet_id_ + " file=" + model_file);

  int target_w = 0;
  int target_h = 0;
  {
    std::lock_guard<std::mutex> lock(target_mutex_);
    target_w = target_width_;
    target_h = target_height_;
  }
  model_->CreateRenderer(static_cast<Csm::csmUint32>(target_w),
                         static_cast<Csm::csmUint32>(target_h));
  model_->ResizeMaskBuffer(target_w, target_h);
  model_->SetupTextures();
  // Manifest framing (pack `scale` / `translate`) rides on the automatic fit; set
  // before the fit so the first frame is already framed the way the author wants.
  // The manifest's y is screen-space (down); model space is up, hence the flip.
  model_->SetFitAdjust(fit_scale, fit_offset_x, -fit_offset_y);
  model_->FitToView(target_w, target_h);
  model_loaded_ = true;
}

bool Live2DInstance::IsModelLoaded() const { return model_loaded_ && model_; }

void Live2DInstance::NoteActivity() {
  last_activity_ = std::chrono::steady_clock::now();
}

bool Live2DInstance::IsActive() const {
  if (model_ && model_loaded_ && model_->IsMotionPlaying()) return true;
  return std::chrono::steady_clock::now() - last_activity_ <
         std::chrono::seconds(1);
}

void Live2DInstance::StartMotion(const std::string& group, int index,
                                 int priority, bool loop) {
  LogLine("[l2d] motion pet=" + pet_id_ + " group=" + group + " idx=" +
          std::to_string(index) + " prio=" + std::to_string(priority) +
          " loop=" + (loop ? "1" : "0"));
  NoteActivity();
  if (model_) model_->StartMotion(group.c_str(), index, priority, loop);
}

void Live2DInstance::SetExpression(int index) {
  if (TraceEnabled()) {
    LogLine("[l2d] expression pet=" + pet_id_ + " idx=" + std::to_string(index));
  }
  NoteActivity();
  if (model_) model_->SetExpression(index);
}

void Live2DInstance::SetParameter(const std::string& parameter_id,
                                  double value) {
  if (TraceEnabled()) {
    LogLine("[l2d] param pet=" + pet_id_ + " " + parameter_id + "=" +
            std::to_string(value));
  }
  NoteActivity();
  if (model_) model_->SetParameter(parameter_id.c_str(),
                                   static_cast<Csm::csmFloat32>(value));
}

void Live2DInstance::ResetParameter(const std::string& parameter_id) {
  NoteActivity();
  if (model_) model_->ResetParameter(parameter_id.c_str());
}

void Live2DInstance::ClearParameters() {
  if (model_) model_->ClearParameterOverrides();
}

void Live2DInstance::SetMotionSpeed(double speed) {
  if (TraceEnabled()) {
    LogLine("[l2d] speed pet=" + pet_id_ + " " + std::to_string(speed));
  }
  if (model_) model_->SetMotionSpeed(static_cast<Csm::csmFloat32>(speed));
}

void Live2DInstance::SetDragging(double x, double y) {
  if (model_) {
    model_->SetDragging(static_cast<Csm::csmFloat32>(x),
                        static_cast<Csm::csmFloat32>(y));
  }
}

bool Live2DInstance::RenderFrame(float delta_time) {
  auto target = this->target();
  if (!target || !context_) return false;

  const int width = static_cast<int>(target->descriptor.width);
  const int height = static_cast<int>(target->descriptor.height);

  D3D11_VIEWPORT viewport = {};
  viewport.Width = static_cast<float>(width);
  viewport.Height = static_cast<float>(height);
  viewport.MinDepth = 0.0f;
  viewport.MaxDepth = 1.0f;
  context_->RSSetViewports(1, &viewport);

  // Binding the target is NOT optional: without it the clear still works (a
  // render-target view can be cleared while unbound) but the model is drawn
  // somewhere else, which looks exactly like "the pet renders nothing".
  ID3D11RenderTargetView* render_target = target->render_target_view.Get();
  context_->OMSetRenderTargets(1, &render_target, target->depth_view.Get());

  const float clear_color[4] = {0.0f, 0.0f, 0.0f, 0.0f};
  context_->ClearRenderTargetView(render_target, clear_color);
  context_->ClearDepthStencilView(target->depth_view.Get(),
                                  D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 1.0f,
                                  0);

  if (model_ && model_loaded_) {
    auto* renderer = model_->GetRenderer<Csm::Rendering::CubismRenderer_D3D11>();
    if (renderer) {
      renderer->StartFrame(context_.Get());
      model_->Update(delta_time);
      // Re-fit whenever the rendered target's size differs from the fitted one,
      // and while the model is still growing its fit box to cover artwork that
      // has just been revealed (cheap: pure matrix math, nothing is allocated).
      // Comparing sizes rather than consuming a one-shot flag: a one-shot was
      // race-prone: the platform thread can swap the target mid-frame, the flag
      // got consumed while still rendering the previous target, and the new one
      // was then never fitted (the model rendered oversized for the smaller
      // target and came out cropped).
      if (fitted_width_ != width || fitted_height_ != height ||
          bounds_refit_pending_ || model_->IsAdaptingBounds()) {
        bounds_refit_pending_ = false;
        const bool target_resized =
            fitted_width_ != width || fitted_height_ != height;
        fitted_width_ = width;
        fitted_height_ = height;
        // Exactly what the vendored plugin's Resize() does, but resizing the
        // clipping mask buffers only on a real size change: the renderer rebuilds
        // them when this is called, and this block runs every adapting frame.
        // The renderer is NOT recreated and the MODEL IS NOT RELOADED - that is
        // what keeps a resize instant and blank-free.
        if (target_resized) model_->ResizeMaskBuffer(width, height);
        model_->FitToView(width, height);
      }

      Csm::CubismMatrix44 projection;
      projection.LoadIdentity();
      if (width > height) {
        projection.Scale(static_cast<float>(height) / static_cast<float>(width),
                         1.0f);
      } else {
        projection.Scale(1.0f,
                         static_cast<float>(width) / static_cast<float>(height));
      }
      model_->Draw(projection);
      renderer->EndFrame();
      Csm::Rendering::CubismDeviceInfo_D3D11::GetDeviceInfo(device_.Get())
          ->GetOffscreenManager()
          ->EndFrameProcess();
    }
  }

  context_->Flush();
  RetireOldTargets();

  if (!logged_first_frame_) {
    logged_first_frame_ = true;
    LogLine("[l2d] first frame pet=" + pet_id_ + " target=" +
            std::to_string(width) + "x" + std::to_string(height) +
            " model=" + (model_loaded_ ? "yes" : "no"));
  }
  // Opt-in diagnostic: set PET_LIVE2D_DUMP=1 to write the render target next to
  // the executable (~6 MB). It answers "did we draw nothing, or did the engine
  // not composite what we drew?" - the question that took the longest to settle.
  if (model_loaded_ && dump_next_frame_) {
    dump_next_frame_ = false;
    const char* enabled = std::getenv("PET_LIVE2D_DUMP");
    if (enabled && std::strcmp(enabled, "1") == 0) {
      // Re-read the target: the platform thread may have swapped it after this
      // frame captured its local copy. Dumping the stale one produced dumps that
      // looked like a "fragment render" and sent the investigation the wrong way.
      auto dump_target = this->target();
      if (dump_target) {
        const int dump_width =
            static_cast<int>(dump_target->descriptor.width);
        const int dump_height =
            static_cast<int>(dump_target->descriptor.height);
        const std::string dump_name =
            "l2d_dump_" + pet_id_ + "_" + std::to_string(dump_width) + "x" +
            std::to_string(dump_height) + ".bmp";
        const std::wstring wide_name(dump_name.begin(), dump_name.end());
        DumpTextureToBmp(device_.Get(), context_.Get(),
                         dump_target->texture.Get(), dump_width, dump_height,
                         PathBesideExecutable(wide_name.c_str()));
        LogLine("[l2d] dumped " + dump_name);
      }
    }
  }
  return true;
}

}  // namespace pet_live2d
