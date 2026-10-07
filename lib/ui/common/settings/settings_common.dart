import '../../../storage/models/settings_model.dart';
import '../../../storage/storage_service.dart';

/// 设置写入的**唯一入口**。
///
/// 各分区一律经由它改设置，不再各自 `settings.xxx = v; writeSettings(settings)`——
/// 那样会改到 provider 缓存着的那份实例。
///
/// 写完就够了：[StorageService.changes] 会让 `appDataProvider` 自动重算，调用方
/// 不需要（也不应该）自己 invalidate。
void applySettings(SettingsModel Function(SettingsModel settings) transform) {
  StorageService.updateSettings(transform);
}
