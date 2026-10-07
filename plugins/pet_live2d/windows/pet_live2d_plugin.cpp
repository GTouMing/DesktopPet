#include "pet_live2d_plugin.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <string>

namespace pet_live2d {
namespace {

constexpr char kChannelName[] = "desktop_pet/live2d";

/// Render-target bounds. The Dart side derives the wanted size from the pet
/// pack's frame size, the scale ceiling and the device pixel ratio - it is the
/// pet's maximum plausible size, so scaling never has to touch the texture.
constexpr int kMinTarget = 64;
constexpr int kMaxTarget = 4096;
constexpr int kDefaultTarget = 512;

const flutter::EncodableMap* AsMap(const flutter::EncodableValue* value) {
  return value ? std::get_if<flutter::EncodableMap>(value) : nullptr;
}

std::string StringArg(const flutter::EncodableMap& args, const char* key,
                      const char* fallback = "") {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return fallback;
  const auto* value = std::get_if<std::string>(&it->second);
  return value ? *value : fallback;
}

int IntArg(const flutter::EncodableMap& args, const char* key, int fallback) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return fallback;
  if (const auto* value = std::get_if<int32_t>(&it->second)) return *value;
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*value);
  }
  return fallback;
}

double DoubleArg(const flutter::EncodableMap& args, const char* key,
                 double fallback) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return fallback;
  if (const auto* value = std::get_if<double>(&it->second)) return *value;
  if (const auto* value = std::get_if<int32_t>(&it->second)) return *value;
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<double>(*value);
  }
  return fallback;
}

bool BoolArg(const flutter::EncodableMap& args, const char* key,
             bool fallback) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return fallback;
  const auto* value = std::get_if<bool>(&it->second);
  return value ? *value : fallback;
}

/// Encodes parameter metadata for the channel (see `ModelParameter` in Dart).
flutter::EncodableList EncodeParameters(
    const std::vector<Live2DModel::ParameterInfo>& parameters) {
  flutter::EncodableList list;
  list.reserve(parameters.size());
  for (const auto& parameter : parameters) {
    flutter::EncodableMap entry;
    entry[flutter::EncodableValue("id")] =
        flutter::EncodableValue(parameter.id);
    entry[flutter::EncodableValue("min")] =
        flutter::EncodableValue(static_cast<double>(parameter.minimum));
    entry[flutter::EncodableValue("max")] =
        flutter::EncodableValue(static_cast<double>(parameter.maximum));
    entry[flutter::EncodableValue("default")] =
        flutter::EncodableValue(static_cast<double>(parameter.default_value));
    list.push_back(flutter::EncodableValue(entry));
  }
  return list;
}

}  // namespace

void PetLive2DPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto* channel_pointer = channel.get();
  auto plugin =
      std::make_unique<PetLive2DPlugin>(registrar, std::move(channel));
  channel_pointer->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

