#include "overlay_window.h"

#include "channels.h"
#include "pet_cursor_surface.h"

#include <memory>
#include <string>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

namespace overlay_window {
namespace {

HWND g_window = nullptr;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

// Topmost watchdog (see RaiseToTopMost). One SetWindowPos per tick, with no
// move/size/activate, so it costs nothing visible.
constexpr UINT_PTR kTopmostTimerId = 0xDE5C;
constexpr UINT kTopmostTimerMs = 1000;

// The union of every monitor, in physical pixels.
RECT VirtualScreenRect() {
  const int x = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int y = ::GetSystemMetrics(SM_YVIRTUALSCREEN);
  return RECT{x, y, x + ::GetSystemMetrics(SM_CXVIRTUALSCREEN),
              y + ::GetSystemMetrics(SM_CYVIRTUALSCREEN)};
}

// Puts the window on OverlayWindowRect(). Re-applied on WM_DPICHANGED, where the
// default handler would otherwise resize us to Windows' own suggestion.
void ApplyOverlayGeometry() {
  if (g_window == nullptr) return;
  const RECT target = OverlayWindowRect();
  ::SetWindowPos(g_window, HWND_TOPMOST, target.left, target.top,
                 target.right - target.left, target.bottom - target.top,
                 SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

// Re-asserts the overlay's topmost band membership and keeps the pet cursor
// surface parked right under it (see RaiseToTopMost).
void ReassertTopMost() {
  RaiseToTopMost();
  pet_cursor_surface::ReassertBelowOverlay();
}

void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == channels::overlay::kGetVirtualScreenRect) {
    const RECT screen = VirtualScreenRect();
    flutter::EncodableMap map;
    map[flutter::EncodableValue(channels::overlay::kLeft)] =
        flutter::EncodableValue(static_cast<int32_t>(screen.left));
    map[flutter::EncodableValue(channels::overlay::kTop)] =
        flutter::EncodableValue(static_cast<int32_t>(screen.top));
    map[flutter::EncodableValue(channels::overlay::kWidth)] = flutter::EncodableValue(
        static_cast<int32_t>(screen.right - screen.left));
    map[flutter::EncodableValue(channels::overlay::kHeight)] = flutter::EncodableValue(
        static_cast<int32_t>(screen.bottom - screen.top));
    result->Success(flutter::EncodableValue(map));
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void RaiseToTopMost() {
  if (g_window == nullptr) return;
  ::SetWindowPos(g_window, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

RECT OverlayWindowRect() {
  const RECT screen = VirtualScreenRect();
  const int width = screen.right - screen.left;
  const int height = screen.bottom - screen.top;
  // Square, bottom-aligned with the desktop: see the header.
  return RECT{screen.left, screen.top + height - width, screen.left + width,
              screen.top + height};
}

void Install(HWND window, flutter::BinaryMessenger* messenger) {
  g_window = window;

  // Window styles (frameless / not resizable / not maximizable) belong to Dart
  // through window_manager - see AppHost.start(). Native only sets the extended
  // styles below, which window_manager cannot express.

  // The caption is removed from Dart (window_manager.setAsFrameless), which is
  // how this app's original host window did it.
  //
  // WS_EX_LAYERED | WS_EX_TRANSPARENT are set once and NEVER toggled: see the
  // header for why that, and not WM_NCHITTEST or a window region, is what keeps
  // the desktop usable. WS_EX_TOOLWINDOW keeps it out of the taskbar and
  // Alt+Tab; WS_EX_NOACTIVATE means clicking a pet never steals focus from the
  // app the user is working in.
  ::SetWindowLongPtrW(
      window, GWL_EXSTYLE,
      ::GetWindowLongPtrW(window, GWL_EXSTYLE) | WS_EX_LAYERED |
          WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);
  // A layered window without SetLayeredWindowAttributes is not composited
  // (looks missing), so always set it - but start at alpha 0: the window is
  // shown from Flutter's first-frame callback, which is still early enough for
  // its surface (not yet composited, defaulting to white) to flash the whole
  // desktop white for ~70ms (measured). Dart reveals it afterwards (AppHost.start
  // -> windowManager.setOpacity), so the reveal timing lives on one side only.
  ::SetLayeredWindowAttributes(window, 0, 0, LWA_ALPHA);

  ApplyOverlayGeometry();

  // Watchdog: Windows can drop the window out of the topmost band while leaving
  // WS_EX_TOPMOST set (see RaiseToTopMost), so re-assert on a timer in addition
  // to foreground changes.
  ::SetTimer(window, kTopmostTimerId, kTopmostTimerMs, nullptr);

  if (messenger != nullptr) {
    g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, channels::overlay::kName,
        &flutter::StandardMethodCodec::GetInstance());
    g_channel->SetMethodCallHandler(HandleMethodCall);
  }
}

void Shutdown() {
  if (g_window != nullptr) {
    ::KillTimer(g_window, kTopmostTimerId);
  }
  g_channel = nullptr;
  g_window = nullptr;
}

std::optional<LRESULT> HandleWindowMessage(HWND window, UINT message,
                                           WPARAM wparam, LPARAM lparam) {
  if (message == WM_GETMINMAXINFO) {
    // Windows limits a window's size to the maximum tracking size (roughly the
    // screen plus the frame) and enforces it while processing
    // WM_WINDOWPOSCHANGING. The overlay is square on purpose and therefore
    // taller than the screen (1920x1920 on a 1080-tall desktop, bottom-aligned),
    // so without this it is silently truncated and the frame comes out squashed.
    //
    // This runs before the engine's plugins and before DefWindowProc, so it wins.
    auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
    const RECT target = OverlayWindowRect();
    const LONG width = target.right - target.left;
    const LONG height = target.bottom - target.top;
    info->ptMaxTrackSize.x = width;
    info->ptMaxTrackSize.y = height;
    info->ptMaxSize.x = width;
    info->ptMaxSize.y = height;
    return 0;
  }

  if (message == WM_DPICHANGED) {
    ApplyOverlayGeometry();
    if (g_channel != nullptr) {
      // Dart owns the scene rectangles; ask it to re-derive them.
      g_channel->InvokeMethod(channels::overlay::kOnGeometryChanged, nullptr);
    }
    return 0;
  }

  if (message == WM_ACTIVATEAPP) {
    // Another app took (or gave back) the foreground - the z order is being
    // reshuffled, which is when the window tends to slip out of the topmost
    // band. Re-assert now; the timer is the safety net for band changes that
    // happen without an activation event.
    ReassertTopMost();
    return std::nullopt;
  }

  if (message == WM_TIMER && wparam == kTopmostTimerId) {
    ReassertTopMost();
    return 0;
  }

  return std::nullopt;
}

}  // namespace overlay_window
