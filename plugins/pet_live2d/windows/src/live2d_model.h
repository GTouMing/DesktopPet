#pragma once

#include <CubismFramework.hpp>
#include <ICubismModelSetting.hpp>
#include <Effect/CubismBreath.hpp>
#include <Math/CubismMatrix44.hpp>
#include <Model/CubismUserModel.hpp>
#include <Type/csmVector.hpp>

#include <string>
#include <vector>

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

  /// One parameter's metadata, read from the model itself. Dart derives the
  /// cursor-follow mapping from it: the standard look-at parameters' `[minimum,
  /// maximum]` give the scale, and `default_value` is the neutral baseline the
  /// follow is applied on top of (see `pet/mouse_follow.dart`).
  struct ParameterInfo {
    std::string id;
    float minimum = 0.0f;
    float maximum = 0.0f;
    float default_value = 0.0f;
  };

  /// Every parameter's metadata. Empty until the model is loaded.
  std::vector<ParameterInfo> GetParameterInfo() const;

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
  /// Restores `parameter_id` to the model's OWN default (pinned, like
  /// SetParameter). This is how a slot group undoes the option it is not using:
  /// 0 is NOT the neutral value in general - this model parks its base hands at
  /// `ParamCheek5x = 1`, so clearing them with 0 hid the hands entirely.
  void ResetParameter(const Csm::csmChar* parameter_id);
  void ClearParameterOverrides();

  /// Loads the model's textures into the Cubism D3D11 renderer.
  void SetupTextures();

  /// Measures the fit box ONCE from the model's resting (default) pose and
  /// freezes it. The pet is scaled and centred to this box for its whole
  /// lifetime: a prop revealed later (parameter write, action, expression) may
  /// extend past it and be clipped by the pet's window, but it can never shrink
  /// the pet on screen. Must run before the first FitToView().
  void MeasureRestingBounds();

  /// Fits the model to a view of `width` x `height` pixels, using the RESTING
  /// box frozen by `MeasureRestingBounds()` rather than the declared canvas: this
  /// pack's artwork extends past the (normalized 1x1) canvas, so a canvas fit
  /// crops the desk. The box never changes for the model's lifetime, so artwork
  /// revealed later can be clipped by the pet's window but can never rescale the
  /// pet down. Idempotent: the matrix is reset first, since Scale/Translate
  /// multiply.
  void FitToView(int width, int height);

  /// Clipping-mask buffers follow the render target's size.
  void ResizeMaskBuffer(int width, int height);

  /// Group names with motion counts, for diagnostics.
  Csm::csmInt32 MotionCount(const Csm::csmChar* group) const;

  /// True while a motion is in flight (or a loop is armed). The render loop uses
  /// this to give an active pet the full frame rate and a resting one a lower one.
  bool IsMotionPlaying() const;

  /// Framing declared by the pack manifest, applied on top of the automatic fit:
  /// [scale] multiplies it, and [offset_x]/[offset_y] shift the model away from
  /// the view centre. Offsets are in view units (1 = half the view's short side)
  /// with **+y up**, i.e. already flipped from the manifest's screen-space y.
  /// This is what the reference implementation does with its `live2d.scale` /
  /// `live2d.translate` (`scale.set(fit * manifest.scale)`,
  /// `position.set(w/2 + manifest.x, h/2 + manifest.y)`).
  void SetFitAdjust(float scale, float offset_x, float offset_y);

  /// Idle-breath amplitude: `1.0` is the Cubism samples' scale, `0` disables
  /// breathing. The engine always drives the STANDARD breath values (model authors
  /// tune their sway in the physics), so the pack manifest may only scale it down -
  /// how much a model may sway is the model's call, not the engine's.
  void SetBreathScale(float scale) { breath_scale_ = scale; }

 private:
  Csm::csmByte* CreateBuffer(const Csm::csmChar* path, Csm::csmSizeInt* size);
  void DeleteBuffer(Csm::csmByte* buffer);
  void SetupModel();
  void PreloadMotionGroup(const Csm::csmChar* group);
  void ReleaseMotions();
  void ReleaseExpressions();
  bool StartPreloadedMotion(const Csm::csmChar* group, Csm::csmInt32 index,
                            Csm::csmInt32 priority);
  /// Resets every parameter to the model's default and bakes that into the saved
  /// base. Called whenever a motion starts, so the pose a finished action left
  /// behind cannot leak into the next one (actions are mutually exclusive; see
  /// the call site).
  void ResetParametersToDefault();
  /// Writes `parameter_overrides_` onto the model. Must run after every
  /// `LoadParameters()` (and after ResetParametersToDefault), or a one-shot write
  /// from Dart is discarded by the restored base.
  void ApplyParameterOverrides();

  Csm::ICubismModelSetting* model_setting_ = nullptr;
  std::string model_home_dir_;
  Csm::csmFloat32 motion_speed_ = 1.0f;
  int view_width_ = 1;
  int view_height_ = 1;

  /// Manifest framing; see SetFitAdjust().
  float fit_scale_ = 1.0f;
  float fit_offset_x_ = 0.0f;
  float fit_offset_y_ = 0.0f;

  /// Fit box in model units: the resting pose's silhouette, measured once by
  /// MeasureRestingBounds() and never changed afterwards. A stable reference that
  /// keeps the pet the same size however much artwork a parameter or an action
  /// reveals. `bounds_valid_` is false until that measurement has run, in which
  /// case FitToView falls back to the declared canvas.
  bool bounds_valid_ = false;
  float bounds_min_x_ = 0.0f;
  float bounds_min_y_ = 0.0f;
  float bounds_max_x_ = 0.0f;
  float bounds_max_y_ = 0.0f;
  Live2DTextureManager* texture_manager_ = nullptr;

  /// Re-applied after every LoadParameters(); see the class comment.
  Csm::csmMap<Csm::csmString, Csm::csmFloat32> parameter_overrides_;
  Csm::csmVector<Csm::CubismIdHandle> lip_sync_ids_;

  /// Idle breathing: oscillates the head/body angles and `ParamBreath` every
  /// frame, which the physics then propagates to hair, tail and body. Without it
  /// those inputs stay constant and every pendulum settles, so the pet reads as
  /// stiff. `nullptr` when the pack disabled breathing. Scaled by `breath_scale_`.
  Csm::CubismBreath* _breath = nullptr;
  float breath_scale_ = 1.0f;
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
  const Csm::CubismId* id_param_breath_ = nullptr;
};

}  // namespace pet_live2d
