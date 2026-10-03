import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../core/overlay_channel.dart';

/// 设置窗口的**宿主侧**控制（运行在悬浮窗引擎里）。
///
/// 设置窗口是本应用唯一的 dmw 子窗口：
/// - **启动即预热**：应用启动时就把子引擎建好并保持隐藏（见 [warmUp]）。不做懒
///   创建——懒创建会把"拉起新进程 + 启动引擎 + 首帧"这整段开销压在用户点"设置"
///   的那一刻，首次打开必然可见地卡一下；
/// - **关闭只隐藏**，引擎热机保留。之所以不"关闭即销毁"：本项目历史上反复被
///   "dmw 子引擎 Dart 入口启动不稳定"咬过（旧实现为此在启动时做了逐个 600ms
///   错开），而设置窗口一个会话内会反复开关，销毁重建等于把这个坑重挖一遍。
///   代价只是常量 2 个引擎（悬浮窗 + 设置窗口），与桌宠数量无关。
class SettingsWindowHost {
  SettingsWindowHost._();

  /// 子引擎启动（消息处理器就绪）存在窗口期：创建返回后消息可能尚未可达，
  /// 因此发送失败时短时重试（与改造前 ring 子窗口同样的竞态处理）。
  static const int _maxAttempts = 8;
  static const Duration _retryDelay = Duration(milliseconds: 250);

  static dmw.WindowController? _ctrl;
  static Future<dmw.WindowController?>? _creating;

  /// 启动阶段预热：提前把子引擎建好（保持隐藏，见 [dmw.WindowConfiguration.hiddenAtLaunch]）。
  ///
  /// 由 `AppHost.start()` 在启动时**不 await** 地发起：子引擎启动不该拖住悬浮窗
  /// 首帧，用户点"设置"时它早已就绪（若尚未就绪，[show] 会等同一个创建 Future）。
  static Future<void> warmUp() async {
    await ensureCreated();
  }

  /// 打开设置窗口（必要时先创建）。
  static Future<void> show() async {
    final ctrl = await ensureCreated();
    if (ctrl == null) return;
    await _invoke(ctrl, OverlayChannel.settingsShow);
  }

  /// 隐藏设置窗口（窗口与引擎保留）。
  static Future<void> hide() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    await _invoke(ctrl, OverlayChannel.settingsHide);
  }

  // ── 创建 / 消息 ──────────────────────────────────────────────────────

  /// 创建（并发调用共享同一次创建；失败后允许重试）。
  static Future<dmw.WindowController?> ensureCreated() async {
    final existing = _ctrl;
    if (existing != null) return existing;

    final pending = _creating;
    if (pending != null) return pending;

    final future = _create();
    _creating = future;
    try {
      return await future;
    } finally {
      _creating = null;
    }
  }

  static Future<dmw.WindowController?> _create() async {
    try {
      final ctrl = await dmw.WindowController.create(
        dmw.WindowConfiguration(
          arguments: settingsWindowRole,
          // 启动即隐藏：首次 settings_show 之前不应露脸。
          hiddenAtLaunch: true,
        ),
      );
      _ctrl = ctrl;
      return ctrl;
    } catch (e) {
      if (kDebugMode) debugPrint('[settings] window create failed: $e');
      return null;
    }
  }

  static Future<bool> _invoke(
      dmw.WindowController ctrl, String method) async {
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        await ctrl.invokeMethod(method);
        return true;
      } catch (_) {
        if (attempt < _maxAttempts - 1) {
          await Future<void>.delayed(_retryDelay);
        }
      }
    }
    return false;
  }
}
