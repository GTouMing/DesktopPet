#ifndef RUNNER_CHANNELS_H_
#define RUNNER_CHANNELS_H_

// Method-channel names, method names and payload keys, mirrored from the Dart
// side.
//
// Mirror of lib/platform/windows/windows_channels.dart - keep the two in sync.
// Before this existed the same literals were spelled out in every native file
// and on both sides of each channel, where a typo is a silent no-op.
namespace channels {

// "desktop_pet/global_input" (windows/runner/global_input.cpp).
namespace global_input {
constexpr char kName[] = "desktop_pet/global_input";

// Dart -> native
constexpr char kConfigure[] = "configure";
constexpr char kSetWatchRegions[] = "setWatchRegions";
constexpr char kSetMouseTracking[] = "setMouseTracking";
constexpr char kStart[] = "start";
constexpr char kStop[] = "stop";

// native -> Dart
constexpr char kOnTrigger[] = "onTrigger";
constexpr char kOnMouse[] = "onMouse";

// payload keys
constexpr char kBindings[] = "bindings";
constexpr char kId[] = "id";
constexpr char kType[] = "type";
constexpr char kVk[] = "vk";
constexpr char kMods[] = "mods";
constexpr char kButton[] = "button";
constexpr char kState[] = "state";
constexpr char kEvent[] = "event";
constexpr char kX[] = "x";
constexpr char kY[] = "y";
constexpr char kLeft[] = "left";
constexpr char kTop[] = "top";
constexpr char kRight[] = "right";
constexpr char kBottom[] = "bottom";

// Hit shape payload (extensible, see single-engine-overlay.md 13.2):
// shape: {kind:'rect'|'grid', cols?, rows?, bits?}.
constexpr char kShape[] = "shape";
constexpr char kKind[] = "kind";
constexpr char kCols[] = "cols";
constexpr char kRows[] = "rows";
constexpr char kBits[] = "bits";

// values
constexpr char kTypeKey[] = "key";
constexpr char kTypeMouse[] = "mouse";
constexpr char kPhaseDown[] = "down";
constexpr char kPhaseUp[] = "up";
constexpr char kPhaseMove[] = "move";
constexpr char kPhaseHover[] = "hover";
constexpr char kPhaseLDown[] = "leftDown";
constexpr char kPhaseLUp[] = "leftUp";
constexpr char kPhaseRDown[] = "rightDown";
constexpr char kPhaseRUp[] = "rightUp";
constexpr char kShapeRect[] = "rect";
constexpr char kShapeGrid[] = "grid";
}  // namespace global_input

// "desktop_pet/overlay" (windows/runner/overlay_window.cpp).
namespace overlay {
constexpr char kName[] = "desktop_pet/overlay";
constexpr char kGetVirtualScreenRect[] = "getVirtualScreenRect";
constexpr char kOnGeometryChanged[] = "onGeometryChanged";
constexpr char kLeft[] = "left";
constexpr char kTop[] = "top";
constexpr char kWidth[] = "width";
constexpr char kHeight[] = "height";
}  // namespace overlay

}  // namespace channels

#endif  // RUNNER_CHANNELS_H_
