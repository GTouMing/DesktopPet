#include "live2d_runtime.h"

#include <Rendering/D3D11/CubismDeviceInfo_D3D11.hpp>
#include <Rendering/D3D11/CubismRenderer_D3D11.hpp>

#include <chrono>
#include <vector>

#include "live2d_log.h"
#include "live2d_pal.h"

namespace pet_live2d {
namespace {

constexpr auto kFrameInterval = std::chrono::milliseconds(16);
/// Resting pets update every Nth tick (~20fps at 60Hz). Never a full stop.
constexpr int kIdleDivisor = 3;
/// Cubism motion evaluation assumes a constant step, so the loop feeds a fixed
/// delta rather than the measured wall-clock delta.
constexpr float kFixedDeltaTime = 1.0f / 60.0f;

const D3D_FEATURE_LEVEL kFeatureLevels[] = {
    D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1,
    D3D_FEATURE_LEVEL_10_0};

}  // namespace

Live2DRuntime::Live2DRuntime(flutter::TextureRegistrar* texture_registrar)
    : texture_registrar_(texture_registrar) {}

Live2DRuntime::~Live2DRuntime() { Stop(); }

bool Live2DRuntime::Start() {
  if (running_.load()) return true;
  // Device + Cubism framework init happen on the platform thread during plugin
  // registration, i.e. before the first Flutter frame - time them.
  const auto init_start = std::chrono::steady_clock::now();
  if (!StartDevice()) return false;
  const long long init_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                                std::chrono::steady_clock::now() - init_start)
                                .count();
  LogLine("[l2d] runtime init took " + std::to_string(init_ms) +
          "ms featureLevel=" + std::to_string(feature_level_) +
          (warp_fallback_ ? " WARP" : " hardware"));
  running_.store(true);
  render_thread_ = std::thread([this]() { RenderLoop(); });
  ready_ = true;
  return true;
}

void Live2DRuntime::Stop() {
  if (!running_.exchange(false)) return;
  if (render_thread_.joinable()) render_thread_.join();

  {
    std::lock_guard<std::mutex> lock(instances_mutex_);
    for (auto& entry : instances_) entry.second->MarkDead();
    instances_.clear();
  }
  {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    queue_.clear();
  }
  StopDevice();
  ready_ = false;
}

bool Live2DRuntime::StartDevice() {
  // Never request the D3D11 debug layer. When that layer is not installed,
  // D3D11CreateDevice fails and the fallback lands on WARP, whose shared
  // textures the engine's hardware device cannot bind.
  const UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
  D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL_11_0;

  HRESULT status = D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, flags, kFeatureLevels,
      ARRAYSIZE(kFeatureLevels), D3D11_SDK_VERSION, device_.GetAddressOf(),
      &level, context_.GetAddressOf());
  if (FAILED(status)) {
    warp_fallback_ = true;
    status = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_WARP, nullptr, flags, kFeatureLevels,
        ARRAYSIZE(kFeatureLevels), D3D11_SDK_VERSION, device_.GetAddressOf(),
        &level, context_.GetAddressOf());
  }
  if (FAILED(status)) return false;
  feature_level_ = static_cast<int>(level);

  cubism_option_.LogFunction = nullptr;
  cubism_option_.LoggingLevel = Csm::CubismFramework::Option::LogLevel_Off;
  cubism_option_.LoadFileFunction = pal::LoadFileAsBytes;
  cubism_option_.ReleaseBytesFunction = pal::ReleaseBytes;
  if (!Csm::CubismFramework::StartUp(&allocator_, &cubism_option_)) return false;
  Csm::CubismFramework::Initialize();
  Csm::Rendering::CubismRenderer_D3D11::SetConstantSettings(1, device_.Get());
  return true;
}

void Live2DRuntime::StopDevice() {
  if (device_ &&
      Csm::Rendering::CubismDeviceInfo_D3D11::GetDeviceInfo(device_.Get())) {
    Csm::Rendering::CubismDeviceInfo_D3D11::ReleaseAllDeviceInfo();
  }
  Csm::CubismFramework::Dispose();
  context_.Reset();
  device_.Reset();
}

