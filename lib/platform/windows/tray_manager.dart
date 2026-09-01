import 'dart:io';

import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../../storage/storage_service.dart';

/// Manages the Windows system tray icon and its context menu.
///
/// Exposes static callbacks that the application layer wires up
/// at startup so the tray menu can trigger pet actions.
class TrayManager {

  static SystemTray? _instance;

  static Future<void> create() async {
    if (!Platform.isWindows) return;

    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: '锁定', onClicked: (_) => onLock(true)),
      MenuItemLabel(label: '解锁', onClicked: (_) => onLock(false)),
      MenuSeparator(),
      MenuItemLabel(label: '设置', onClicked: (_) async {
        await windowManager.show();
      }),
      MenuSeparator(),
      MenuItemLabel(label: '退出', onClicked: (_) async {
        await destroy();
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

  /// 销毁系统托盘（应用退出时调用）。
  static Future<void> destroy() async {
    await _instance?.destroy();
    _instance = null;
  }

  /// 锁定/解锁所有桌宠。
  ///
  /// 1. 更新 MMKV 中所有宠物的锁定状态
  /// 2. 通知各桌宠子窗口（通过 PetWindowChannel 跨引擎通信）
  /// 3. 同步默认引擎自身的鼠标穿透状态
  static void onLock(bool lock) {
    final pets = StorageService.readPets();
    for (final pet in pets) {
      StorageService.updatePet(pet.id, (_) => pet.copyWith(isLocked: lock));
    }
    StorageService.onSettingsChanged?.call();
  }

}
