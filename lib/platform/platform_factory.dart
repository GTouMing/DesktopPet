import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../storage/models/pet_config.dart';
import '../storage/storage_service.dart';
import 'android/multi_floating_window/multi_floating_window_android.dart';
import 'android/window_android.dart';
import 'window_interface.dart';

/// 创建桌宠窗口控制器。
///
/// 只有 Android 需要：那里每只桌宠仍是一个系统悬浮窗。
/// Windows 单引擎下桌宠只是悬浮窗场景里的一个条目（见 `lib/ui/host/overlay_scene.dart`），
/// 位置/显隐/锁定都由场景自身表达，没有对应的窗口可操作，返回 null。
WindowController? createWindowController({String? windowId}) {
  if (Platform.isAndroid) {
    return WindowControllerAndroid(overlayId: windowId ?? 'default');
  }
  return null;
}

/// 正在创建中的桌宠 id:避免批量创建与补建并发重复创建。
final Set<String> _spawning = {};

/// 为指定桌宠创建系统悬浮窗（Android）。
Future<void> spawnPetWindow(PetConfig pet) async {
  if (!Platform.isAndroid) return;
  if (!_spawning.add(pet.id)) return;
  try {
    final settings = StorageService.readSettings();
    final scale = finalScaleOf(settings.baseScale, pet.scaleMultiplier);
    // 原生布局参数与起点坐标均为物理像素，统一经 window_android 的换算入口。
    final physicalSize =
        logicalToPhysicalSize(Size(pet.width * scale, pet.height * scale));
    final physicalPos = logicalToPhysicalOffset(pet.position);
    await MultiFloatingWindowAndroid.showOverlay(
      overlayId: pet.id,
      width: physicalSize.width.round(),
      height: physicalSize.height.round(),
      startPosition: OverlayPosition(
        physicalPos.dx.round(),
        physicalPos.dy.round(),
      ),
    );
  } catch (e) {
    if (kDebugMode) debugPrint('[pet] spawn overlay failed ${pet.id}: $e');
  } finally {
    _spawning.remove(pet.id);
  }
}

/// 确保每个已保存桌宠都有悬浮窗：缺失的补建,已有的跳过（幂等）。
///
/// 兜底悬浮窗被动消失(如被系统回收)后的恢复。
Future<void> loadAllPetWindows() async {
  if (!Platform.isAndroid) return;
  for (final pet in StorageService.readPets()) {
    bool showing;
    try {
      showing = await MultiFloatingWindowAndroid.isOverlayShowing(pet.id);
    } catch (_) {
      continue;
    }
    if (showing) continue;
    await spawnPetWindow(pet);
  }
}

/// 关闭指定桌宠的悬浮窗(删除桌宠时调用,回收其引擎)。
Future<void> closePetWindow(String petId) async {
  if (!Platform.isAndroid) return;
  try {
    await MultiFloatingWindowAndroid.closeOverlay(petId);
  } catch (_) {}
}
