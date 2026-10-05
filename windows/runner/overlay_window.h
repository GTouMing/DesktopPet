#ifndef RUNNER_OVERLAY_WINDOW_H_
#define RUNNER_OVERLAY_WINDOW_H_

#include <windows.h>

#include <flutter/binary_messenger.h>

#include <optional>

// Single-window overlay support for the desktop pet host window.
//
// The host window is the *only* window the app owns on Windows: it hosts every
// pet plus the ring menu as Flutter content. The settings form needs real window
// input (focus, keyboard, IME), so it lives in its own real window
// (lib/platform/windows/settings_window.dart) rather than in a region of this
// one.
//
// ## Why the window is square
//
// See OverlayWindowRect(). In short: on this platform the engine's rendering
// surface always comes out square - its height equals the window *width* - and
// Windows then stretches it into the window's client area. A non-square client
// squashes the whole frame vertically by height/width (pixel-measured at three
// sizes: 1920x1080 -> 0.5625, 1000x800 -> 0.8, 800x600 -> 0.75) and anchors it
// to the bottom. A square client makes that stretch an identity, and Dart draws
// the scene into the bottom (width x height) band so all coordinates stay in
// plain desktop space.
//
// ## Why the desktop stays usable
//
// Not with WM_NCHITTEST and not by shaping the window:
//
//   * Returning HTTRANSPARENT from WM_NCHITTEST only forwards the message to
//     windows **in the same thread**, so it cannot pass a click to another
//     process - "interactive regions" built that way swallow every click that
//     lands outside them.
//   * WS_EX_TRANSPARENT does pass clicks through, but only in combination with
//     WS_EX_LAYERED, and shaping the window with SetWindowRgn instead makes a
//     missing/empty region swallow the whole desktop.
//
// So WS_EX_LAYERED | WS_EX_TRANSPARENT are set once and never toggled: the
// system skips this window entirely during hit-testing, and a full-desktop
// window can therefore never swallow a click, no matter what the Flutter side
// does or fails to do.
//
// Pets get their mouse input from the process-wide low-level hook instead
// (windows/runner/global_input.cpp + lib/pet/pet_pointer_router.dart), so a drag
// keeps working even when the cursor leaves the pet.
namespace overlay_window {

// Returns the overlay window's target rectangle, in physical screen pixels.
//
// Deliberately SQUARE: (desktop_width x desktop_width), positioned so that its
// bottom desktop_height rows line up exactly with the desktop.
RECT OverlayWindowRect();

// Applies the overlay window styles and geometry, and registers the
// "desktop_pet/overlay" method channel. Call once, from
// FlutterWindow::OnCreate (host window only).
void Install(HWND window, flutter::BinaryMessenger* messenger);

// Releases the channel. Call from FlutterWindow::OnDestroy.
void Shutdown();

// Puts the overlay back at the top of the topmost band, without moving,
// resizing or activating it. Idempotent; safe to call at any time.
//
// Windows can silently drop a topmost window out of the topmost band while
// leaving WS_EX_TOPMOST set (measured on Windows 10 while another
// always-on-top overlay churns the z order): the style bit alone then stops
// keeping the window above ordinary windows, and because the overlay is
// WS_EX_NOACTIVATE it can never be activated to be raised back. The window
// therefore re-asserts itself on foreground changes and on a timer (see
// HandleWindowMessage); call this to do it on demand.
void RaiseToTopMost();

// Routes window messages (WM_GETMINMAXINFO / WM_DPICHANGED / WM_ACTIVATEAPP /
// the topmost watchdog WM_TIMER). Returns a result when the message is handled;
// call before the Flutter controller handles it.
std::optional<LRESULT> HandleWindowMessage(HWND window, UINT message,
                                           WPARAM wparam, LPARAM lparam);

}  // namespace overlay_window

#endif  // RUNNER_OVERLAY_WINDOW_H_
