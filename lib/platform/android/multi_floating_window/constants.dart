/// Method name constants
class Constants {
  static const String getPlatformVersion = "getPlatformVersion";
  static const String isPermissionGranted = "isPermissionGranted";
  static const String requestPermission = "requestPermission";
  static const String showOverlay = "showOverlay";
  static const String closeOverlay = "closeOverlay";
  static const String closeAllOverlays = "closeAllOverlays";
  static const String updateFlag = "updateFlag";
  static const String resizeOverlay = "resizeOverlay";
  static const String startDragging = "startDragging";
  static const String moveOverlay = "moveOverlay";
  static const String getOverlayPosition = "getOverlayPosition";
  static const String shareData = "shareData";
  static const String openMainApp = "openMainApp";
  static const String closeOverlayFromOverlay = "close";
  static const String overlayControlChannel = "multi_floating_window_android/overlay_control";
  static const String isMainAppRunning = "isMainAppRunning";
  static const String navigateToPage = "navigateToPage";
  static const String isShowing = "isShowing";
  static const String isOverlayShowing = "isOverlayShowing";
  static const String getOverlayIds = "getOverlayIds";
  static const String getScreenSize = "getScreenSize";

  /// 主窗口写入 MMKV 后通知所有悬浮窗刷新设置
  static const String sendSettingsUpdated = "sendSettingsUpdated";

  /// MethodChannel on overlay engine for native→Dart gesture events
  static const String gestureMethodChannel = "multi_floating_window_android/gesture_events";

  static const String navigationEventChannel = "com.desktop_pet.multi_floating_window/navigation";

  // Parameter constants
  static const String overlayId = "overlayId";
  static const String height = "height";
  static const String width = "width";
  static const String flag = "flag";
  static const String enableDrag = "enableDrag";
  static const String startPosition = "startPosition";
  static const String x = "x";
  static const String y = "y";
  static const String data = "data";

  // Gesture event keys (must match Kotlin Constants.kt)
  static const String gestureEventKey = "event";
  static const String gestureEventOverlayId = "overlayId";
  static const String gestureEventX = "x";
  static const String gestureEventY = "y";
  static const String gestureEventDx = "dx";
  static const String gestureEventDy = "dy";

  // Gesture event type values
  static const String gestureDragStart = "dragStart";
  static const String gestureDragMove = "dragMove";
  static const String gestureDragEnd = "dragEnd";
  static const String gestureTap = "tap";
}
