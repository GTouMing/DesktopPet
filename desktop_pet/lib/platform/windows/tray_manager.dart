import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';

/// Manages the Windows system tray icon and its context menu.
///
/// Exposes static callbacks that the application layer wires up
/// at startup so the tray menu can trigger pet actions.
class TrayManager {
  static VoidCallback? onLock;
  static VoidCallback? onUnlock;
  static VoidCallback? onSettings;

  /// 退出前同步保存回调（由 app 层在 init 时绑定）。
  static VoidCallback? onBeforeExit;

  static SystemTray? _instance;

  static Future<void> create() async {
    if (!Platform.isWindows) return;

    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: '锁定', onClicked: (_) => onLock?.call()),
      MenuItemLabel(label: '解锁', onClicked: (_) => onUnlock?.call()),
      MenuSeparator(),
      MenuItemLabel(label: '设置', onClicked: (_) => onSettings?.call()),
      MenuSeparator(),
      MenuItemLabel(label: '退出', onClicked: (_) async {
        onBeforeExit?.call();
        await _instance?.destroy();
        exit(0);
      }),
    ]);

    _instance = SystemTray();
    await _instance!.initSystemTray(
      title: '桌面宠物',
      iconPath: 'assets/app_icon.ico',
      toolTip: '桌面宠物',
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
}
