/// 与原生 `Constants.kt` 一一对应的通道方法名与参数名。
///
/// 只保留 Dart 侧真正会调用的部分；原生遗留的通用能力(shareData / openMainApp /
/// 事件总线等)已随死代码一并移除。
class Constants {
  /// 主通道名(与原生 `Constants.kt` / `OverlayManager.kt` 一致)。
  static const String channelName = "multi_floating_window_android";

  /// 原生 → 悬浮窗:设置已更新,请重读存储。
  static const String settingsUpdatedEvent = "settings_updated";

  // ── 方法名 ───────────────────────────────────────────────────────────
  static const String requestPermission = "requestPermission";
  static const String hasPermission = "hasPermission";
  static const String showOverlay = "showOverlay";
  static const String closeOverlay = "closeOverlay";
  static const String updateFlag = "updateFlag";
  static const String resizeOverlay = "resizeOverlay";
  static const String startDragging = "startDragging";
  static const String moveOverlay = "moveOverlay";
  static const String getOverlayPosition = "getOverlayPosition";
  static const String isOverlayShowing = "isOverlayShowing";
  static const String getScreenSize = "getScreenSize";

  /// 主窗口写入 MMKV 后通知所有悬浮窗刷新设置。
  static const String sendSettingsUpdated = "sendSettingsUpdated";

  // ── 参数名 ───────────────────────────────────────────────────────────
  static const String overlayId = "overlayId";
  static const String height = "height";
  static const String width = "width";
  static const String flag = "flag";
  static const String startPosition = "startPosition";
  static const String x = "x";
  static const String y = "y";

  // ── 兜底值 ───────────────────────────────────────────────────────────
  /// 原生取屏幕尺寸失败时的兜底(物理像素)。全工程只此一份。
  static const int fallbackScreenWidth = 1080;
  static const int fallbackScreenHeight = 1920;
}