PetLive2DPlugin::PetLive2DPlugin(
    flutter::PluginRegistrarWindows* registrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : channel_(std::move(channel)),
      runtime_(std::make_unique<Live2DRuntime>(registrar->texture_registrar())) {
  runtime_->Start();
}

PetLive2DPlugin::~PetLive2DPlugin() { runtime_->Stop(); }

void PetLive2DPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  const flutter::EncodableMap* args =
      AsMap(method_call.arguments() ? method_call.arguments() : nullptr);

  if (method == "getStatus") {
    flutter::EncodableMap status;
    status[flutter::EncodableValue("ready")] =
        flutter::EncodableValue(runtime_->ready());
    status[flutter::EncodableValue("warpFallback")] =
        flutter::EncodableValue(runtime_->warp_fallback());
    status[flutter::EncodableValue("featureLevel")] =
        flutter::EncodableValue(runtime_->feature_level());
    status[flutter::EncodableValue("instances")] =
        flutter::EncodableValue(static_cast<int32_t>(runtime_->instance_count()));
    result->Success(flutter::EncodableValue(status));
    return;
  }

  if (!runtime_->ready()) {
    result->Error("RUNTIME_NOT_READY", "Live2D runtime failed to initialise.");
    return;
  }
  if (!args) {
    result->Error("INVALID_ARGS", "This method requires an argument map.");
    return;
  }

  if (method == "create") {
    const std::string pet_id = StringArg(*args, "petId");
    const std::string model_dir = StringArg(*args, "modelDir");
    const std::string model_file = StringArg(*args, "modelFileName");
    const int width =
        std::clamp(IntArg(*args, "widthPx", kDefaultTarget), kMinTarget, kMaxTarget);
    const int height = std::clamp(IntArg(*args, "heightPx", kDefaultTarget),
                                  kMinTarget, kMaxTarget);
    // Manifest framing (`scale` / `translate`): the same two knobs the reference
    // implementation exposes (`scale.set(fit * manifest.scale)`,
    // `position.set(w/2 + x, h/2 + y)`). The offsets arrive in view units
    // (1 = half the box's short side) and in screen orientation (+y down).
    const double fit_scale = DoubleArg(*args, "fitScale", 1.0);
    const double fit_offset_x = DoubleArg(*args, "fitOffsetX", 0.0);
    const double fit_offset_y = DoubleArg(*args, "fitOffsetY", 0.0);
    // Idle-breath amplitude from the pack manifest (1 = Cubism standard, 0 = off).
    const double breath_scale = DoubleArg(*args, "breathScale", 1.0);
    if (pet_id.empty() || model_dir.empty() || model_file.empty()) {
      result->Error("INVALID_ARGS",
                    "create requires petId, modelDir and modelFileName.");
      return;
    }
    const int64_t texture_id = runtime_->Create(
        pet_id, model_dir, model_file, width, height, fit_scale, fit_offset_x,
        fit_offset_y, breath_scale);
    if (texture_id < 0) {
      result->Error("CREATE_FAILED", "Could not create the Live2D render target.");
      return;
    }
    flutter::EncodableMap reply;
    reply[flutter::EncodableValue("textureId")] =
        flutter::EncodableValue(texture_id);
    reply[flutter::EncodableValue("widthPx")] = flutter::EncodableValue(width);
    reply[flutter::EncodableValue("heightPx")] = flutter::EncodableValue(height);
    result->Success(flutter::EncodableValue(reply));
    return;
  }

  if (method == "dispose") {
    result->Success(
        flutter::EncodableValue(runtime_->Destroy(StringArg(*args, "petId"))));
    return;
  }

  if (method == "getModelInfo") {
    const auto info = runtime_->GetModelInfo(StringArg(*args, "petId"));
    flutter::EncodableMap reply;
    reply[flutter::EncodableValue("ready")] =
        flutter::EncodableValue(info.ready);
    reply[flutter::EncodableValue("parameters")] =
        flutter::EncodableValue(EncodeParameters(info.parameters));
    result->Success(flutter::EncodableValue(reply));
    return;
  }

  const bool ok = [&]() -> bool {
    const std::string pet_id = StringArg(*args, "petId");
    if (pet_id.empty()) return false;

    if (method == "setMotion") {
      return runtime_->PostStartMotion(
          pet_id, StringArg(*args, "group"), IntArg(*args, "index", 0),
          IntArg(*args, "priority", 2), BoolArg(*args, "loop", false));
    }
    if (method == "setExpression") {
      return runtime_->PostSetExpression(pet_id, IntArg(*args, "index", 0));
    }
    if (method == "setParameter") {
      return runtime_->PostSetParameter(pet_id, StringArg(*args, "parameterId"),
                                        DoubleArg(*args, "value", 0.0));
    }
    if (method == "resetParameter") {
      return runtime_->PostResetParameter(pet_id,
                                          StringArg(*args, "parameterId"));
    }
    if (method == "clearParameters") {
      return runtime_->PostClearParameters(pet_id);
    }
    if (method == "setMotionSpeed") {
      return runtime_->PostSetMotionSpeed(pet_id, DoubleArg(*args, "speed", 1.0));
    }
    if (method == "setDragging") {
      return runtime_->PostSetDragging(pet_id, DoubleArg(*args, "x", 0.0),
                                       DoubleArg(*args, "y", 0.0));
    }
    return false;
  }();

  if (ok) {
    result->Success();
    return;
  }
  if (method == "setMotion" || method == "setExpression" ||
      method == "setParameter" || method == "resetParameter" ||
      method == "clearParameters" || method == "setMotionSpeed" ||
      method == "setDragging") {
    // Unknown pet: the instance is gone (pet removed). Not an error worth
    // surfacing - the Dart side keeps pushing until it is told to stop.
    result->Success(flutter::EncodableValue(false));
    return;
  }
  result->NotImplemented();
}

}  // namespace pet_live2d
