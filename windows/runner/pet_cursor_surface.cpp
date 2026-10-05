#include "pet_cursor_surface.h"

namespace pet_cursor_surface {
namespace {

constexpr wchar_t kClassName[] = L"DesktopPetCursorSurface";

HWND g_surface = nullptr;

// The overlay window, used once as the z-order anchor (see Install).
HWND g_anchor = nullptr;

// Pet rectangles as last published by Dart.
std::vector<RECT> g_rects;

// The rectangle the surface currently covers; only meaningful while shown.
RECT g_shown_rect = {};
bool g_shown = false;

// Whether the z order has been applied already. Later moves use SWP_NOZORDER so
// the surface never jumps back above a window the user has raised since.
bool g_placed = false;

// Any mouse button physically down right now.
//
// A gesture that did not start on a pet (selecting text, moving a window,
// dragging a scrollbar) keeps its moves: the surface must stay out of the way
// for its whole duration or the window underneath would stall.
bool AnyMouseButtonDown() {
  return (GetAsyncKeyState(VK_LBUTTON) & 0x8000) != 0 ||
         (GetAsyncKeyState(VK_RBUTTON) & 0x8000) != 0 ||
         (GetAsyncKeyState(VK_MBUTTON) & 0x8000) != 0 ||
         (GetAsyncKeyState(VK_XBUTTON1) & 0x8000) != 0 ||
         (GetAsyncKeyState(VK_XBUTTON2) & 0x8000) != 0;
}

bool EnsureWindow() {
  if (g_surface != nullptr) {
    return true;
  }

  static bool registered = false;
  if (!registered) {
    WNDCLASS window_class = {};
    // DefWindowProc is all this window needs: it answers WM_SETCURSOR with the
    // class cursor and paints nothing.
    window_class.lpfnWndProc = DefWindowProc;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.lpszClassName = kClassName;
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    if (RegisterClass(&window_class) == 0) {
      return false;
    }
    registered = true;
  }

  g_surface = CreateWindowEx(
      WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TOPMOST,
      kClassName, L"", WS_POPUP, 0, 0, 0, 0, nullptr, nullptr,
      GetModuleHandle(nullptr), nullptr);
  if (g_surface == nullptr) {
    return false;
  }

  // Alpha 1/255: invisible (at most 0.4% of this window's never-painted pixels
  // reach the screen), but NOT zero - a layered window whose alpha is zero is
  // passed through in hit testing, which is exactly what this window exists to
  // avoid.
  SetLayeredWindowAttributes(g_surface, 0, 1, LWA_ALPHA);
  return true;
}

const RECT* RectContaining(const POINT& point) {
  for (const RECT& rect : g_rects) {
    if (PtInRect(&rect, point)) {
      return &rect;
    }
  }
  return nullptr;
}

void Hide() {
  if (!g_shown) {
    return;
  }
  ShowWindow(g_surface, SW_HIDE);
  g_shown = false;
}

void ShowOn(const RECT& rect) {
  if (g_shown && EqualRect(&g_shown_rect, &rect)) {
    return;
  }
  // Park it behind the overlay the first time (the settings window lives above
  // the overlay, so it stays above the surface as well); afterwards only move
  // it, leaving the z order alone.
  SetWindowPos(g_surface, g_placed ? nullptr : g_anchor, rect.left, rect.top,
               rect.right - rect.left, rect.bottom - rect.top,
               SWP_NOACTIVATE | SWP_SHOWWINDOW |
                   (g_placed ? SWP_NOZORDER : 0u));
  g_placed = true;
  g_shown_rect = rect;
  g_shown = true;
}

}  // namespace

void Install(HWND overlay_window) {
  g_anchor = overlay_window;
  EnsureWindow();
}

void SetRects(std::vector<RECT> rects) {
  g_rects = std::move(rects);

  if (!g_shown) {
    return;
  }
  // A walking pet can leave a stationary cursor behind: follow the new
  // rectangles instead of holding a stale patch of screen.
  POINT cursor = {};
  const RECT* rect =
      GetCursorPos(&cursor) != FALSE ? RectContaining(cursor) : nullptr;
  if (rect == nullptr) {
    Hide();
    return;
  }
  ShowOn(*rect);
}

bool ContainsPoint(const POINT& point) {
  return RectContaining(point) != nullptr;
}

void Update(const POINT& point, bool inside, bool owned, bool is_move) {
  if (g_surface == nullptr) {
    return;
  }
  if (!inside) {
    Hide();
    return;
  }

  // Pure hovering is what the surface holds by itself; a press, wheel or
  // already-running gesture (AnyMouseButtonDown) that the pet does NOT own hands
  // the event - this one included - back to the window underneath, which keeps
  // scrolling and gestures that started elsewhere behaving exactly as before. An
  // owned press (a pet drag, or a right press that started on a pet) keeps it up
  // for the gesture's duration.
  if (!owned && !(is_move && !AnyMouseButtonDown())) {
    Hide();
    return;
  }

  const RECT* rect = RectContaining(point);
  if (rect == nullptr) {
    Hide();
    return;
  }
  ShowOn(*rect);
}

bool IsSurfaceWindow(HWND window) {
  return window != nullptr && window == g_surface;
}

void ReassertBelowOverlay() {
  if (g_surface == nullptr || g_anchor == nullptr) {
    return;
  }
  // Insert-after the overlay puts the surface directly below it. The overlay is
  // topmost, so this keeps the surface in the topmost band right under it; it no
  // longer relies on the one-shot placement in ShowOn. Move/size/visibility are
  // left untouched.
  ::SetWindowPos(g_surface, g_anchor, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  g_placed = true;
}

void Shutdown() {
  if (g_surface != nullptr) {
    DestroyWindow(g_surface);
    g_surface = nullptr;
  }
  g_anchor = nullptr;
  g_rects.clear();
  g_shown = false;
  g_placed = false;
}

}  // namespace pet_cursor_surface
