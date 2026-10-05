#pragma once

#include <CubismFramework.hpp>
#include <ICubismModelSetting.hpp>
#include <Math/CubismMatrix44.hpp>
#include <Model/CubismUserModel.hpp>
#include <Type/csmVector.hpp>

#include <string>

#include "live2d_texture_manager.h"

namespace pet_live2d {

/// One Cubism model. Ported from live2d_flutter's Live2DModel with three
/// deliberate design changes:
///
///  * `SetParameter` records an override that is re-applied after every
///    `LoadParameters()`. The old plugin needed a source patch for this because
///    Cubism restores motion-saved values each frame, which silently discarded
///    one-shot writes from Dart.
///  * looping is explicit (`StartMotion(..., loop)`); the old plugin hard-coded
///    "restart the Idle group whenever the queue drains", which fought the app's
///    own state machine.
///  * the model is owned by the runtime, not by a Flutter view, so it survives
///    widget churn and resizes.
class Live2DModel : public Csm::CubismUserModel {
 public:
  explicit Live2DModel(Live2DTextureManager* texture_manager);
  ~Live2DModel() override;

  Live2DModel(const Live2DModel&) = delete;
  Live2DModel& operator=(const Live2DModel&) = delete;

  void LoadAssets(const Csm::csmChar* model_dir,
                  const Csm::csmChar* model_file_name);
  bool IsLoaded() const { return model_setting_ != nullptr && _model != nullptr; }

  /// Advances the model by `delta_time` seconds. Call with a FIXED step: Cubism
  /// motion evaluation assumes a constant frame delta.
  void Update(Csm::csmFloat32 delta_time);

  void Draw(const Csm::CubismMatrix44& matrix);

  void StartMotion(const Csm::csmChar* group, Csm::csmInt32 index,
                   Csm::csmInt32 priority, bool loop);
  void StopMotions();
  void SetExpression(Csm::csmInt32 index);
  void SetMotionSpeed(Csm::csmFloat32 speed);
  void SetDragging(Csm::csmFloat32 x, Csm::csmFloat32 y);

  void SetParameter(const Csm::csmChar* parameter_id, Csm::csmFloat32 value);
  void ClearParameterOverrides();

  /// Loads the model's textures into the Cubism D3D11 renderer.
  void SetupTextures();

  /// Fits the model to a view of `width` x `height` pixels, using the model's
  /// actual vertex bounds rather than its declared canvas: this pack's artwork
  /// extends past the (normalized 1x1) canvas, so a canvas fit crops the desk.
  /// Idempotent: the matrix is reset first, since SetWidth/SetHeight multiply.
  void FitToView(int width, int height);

  /// Clipping-mask buffers follow the render target's size.
  void ResizeMaskBuffer(int width, int height);

  /// Group names with motion counts, for diagnostics.
  Csm::csmInt32 MotionCount(const Csm::csmChar* group) const;

  /// True while a motion is in flight (or a loop is armed). The render loop uses
  /// this to give an active pet the full frame rate and a resting one a lower one.
  bool IsMotionPlaying() const;

 private:
  Csm::csmByte* CreateBuffer(const Csm::csmChar* path, Csm::csmSizeInt* size);
  void DeleteBuffer(Csm::csmByte* buffer);
  void SetupModel();
  void PreloadMotionGroup(const Csm::csmChar* group);
  void ReleaseMotions();
  void ReleaseExpressions();
  bool StartPreloadedMotion(const Csm::csmChar* group, Csm::csmInt32 index,
                            Csm::csmInt32 priority);
  /// Caches the min/max of every drawable's vertices. Needs one `Update()` to
  /// have run, otherwise the vertices are not deformed yet.
  void ComputeContentBounds();

  Csm::ICubismModelSetting* model_setting_ = nullptr;
  std::string model_home_dir_;
  Csm::csmFloat32 motion_speed_ = 1.0f;
  int view_width_ = 1;
  int view_height_ = 1;

  /// Vertex bounds of the model's content, in model units.
  bool bounds_valid_ = false;
  float bounds_min_x_ = 0.0f;
  float bounds_min_y_ = 0.0f;
  float bounds_max_x_ = 0.0f;
  float bounds_max_y_ = 0.0f;
  Live2DTextureManager* texture_manager_ = nullptr;

  /// Re-applied after every LoadParameters(); see the class comment.
  Csm::csmMap<Csm::csmString, Csm::csmFloat32> parameter_overrides_;
  Csm::csmVector<Csm::CubismIdHandle> lip_sync_ids_;
  Csm::csmMap<Csm::csmString, Csm::ACubismMotion*> motions_;
  Csm::csmMap<Csm::csmString, Csm::ACubismMotion*> expressions_;

  /// Loop bookkeeping: when the queue drains, the last motion is replayed iff it
  /// was requested with `loop`.
  bool loop_requested_ = false;
  Csm::csmString loop_group_;
  Csm::csmInt32 loop_index_ = 0;
  Csm::csmInt32 loop_priority_ = 2;

  const Csm::CubismId* id_param_angle_x_ = nullptr;
  const Csm::CubismId* id_param_angle_y_ = nullptr;
  const Csm::CubismId* id_param_angle_z_ = nullptr;
  const Csm::CubismId* id_param_body_angle_x_ = nullptr;
  const Csm::CubismId* id_param_eye_ball_x_ = nullptr;
  const Csm::CubismId* id_param_eye_ball_y_ = nullptr;
};

}  // namespace pet_live2d
