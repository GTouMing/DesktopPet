import '../core/constants.dart';
import '../storage/storage_service.dart';
import '../storage/models/pet_config.dart';
import '../storage/models/settings_model.dart';

/// 应用启动预加载器。
///
/// 按窗口类型按需加载：
/// - 主界面/设置窗口：仅初始化持久化存储
/// - 桌宠子窗口：初始化持久化存储 + 加载该桌宠的皮肤包
class PetInitializer {
  /// 初始化持久化存储（所有窗口都需要）。
  static Future<void> initStorage() async {
    await StorageService.init();

    // 首次启动：设置全局皮肤目录并创建一个默认桌宠
    if (StorageService.readPets().isEmpty) {
      StorageService.writeSettings(
        SettingsModel(
          skinDir: defaultSkinPath,
        ),
      );
      StorageService.writePets([
        PetConfig(
          id: defaultPetId,
          name: '我的桌宠',
          width: 200,
          height: 200,
        ),
      ]);
    }
  }
}