import 'dart:io';

import '../../storage/storage_service.dart';
import 'multi_floating_window/multi_floating_window_android.dart';

/// 桌宠设置变更通知（Android）。
///
/// 每只桌宠是一个独立的悬浮窗引擎，设置写入后需通过原生层把 `settings_updated`
/// 推给它们。
///
/// Windows 不再需要这个通道：桌宠与设置改动同处一个 isolate，设置窗口写完后只需
/// 通知悬浮窗重读存储即可（见 `core/overlay_channel.dart`）。
///
/// 放在 `platform/android/` 而不是 `core/`：它直接依赖 Android 插件实现，留在 core
/// 会让 core 反向依赖平台层。
class PetWindowChannel {
  PetWindowChannel._();

  /// 注册设置变更通知（仅 Android 主窗口调用）。
  static void register() {
    StorageService.addSettingsListener(_notifySettingsChanged);
  }

  static void _notifySettingsChanged() {
    if (Platform.isAndroid) {
      MultiFloatingWindowAndroid.notifySettingsUpdated();
    }
  }
}
