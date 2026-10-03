#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <mmkv_win32/mmkv_win32_plugin.h>
#include <window_manager/window_manager_plugin.h>

#include "global_input.h"
#include "overlay_window.h"
#include "pet_cursor_surface.h"
#include "settings_window.h"
#include "tray_icon.h"

namespace {

// Registers the plugins the settings window engine needs.
//
// The settings window is the app's only dmw child engine: pets and the ring menu
// are drawn by the overlay engine (this one), so a child engine only needs
// enough to run a normal 800x600 settings window.
//
// Left out on purpose:
//   - system_tray / flutter_alone: owned by the overlay
//     (lib/platform/windows/tray_manager.dart, lib/main.dart);
//   - audioplayers: pets play sound, and pets live in the overlay engine;
//   - screen_retriever: only reached by window_manager's setAlignment/center,
//     which the settings window never calls.
// desktop_multi_window must stay: a child engine's window identity and its
// window channel come from it (MultiWindowManager::Create).
void RegisterChildPlugins(flutter::PluginRegistry* registry) {
  DesktopMultiWindowPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DesktopMultiWindowPlugin"));
  MmkvWin32PluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MmkvWin32Plugin"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project, bool auto_show)
    : project_(project), show_on_first_frame_(auto_show) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // Global quick-launch input hooks (host window only; child windows do not
  // go through FlutterWindow::OnCreate).
  global_input::RegisterWithMessenger(flutter_controller_->engine()->messenger());
  // The hooks compare z order against this window: a pet drawn on top of the
  // settings window must keep the click (see OverOwnRealWindow).
  global_input::SetOverlayWindow(GetHandle());
  // Single-window overlay: window styles, geometry and the click-through
  // contract (see overlay_window.h).
  overlay_window::Install(GetHandle(), flutter_controller_->engine()->messenger());
  // Keeps the cursor shape out of the hands of the window under a pet
  // (see pet_cursor_surface.h). Driven by the hooks registered just above.
  pet_cursor_surface::Install(GetHandle());
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *registry = flutter_view_controller->engine();
    // Child engines register only the plugins they need (see
    // RegisterChildPlugins); the host gets the full set above.
    RegisterChildPlugins(registry);
    // Native window control for the settings window itself (the only child
    // engine): z-order changes window_manager cannot express. Taken straight
    // from the engine/view - going through PluginRegistrarManager would need
    // flutter_wrapper_plugin, which this target does not link.
    auto *view = flutter_view_controller->view();
    settings_window::Install(
        registry->messenger(),
        view != nullptr ? ::GetAncestor(view->GetNativeWindow(), GA_ROOT)
                        : nullptr);
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (show_on_first_frame_) {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Release input hooks before the engine/messenger goes away.
  overlay_window::Shutdown();
  global_input::Shutdown();
  // The surface is driven by those hooks: tear it down once they are gone.
  pet_cursor_surface::Shutdown();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Overlay hit-testing / watchdog take precedence.
  if (auto overlay_result =
          overlay_window::HandleWindowMessage(hwnd, message, wparam, lparam)) {
    return *overlay_result;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_QUERYENDSESSION:
    case WM_ENDSESSION:
    case WM_DESTROY:
      // Native safety net: remove the notification-area icon while the owner
      // window is still valid, so it cannot linger as a ghost on teardown
      // paths that bypass Dart's TrayManager.destroy() (OS shutdown/restart,
      // window destruction).
      tray_icon::RemoveForWindow(hwnd);
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
