import 'package:flutter/services.dart';

import '../../../storage/models/pet_config.dart';
import '../../../storage/models/settings_model.dart';

/// 回调类型：收到全局设置更新。
typedef OnGlobalSettings = void Function(SettingsModel settings);

/// 回调类型：收到桌宠列表更新。
typedef OnPetListSync = void Function(List<PetConfig> pets);

/// Android 悬浮窗端设置同步接收器。
///
/// 在主应用调用 [MultiFloatingWindowAndroid.shareData] 后，
/// 原生层通过本 Channel 将序列化的设置数据转发给悬浮窗引擎。
///
/// 使用方法：
/// ```dart
/// SettingsSyncHandler(
///   onSettings: (s) { /* apply global settings */ },
///   onPets: (pets) { /* update pet list */ },
/// );
/// ```
class SettingsSyncHandler {
  /// 主应用 → 悬浮窗的设置同步通道。
  /// 原生 `multi_floating_window` 插件收到 `shareData` 调用后，
  /// 如果 type 为 `settings_sync`，会在此通道上 invoke `onSettingsSync`。
  static const MethodChannel _channel = MethodChannel(
    'multi_floating_window_android/settings_sync',
  );

  final OnGlobalSettings? onSettings;
  final OnPetListSync? onPets;

  SettingsSyncHandler({this.onSettings, this.onPets}) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onSettingsSync') return null;

    final args = call.arguments as Map?;
    if (args == null) return null;

    try {
      // 解析全局设置
      final settingsRaw = args['settings'] as Map<String, dynamic>?;
      if (settingsRaw != null && onSettings != null) {
        onSettings!(SettingsModel.fromJson(settingsRaw));
      }

      // 解析桌宠列表
      final petsRaw = args['pets'] as List<dynamic>?;
      if (petsRaw != null && onPets != null) {
        final pets = petsRaw
            .map((e) => PetConfig.fromJson(e as Map<String, dynamic>))
            .toList();
        onPets!(pets);
      }
    } catch (_) {
      // 解析失败不冒泡
    }

    return null;
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
