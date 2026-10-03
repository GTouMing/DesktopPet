/// Windows 各原生通道的通道名、方法名与 payload key 的唯一定义(Dart 侧)。
///
/// 原生侧有一份镜像:`windows/runner/channels.h`。改这里必须同步改那边——此前这些
/// 字符串散落在两边各文件中,拼错一个字母就是静默失效。
library;

/// `desktop_pet/global_input` —— 进程级低级钩子。
///
/// 见 `windows/runner/global_input.cpp` 与 `lib/input/platform/windows_input_source.dart`。
class GlobalInputChannel {
  GlobalInputChannel._();

  static const String name = 'desktop_pet/global_input';

  // Dart → 原生
  static const String configure = 'configure';
  static const String setWatchRects = 'setWatchRects';
  static const String start = 'start';
  static const String stop = 'stop';

  // 原生 → Dart
  static const String onTrigger = 'onTrigger';
  static const String onMouse = 'onMouse';

  // payload key
  static const String bindings = 'bindings';
  static const String id = 'id';
  static const String type = 'type';
  static const String vk = 'vk';
  static const String mods = 'mods';
  static const String button = 'button';
  static const String state = 'state';
  static const String event = 'event';
  static const String x = 'x';
  static const String y = 'y';
  static const String left = 'left';
  static const String top = 'top';
  static const String right = 'right';
  static const String bottom = 'bottom';

  // 值
  static const String typeKey = 'key';
  static const String typeMouse = 'mouse';
  static const String phaseDown = 'down';
  static const String phaseUp = 'up';
  static const String phaseMove = 'move';
}

/// `desktop_pet/overlay` —— 宿主悬浮窗的原生控制。
///
/// 见 `windows/runner/overlay_window.cpp` 与 `lib/platform/windows/overlay_window.dart`。
class OverlayWindowChannel {
  OverlayWindowChannel._();

  static const String name = 'desktop_pet/overlay';

  /// Dart → 原生:虚拟桌面矩形(物理像素)。
  static const String getVirtualScreenRect = 'getVirtualScreenRect';

  /// 原生 → Dart:窗口几何被原生重铺(DPI 变化),请重新推导场景。
  static const String onGeometryChanged = 'onGeometryChanged';

  // payload key
  static const String left = 'left';
  static const String top = 'top';
  static const String width = 'width';
  static const String height = 'height';
}

/// `desktop_pet/settings_window` —— 设置子窗口的原生控制。
///
/// 见 `windows/runner/settings_window.cpp` 与
/// `lib/platform/windows/settings_window.dart`。
class SettingsWindowChannel {
  SettingsWindowChannel._();

  static const String name = 'desktop_pet/settings_window';

  /// 清掉置顶并插回当前前台窗口之后。
  static const String toBack = 'toBack';
}
