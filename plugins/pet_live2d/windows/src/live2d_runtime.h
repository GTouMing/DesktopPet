#pragma once

#include <CubismFramework.hpp>
#include <d3d11.h>
#include <flutter/texture_registrar.h>
#include <wrl/client.h>

#include <atomic>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include "live2d_allocator.h"
#include "live2d_instance.h"

namespace pet_live2d {

/// Process-wide Live2D runtime.
///
/// Owns the D3D11 device/context and the Cubism framework, the render thread and
/// the `petId -> Live2DInstance` map. Deliberately NOT one-renderer-per-Flutter-
/// view: the model outlives widget churn, which is what makes resizing a pet
/// free (no reload) and what the old plugin could not do.
///
/// Threading contract:
///  * `Create`/`Destroy`/`SetVisibleSize` run on the platform thread (they touch
///    the device and the texture registrar).
///  * Everything that touches Cubism, the immediate context or the model is
///    queued and executed on the render thread.
class Live2DRuntime {
 public:
  Live2DRuntime(flutter::TextureRegistrar* texture_registrar);
  ~Live2DRuntime();

  Live2DRuntime(const Live2DRuntime&) = delete;
  Live2DRuntime& operator=(const Live2DRuntime&) = delete;

  bool Start();
  void Stop();

  bool ready() const { return ready_; }
  bool warp_fallback() const { return warp_fallback_; }
  int feature_level() const { return feature_level_; }
  size_t instance_count() const;

  // ---- platform thread ----------------------------------------------------

  /// Creates (or replaces) the instance for `pet_id` and returns its Flutter
  /// texture id, or -1 on failure. [width]/[height] are the pet's display box in
  /// physical pixels; the render target is sized from them. The model itself is
  /// loaded asynchronously on the render thread.
  ///
  /// [fit_scale] / [fit_offset_x] / [fit_offset_y] are the pack manifest's framing
  /// (`scale` / `translate`), applied on top of the automatic fit. The offsets are
  /// in view units (1 = half the box's short side) and in SCREEN orientation
  /// (+y down), exactly as Dart sends them.
  ///
  /// [breath_scale] is the pack manifest's idle-breath amplitude (1 = standard,
  /// 0 = off); see `Live2DModel::SetBreathScale`.
  int64_t Create(const std::string& pet_id, const std::string& model_dir,
                 const std::string& model_file, int width, int height,
                 double fit_scale, double fit_offset_x, double fit_offset_y,
                 double breath_scale);
  bool Destroy(const std::string& pet_id);

  /// Parameter metadata + readiness for `pet_id`, for the Dart side to poll
  /// (the native `modelReady` push does not reach child/multi-window engines).
  /// Platform thread; `ready=false` while loading or when the instance is gone.
  Live2DInstance::ModelInfo GetModelInfo(const std::string& pet_id);

  /// The pet's display box in physical pixels. Rebuilds the render target (and
  /// re-registers the texture, notifying through TextureChangedFn) only when the
  /// box leaves the current target's headroom.
  bool SetBoxSize(const std::string& pet_id, int width, int height);

  // ---- queued to the render thread ---------------------------------------

  bool PostStartMotion(const std::string& pet_id, const std::string& group,
                       int index, int priority, bool loop);
  bool PostSetExpression(const std::string& pet_id, int index);
  bool PostSetParameter(const std::string& pet_id,
                        const std::string& parameter_id, double value);
  bool PostResetParameter(const std::string& pet_id,
                          const std::string& parameter_id);
  bool PostClearParameters(const std::string& pet_id);
  bool PostSetMotionSpeed(const std::string& pet_id, double speed);
  bool PostSetDragging(const std::string& pet_id, double x, double y);

 private:
  void RenderLoop();
  void Post(std::function<void()> command);
  std::shared_ptr<Live2DInstance> Find(const std::string& pet_id);
  bool StartDevice();
  void StopDevice();

  flutter::TextureRegistrar* texture_registrar_ = nullptr;

  Microsoft::WRL::ComPtr<ID3D11Device> device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> context_;
  Live2DAllocator allocator_;
  Csm::CubismFramework::Option cubism_option_{};
  bool ready_ = false;
  bool warp_fallback_ = false;
  int feature_level_ = 0;

  std::atomic<bool> running_{false};
  std::thread render_thread_;
  std::mutex queue_mutex_;
  std::deque<std::function<void()>> queue_;

  mutable std::mutex instances_mutex_;
  std::map<std::string, std::shared_ptr<Live2DInstance>> instances_;
};

}  // namespace pet_live2d
