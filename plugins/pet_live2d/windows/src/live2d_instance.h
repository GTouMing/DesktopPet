#pragma once

#include <d3d11.h>
#include <flutter/texture_registrar.h>
#include <wrl/client.h>

#include <atomic>
#include <chrono>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

#include "live2d_model.h"
#include "live2d_texture_manager.h"

namespace pet_live2d {

/// One pet's renderer.
///
/// Two rules, both learned the hard way:
///
///  1. The render target tracks the pet's **display box**, so the model is
///     rasterised at roughly the resolution it is shown at. A fixed oversized
///     target plus an engine downscale was visibly soft (the engine has no
///     mipmaps for external textures, so a 3-4x downscale aliases).
///  2. When the target size changes the Flutter texture is **re-registered**.
///     The engine does not re-read a changed descriptor, but it does pick up a
///     freshly registered texture - which is exactly why hiding and re-showing
///     the pet used to "fix" it. The model itself is never reloaded.
class Live2DInstance {
 public:
  Live2DInstance(std::string pet_id, ID3D11Device* device,
                 ID3D11DeviceContext* context,
                 flutter::TextureRegistrar* texture_registrar);
  ~Live2DInstance();

  Live2DInstance(const Live2DInstance&) = delete;
  Live2DInstance& operator=(const Live2DInstance&) = delete;

  bool ok() const { return texture_id_.load() >= 0 && target() != nullptr; }
  int64_t texture_id() const { return texture_id_.load(); }
  int width() const;
  int height() const;

  bool alive() const { return alive_.load(std::memory_order_acquire); }
  void MarkDead() { alive_.store(false, std::memory_order_release); }

  /// Unregisters the Flutter texture. Platform thread only (the registrar may
  /// block), idempotent. Called by the runtime before dropping the instance when
  /// the render loop's snapshot may still hold the last reference.
  void UnregisterTexture();

  /// Platform thread: the pet's display box in physical pixels. Rebuilds the
  /// render target at exactly this size. (The texture registration is untouched;
  /// the engine re-reads the descriptor every frame.)
  void SetBoxSize(int width, int height);

  // ---- render thread ------------------------------------------------------

  void LoadModel(const std::string& model_dir, const std::string& model_file,
                 float fit_scale, float fit_offset_x, float fit_offset_y,
                 float breath_scale);
  bool IsModelLoaded() const;
  void StartMotion(const std::string& group, int index, int priority, bool loop);
  void SetExpression(int index);
  void SetParameter(const std::string& parameter_id, double value);
  /// Restores a parameter to the model's own default (see `Live2DModel::ResetParameter`).
  void ResetParameter(const std::string& parameter_id);
  void ClearParameters();
  void SetMotionSpeed(double speed);
  void SetDragging(double x, double y);
  bool RenderFrame(float delta_time);

  /// "Active" = a motion is in flight, or input arrived recently. The render loop
  /// gives active pets the full frame rate and resting ones a reduced one - never
  /// a full stop, since eye-blink and physics are what make it feel alive.
  void NoteActivity();
  bool IsActive() const;

 private:
  struct RenderTarget;

  std::shared_ptr<RenderTarget> CreateRenderTarget(int width, int height);
  int64_t RegisterTexture();
  const FlutterDesktopGpuSurfaceDescriptor* ObtainSurfaceDescriptor();
  std::shared_ptr<RenderTarget> target() const;
  void RetireOldTargets();

  std::string pet_id_;
  bool logged_first_frame_ = false;
  /// Dump the render target after each rebuild (PET_LIVE2D_DUMP=1), so a real
  /// resize can be inspected from outside.
  bool dump_next_frame_ = true;
  /// Render-thread only: the target size the model is currently fitted to, plus a
  /// one-shot for the first re-fit (content bounds are only meaningful once the
  /// vertices have been deformed by an Update).
  int fitted_width_ = 0;
  int fitted_height_ = 0;
  bool bounds_refit_pending_ = true;
  std::atomic<bool> texture_registered_{false};
  std::atomic<int64_t> texture_id_{-1};
  std::atomic<bool> alive_{true};

  Microsoft::WRL::ComPtr<ID3D11Device> device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> context_;
  flutter::TextureRegistrar* texture_registrar_ = nullptr;
  std::unique_ptr<flutter::TextureVariant> texture_;

  /// Guards the target, its size, the retired list and the box.
  mutable std::mutex target_mutex_;
  std::shared_ptr<RenderTarget> active_target_;
  std::vector<std::pair<std::shared_ptr<RenderTarget>, int>> retired_targets_;
  std::atomic<const FlutterDesktopGpuSurfaceDescriptor*> active_descriptor_{
      nullptr};
  int target_width_ = 0;
  int target_height_ = 0;
  int box_width_ = 0;
  int box_height_ = 0;

  /// When input last arrived; a pet stays "active" for a moment after it.
  std::chrono::steady_clock::time_point last_activity_ =
      std::chrono::steady_clock::now();

  std::unique_ptr<Live2DTextureManager> texture_manager_;
  std::unique_ptr<Live2DModel> model_;
  bool model_loaded_ = false;
};

}  // namespace pet_live2d
