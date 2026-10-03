import 'dart:async';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:desktop_pet/core/device.dart';
import 'package:desktop_pet/core/overlay_channel.dart';
import 'package:desktop_pet/platform/windows/windows_channels.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// 设置窗口（**设置引擎侧**）的窗口控制。
///
/// 与悬浮窗的分工：
/// - 悬浮窗通过 [OverlayChannel.settingsShow] / [OverlayChannel.settingsHide]
///   消息驱动本窗口显隐；
/// - 本窗口自己应用窗口几何、置顶与透明度门控（沿用改造前 ring 子窗口的模式：
///   宿主侧的 `dmw.WindowController` 没有 setBounds，窗口只能自己管自己）。
///
/// 置顶只在**本窗口是活动窗口**期间保持。
///
/// 悬浮窗铺满整个虚拟桌面且常驻 topmost，设置窗口不置顶就会被桌宠压在下面；但
/// 常驻置顶又不符合普通窗口的使用习惯——用户切去别的程序时它还挡在最上。因此
/// 焦点进来才置顶、失焦立刻撤掉（见 [setPinned]，触发点在
/// `ui/host/settings_window_root.dart` 的 onWindowFocus/onWindowBlur）。
class SettingsWindow {
  SettingsWindow._();

  /// 设置窗口尺寸（逻辑像素）。
  static const Size windowSize = Size(800, 600);

  static Future<void>? _initFuture;

  /// 当前是否已置顶（避免把同样的状态重复下发给原生）。
  static bool _pinned = false;

  /// 本窗口引擎独有的原生窗口控制（见 windows/runner/settings_window.cpp）。
  static const MethodChannel _native =
      MethodChannel(SettingsWindowChannel.name);

  /// 配置窗口并注册跨引擎消息处理器（幂等）。
  ///
  /// 用 Future 记录而非布尔：`settings_show` 可能在本方法尚未跑完时到达，
  /// [show] 需要等它落地，否则窗口会先以系统标题栏露面再被改成无边框。
  static Future<void> init() => _initFuture ??= _initialize();

  static Future<void> _initialize() async {
    await windowManager.ensureInitialized();

    // 先注册跨引擎消息处理器：宿主的 settings_show 可能早于窗口选项就绪到达
    // （改造前 ring 子窗口踩过同样的竞态）。
    try {
      final ctrl = await dmw.WindowController.fromCurrentEngine();
      await ctrl.setWindowMethodHandler(_handleMethod);
    } catch (_) {
      // 通道不可用时仍继续配置窗口；宿主侧发送失败会重试。
    }

    // 标题栏关闭键 → 隐藏回托盘，而不是销毁窗口（销毁后没有重建入口）。
    await windowManager.setPreventClose(true);
    await windowManager.setResizable(false);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);

    const options = WindowOptions(
      title: 'Desktop Pet',
      size: windowSize,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Color(0x00000000),
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      // 首次 settings_show 之前保持完全不可见。
      await windowManager.setOpacity(0);
    });
  }

  static Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case OverlayChannel.settingsShow:
        await show();
      case OverlayChannel.settingsHide:
        await hide();
    }
    return null;
  }

  /// 居中显示并聚焦。
  static Future<void> show() async {
    await init();
    final rect = _centeredOnScreen();

    // opacity 0 → 摆好几何 → 出一帧 → opacity 1：任何中间帧都不可见。
    await windowManager.setOpacity(0);
    await windowManager.setBounds(rect);
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    // 首显表面同步：引擎合成表面可能与最终窗口几何不同步，导致窗口顶部出现
    // 透明空带（内容不填满）。在透明闸门内做一次尺寸往返，强制按最终几何重建
    // 合成表面（±1px 不会被人眼感知）。
    final bump =
        Rect.fromLTWH(rect.left, rect.top, rect.width + 1, rect.height + 1);
    await windowManager.setBounds(bump);
    await windowManager.setBounds(rect);
    await windowManager.focus();
    // 先按"这个窗口是用户要用的"置顶，否则会先露出一帧被桌宠压住的面板。
    await setPinned(true);
    await SchedulerBinding.instance.endOfFrame;
    await windowManager.setOpacity(1);
    // 但置顶要以真的拿到焦点为准：Windows 可能拒绝前台焦点请求
    // （SetForegroundWindow 失败时窗口只闪任务栏），那就撤掉置顶，别留下一个
    // 谁也没在用的置顶窗口——用户点它一下会重新拿到焦点并置顶。
    await setPinned(await windowManager.isFocused());
  }

  /// 隐藏回托盘（窗口与引擎都保留，下次打开是即时的）。
  static Future<void> hide() async {
    await init();
    await windowManager.setOpacity(0);
    await windowManager.hide();
  }

  /// 设置是否置顶（幂等；只在状态真的变化时下发原生）。
  ///
  /// 见类文档：只在本窗口是活动窗口期间置顶。
  static Future<void> setPinned(bool pinned) async {
    if (_pinned == pinned) return;
    _pinned = pinned;
    if (pinned) {
      await windowManager.setAlwaysOnTop(true);
      return;
    }
    // 撤置顶不能只调 windowManager.setAlwaysOnTop(false)：那在原生是
    // SetWindowPos(HWND_NOTOPMOST)，而该标志会把窗口抬到所有非置顶窗口之上——
    // 也就是抬到用户刚点的那个程序前面。表现就是"点了别的应用，设置界面仍在前台"。
    // 原生因此多了一步：清掉 topmost 后把窗口插回当前前台窗口之后。
    try {
      await _native.invokeMethod(SettingsWindowChannel.toBack);
    } catch (_) {
      // 通道不可用（子引擎已注册，仅作兜底）：退回 window_manager 的行为。
      await windowManager.setAlwaysOnTop(false);
    }
  }

  /// 以当前显示器为中心的窗口矩形（逻辑像素）。
  static Rect _centeredOnScreen() {
    final display = PlatformDispatcher.instance.views.first.display;
    final screen = display.size / currentDevicePixelRatio;
    final left = ((screen.width - windowSize.width) / 2)
        .clamp(0.0, screen.width)
        .toDouble();
    final top = ((screen.height - windowSize.height) / 2)
        .clamp(0.0, screen.height)
        .toDouble();
    return Rect.fromLTWH(left, top, windowSize.width, windowSize.height);
  }
}
