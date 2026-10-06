#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <memory>
#include <mutex>
#include <string>
#include <vector>

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
  /// Queues `modelReady`: the Dart side swaps a warmed-up instance in only once
  /// it can actually draw, so a resize never shows a blank frame.
  ///
  /// Called from the runtime's RENDER thread. A platform-channel message may only
  /// be sent from the platform thread (otherwise the engine logs "sent a message
  /// on a non-platform thread" and may drop it), so this only enqueues and posts
  /// a window message; [FlushModelReady] does the actual send.
  void SendModelReady(const std::string& pet_id);

  /// Drains queued pet ids on the platform thread and invokes the channel.
  void FlushModelReady();

  flutter::PluginRegistrarWindows* registrar_ = nullptr;

  /// Top-level window that receives the posted `modelReady` notification.
  HWND ready_window_ = nullptr;
  int window_proc_id_ = -1;

  std::mutex ready_mutex_;
  std::vector<std::string> ready_queue_;

  /// Kept alive (unlike the usual plugin template, which lets the channel die
  /// after registration) because we also call INTO Dart.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<Live2DRuntime> runtime_;
};

}  // namespace pet_live2d
