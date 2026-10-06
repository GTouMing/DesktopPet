#include "live2d_model.h"

#include <CubismDefaultParameterId.hpp>
#include <CubismModelSettingJson.hpp>
#include <Effect/CubismBreath.hpp>
#include <Effect/CubismEyeBlink.hpp>
#include <Id/CubismIdManager.hpp>
#include <Motion/CubismMotion.hpp>
#include <Physics/CubismPhysics.hpp>
#include <Rendering/D3D11/CubismRenderer_D3D11.hpp>

#include <algorithm>
#include <cstdio>
#include <cstring>

#include "live2d_log.h"
#include "live2d_pal.h"

using namespace Live2D::Cubism::Framework;
using namespace Live2D::Cubism::Framework::DefaultParameterId;

namespace pet_live2d {
namespace {

/// Safety margin around the model's content, as a fraction of the view. Without
/// it the artwork sits flush against the pet's box edge, which reads as clipped.
constexpr float kFitMargin = 0.04f;

/// Growth below this (on any edge, in model units) counts as "settled": it is
/// about a pixel on a 400px pet. Without it, sub-pixel physics wobble would keep
/// the box nominally growing forever and it would never lock.
constexpr float kBoundsGrowEpsilon = 0.002f;

/// Consecutive settled frames before the fit box is locked. One frame is not
/// enough - a motion can hold a pose for a frame in the middle of its arc.
constexpr int kBoundsStableFrames = 3;

/// The Cubism samples' breathing values - the de-facto standard that model
/// authors design their physics against (they tune the visible sway via the
/// physics `PhysicsSetting` output `Scale`s, not via the engine). The engine must
/// therefore NOT invent its own amplitude; the pack manifest may only scale the
/// standard down through `Live2DModel::SetBreathScale` (0 turns breathing off).
///
/// `CubismBreath` adds `peak * sin(...) * weight`, so weight and peak MULTIPLY.
/// Note a weight of 0 would silently silence the breath entirely (some Cubism
/// samples ship exactly that).
constexpr float kBreathAnglePeak = 15.0f;
constexpr float kBreathBodyPeak = 10.0f;
constexpr float kBreathCycle = 6.28f;
constexpr float kBreathParamOffset = 0.5f;
constexpr float kBreathParamPeak = 0.5f;
constexpr float kBreathParamCycle = 3.2345f;

/// Callers hand us a directory; every path we build from it is
/// `dir + fileName`, so a missing separator silently produces ".../packName.json".
std::string WithTrailingSeparator(const char* directory) {
  std::string value = directory ? directory : "";
  if (!value.empty() && value.back() != '\\' && value.back() != '/') {
    value.push_back('\\');
  }
  return value;
}

}  // namespace

Live2DModel::Live2DModel(Live2DTextureManager* texture_manager)
    : CubismUserModel(), texture_manager_(texture_manager) {
  id_param_angle_x_ = CubismFramework::GetIdManager()->GetId(ParamAngleX);
  id_param_angle_y_ = CubismFramework::GetIdManager()->GetId(ParamAngleY);
  id_param_angle_z_ = CubismFramework::GetIdManager()->GetId(ParamAngleZ);
  id_param_body_angle_x_ = CubismFramework::GetIdManager()->GetId(ParamBodyAngleX);
  id_param_eye_ball_x_ = CubismFramework::GetIdManager()->GetId(ParamEyeBallX);
  id_param_eye_ball_y_ = CubismFramework::GetIdManager()->GetId(ParamEyeBallY);
  id_param_breath_ = CubismFramework::GetIdManager()->GetId(ParamBreath);
}

Live2DModel::~Live2DModel() {
  ReleaseMotions();
  ReleaseExpressions();
  Csm::CubismBreath::Delete(_breath);
  _breath = nullptr;
  delete model_setting_;
  model_setting_ = nullptr;
}

Csm::csmByte* Live2DModel::CreateBuffer(const Csm::csmChar* path,
                                        Csm::csmSizeInt* size) {
  return pal::LoadFileAsBytes(path, size);
}

void Live2DModel::DeleteBuffer(Csm::csmByte* buffer) {
  pal::ReleaseBytes(buffer);
}

void Live2DModel::LoadAssets(const Csm::csmChar* model_dir,
                             const Csm::csmChar* model_file_name) {
  model_home_dir_ = WithTrailingSeparator(model_dir);
  Csm::csmSizeInt size = 0;
  const Csm::csmString path =
      Csm::csmString(model_home_dir_.c_str()) + model_file_name;
  Csm::csmByte* buffer = CreateBuffer(path.GetRawString(), &size);
  if (!buffer || size <= 0) return;

  model_setting_ = new CubismModelSettingJson(buffer, size);
  DeleteBuffer(buffer);
  SetupModel();
}

void Live2DModel::SetupModel() {
  _updating = true;
  _initialized = false;
  parameter_overrides_.Clear();

  {
    Csm::csmSizeInt size = 0;
    const Csm::csmString path =
        Csm::csmString(model_home_dir_.c_str()) + model_setting_->GetModelFileName();
    Csm::csmByte* buffer = CreateBuffer(path.GetRawString(), &size);
    if (!buffer || size <= 0) return;
    LoadModel(buffer, size);
    DeleteBuffer(buffer);
    if (!_model) return;
  }

  for (Csm::csmInt32 i = 0; i < model_setting_->GetExpressionCount(); ++i) {
    const Csm::csmChar* name = model_setting_->GetExpressionName(i);
    const Csm::csmString path = Csm::csmString(model_home_dir_.c_str()) +
                                model_setting_->GetExpressionFileName(i);
    Csm::csmSizeInt size = 0;
    Csm::csmByte* buffer = CreateBuffer(path.GetRawString(), &size);
    if (!buffer) continue;
    expressions_[name] = LoadExpression(buffer, size, name);
    DeleteBuffer(buffer);
  }

  if (strcmp(model_setting_->GetPhysicsFileName(), "") != 0) {
    const Csm::csmString path = Csm::csmString(model_home_dir_.c_str()) +
                                model_setting_->GetPhysicsFileName();
    Csm::csmSizeInt size = 0;
    Csm::csmByte* buffer = CreateBuffer(path.GetRawString(), &size);
    if (buffer) {
      LoadPhysics(buffer, size);
      DeleteBuffer(buffer);
    }
  }

  if (strcmp(model_setting_->GetPoseFileName(), "") != 0) {
    const Csm::csmString path = Csm::csmString(model_home_dir_.c_str()) +
                                model_setting_->GetPoseFileName();
    Csm::csmSizeInt size = 0;
    Csm::csmByte* buffer = CreateBuffer(path.GetRawString(), &size);
    if (buffer) {
      LoadPose(buffer, size);
      DeleteBuffer(buffer);
    }
  }

  if (model_setting_->GetEyeBlinkParameterCount() > 0) {
    _eyeBlink = CubismEyeBlink::Create(model_setting_);
  }

  // Breathing: the model's own swing input. Physics needs a parameter that keeps
  // changing, otherwise every pendulum settles and the pet is motionless between
  // motions. The values are always the Cubism standard; `breath_scale_` (from the
  // pack manifest) only scales them, and 0 skips breathing altogether. The model
  // ignores any id it does not have.
  if (breath_scale_ > 0.0f) {
    _breath = Csm::CubismBreath::Create();
    Csm::csmVector<Csm::CubismBreath::BreathParameterData> breath_parameters;
    breath_parameters.PushBack(Csm::CubismBreath::BreathParameterData(
        id_param_angle_x_, 0.0f, kBreathAnglePeak, kBreathCycle, breath_scale_));
    breath_parameters.PushBack(Csm::CubismBreath::BreathParameterData(
        id_param_angle_y_, 0.0f, kBreathAnglePeak, kBreathCycle, breath_scale_));
    breath_parameters.PushBack(Csm::CubismBreath::BreathParameterData(
        id_param_angle_z_, 0.0f, kBreathAnglePeak, kBreathCycle, breath_scale_));
    breath_parameters.PushBack(Csm::CubismBreath::BreathParameterData(
        id_param_body_angle_x_, 0.0f, kBreathBodyPeak, kBreathCycle,
        breath_scale_));
    breath_parameters.PushBack(Csm::CubismBreath::BreathParameterData(
        id_param_breath_, kBreathParamOffset, kBreathParamPeak, kBreathParamCycle,
        breath_scale_));
    _breath->SetParameters(breath_parameters);
  }

  for (Csm::csmInt32 i = 0; i < model_setting_->GetLipSyncParameterCount(); ++i) {
    lip_sync_ids_.PushBack(model_setting_->GetLipSyncParameterId(i));
  }

  if (strcmp(model_setting_->GetUserDataFile(), "") != 0) {
    const Csm::csmString path = Csm::csmString(model_home_dir_.c_str()) +
                                model_setting_->GetUserDataFile();
    Csm::csmSizeInt size = 0;
    Csm::csmByte* buffer = CreateBuffer(path.GetRawString(), &size);
    if (buffer) {
      LoadUserData(buffer, size);
      DeleteBuffer(buffer);
    }
  }

  for (Csm::csmInt32 i = 0; i < model_setting_->GetMotionGroupCount(); ++i) {
    PreloadMotionGroup(model_setting_->GetMotionGroupName(i));
  }

  _model->SaveParameters();
  bounds_valid_ = false;  // start the box over for the new model's vertices
  bounds_adapting_ = true;
  bounds_stable_frames_ = 0;
  _updating = false;
  _initialized = true;
}

void Live2DModel::SetupTextures() {
  auto* renderer = GetRenderer<Rendering::CubismRenderer_D3D11>();
  if (!renderer || !model_setting_) return;

  for (Csm::csmInt32 i = 0; i < model_setting_->GetTextureCount(); ++i) {
    if (strcmp(model_setting_->GetTextureFileName(i), "") == 0) continue;
    const Csm::csmString path = Csm::csmString(model_home_dir_.c_str()) +
                                model_setting_->GetTextureFileName(i);
    auto* texture = texture_manager_->CreateTextureFromPngFile(path.GetRawString());
    if (texture) renderer->BindTexture(i, texture->texture_view.Get());
  }
  renderer->IsPremultipliedAlpha(false);
}

void Live2DModel::PreloadMotionGroup(const Csm::csmChar* group) {
  for (Csm::csmInt32 i = 0; i < model_setting_->GetMotionCount(group); ++i) {
    const Csm::csmString path = Csm::csmString(model_home_dir_.c_str()) +
                                model_setting_->GetMotionFileName(group, i);
    Csm::csmSizeInt size = 0;
    Csm::csmByte* buffer = CreateBuffer(path.GetRawString(), &size);
    if (!buffer) continue;
    auto* motion = static_cast<CubismMotion*>(LoadMotion(buffer, size, nullptr));
    DeleteBuffer(buffer);
    if (!motion) continue;

    Csm::csmFloat32 fade_time = model_setting_->GetMotionFadeInTimeValue(group, i);
    if (fade_time >= 0.0f) motion->SetFadeInTime(fade_time);
    fade_time = model_setting_->GetMotionFadeOutTimeValue(group, i);
    if (fade_time >= 0.0f) motion->SetFadeOutTime(fade_time);

    char index[16];
    snprintf(index, sizeof(index), "%d", i);
    const Csm::csmString name = Csm::csmString(group) + "_" + index;
    motions_[name.GetRawString()] = motion;
  }
}

void Live2DModel::ReleaseMotions() {
  for (auto it = motions_.Begin(); it != motions_.End(); ++it) {
    Csm::ACubismMotion::Delete(it->Second);
  }
  motions_.Clear();
}

void Live2DModel::ReleaseExpressions() {
  for (auto it = expressions_.Begin(); it != expressions_.End(); ++it) {
    Csm::ACubismMotion::Delete(it->Second);
  }
  expressions_.Clear();
}

void Live2DModel::Update(Csm::csmFloat32 delta_time) {
  if (!_model) return;

  _dragManager->Update(delta_time);
  const Csm::csmFloat32 drag_x = _dragManager->GetX();
  const Csm::csmFloat32 drag_y = _dragManager->GetY();

  _model->LoadParameters();
  // Re-apply app-driven parameters: Cubism's LoadParameters() restores the
  // motion-saved values, which would otherwise discard a one-shot write from
  // Dart before it is ever rendered.
  ApplyParameterOverrides();

  if (_motionManager->IsFinished()) {
    // Explicit loop: replay only when the caller asked for it. The old plugin
    // hard-coded a restart of the "Idle" group here, which fought the app's own
    // state machine.
    if (loop_requested_) {
      StartPreloadedMotion(loop_group_.GetRawString(), loop_index_, loop_priority_);
    }
  } else {
    _motionManager->UpdateMotion(_model, delta_time * motion_speed_);
  }
  _model->SaveParameters();

  _model->AddParameterValue(id_param_angle_x_, drag_x * 30.0f);
  _model->AddParameterValue(id_param_angle_y_, drag_y * 30.0f);
  _model->AddParameterValue(id_param_angle_z_, drag_x * drag_y * -30.0f);
  _model->AddParameterValue(id_param_body_angle_x_, drag_x * 10.0f);
  _model->AddParameterValue(id_param_eye_ball_x_, drag_x);
  _model->AddParameterValue(id_param_eye_ball_y_, drag_y);

  if (_eyeBlink) _eyeBlink->UpdateParameters(_model, delta_time);
  // Breath before physics: it drives the angles that physics propagates to hair
  // and tail. It must run after the motion and add on top of it.
  if (_breath) _breath->UpdateParameters(_model, delta_time);
  if (_expressionManager) _expressionManager->UpdateMotion(_model, delta_time);
  if (_physics) _physics->Evaluate(_model, delta_time);
  if (_pose) _pose->UpdateParameters(_model, delta_time);
  _model->Update();

  // Measure here rather than in FitToView: the vertices are only meaningful once
  // the model has been updated, and the caller re-fits immediately after this,
  // so artwork that appeared this frame is fitted in the frame it appears.
  AccumulateContentBounds();
}

void Live2DModel::Draw(const Csm::CubismMatrix44& matrix) {
  if (!_model) return;
  Csm::CubismMatrix44 mvp = matrix;
  mvp.MultiplyByMatrix(_modelMatrix);
  auto* renderer = GetRenderer<Rendering::CubismRenderer_D3D11>();
  if (!renderer) return;
  renderer->SetMvpMatrix(&mvp);
  renderer->DrawModel();
}

bool Live2DModel::StartPreloadedMotion(const Csm::csmChar* group,
                                       Csm::csmInt32 index,
                                       Csm::csmInt32 priority) {
  if (!model_setting_ || !group) return false;
  char index_text[16];
  snprintf(index_text, sizeof(index_text), "%d", index);
  const Csm::csmString name = Csm::csmString(group) + "_" + index_text;
  if (!motions_.IsExist(name)) return false;

  if (priority == 3) {
    _motionManager->SetReservePriority(priority);
  } else if (!_motionManager->ReserveMotion(priority)) {
    return false;
  }
  // Actions are mutually exclusive: start every motion from the model's default
  // pose so the previous motion's leftovers are gone. Without this the per-frame
  // SaveParameters() in Update() carries a finished motion's pose into the saved
  // base, and a further motion that does not drive the same parameters (e.g. the
  // idle loop, which does not touch this pack's `chuipaopao*` props) never clears
  // it - measured: the "bubble gum" action's bubble stayed for every later action.
  ResetParametersToDefault();
  // The new action can drive parameters that reveal artwork, so re-open the fit
  // box's growth window: whatever it shows is fitted in the frame it appears.
  RestartBoundsAdaptation();
  _motionManager->StartMotionPriority(motions_[name], false, priority);
  return true;
}

void Live2DModel::ResetParametersToDefault() {
  if (!_model) return;
  const Csm::csmInt32 count = _model->GetParameterCount();
  for (Csm::csmInt32 i = 0; i < count; ++i) {
    _model->SetParameterValue(i, _model->GetParameterDefaultValue(i));
  }
  // App-driven parameters are not "leftovers": keep them across the reset.
  ApplyParameterOverrides();
  _model->SaveParameters();
}

void Live2DModel::ApplyParameterOverrides() {
  if (!_model) return;
  for (auto it = parameter_overrides_.Begin(); it != parameter_overrides_.End();
       ++it) {
    const Csm::CubismId* id =
        CubismFramework::GetIdManager()->GetId(it->First.GetRawString());
    if (_model->GetParameterIndex(id) < 0) continue;
    _model->SetParameterValue(id, it->Second);
  }
}

void Live2DModel::StartMotion(const Csm::csmChar* group, Csm::csmInt32 index,
                              Csm::csmInt32 priority, bool loop) {
  if (!model_setting_ || !group) return;
  const Csm::csmInt32 count = model_setting_->GetMotionCount(group);
  if (index < 0 || index >= count) return;
  if (!StartPreloadedMotion(group, index, priority)) return;

  loop_requested_ = loop;
  loop_group_ = Csm::csmString(group);
  loop_index_ = index;
  loop_priority_ = priority;
}

void Live2DModel::StopMotions() {
  if (_motionManager) _motionManager->StopAllMotions();
  loop_requested_ = false;
}

void Live2DModel::SetExpression(Csm::csmInt32 index) {
  if (!model_setting_ || index < 0 ||
      index >= model_setting_->GetExpressionCount()) {
    return;
  }
  const Csm::csmChar* name = model_setting_->GetExpressionName(index);
  if (expressions_.IsExist(name)) {
    _expressionManager->StartMotion(expressions_[name], false);
    RestartBoundsAdaptation();
  }
}

void Live2DModel::SetMotionSpeed(Csm::csmFloat32 speed) {
  motion_speed_ = speed > 0.0f ? speed : 0.0f;
}

void Live2DModel::SetDragging(Csm::csmFloat32 x, Csm::csmFloat32 y) {
  _dragManager->Set(x, y);
}

void Live2DModel::SetParameter(const Csm::csmChar* parameter_id,
                               Csm::csmFloat32 value) {
  if (!_model || !parameter_id) return;
  const Csm::CubismId* id = CubismFramework::GetIdManager()->GetId(parameter_id);
  // An unknown id would make CubismModel::SetParameterValue write out of bounds.
  if (_model->GetParameterIndex(id) < 0) return;
  parameter_overrides_[Csm::csmString(parameter_id)] = value;
  _model->SetParameterValue(id, value);
  // A parameter write is how the app shows props (the tunable groups), so it can
  // reveal artwork anywhere - let the box grow to cover it.
  RestartBoundsAdaptation();
}

void Live2DModel::ResetParameter(const Csm::csmChar* parameter_id) {
  if (!_model || !parameter_id) return;
  const Csm::CubismId* id = CubismFramework::GetIdManager()->GetId(parameter_id);
  const Csm::csmInt32 index = _model->GetParameterIndex(id);
  if (index < 0) return;
  // The model's OWN default, not 0: a slot group "clears" the options it is not
  // using, and 0 is not the neutral value in general - this model parks its base
  // hands at `ParamCheek5x = 1`, so zeroing them hid the hands. Pinned like
  // SetParameter so it survives the per-frame LoadParameters().
  const Csm::csmFloat32 value = _model->GetParameterDefaultValue(index);
  parameter_overrides_[Csm::csmString(parameter_id)] = value;
  _model->SetParameterValue(index, value);
  RestartBoundsAdaptation();
}

void Live2DModel::ClearParameterOverrides() {
  parameter_overrides_.Clear();
  RestartBoundsAdaptation();
}

void Live2DModel::FitToView(int width, int height) {
  if (!_model) return;
  view_width_ = width > 0 ? width : 1;
  view_height_ = height > 0 ? height : 1;

  // Fit the box `AccumulateContentBounds()` has grown, not the declared canvas:
  // this pack's artwork extends past its (normalized 1x1) canvas, so a canvas
  // fit crops the desk. Until the first Update has measured anything there is no
  // box yet, so fall back to the canvas for that one call.
  float min_x = 0.0f;
  float min_y = 0.0f;
  float max_x = 0.0f;
  float max_y = 0.0f;
  if (bounds_valid_) {
    min_x = bounds_min_x_;
    min_y = bounds_min_y_;
    max_x = bounds_max_x_;
    max_y = bounds_max_y_;
  } else {
    const float canvas_width = _model->GetCanvasWidth();
    const float canvas_height = _model->GetCanvasHeight();
    min_x = -canvas_width * 0.5f;
    max_x = canvas_width * 0.5f;
    min_y = -canvas_height * 0.5f;
    max_y = canvas_height * 0.5f;
  }

  const float content_width = max_x - min_x;
  const float content_height = max_y - min_y;
  if (content_width <= 0.0f || content_height <= 0.0f) return;

  auto* matrix = GetModelMatrix();
  // Scale/Translate MULTIPLY onto the current matrix, so reset first or the fit
  // accumulates across resizes.
  matrix->LoadIdentity();

  // Contain the content with a small margin, so nothing sits flush against the
  // pet's box edge (flush artwork reads as "clipped").
  const float usable = 2.0f * (1.0f - kFitMargin);
  const float fit = (std::min)(usable / content_width, usable / content_height);
  // The manifest's scale multiplies the automatic fit, and its translate is a
  // shift from the view centre - the same two knobs the reference implementation
  // exposes (`fit * manifest.scale`, `centre + manifest.translate`). Combining
  // them in ONE Translate() call is not cosmetic: Translate() SETS the
  // translation rather than adding to it, so a second call would drop the
  // centring term.
  const float scale = fit * (fit_scale_ > 0.0f ? fit_scale_ : 1.0f);
  matrix->Scale(scale, scale);
  matrix->Translate(-(min_x + max_x) * 0.5f * scale + fit_offset_x_,
                    -(min_y + max_y) * 0.5f * scale + fit_offset_y_);
}

void Live2DModel::SetFitAdjust(float scale, float offset_x, float offset_y) {
  fit_scale_ = scale > 0.0f ? scale : 1.0f;
  fit_offset_x_ = offset_x;
  fit_offset_y_ = offset_y;
}

void Live2DModel::AccumulateContentBounds() {
  if (!_model) return;
  // Locked and nothing has re-opened the window: the box is final, and this scan
  // is O(every vertex in the model), so it must not run on every frame for the
  // whole life of the pet. Everything that can reveal artwork re-arms it.
  if (!bounds_adapting_) return;
  bool seen = false;
  float min_x = 0.0f;
  float min_y = 0.0f;
  float max_x = 0.0f;
  float max_y = 0.0f;

  const Csm::csmInt32 drawable_count = _model->GetDrawableCount();
  for (Csm::csmInt32 i = 0; i < drawable_count; ++i) {
    // Only what is actually drawn this frame counts, i.e. the non-transparent
    // parts. A pack parks props (ds-whale-girl's whale, desk ornaments, hearts,
    // stickers, symbols) at opacity 0, and those parked poses sit nowhere near
    // the resting one - folding them in unconditionally left the pet filling
    // only ~60% of its box (measured). They enter the box the moment they are
    // revealed instead, which is what RestartBoundsAdaptation() is for.
    //
    // NOTE: `GetDrawableDynamicFlagIsVisible` is not consulted - this pack has
    // parts the flag reports as hidden while they are in fact drawn.
    if (_model->GetDrawableOpacity(i) <= 0.01f) continue;
    const Csm::csmInt32 vertex_count = _model->GetDrawableVertexCount(i);
    const auto* vertices = _model->GetDrawableVertexPositions(i);
    if (!vertices) continue;
    for (Csm::csmInt32 v = 0; v < vertex_count; ++v) {
      const float x = vertices[v].X;
      const float y = vertices[v].Y;
      if (!seen) {
        min_x = max_x = x;
        min_y = max_y = y;
        seen = true;
      } else {
        min_x = (std::min)(min_x, x);
        min_y = (std::min)(min_y, y);
        max_x = (std::max)(max_x, x);
        max_y = (std::max)(max_y, y);
      }
    }
  }
  if (!seen) return;

  // Skip degenerate/invalid results (e.g. queried before the first Update).
  if (max_x - min_x <= 0.0f || max_y - min_y <= 0.0f) return;

  if (!bounds_valid_) {
    bounds_min_x_ = min_x;
    bounds_min_y_ = min_y;
    bounds_max_x_ = max_x;
    bounds_max_y_ = max_y;
    bounds_valid_ = true;
    bounds_stable_frames_ = 0;
    LogLine("[l2d] bounds " + std::to_string(min_x) + "," +
            std::to_string(min_y) + " .. " + std::to_string(max_x) + "," +
            std::to_string(max_y));
    return;
  }

  // Grow-only union: artwork that has been on screen once stays inside the box
  // for the rest of the session, so it can never be clipped again. Whether the
  // box counts as having moved is decided with an epsilon; the union itself
  // always takes the exact values, so coverage stays exact.
  const bool grew = min_x < bounds_min_x_ - kBoundsGrowEpsilon ||
                    min_y < bounds_min_y_ - kBoundsGrowEpsilon ||
                    max_x > bounds_max_x_ + kBoundsGrowEpsilon ||
                    max_y > bounds_max_y_ + kBoundsGrowEpsilon;
  bounds_min_x_ = (std::min)(bounds_min_x_, min_x);
  bounds_min_y_ = (std::min)(bounds_min_y_, min_y);
  bounds_max_x_ = (std::max)(bounds_max_x_, max_x);
  bounds_max_y_ = (std::max)(bounds_max_y_, max_y);

  if (grew) {
    // Still discovering content: keep re-fitting, and restart the count.
    bounds_stable_frames_ = 0;
    return;
  }
  if (!bounds_adapting_) return;
  if (++bounds_stable_frames_ < kBoundsStableFrames) return;

  // Max reached: this is the box the model uses from here on, until something
  // new is revealed and re-opens the window.
  bounds_adapting_ = false;
  LogLine("[l2d] bounds locked " + std::to_string(bounds_min_x_) + "," +
          std::to_string(bounds_min_y_) + " .. " +
          std::to_string(bounds_max_x_) + "," +
          std::to_string(bounds_max_y_));
}

void Live2DModel::RestartBoundsAdaptation() {
  bounds_adapting_ = true;
  bounds_stable_frames_ = 0;
}

void Live2DModel::ResizeMaskBuffer(int width, int height) {
  auto* renderer = GetRenderer<Rendering::CubismRenderer_D3D11>();
  if (renderer) {
    renderer->SetDrawableClippingMaskBufferSize(
        static_cast<Csm::csmFloat32>(width),
        static_cast<Csm::csmFloat32>(height));
  }
}

bool Live2DModel::IsMotionPlaying() const {
  if (!_motionManager) return false;
  return !_motionManager->IsFinished() || loop_requested_;
}

Csm::csmInt32 Live2DModel::MotionCount(const Csm::csmChar* group) const {
  if (!model_setting_ || !group) return 0;
  return model_setting_->GetMotionCount(group);
}

}  // namespace pet_live2d
