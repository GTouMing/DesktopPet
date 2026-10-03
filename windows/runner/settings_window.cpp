#include "settings_window.h"

#include <string.h>
#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "channels.h"

namespace settings_window {
namespace {

HWND g_window = nullptr;

// Held for the lifetime of the engine: the handler lives in the channel object.
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

// Whether |window| is one of the shell's desktop windows.
//
// Inserting below one of those would bury this window under the wallpaper.
bool IsDesktopWindow(HWND window) {
  wchar_t class_name[64] = {};
  if (::GetClassNameW(window, class_name, 64) == 0) {
    return false;
  }
  return wcscmp(class_name, L"Progman") == 0 ||
         wcscmp(class_name, L"WorkerW") == 0;
}

// Clears WS_EX_TOPMOST and leaves the window behind the one the user activated.
//
// The activation that caused this call already happened, so the plain
// HWND_NOTOPMOST raise must be undone - see the header.
void ToBack() {
  const HWND window = g_window;
  if (window == nullptr || !::IsWindow(window)) {
    return;
  }

  ::SetWindowPos(window, HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  const HWND foreground = ::GetForegroundWindow();
  if (foreground == nullptr || foreground == window) {
    return;
  }
  // Inserting below a topmost window would put this one back into the topmost
  // band, and below the desktop would hide it: both cases keep the raise.
  if ((::GetWindowLongPtrW(foreground, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0) {
    return;
  }
  if (IsDesktopWindow(foreground)) {
    return;
  }
  ::SetWindowPos(window, foreground, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == channels::settings::kToBack) {
    ToBack();
    result->Success(flutter::EncodableValue(true));
    return;
  }
  result->NotImplemented();
}

}  // namespace

void Install(flutter::BinaryMessenger* messenger, HWND window) {
  if (messenger == nullptr || g_channel != nullptr) {
    return;
  }
  g_window = window;
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, channels::settings::kName,
    &flutter::StandardMethodCodec::GetInstance());
  g_channel->SetMethodCallHandler([](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

}  // namespace settings_window
