import 'dart:async';
import 'dart:io';

import 'package:desktop_pet/shortcut/quick_launch_host.dart';
import 'package:desktop_pet/shortcut/shortcut_launcher.dart';
import 'package:desktop_pet/storage/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_window_host.dart';
import 'tray_manager.dart';

/// Windows 宿主（**悬浮窗引擎**）启动器。
///
/// 这唯一的窗口同时承载全部桌宠、环形菜单与托盘，因此这里只剩下进程级的一次性
/// 装配：窗口防误关、托盘、全局输入。
///
/// 桌宠窗口与环形菜单子窗口都不再存在，故这里原先的"创建 ring 窗口 / 批量创建
/// 桌宠窗口"整段被删除；设置窗口则改由 [SettingsWindowHost] 按需懒创建。
class AppHost {
  AppHost._();

  static bool _started = false;

  /// 首帧之后到"把窗口显出来"之间的等待。
  ///
  /// 窗口被 show 时引擎的合成表面还没上屏,那几帧会整块白屏(原生实测约 70ms),
  /// 所以先透明、过一拍再揭示。透明度本身仍由原生在 Install 时置 0
  ///(见 `windows/runner/overlay_window.cpp`),这里只决定"何时打开"。
  static const Duration _revealDelay = Duration(milliseconds: 200);

  /// 最近一次已应用到托盘的语言（见 [_refreshTrayLocale]）。
  static String? _appliedTrayLocale;

  /// 启动 Windows 宿主（幂等，仅 Windows 有效）。
  static Future<void> start() async {
    if (_started || !Platform.isWindows) return;
    _started = true;

    await windowManager.ensureInitialized();

    // 去掉标题栏。窗口样式全部由 Dart(window_manager)负责,原生侧不再改样式:
    // 这里用 WM_NCCALCSIZE 拦截把客户区扩到整窗,与原宿主窗口当年的做法一致。
    await windowManager.setAsFrameless();

    // 固定尺寸 + 禁止最大化。取代原先散在原生里的三段:
    //   - overlay_window.cpp 去掉 WS_THICKFRAME/WS_MAXIMIZEBOX;
    //   - flutter_window.cpp 拦截 WM_NCLBUTTONDBLCLK/WM_LBUTTONDBLCLK;
    //   - flutter_window.cpp 拦截 WM_SYSCOMMAND(SC_MAXIMIZE/SC_RESTORE)。
    // 设置窗口早就是这样做的,两边现在一致。
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(false);

    // 悬浮窗没有标题栏，正常不会被关闭；拦下 WM_CLOSE 以免误触退出应用。
    await windowManager.setPreventClose(true);

    // 窗口常驻透明：原生把它设成 layered 窗口（见 overlay_window.cpp），这里让
    // Flutter 侧也按透明合成，否则整块桌面会被不透明内容盖住。
    await windowManager.setBackgroundColor(Colors.transparent);

    // 托盘菜单里的"设置"打开独立的设置窗口（菜单项在点击时才读该回调）。
    TrayManager.onShowSettings = showSettings;

    // 托盘（设置/锁定/退出入口）。
    await TrayManager.create();
    _refreshTrayLocale();
    // 托盘属于本引擎，而语言是在**设置窗口**里改的：那边的写入在本引擎不会触发
    // 内存监听器，靠悬浮窗收到"存储已改"后调 notifySettingsChanged 把这一条带起来
    //（见 OverlayScene._setupStorageChannel）。
    StorageService.addSettingsListener(_refreshTrayLocale);

    // 设置窗口不再懒创建：等到用户点"设置"才拉起子引擎，会把"新进程 + 启动引擎
    // + 首帧"整段开销压在那一刻，首次打开必然卡一下。这里在启动阶段就建好并保持
    // 隐藏，之后每次打开都是即时的。
    //
    // 刻意**不 await**：子引擎启动（另一个进程 + Flutter 引擎）不该拖住悬浮窗首帧
    // ——窗口此刻已经显示，等太久会先露出一块空白（见 overlay_window.cpp 里
    // WM_SHOWWINDOW 的揭示时序）。用户点"设置"时若它还在启动，show() 会等同一个
    // 创建 Future，不会重复拉起。
    unawaited(SettingsWindowHost.warmUp());

    // 预热快捷启动的工人 isolate：它做"检查目标 + 拉起进程"这类同步阻塞调用，
    // 必须在装钩子之前就绪——否则第一次命中扇区松手会在钩子回调里同步启动
    // isolate（debug 构建可达数百毫秒），钩子超时会被系统摘掉。见 ShortcutLauncher。
    await ShortcutLauncher.warmUp();

    // 全局输入宿主（热键/中键 → 环形菜单）。
    await QuickLaunchInputHost.instance.start();

    // 首帧之后再过一拍才把窗口显出来（详见 [_revealDelay]）。
    //
    // 取代原先原生里的 WM_SHOWWINDOW + 200ms 定时器：现在两个窗口的揭示都由
    // Dart 触发，原生不再持有任何显示时机策略。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(_revealDelay, () => windowManager.setOpacity(1));
    });

    // 注：设置窗口不在此创建。它由托盘"设置"触发、懒创建一次并热机保留
    //（见 settings_window_host.dart）。
  }

  /// 语言变了才重建托盘菜单与悬停提示（其它设置写入不碰托盘）。
  static void _refreshTrayLocale() {
    final locale = StorageService.readSettings().locale;
    if (locale == _appliedTrayLocale) return;
    _appliedTrayLocale = locale;
    unawaited(TrayManager.refreshMenu());
  }

  /// 托盘“设置”：显示设置窗口。
  static Future<void> showSettings() => SettingsWindowHost.show();

  /// 隐藏设置窗口（回到只有桌宠的状态）。
  static Future<void> hideSettings() => SettingsWindowHost.hide();
}
