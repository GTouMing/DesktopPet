#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "crash_handler.h"
#include "flutter_window.h"
#include "overlay_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Windows Error Reporting may be disabled on the target machine, so install
  // our own handler to leave a crash log / minidump behind.
  crash_handler::Install();

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Single-window overlay: this is the app's only window.
  //
  // The geometry is deliberately square (see overlay_window.h: OverlayWindowRect)
  // and the size is applied *before* the engine exists, so the engine's view -
  // and hence its rendering surface - is created at its final size and never has
  // to be recreated.
  //
  // Only the size is set here: the rectangle's origin is above the screen
  // (negative Y) and Win32Window::Point takes an unsigned value, so Install
  // moves the window into place instead. A move does not recreate the surface.
  const RECT overlay_rect = overlay_window::OverlayWindowRect();

  FlutterWindow window(project, /*auto_show=*/true);
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(
      static_cast<unsigned int>(overlay_rect.right - overlay_rect.left),
      static_cast<unsigned int>(overlay_rect.bottom - overlay_rect.top));
  if (!window.Create(L"desktop_pet", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  // Use PeekMessage+GetMessage hybrid so non-queued sent messages
  // (used by system tray plugin) are dispatched properly.
  while (true) {
    while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
      if (msg.message == WM_QUIT) {
        ::CoUninitialize();
        return static_cast<int>(msg.wParam);
      }
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }
    // Let Flutter engine process pending frames while waiting
    ::MsgWaitForMultipleObjects(0, nullptr, FALSE, 1, QS_ALLINPUT);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
