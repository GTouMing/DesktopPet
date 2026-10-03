import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;

/// 悬浮窗 ↔ 设置窗口之间的跨引擎消息。
///
/// 单引擎改造后这两个窗口是仅剩的一对引擎，消息也就只剩两个方向：
/// - 悬浮窗 → 设置窗口：显隐设置面板（窗口几何/透明度门控由设置窗口自己应用，
///   与改造前的 ring 子窗口同构）；
/// - 设置窗口 → 悬浮窗：设置窗口写过存储，悬浮窗需要重读并刷新场景与全局输入。
class OverlayChannel {
  OverlayChannel._();

  /// 悬浮窗 → 设置窗口：显示、聚焦并置顶设置窗口。
  static const String settingsShow = 'settings_show';

  /// 悬浮窗 → 设置窗口：隐藏设置窗口（保留引擎与窗口，下次即开）。
  static const String settingsHide = 'settings_hide';

  /// 设置窗口 → 悬浮窗：存储已变更，请重读并刷新桌宠场景。
  static const String storageChanged = 'storage_changed';

  /// 找出悬浮窗（dmw 主窗口）的控制器。
  ///
  /// 悬浮窗是应用主窗口，由 `AttachFlutterMainWindow` 注册，**没有**
  /// `windowArgument`；设置窗口是唯一的子窗口且带 [settingsWindowRole]。
  /// 因此"参数为空"即悬浮窗（见 desktop_multi_window 的
  /// multi_window_manager.cc）。
  static Future<dmw.WindowController?> findOverlay() async {
    try {
      for (final ctrl in await dmw.WindowController.getAll()) {
        if (ctrl.arguments.isEmpty) return ctrl;
      }
    } catch (_) {
      // 枚举失败时静默：通知只是刷新优化，不是正确性前提。
    }
    return null;
  }

  /// 在设置窗口里调用：通知悬浮窗重读存储。
  static Future<void> notifyStorageChanged() async {
    final overlay = await findOverlay();
    if (overlay == null) return;
    try {
      await overlay.invokeMethod(storageChanged);
    } catch (_) {}
  }
}
