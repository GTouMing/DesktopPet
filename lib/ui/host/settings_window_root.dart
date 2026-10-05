import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../app.dart';
import '../../core/overlay_channel.dart';
import '../../platform/windows/settings_window.dart';
import '../../storage/storage_service.dart';

/// 设置窗口（**设置引擎**）的根组件。
///
/// 内容就是 [MainApp]（与 Android 主界面同一套 UI），本组件只负责窗口侧的三件事：
/// 1. 初始化本窗口的几何与透明度门控（见 [SettingsWindow]）；
/// 2. 把本窗口内的任何存储写入转告悬浮窗；
/// 3. 标题栏关闭键隐藏回托盘。
///
/// 本窗口**不置顶**（见 [SettingsWindow]）：常驻 topmost 且穿透的悬浮窗永远压在它之上，
/// 桌宠因此永远绘制在设置面板之上。
///
/// 第 2 点是必须的：MMKV 虽是多进程共享，但写入方（本引擎）的内存监听器不会在
/// 悬浮窗引擎里触发，故必须显式通知对方重读。
class SettingsWindowRoot extends ConsumerStatefulWidget {
  const SettingsWindowRoot({super.key});

  @override
  ConsumerState<SettingsWindowRoot> createState() =>
      _SettingsWindowRootState();
}

class _SettingsWindowRootState extends ConsumerState<SettingsWindowRoot>
    with WindowListener {
  /// 存储变更订阅（本窗口销毁时取消）。
  StreamSubscription<void>? _settingsSub;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _settingsSub = StorageService.addSettingsListener(_notifyOverlay);
    unawaited(SettingsWindow.init());
  }

  @override
  void dispose() {
    unawaited(_settingsSub?.cancel());
    _settingsSub = null;
    windowManager.removeListener(this);
    super.dispose();
  }

  /// 本窗口写过存储 → 悬浮窗重读并刷新桌宠场景与全局快捷键绑定。
  void _notifyOverlay() => unawaited(OverlayChannel.notifyStorageChanged());

  /// 标题栏关闭键 = 隐藏回托盘（窗口留用，下次打开是即时的）。
  @override
  void onWindowClose() => unawaited(SettingsWindow.hide());

  @override
  Widget build(BuildContext context) => const MainApp();
}
