#include "global_input.h"
#include "pet_cursor_surface.h"

#include <windows.h>

#include <atomic>
#include <iostream>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "channels.h"

namespace global_input {

// Channel names / method names / payload keys, shared with the Dart side.
namespace ch = ::channels::global_input;

namespace {

// Diagnostic logging (Debug builds only; NDEBUG is defined in Release).
#ifndef NDEBUG
#define HK_LOG(msg)                      \
  do {                                   \
    std::cout << "[hk:native] " << msg << std::endl; \
  } while (0)
#else
#define HK_LOG(msg) do {} while (0)
#endif

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;
HHOOK g_keyboard_hook = nullptr;
HHOOK g_mouse_hook = nullptr;

// Cursor-follow / mouse-button feedback for Live2D packs that ask for it (see
// setMouseTracking). Off unless a pack declares mouseParams; emitted in its own
// phases so the pet-drag path (down/move/up) is untouched.
std::atomic<bool> g_track_mouse{false};
ULONGLONG g_last_hover_emit = 0;

// A registered key binding: either a keyboard combo (vk + required modifiers)
// or a mouse button. `down` tracks whether a down event was reported and the
// matching up has not fired yet (also suppresses key auto-repeat).
//
// `mod_groups` holds the modifier VKs Dart resolved for this binding: every group
// must be satisfied, and a group is satisfied when ANY of its VKs is down (left
// and right Win are two VKs but one modifier). Native therefore keeps no
// modifier table of its own - the knowledge lives in the Dart input source.
struct Binding {
  std::string id;
  bool is_mouse = false;
  int vk = 0;
  std::vector<std::vector<int>> mod_groups;
  int button = -1;
  bool down = false;
};

std::mutex g_mutex;
std::vector<Binding> g_bindings;

// ---- Pet pointer routing -------------------------------------------------
//
// The overlay window is permanently WS_EX_TRANSPARENT and therefore receives no
// mouse messages at all - that is what keeps the desktop usable. Pet clicks and
// drags must come from this process-wide hook instead: when the left button goes
// down inside a pet rectangle declared by Dart, we start forwarding down/move/up
// and Dart does the per-pet hit-testing and dragging.
//
// Because the overlay never receives the click, the click would otherwise carry
// on to whatever is underneath the pet (selecting a desktop icon, pressing a
// button in another app). So the hook also *swallows* those events: a low-level
// hook returns nonzero to have the event discarded instead of being delivered to
// any window or application. A left-button drag, or a right-button press, that
// starts on a pet is therefore consumed for its whole duration; everything else
// falls through untouched.
//
// Capture semantics: move events are only forwarded after a press inside a pet
// rectangle, so moving the cursor anywhere else costs no channel traffic.
//
// The one thing the hook cannot fix is the cursor shape: the window under a pet
// keeps setting the I-beam over its text box, the resize arrows on its frame or
// a tooltip from the moves it receives, and discarding those moves here would
// freeze the pointer instead of hiding them (the low-level hook runs *before*
// the system applies the event, so a veto cancels the movement too). The pet
// cursor surface exists for that (windows/runner/pet_cursor_surface.cpp): this
// hook drives its visibility - up for pure hovering over a pet, out of the way
// for everything else.
// Registered mouse-button bindings (e.g. the middle-button quick launch).
//
// The ring menu is opened by *holding* such a button, and released wherever the
// cursor happens to be over the ring - a different window from the one that got
// the press. A low-level hook cannot move a message to another window: the
// system routes the release by position, so the window that received the press
// would never see its up and would sit there with the button held (that is what
// an application's autoscroll/middle-drag mode looks like). When the press was
// one we let through, remember its target and complete the click ourselves if
// the release lands somewhere else.
HWND g_press_target = nullptr;
int g_press_button = -1;
POINT g_press_point = {};

bool g_capturing = false;

// Mouse button whose press started on a pet and is currently held, so its release
// (and the moves in between) are swallowed too. -1 when nothing is held.
int g_swallowed_button = -1;

// The right button, held after a press that started on a pet. An unlocked pet
// owns the right press and its release for the whole gesture, so neither a
// single nor a double right-click reaches the window underneath. Only down/up
// are swallowed - moves are left alone for the same reason as the left drag
// (swallowing a move cancels it and freezes the cursor).
bool g_right_capturing = false;

// The host (overlay) window: the only window the pets are drawn in, and the only
// one that is topmost for its whole lifetime. Set through SetOverlayWindow.
HWND g_overlay_window = nullptr;

// Whether |window| sits above |other| in the top-level z order.
//
// Both are expected to be top-level windows on this desktop. When the walk sees
// neither (some shell/menu windows are not in the chain it starts from) it falls
// back to WS_EX_TOPMOST, which is what puts a window above the permanently
// topmost overlay.
bool IsAboveInZOrder(HWND window, HWND other) {
  int index = 0;
  int window_index = -1;
  int other_index = -1;
  for (HWND h = ::GetTopWindow(nullptr); h != nullptr;
       h = ::GetWindow(h, GW_HWNDNEXT), ++index) {
    if (h == window) window_index = index;
    if (h == other) other_index = index;
    if (window_index >= 0 && other_index >= 0) break;
  }
  if (window_index < 0 || other_index < 0) {
    return (::GetWindowLongPtrW(window, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
  }
  return window_index < other_index;
}

// Whether the cursor is over a window of this process that is ABOVE the pets, so
// a click there belongs to that window and must not also be treated as "grabbed
// the pet underneath".
//
// The settings window is a window of this process (dmw creates child engines
// in-process) and it is topmost only while it is the active window - see
// lib/platform/windows/settings_window.dart, which flushes it behind the overlay
// as soon as it loses focus. While it is behind, a pet drawn on top of it is the
// window the user is actually pointing at: the press must be grabbed and
// swallowed by the pet, not passed to the settings form underneath (which used to
// happen, because this only asked whether the hit window was ours).
//
// The pet cursor surface is ours as well, but it is not a real window: a press
// that lands on it is a press on the pet (the surface steps aside for any press
// anyway).
//
// The overlay itself is WS_EX_TRANSPARENT so WindowFromPoint skips it; asking
// about the hit window needs no position sync between the two engines.
bool OverOwnRealWindow(const POINT& point) {
  const HWND hit = ::WindowFromPoint(point);
  if (hit == nullptr) return false;
  if (pet_cursor_surface::IsSurfaceWindow(hit)) return false;
  const HWND root = ::GetAncestor(hit, GA_ROOT);
  if (root == nullptr) return false;
  DWORD pid = 0;
  ::GetWindowThreadProcessId(root, &pid);
  if (pid != ::GetCurrentProcessId()) return false;
  return g_overlay_window == nullptr || IsAboveInZOrder(root, g_overlay_window);
}

void EmitMouse(const char* phase, const POINT& point) {
  if (g_channel == nullptr) return;
  flutter::EncodableMap args;
  args[flutter::EncodableValue(ch::kEvent)] =
      flutter::EncodableValue(std::string(phase));
  args[flutter::EncodableValue(ch::kX)] =
      flutter::EncodableValue(static_cast<int32_t>(point.x));
  args[flutter::EncodableValue(ch::kY)] =
      flutter::EncodableValue(static_cast<int32_t>(point.y));
  g_channel->InvokeMethod(
      ch::kOnMouse, std::make_unique<flutter::EncodableValue>(std::move(args)));
}

// A hook callback must never call into Flutter while holding g_mutex.
//
// The method channel is delivered to Dart inline on this (the platform) thread.
// Any window operation the handler performs that dispatches messages --
// DestroyWindow, ShowWindow/SetWindowPos, a cross-thread SendMessage -- pumps
// the queue and can re-enter this hook on the same thread. std::mutex is not
// recursive, so the nested lock_guard throws std::system_error; nothing catches
// it, terminate() runs and the whole process (every engine) dies. Observed as a
// crash with 0xE06D7363 inside MouseHookProc's lock_guard.
//
// Therefore: mutate state and collect the events to send under the lock, then
// release it and send.
struct Emit {
  std::string id;
  std::string state;
};

void EmitTrigger(const std::string& id, const std::string& state) {
  HK_LOG("emit id=" << id << " state=" << state);
  if (g_channel == nullptr) {
    HK_LOG("emit skipped: channel is null");
    return;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue(ch::kId)] = flutter::EncodableValue(id);
  args[flutter::EncodableValue(ch::kState)] = flutter::EncodableValue(state);
  g_channel->InvokeMethod(
      ch::kOnTrigger, std::make_unique<flutter::EncodableValue>(std::move(args)));
}

bool IsKeyPressed(int vk) {
  return (GetAsyncKeyState(vk) & 0x8000) != 0;
}

// Whether |vk| is one of the modifier keys some binding is watching. Used to
// notice a required modifier being released before the main key. Called with
// g_mutex held.
bool IsModifierVk(int vk) {
  for (const auto& b : g_bindings) {
    if (b.is_mouse) continue;
    for (const auto& group : b.mod_groups) {
      for (int candidate : group) {
        if (candidate == vk) return true;
      }
    }
  }
  return false;
}

// Every required modifier group must be satisfied; a group is satisfied when any
// of its VKs is down.
bool ModifiersMatch(const Binding& binding) {
  for (const auto& group : binding.mod_groups) {
    bool group_down = false;
    for (int vk : group) {
      if (IsKeyPressed(vk)) {
        group_down = true;
        break;
      }
    }
    if (!group_down) return false;
  }
  return true;
}

bool HasKeyboardBinding() {
  for (const auto& b : g_bindings) {
    if (!b.is_mouse) return true;
  }
  return false;
}

// The "button released" message for a binding button index (0=L, 1=R, 2=M).
UINT ButtonUpMessage(int button) {
  switch (button) {
    case 0:
      return WM_LBUTTONUP;
    case 1:
      return WM_RBUTTONUP;
    case 2:
      return WM_MBUTTONUP;
    default:
      return 0;
  }
}

LRESULT CALLBACK KeyboardHookProc(int n_code, WPARAM w_param,
                                  LPARAM l_param) {
  if (n_code != HC_ACTION) {
    return CallNextHookEx(nullptr, n_code, w_param, l_param);
  }
  const bool down = w_param == WM_KEYDOWN || w_param == WM_SYSKEYDOWN;
  const bool up = w_param == WM_KEYUP || w_param == WM_SYSKEYUP;
  if (!down && !up) {
    return CallNextHookEx(nullptr, n_code, w_param, l_param);
  }

  const auto* kb = reinterpret_cast<KBDLLHOOKSTRUCT*>(l_param);
  const int vk = static_cast<int>(kb->vkCode);

  std::vector<Emit> emits;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!HasKeyboardBinding()) {
      return CallNextHookEx(nullptr, n_code, w_param, l_param);
    }

    for (auto& b : g_bindings) {
      if (b.is_mouse || vk != b.vk) continue;
      if (down) {
        if (!b.down && ModifiersMatch(b)) {
          b.down = true;
          emits.push_back({b.id, ch::kPhaseDown});
        }
      } else if (b.down) {
        b.down = false;
        emits.push_back({b.id, ch::kPhaseUp});
      }
    }

    // The user released a required modifier before the main key: fire the up
    // event for any still-down binding whose modifiers no longer match, so the
    // hold gesture does not get stuck.
    if (up && IsModifierVk(vk)) {
      for (auto& b : g_bindings) {
        if (b.is_mouse || !b.down) continue;
        if (!ModifiersMatch(b)) {
          b.down = false;
          emits.push_back({b.id, ch::kPhaseUp});
        }
      }
    }
  }

  for (const auto& e : emits) {
    EmitTrigger(e.id, e.state);
  }
  return CallNextHookEx(nullptr, n_code, w_param, l_param);
}

LRESULT CALLBACK MouseHookProc(int n_code, WPARAM w_param, LPARAM l_param) {
  if (n_code != HC_ACTION) {
    return CallNextHookEx(nullptr, n_code, w_param, l_param);
  }
  const auto* mouse = reinterpret_cast<MSLLHOOKSTRUCT*>(l_param);
  const POINT point = mouse->pt;

  // Resolve the configured mouse binding for this message and collect the events
  // to send; the sends happen after g_mutex is released (see the note on Emit).
  std::vector<Emit> emits;
  std::string pointer_phase;
  bool swallow = false;
  bool on_pet = false;
  bool owns_gesture = false;

  {
    std::lock_guard<std::mutex> lock(g_mutex);

    // Is the cursor on a pet? Inside a rectangle Dart declared and not over one
    // of our own real windows (the settings window keeps its own input). Used
    // both for presses and to drive the pet cursor surface.
    on_pet = pet_cursor_surface::ContainsPoint(point) && !OverOwnRealWindow(point);

    const bool is_press = w_param == WM_LBUTTONDOWN ||
                          w_param == WM_RBUTTONDOWN ||
                          w_param == WM_MBUTTONDOWN ||
                          w_param == WM_XBUTTONDOWN;
    const bool press_on_pet = is_press && on_pet;

    // Pet drag.
    //
    // The press is re-evaluated on every down rather than latched, so a capture
    // can never get stuck: clicking anywhere that is not a pet always clears it.
    switch (w_param) {
      case WM_LBUTTONDOWN:
        g_capturing = press_on_pet;
        if (g_capturing) {
          pointer_phase = ch::kPhaseDown;
          swallow = true;
        }
        break;
      case WM_MOUSEMOVE:
        if (g_capturing) pointer_phase = ch::kPhaseMove;
        break;
      case WM_LBUTTONUP:
        if (g_capturing) {
          g_capturing = false;
          pointer_phase = ch::kPhaseUp;
          swallow = true;
        }
        break;
      case WM_RBUTTONDOWN:
        // Not a drag button, but an unlocked pet still owns the click: swallow
        // the press so it - and, on a second click, the double-click the window
        // underneath would synthesize - never reaches that window. Re-evaluated
        // on every down, so the capture cannot get stuck.
        g_right_capturing = press_on_pet;
        if (g_right_capturing) swallow = true;
        break;
      case WM_RBUTTONUP:
        if (g_right_capturing) {
          g_right_capturing = false;
          swallow = true;
        }
        break;
      default:
        break;
    }

    // Registered mouse-button bindings (e.g. the middle-button quick launch).
    int binding_button = -1;
    bool binding_down = false;
    switch (w_param) {
      case WM_LBUTTONDOWN: binding_down = true; binding_button = 0; break;
      case WM_LBUTTONUP: binding_button = 0; break;
      case WM_RBUTTONDOWN: binding_down = true; binding_button = 1; break;
      case WM_RBUTTONUP: binding_button = 1; break;
      case WM_MBUTTONDOWN: binding_down = true; binding_button = 2; break;
      case WM_MBUTTONUP: binding_button = 2; break;
      case WM_XBUTTONDOWN:
      case WM_XBUTTONUP: {
        const int xbutton = static_cast<int>(HIWORD(mouse->mouseData));
        binding_button = xbutton == 1 ? 3 : 4;
        binding_down = w_param == WM_XBUTTONDOWN;
        break;
      }
      default:
        break;
    }

    if (binding_button >= 0) {
      bool matched = false;
      for (auto& b : g_bindings) {
        if (!b.is_mouse || b.button != binding_button) continue;
        if (binding_down) {
          // Unlike a key, a mouse button cannot auto-repeat: a second down while
          // we still believe the button is held means the matching up never
          // reached us. Take it as a fresh press - otherwise the trigger stays
          // latched and the user's button silently does nothing from then on.
          b.down = true;
          matched = true;
          emits.push_back({b.id, ch::kPhaseDown});
        } else if (b.down) {
          b.down = false;
          matched = true;
          emits.push_back({b.id, ch::kPhaseUp});
        }
      }

      if (binding_down) {
        if (matched) {
          // Only a trigger pressed on a pet is swallowed, matching the old
          // per-pet window (which captured the mouse). A press anywhere else is
          // left alone, so e.g. middle-click still works in other applications.
          //
          // Press and release are swallowed TOGETHER, on this and on the branch
          // below - never one without the other. Swallowing only the release
          // (as this used to) delivers the press to the window under the cursor
          // and then cancels its release: that window holds a middle button
          // down it never sees released, so it stays in autoscroll /
          // middle-drag mode (blocking the input it would otherwise take)
          // until the next middle click happens to complete the pair. Whether
          // the press reaches that window by luck - the pet cursor surface
          // usually sits under the cursor - is not something to rely on.
          g_swallowed_button = press_on_pet ? binding_button : -1;
          swallow = g_swallowed_button >= 0;
          // A press we let through: remember which window got it, so its click
          // can be completed on release if that release lands elsewhere.
          g_press_button = g_swallowed_button < 0 ? binding_button : -1;
          g_press_target =
              g_press_button >= 0 ? ::WindowFromPoint(point) : nullptr;
          g_press_point = point;
        }
      } else if (binding_button == g_swallowed_button) {
        g_swallowed_button = -1;
        swallow = true;
      } else if (binding_button == g_press_button) {
        const UINT up_message = ButtonUpMessage(binding_button);
        const HWND release_target = ::WindowFromPoint(point);
        if (up_message != 0 && g_press_target != nullptr &&
            release_target != g_press_target) {
          // The press went to one window and the release would go to another:
          // hand the release to the window that got the press, or it never
          // learns the button came back up.
          POINT client = g_press_point;
          ::ScreenToClient(g_press_target, &client);
          ::PostMessage(g_press_target, up_message, 0,
                        MAKELPARAM(client.x, client.y));
          // The real release is deliberately let through as well. Swallowing
          // it (as this used to) is only safe while the window under the
          // cursor is the one that got the press; a window with the mouse
          // captured - which is exactly what a middle-drag / autoscroll does -
          // need not be, and cancelling its release leaves it holding the
          // button. The window under the cursor never saw the press, so the
          // extra release is inert to it.
        }
        g_press_button = -1;
        g_press_target = nullptr;
      }
    }

    // Is a gesture of ours in progress *after* this event? A pet drag, or a
    // bound mouse button pressed on a pet: those are consumed for their whole
    // duration, so the pet may keep the cursor instead of letting it pick up
    // the shape of whatever it is being dragged over.
    owns_gesture = g_capturing || g_swallowed_button >= 0 || g_right_capturing;
  }

  // Drive the pet cursor surface before this event is routed, so it is up while
  // the cursor sits on a pet and out of the way for anything that is *done*
  // there (windows/runner/pet_cursor_surface.h).
  pet_cursor_surface::Update(point, on_pet, owns_gesture,
                             w_param == WM_MOUSEMOVE);

  // Cursor following / mouse-button feedback (only while a pack asked for it).
  // Hover is throttled to ~60Hz so a global cursor stream stays cheap.
  if (g_track_mouse.load()) {
    switch (w_param) {
      case WM_MOUSEMOVE: {
        const ULONGLONG now = ::GetTickCount64();
        if (now - g_last_hover_emit >= 16) {
          g_last_hover_emit = now;
          EmitMouse(ch::kPhaseHover, point);
        }
        break;
      }
      case WM_LBUTTONDOWN:
        EmitMouse(ch::kPhaseLDown, point);
        break;
      case WM_LBUTTONUP:
        EmitMouse(ch::kPhaseLUp, point);
        break;
      case WM_RBUTTONDOWN:
        EmitMouse(ch::kPhaseRDown, point);
        break;
      case WM_RBUTTONUP:
        EmitMouse(ch::kPhaseRUp, point);
        break;
      default:
        break;
    }
  }

  if (!pointer_phase.empty()) {
    EmitMouse(pointer_phase.c_str(), point);
  }
  for (const auto& e : emits) {
    EmitTrigger(e.id, e.state);
  }

  // A low-level hook swallows the event by returning nonzero: the system then
  // discards it instead of delivering it to any window or application. That is
  // what stops a click on a pet from also acting on whatever is behind it.
  if (swallow) {
    return 1;
  }
  return CallNextHookEx(nullptr, n_code, w_param, l_param);
}

bool InstallHooks() {
  if (g_keyboard_hook == nullptr) {
    g_keyboard_hook = SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardHookProc,
                                        GetModuleHandle(nullptr), 0);
  }
  if (g_mouse_hook == nullptr) {
    g_mouse_hook = SetWindowsHookExW(WH_MOUSE_LL, MouseHookProc,
                                     GetModuleHandle(nullptr), 0);
  }
  return g_keyboard_hook != nullptr || g_mouse_hook != nullptr;
}

void UninstallHooks() {
  if (g_keyboard_hook != nullptr) {
    UnhookWindowsHookEx(g_keyboard_hook);
    g_keyboard_hook = nullptr;
  }
  if (g_mouse_hook != nullptr) {
    UnhookWindowsHookEx(g_mouse_hook);
    g_mouse_hook = nullptr;
  }
  std::lock_guard<std::mutex> lock(g_mutex);
  for (auto& b : g_bindings) {
    b.down = false;
  }
  g_capturing = false;
  g_swallowed_button = -1;
  g_right_capturing = false;
  g_press_button = -1;
  g_press_target = nullptr;
}

std::string GetString(const flutter::EncodableMap& map, const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return {};
  const auto* value = std::get_if<std::string>(&it->second);
  return value != nullptr ? *value : std::string();
}

int GetInt(const flutter::EncodableMap& map, const char* key, int fallback) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return fallback;
  if (const auto* v32 = std::get_if<int32_t>(&it->second)) return *v32;
  if (const auto* v64 = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*v64);
  }
  return fallback;
}