std::shared_ptr<Live2DInstance> Live2DRuntime::Find(const std::string& pet_id) {
  std::lock_guard<std::mutex> lock(instances_mutex_);
  auto it = instances_.find(pet_id);
  return it == instances_.end() ? nullptr : it->second;
}

size_t Live2DRuntime::instance_count() const {
  std::lock_guard<std::mutex> lock(instances_mutex_);
  return instances_.size();
}

void Live2DRuntime::Post(std::function<void()> command) {
  if (!running_.load()) return;
  std::lock_guard<std::mutex> lock(queue_mutex_);
  queue_.push_back(std::move(command));
}

int64_t Live2DRuntime::Create(const std::string& pet_id,
                              const std::string& model_dir,
                              const std::string& model_file, int width,
                              int height, double fit_scale, double fit_offset_x,
                              double fit_offset_y, double breath_scale) {
  if (!ready_) return -1;

  // Reuse an instance that already matches: the Flutter side remounts PetWidget
  // during startup (the pet list/scene rebuilds), which would otherwise destroy
  // and reload the model a few times for nothing.
  {
    std::lock_guard<std::mutex> lock(instances_mutex_);
    auto it = instances_.find(pet_id);
    if (it != instances_.end() && it->second->alive() &&
        it->second->width() == width && it->second->height() == height) {
      LogLine("[l2d] reuse pet=" + pet_id + " " + std::to_string(width) + "x" +
              std::to_string(height) +
              " texture=" + std::to_string(it->second->texture_id()));
      return it->second->texture_id();
    }
  }

  // Otherwise replace it: retire the old instance first so the texture id is
  // released before a new one is registered.
  Destroy(pet_id);

  auto instance = std::make_shared<Live2DInstance>(
      pet_id, device_.Get(), context_.Get(), texture_registrar_);
  if (!instance->ok()) {
    LogLine("[l2d] create FAILED pet=" + pet_id);
    return -1;
  }
  // Size the target for the box the caller already knows about, so the initial
  // registration the Dart side receives is final (no startup re-register).
  instance->SetBoxSize(width, height);
  const int64_t texture_id = instance->texture_id();
  LogLine("[l2d] create pet=" + pet_id + " box=" + std::to_string(width) + "x" +
          std::to_string(height) + " texture=" + std::to_string(texture_id));

  {
    std::lock_guard<std::mutex> lock(instances_mutex_);
    instances_[pet_id] = instance;
  }

  // Model loading touches Cubism and the immediate context, so it runs on the
  // render thread. The shared_ptr keeps the instance alive even if the pet is
  // disposed meanwhile.
  Post([this, instance, pet_id, model_dir, model_file, fit_scale, fit_offset_x,
        fit_offset_y, breath_scale]() {
    if (!instance->alive()) return;
    instance->LoadModel(model_dir, model_file, static_cast<float>(fit_scale),
                        static_cast<float>(fit_offset_x),
                        static_cast<float>(fit_offset_y),
                        static_cast<float>(breath_scale));
  });
  return texture_id;
}

Live2DInstance::ModelInfo Live2DRuntime::GetModelInfo(
    const std::string& pet_id) {
  auto instance = Find(pet_id);
  if (!instance) return Live2DInstance::ModelInfo{};
  return instance->GetModelInfo();
}

bool Live2DRuntime::Destroy(const std::string& pet_id) {
  std::shared_ptr<Live2DInstance> instance;
  {
    std::lock_guard<std::mutex> lock(instances_mutex_);
    auto it = instances_.find(pet_id);
    if (it == instances_.end()) return false;
    instance = it->second;
    instances_.erase(it);
  }
  // Mark dead so an in-flight render tick skips it, then unregister the texture
  // here - on the platform thread - because the render loop's snapshot can hold
  // the last reference and the registrar must not be called from there.
  instance->MarkDead();
  instance->UnregisterTexture();
  instance.reset();
  LogLine("[l2d] destroy pet=" + pet_id);
  return true;
}

