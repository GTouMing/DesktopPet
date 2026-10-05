#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <memory>

#include "src/live2d_runtime.h"

namespace pet_live2d {

/// Channel front-end for the Live2D runtime.
///
/// Deliberately thinner than live2d_flutter's plugin: there is no view
/// lifetime, no attach/detach dance and no per-view renderer. Pets are
/// addressed by a caller-supplied `petId` for their whole life.
class PetLive2DPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  PetLive2DPlugin(
      flutter::PluginRegistrarWindows* registrar,
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel);
  ~PetLive2DPlugin() override;

  PetLive2DPlugin(const PetLive2DPlugin&) = delete;
  PetLive2DPlugin& operator=(const PetLive2DPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  /// Pushes `modelReady`: the Dart side swaps a warmed-up instance in only once
  /// it can actually draw, so a resize never shows a blank frame.
  void SendModelReady(const std::string& pet_id);

  /// Kept alive (unlike the usual plugin template, which lets the channel die
  /// after registration) because we also call INTO Dart.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<Live2DRuntime> runtime_;
};

}  // namespace pet_live2d
