#include "tray_icon.h"

#include <shellapi.h>

namespace tray_icon {

void RemoveForWindow(HWND owner) {
  if (owner == nullptr) {
    return;
  }
  NOTIFYICONDATAW nid = {};
  nid.cbSize = {sizeof(NOTIFYICONDATAW)};
  nid.hWnd = owner;
  nid.uID = 0;  // system_tray installs with the default id (0).
  Shell_NotifyIconW(NIM_DELETE, &nid);
}

}  // namespace tray_icon
