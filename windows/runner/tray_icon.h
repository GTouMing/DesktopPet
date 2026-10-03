#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <windows.h>

namespace tray_icon {

// Removes the notification-area icon owned by |owner| (id 0), matching the
// NOTIFYICONDATA installed by the system_tray plugin. Safe to call when no
// icon exists.
//
// This is a native safety net so the icon does not linger as a "ghost" (which
// only clears when the mouse moves over the notification area) on teardown
// paths that bypass Dart's TrayManager.destroy(): OS shutdown/restart
// (WM_QUERYENDSESSION/WM_ENDSESSION) and window destruction (WM_DESTROY).
void RemoveForWindow(HWND owner);

}  // namespace tray_icon

#endif  // RUNNER_TRAY_ICON_H_
