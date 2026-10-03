import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/foundation.dart';

import '../../core/overlay_channel.dart';

/// 监听设置窗口发来的"存储已改"通知。
///
/// 必须显式做：MMKV 虽是跨引擎共享的，但设置窗口写的那些键**在本引擎的内存监听器
/// 不会触发**，所以这里的 `appDataProvider` 不会自己失效。
///
/// 通道不可用时静默返回：场景仍能工作，只是设置改动要等下次重建才生效。
Future<void> listenToSettingsWindow(VoidCallback onStorageChanged) async {
  try {
    final ctrl = await dmw.WindowController.fromCurrentEngine();
    await ctrl.setWindowMethodHandler((call) async {
      if (call.method != OverlayChannel.storageChanged) return null;
      onStorageChanged();
      return null;
    });
  } catch (_) {}
}
