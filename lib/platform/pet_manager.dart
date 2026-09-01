import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;

import '../storage/storage_service.dart';
import '../storage/models/pet_config.dart';
import 'android/multi_floating_window/multi_floating_window_android.dart';

/// 桌宠窗口管理器。
///
/// 统一管理所有桌宠的窗口创建、显示/隐藏和生命周期同步。
/// 各平台的具体窗口创建逻辑由内部封装，上层无需平台判断。
class PetManager {
  // ── 生命周期 ─────────────────────────────────────────────────────────

  /// 创建所有已保存桌宠的窗口/悬浮窗。
  Future<void> loadAllExisting() async {
    final pets = StorageService.readPets();
    for (final pet in pets) {
      await open(pet);
    }
  }

  /// 为指定桌宠创建窗口并显示。
  Future<void> open(PetConfig pet) async {
    if (Platform.isAndroid) {
      final settings = StorageService.readSettings();
      final scale = settings.baseScale * pet.scaleMultiplier;
      final w = (pet.width * scale).round();
      final h = (pet.height * scale).round();
      await MultiFloatingWindowAndroid.showOverlay(
        overlayId: pet.id,
        width: w,
        height: h,
        startPosition: OverlayPosition(
          pet.positionX.toInt(),
          pet.positionY.toInt(),
        ),
      );
    } else if (Platform.isWindows) {
      try {
        await dmw.WindowController.create(
          dmw.WindowConfiguration(arguments: pet.id),
        );
      } catch (_) {
        // dmw 通道不可用时静默跳过
      }
    }
  }

  /// 关闭所有窗口并释放控制器。
  void dispose() {}
}
