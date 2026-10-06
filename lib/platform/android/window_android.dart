import 'dart:ui';

import 'package:desktop_pet/platform/window_interface.dart';
import 'package:pet_floating_window/pet_floating_window.dart';

import '../../core/constants.dart';
import '../../core/device.dart';
import '../../storage/storage_service.dart';

/// 逻辑像素尺寸 → 物理像素尺寸。全工程唯一的换算入口。
Size logicalToPhysicalSize(Size logical) {
  final dpr = currentDevicePixelRatio;
  return Size(
    (logical.width * dpr).roundToDouble().clamp(1, 9999).toDouble(),
    (logical.height * dpr).roundToDouble().clamp(1, 9999).toDouble(),
  );
}

/// 逻辑像素坐标 → 物理像素坐标。
Offset logicalToPhysicalOffset(Offset logical) {
  final dpr = currentDevicePixelRatio;
  return Offset(
    (logical.dx * dpr).roundToDouble(),
    (logical.dy * dpr).roundToDouble(),
  );
}

class WindowControllerAndroid implements WindowController {
  final String _overlayId;

  WindowControllerAndroid({String overlayId = 'default'})
      // ignore: prefer_initializing_formals (公开命名参数 overlayId)
      : _overlayId = overlayId;

  @override
  double get devicePixelRatio => currentDevicePixelRatio;

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  @override
  Future<void> petInit() async {
  }

  @override
  Future<void> show() async {
    final settings = StorageService.readSettings();
    final pet = StorageService.readPet(_overlayId);
    final Size logical;
    if (pet == null) {
      logical = const Size(defaultPetSize, defaultPetSize);
    } else {
      final scale = finalScaleOf(settings.baseScale, pet.scaleMultiplier);
      logical = Size(pet.width * scale, pet.height * scale);
    }
    final physical = logicalToPhysicalSize(logical);
    try {
      await PetFloatingWindow.showOverlay(
        overlayId: _overlayId,
        width: physical.width.round(),
        height: physical.height.round(),
      );
    } catch (_) {}
  }

  @override
  Future<void> hide() async {
    await PetFloatingWindow.closeOverlay(_overlayId);
  }

  // ─── Window operations ─────────────────────────────────────────────────

  @override
  Future<void> setIgnoreMouseEvents(bool ignore) async {
    await PetFloatingWindow.updateFlag(_overlayId,
        ignore ? OverlayFlag.clickThrough : OverlayFlag.defaultFlag);
  }

  @override
  Future<Offset> getPosition() async {
    try {
      final overlayPosition =
          await PetFloatingWindow.getOverlayPosition(_overlayId);
      final dpr = currentDevicePixelRatio;
      return Offset(overlayPosition.x / dpr, overlayPosition.y / dpr);
    } catch (e) {
      return Offset.zero;
    }
  }

  @override
  Future<void> setPosition(Offset pos) async {
    final physical = logicalToPhysicalOffset(pos);
    PetFloatingWindow.moveOverlay(
      _overlayId,
      OverlayPosition(physical.dx.round(), physical.dy.round()),
    );
  }

  @override
  void setPositionSync(Offset pos) {
    setPosition(pos);
  }

  @override
  Future<void> setSize(Size size) async {
    final physical = logicalToPhysicalSize(size);
    await PetFloatingWindow.resizeOverlay(
        _overlayId, physical.width.round(), physical.height.round());
  }

  @override
  Future<Size> getScreenSize() async {
    final dpr = currentDevicePixelRatio;
    try {
      final physical = await PetFloatingWindow.getScreenSize();
      return Size(physical.width / dpr, physical.height / dpr);
    } catch (e) {
      return Size(
        PetFloatingWindow.fallbackScreenWidth / dpr,
        PetFloatingWindow.fallbackScreenHeight / dpr,
      );
    }
  }

  @override
  Future<void> startDragging() async {
    await PetFloatingWindow.startDragging(_overlayId);
  }
}
