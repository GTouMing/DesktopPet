#ifndef RUNNER_SETTINGS_WINDOW_H_
#define RUNNER_SETTINGS_WINDOW_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// Native window control for the settings window engine (the dmw child engine).
//
// window_manager cannot express the one thing this window needs (see
// lib/platform/windows/settings_window.dart): clearing WS_EX_TOPMOST is only
// possible through SetWindowPos(HWND_NOTOPMOST), and that call also raises the
// window above every non-topmost window - i.e. above the application the user
// just activated, which is the exact opposite of "the panel goes to the
// background". So dropping the topmost flag needs a second step that puts the
// window back behind that application.
//
// Channel: "desktop_pet/settings_window" (methods: "toBack").
namespace settings_window {

// Registers the channel on |messenger| and remembers |window| (the child
// engine's top-level window). Call once, for the child engine only, from
// DesktopMultiWindowSetWindowCreatedCallback (flutter_window.cpp).
void Install(flutter::BinaryMessenger* messenger, HWND window);

}  // namespace settings_window

#endif  // RUNNER_SETTINGS_WINDOW_H_