// "mods": [[vk, ...], ...] - each group must be satisfied (any VK in it down).
std::vector<std::vector<int>> GetVkGroups(const flutter::EncodableMap& map,
                                         const char* key) {
  std::vector<std::vector<int>> groups;
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return groups;
  const auto* list = std::get_if<flutter::EncodableList>(&it->second);
  if (list == nullptr) return groups;
  for (const auto& item : *list) {
    const auto* vk_list = std::get_if<flutter::EncodableList>(&item);
    if (vk_list == nullptr) continue;
    std::vector<int> vks;
    for (const auto& vk : *vk_list) {
      if (const auto* v32 = std::get_if<int32_t>(&vk)) {
        vks.push_back(*v32);
      } else if (const auto* v64 = std::get_if<int64_t>(&vk)) {
        vks.push_back(static_cast<int>(*v64));
      }
    }
    if (!vks.empty()) groups.push_back(std::move(vks));
  }
  return groups;
}

// "shape": {"kind": "rect"|"grid", ...} - the hit area inside a region's
// rectangle (single-engine-overlay.md 13.2). Returns the kind string, or empty
// when absent/unrecognized; callers treat that as "rect".
//
// The per-cell grid fields (cols/rows/bits) are part of the reserved payload and
// are deliberately not read yet: v1 only ever sends "rect".
std::string ShapeKindOf(const flutter::EncodableMap& map) {
  const auto it = map.find(flutter::EncodableValue(ch::kShape));
  if (it == map.end()) return {};
  const auto* shape = std::get_if<flutter::EncodableMap>(&it->second);
  if (shape == nullptr) return {};
  return GetString(*shape, ch::kKind);
}

