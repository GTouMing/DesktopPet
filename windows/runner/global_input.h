#ifndef RUNNER_GLOBAL_INPUT_H_
#define RUNNER_GLOBAL_INPUT_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// Global low-level input hooks for the desktop pet host window.
//
// Implements:
//  - a configurable WH_KEYBOARD_LL hook (down/up semantics) for the quick
//    launch hotkey (e.g. Alt+G);
//  - an optional WH_MOUSE_LL "watch" hook for a configurable mouse button.
//
// The hooks are installed from the platform (main) thread, whose message loop
// (see main.cpp) services low-level hook callbacks - the same approach the
// win32hooks plugin uses. Events are forwarded to Dart through the
// "desktop_pet/global_input" method channel ("onTrigger").
namespace global_input {

// Registers the method channel on |messenger|. Must be called once per engine
// (primary window only) after the engine is created.
void RegisterWithMessenger(flutter::BinaryMessenger* messenger);

// Declares the overlay window (the host window, the only window the pets are
// drawn in). The hooks need it to tell whether another window of this process
// (the settings window) is really above a pet at the cursor: see
// OverOwnRealWindow in global_input.cpp. Call once, host window only.
void SetOverlayWindow(HWND window);

// Unhooks everything and releases the channel. Call before the engine is
// destroyed (FlutterWindow::OnDestroy).
void Shutdown();

}  // namespace global_input

#endif  // RUNNER_GLOBAL_INPUT_H_
