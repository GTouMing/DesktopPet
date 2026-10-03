#ifndef RUNNER_PET_CURSOR_SURFACE_H_
#define RUNNER_PET_CURSOR_SURFACE_H_

#include <windows.h>

#include <vector>

// Input surface that keeps the cursor shape stable over an unlocked pet.
//
// Why it exists: the overlay window is permanently WS_EX_TRANSPARENT so the
// system skips it during hit testing, which means the window *under* a pet
// keeps receiving the cursor. That window then does what it always does -
// I-beam over a text box, resize arrows on its frame, hover highlight and
// tooltips - as if the pet were not there.
//
// Nothing on the hook side can suppress that (measured on this machine):
//   - discarding WM_MOUSEMOVE in the low-level hook does not merely hide the
//     event, it cancels the cursor movement itself (the pointer freezes at the
//     edge of the discarded area);
//   - discarding it and re-applying the position with SetCursorPos makes the
//     window underneath emit WM_MOUSEMOVE + WM_SETCURSOR again;
//   - SetCursor only applies while the cursor is over a window owned by the
//     calling thread, and that window is the application's, not ours.
//
// So the pet area needs a hit target of its own. This is a hidden popup window
// sitting on the pet the cursor is currently over: while it is up the window
// underneath receives no mouse input at all, and the cursor falls back to the
// class cursor (the plain arrow).
//
// It only ever holds *pure hover*. Anything that is being done - presses, the
// wheel, a gesture that started elsewhere and passes over a pet - makes it step
// aside first, so clicks, context menus, scrolling and drags reach the window
// underneath exactly as they did before (see Update).
namespace pet_cursor_surface {

// Creates the (hidden) surface and parks it just behind |overlay_window| in the
// z order, so anything that belongs above the overlay - the settings window -
// stays above it too. Call once, from the host window.
void Install(HWND overlay_window);

// Declares the pet rectangles the surface may cover (physical screen pixels,
// virtual desktop space). Called whenever Dart publishes new ones.
void SetRects(std::vector<RECT> rects);

// Whether any declared pet rectangle contains |point|.
//
// The rectangles have a single owner (this module); the input hooks ask here
// instead of keeping a second copy.
bool ContainsPoint(const POINT& point);

// Called for every mouse input event, before the system routes it.
//
//   |point|   cursor position carried by the event.
//   |inside|  the point is on a pet: inside a declared rectangle and not over
//             one of our own real windows (see global_input).
//   |owned|   this process owns the whole gesture (a pet drag, or a bound mouse
//             button pressed on a pet) - the window underneath is already kept
//             out of it, so the surface may stay up.
//   |is_move| a bare move, as opposed to a press/release/wheel.
void Update(const POINT& point, bool inside, bool owned, bool is_move);

// Whether |window| is the surface. The hook must not mistake it for a real
// window of ours (e.g. the settings window) when deciding whether a press
// grabbed a pet.
bool IsSurfaceWindow(HWND window);

// Destroys the surface. Call after the input hooks are gone, before the engine
// goes away.
void Shutdown();

}  // namespace pet_cursor_surface

#endif  // RUNNER_PET_CURSOR_SURFACE_H_