std::vector<Binding> ParseBindings(const flutter::EncodableValue* arguments) {
  std::vector<Binding> parsed;
  const auto* args = std::get_if<flutter::EncodableMap>(arguments);
  if (args == nullptr) return parsed;

  const auto it = args->find(flutter::EncodableValue(ch::kBindings));
  if (it == args->end()) return parsed;
  const auto* list = std::get_if<flutter::EncodableList>(&it->second);
  if (list == nullptr) return parsed;

  for (const auto& item : *list) {
    const auto* map = std::get_if<flutter::EncodableMap>(&item);
    if (map == nullptr) continue;

    Binding b;
    b.id = GetString(*map, ch::kId);
    b.is_mouse = GetString(*map, ch::kType) == ch::kTypeMouse;
    b.vk = GetInt(*map, ch::kVk, 0);
    b.mod_groups = GetVkGroups(*map, ch::kMods);
    b.button = GetInt(*map, ch::kButton, -1);
    b.down = false;

    if (b.id.empty()) continue;
    if (b.is_mouse) {
      if (b.button < 0) continue;
    } else if (b.vk == 0) {
      continue;
    }
    parsed.push_back(std::move(b));
  }
  return parsed;
}

void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == ch::kConfigure) {
    auto parsed = ParseBindings(call.arguments());
    {
      std::lock_guard<std::mutex> lock(g_mutex);
      g_bindings = std::move(parsed);
      HK_LOG("configure bindings=" << g_bindings.size());
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method == ch::kSetWatchRegions) {
    // Pet hit regions declared by Dart (physical screen pixels): a left-button
    // press inside one of them counts as grabbing a pet.
    //
    // Each region carries a `shape` (single-engine-overlay.md 13.2) so the
    // decision can be made *here*, synchronously - the low-level hook runs with
    // a system timeout and must not round-trip to Dart. v1 only ever sends
    // {kind:'rect'}: the whole bounding rectangle is the hit area. 'grid' is
    // reserved for Live2D's alpha bitmap; until that lands, a grid region is
    // judged as its bounding rectangle (v1 stays whole-rectangle).
    std::vector<RECT> rects;
    bool saw_grid = false;
    if (const auto* list =
            std::get_if<flutter::EncodableList>(call.arguments())) {
      rects.reserve(list->size());
      for (const auto& item : *list) {
        const auto* map = std::get_if<flutter::EncodableMap>(&item);
        if (map == nullptr) continue;
        const int left = GetInt(*map, ch::kLeft, 0);
        const int top = GetInt(*map, ch::kTop, 0);
        const int right = GetInt(*map, ch::kRight, 0);
        const int bottom = GetInt(*map, ch::kBottom, 0);
        if (right > left && bottom > top) {
          if (ShapeKindOf(*map) == ch::kShapeGrid) saw_grid = true;
          rects.push_back(RECT{left, top, right, bottom});
        }
      }
    }
    if (saw_grid) {
      HK_LOG("setWatchRegions: grid shape not implemented yet, "
             "using the bounding rect");
    }
    // The regions have a single owner: the cursor surface module, which the
    // hook then queries (pet_cursor_surface::ContainsPoint). For now it only
    // needs the rectangles; the shape is judged here (rect) until grid lands.
    //
    // With no pet left to grab, drop the capture so we stop forwarding moves -
    // and stop swallowing clicks - immediately.
    const bool no_pets = rects.empty();
    pet_cursor_surface::SetRects(std::move(rects));
    if (no_pets) {
      std::lock_guard<std::mutex> lock(g_mutex);
      g_capturing = false;
      g_swallowed_button = -1;
      g_right_capturing = false;
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method == ch::kSetMouseTracking) {
    // Cursor-follow + mouse-button feedback (Live2D packs with mouseParams).
    bool on = false;
    if (const auto* value = std::get_if<bool>(call.arguments())) {
      on = *value;
    }
    g_track_mouse.store(on);
    result->Success(flutter::EncodableValue(true));
  } else if (method == ch::kStart) {
    const bool installed = InstallHooks();
    HK_LOG("start installed=" << installed << " kbHook=" << (g_keyboard_hook != nullptr)
                              << " mouseHook=" << (g_mouse_hook != nullptr));
    result->Success(flutter::EncodableValue(installed));
  } else if (method == ch::kStop) {
    HK_LOG("stop (uninstall hooks)");
    UninstallHooks();
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void RegisterWithMessenger(flutter::BinaryMessenger* messenger) {
  if (g_channel != nullptr) {
    return;
  }
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, ch::kName, &flutter::StandardMethodCodec::GetInstance());
  g_channel->SetMethodCallHandler(HandleMethodCall);
}

void SetOverlayWindow(HWND window) {
  g_overlay_window = window;
}

void Shutdown() {
  UninstallHooks();
  g_channel = nullptr;
  g_overlay_window = nullptr;
}

}  // namespace global_input
