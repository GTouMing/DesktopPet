import 'dart:async';
import 'dart:ui';

/// Abstract interface for platform-specific pet window management.
abstract class WindowController {
  /// Unique identifier for this window/overlay instance.
  /// On Android this is the overlayId; on Windows this is the window identifier.
  String get id;

  Future<void> init();
  Future<void> show();
  Future<void> hide();
  Future<void> setIgnoreMouseEvents(bool ignore);
  Future<Offset> getPosition();
  /// 通过 [SetWindowPos]（含 SWP_NOSENDCHANGING）同步移动窗口。
  ///
  /// 仅在 Windows 平台有效，用于避免 `_onTick` 中异步 setPosition
  /// 产生的窗口消息干扰托盘弹出菜单。
  void setPositionSync(Offset pos);

  Future<void> setPosition(Offset pos);
  Future<void> moveRelative(Offset delta);
  Future<void> setSize(Size size);
  Future<void> setAlwaysOnTop(bool value);
  Future<void> close();
  void dispose();
  Future<Size> getScreenSize();

  /// 设备像素比，用于逻辑/物理像素转换。
  /// - Android：使用 Kotlin 侧传入的真实 density（可能不同于 overlay engine 的 PlatformDispatcher）
  /// - Windows：返回 1.0（逻辑像素 == 物理像素）
  double get devicePixelRatio;
  ///
  /// 调用后系统接管拖拽循环，通过 [Future] 返回时表示拖拽结束。
  /// - Windows：使用 [windowManager.startDragging]（发送 WM_SYSCOMMAND）
  /// - Android：使用 [MultiFloatingWindowAndroid.startDragging]
  Future<void> startDragging();

  /// 获取当前前台/活动窗口的标题。仅 Windows 平台有效。
  /// 不支持时返回 `null`（Android 等平台）。
  String? getForegroundWindowTitle() => null;

  /// 前台窗口标题变更事件流。仅 Windows 平台有效（无轮询，通过 WinEvent hook）。
  /// 不支持时返回 `null`（Android 等平台）。
  Stream<String>? get onForegroundWindowTitle => null;
}
