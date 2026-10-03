import 'dart:io';

import 'package:flutter_alone/flutter_alone.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../storage/storage_service.dart';

/// Manages the Windows system tray icon and its context menu.
///
/// Exposes static callbacks that the application layer wires up
/// at startup so the tray menu can trigger pet actions.
class TrayManager {

  static SystemTray? _instance;

  /// 托盘“设置”点击回调(宿主注入): 负责显示并聚焦主窗口。
  static Future<void> Function()? onShowSettings;

  static Future<void> create() async {
    if (!Platform.isWindows) return;

    final l10n = l10nFor(StorageService.readSettings().locale);
    final menu = await _buildMenu(l10n);

    _instance = SystemTray();
    await _instance!.initSystemTray(
      title: l10n.trayTooltip,
      iconPath: 'assets/app_icon.ico',
      toolTip: l10n.trayTooltip,
    );
    _instance!.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        _instance!.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        _instance!.popUpContextMenu();
      }
    });
    _instance!.setContextMenu(menu);
  }

  /// 语言切换后重建托盘菜单与悬停提示。
  static Future<void> refreshMenu() async {
    if (!Platform.isWindows) return;
    final instance = _instance;
    if (instance == null) return;

    final l10n = l10nFor(StorageService.readSettings().locale);
    final menu = await _buildMenu(l10n);
    await instance.setContextMenu(menu);
    await instance.setToolTip(l10n.trayTooltip);
  }

  static Future<Menu> _buildMenu(AppLocalizations l10n) async {
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: l10n.trayLock, onClicked: (_) => onLock(true)),
      MenuItemLabel(label: l10n.trayUnlock, onClicked: (_) => onLock(false)),
      MenuSeparator(),
      MenuItemLabel(label: l10n.traySettings, onClicked: (_) async {
        await onShowSettings?.call();
      }),
      MenuSeparator(),
      MenuItemLabel(label: l10n.trayQuit, onClicked: (_) => quit()),
    ]);
    return menu;
  }

  /// 销毁系统托盘（应用退出时调用）。
  static Future<void> destroy() async {
    await _instance?.destroy();
    _instance = null;
  }

  /// 退出应用。
  ///
  /// 顺序敏感:先移除托盘图标 → 给 Shell 一点时间处理通知区更新(其移除是
  /// 异步的,避免紧接着的进程退出抢先留下"幽灵图标")→ 优雅销毁宿主窗口
  /// (原生 `WM_DESTROY` 会兜底再删一次图标)→ 兜底退出。不再直接 `exit(0)`,
  /// 以免抢在原生收尾之前终止进程。
  ///
  /// 注意:进程被强杀(任务管理器 / IDE 停止 / 无响应时结束)时,Windows
  /// 无法在进程内清理图标,幽灵图标要等鼠标划过通知区才消失——这是系统行为,
  /// 应用侧无法修复。
  static Future<void> quit() async {
    await destroy();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await FlutterAlone.instance.dispose();
    try {
      await windowManager.destroy();
    } catch (_) {
      // 窗口可能已随引擎销毁;忽略。
    }
    exit(0);
  }

  /// 锁定/解锁所有桌宠。
  ///
  /// 逐只写入锁定状态即可：写入会广播设置变更，悬浮窗据此重建场景、把锁定中的
  /// 桌宠从可交互区域里摘掉（见 ui/host/overlay_scene.dart）。
  static void onLock(bool lock) {
    final pets = StorageService.readPets();
    for (final pet in pets) {
      StorageService.updatePet(pet.id, (_) => pet.copyWith(isLocked: lock));
    }
  }

}