bool Live2DRuntime::SetBoxSize(const std::string& pet_id, int width,
                               int height) {
  auto instance = Find(pet_id);
  if (!instance) return false;
  // Runs on the platform thread: only device calls and the texture registrar,
  // both of which are safe there. The model re-fit is deferred to the render
  // thread through a flag.
  instance->SetBoxSize(width, height);
  return true;
}

bool Live2DRuntime::PostStartMotion(const std::string& pet_id,
                                    const std::string& group, int index,
                                    int priority, bool loop) {
  auto instance = Find(pet_id);
  if (!instance) return false;
  Post([instance, group, index, priority, loop]() {
    if (instance->alive()) instance->StartMotion(group, index, priority, loop);
  });
  return true;
}

bool Live2DRuntime::PostSetExpression(const std::string& pet_id, int index) {
  auto instance = Find(pet_id);
  if (!instance) return false;
  Post([instance, index]() {
    if (instance->alive()) instance->SetExpression(index);
  });
  return true;
}

bool Live2DRuntime::PostSetParameter(const std::string& pet_id,
                                     const std::string& parameter_id,
                                     double value) {
  auto instance = Find(pet_id);
  if (!instance) return false;
  Post([instance, parameter_id, value]() {
    if (instance->alive()) instance->SetParameter(parameter_id, value);
  });
  return true;
}

bool Live2DRuntime::PostResetParameter(const std::string& pet_id,
                                       const std::string& parameter_id) {
  auto instance = Find(pet_id);
  if (!instance) return false;
  Post([instance, parameter_id]() {
    if (instance->alive()) instance->ResetParameter(parameter_id);
  });
  return true;
}

bool Live2DRuntime::PostClearParameters(const std::string& pet_id) {
  auto instance = Find(pet_id);
  if (!instance) return false;
  Post([instance]() {
    if (instance->alive()) instance->ClearParameters();
  });
  return true;
}

bool Live2DRuntime::PostSetMotionSpeed(const std::string& pet_id,
                                       double speed) {
  auto instance = Find(pet_id);
  if (!instance) return false;
  Post([instance, speed]() {
    if (instance->alive()) instance->SetMotionSpeed(speed);
  });
  return true;
}

bool Live2DRuntime::PostSetDragging(const std::string& pet_id, double x,
                                    double y) {
  auto instance = Find(pet_id);
  if (!instance) return false;
  Post([instance, x, y]() {
    if (instance->alive()) instance->SetDragging(x, y);
  });
  return true;
}

void Live2DRuntime::RenderLoop() {
  using Clock = std::chrono::steady_clock;
  auto next_frame = Clock::now();
  uint64_t tick = 0;

  while (running_.load()) {
    next_frame += kFrameInterval;

    std::deque<std::function<void()>> commands;
    {
      std::lock_guard<std::mutex> lock(queue_mutex_);
      commands.swap(queue_);
    }
    for (auto& command : commands) command();

    std::vector<std::shared_ptr<Live2DInstance>> snapshot;
    {
      std::lock_guard<std::mutex> lock(instances_mutex_);
      snapshot.reserve(instances_.size());
      for (auto& entry : instances_) snapshot.push_back(entry.second);
    }
    ++tick;
    for (auto& instance : snapshot) {
      if (!instance->alive()) continue;
      // Tiered frame rate: full rate while a pet is active, a third of it when it
      // is just resting. dt scales with the same divisor, so motions, physics and
      // eye-blink keep their real-time speed - only the update density drops.
      const bool active = instance->IsActive();
      if (!active && (tick % kIdleDivisor) != 0) continue;
      const float delta = active ? kFixedDeltaTime : kFixedDeltaTime * kIdleDivisor;
      if (instance->RenderFrame(delta)) {
        texture_registrar_->MarkTextureFrameAvailable(instance->texture_id());
      }
    }

    std::this_thread::sleep_until(next_frame);
    if (Clock::now() - next_frame > kFrameInterval) next_frame = Clock::now();
  }
}

}  // namespace pet_live2d
