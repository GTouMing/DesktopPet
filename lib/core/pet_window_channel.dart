import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;

import '../platform/android/multi_floating_window/multi_floating_window_android.dart';
import '../storage/storage_service.dart';
import 'constants.dart';

/// 桌宠子窗口跨引擎通信通道。
///
/// 主窗口写入 MMKV 后，通过此通道向所有桌宠子窗口推送
/// `settings_updated`消息，触发即时刷新。
///
/// - Windows：使用 desktop_multi_window 跨引擎通信
/// - Android：通过原生层向各悬浮窗引擎推送
class PetWindowChannel {
  PetWindowChannel._();

  /// 注册设置变更通知（仅主窗口调用）。
  ///
  /// 挂载到 [StorageService.onSettingsChanged]，MMKV 写入后自动
  /// 向所有桌宠子窗口推送 [settings_updated] 消息。
  static void register() {
    StorageService.onSettingsChanged = _notifySettingsChanged;
  }

  /// 向所有桌宠子窗口推送设置变更通知。
  static void _notifySettingsChanged() {
    if (Platform.isWindows) {
      _notifyDmw('settings_updated');
    } else if (Platform.isAndroid) {
      MultiFloatingWindowAndroid.notifySettingsUpdated();
    }
  }

  static Future<void> _notifyDmw(String method) async {
    try {
      final all = await dmw.WindowController.getAll();
      for (final ctrl in all) {
        final arg = ctrl.arguments;
        // 排除主窗口和空参数
        if (arg == mainOrSetting) continue;
        try {
          await ctrl.invokeMethod(method);
        } catch (_) {
          // 单窗口失败不影响其他
        }
      }
    } catch (_) {
      // 静默处理
    }
  }
}
