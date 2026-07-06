import 'dart:ui';

import 'package:desktop_pet/platform/window_interface.dart';

import '../../storage/storage_service.dart';
import 'multi_floating_window/multi_floating_window_android.dart';

/// 由 Kotlin OverlayManager 在创建引擎时通过 args[1] 传入的真实 DPR，
/// 用于覆盖 overlay engine 中可能返回 1.0 的 PlatformDispatcher。
double? _overrideDpr;

/// 设置 overlay engine 的真实 DPR（由 main.dart 在解析启动参数时调用）。
void setOverrideDpr(double dpr) {
  _overrideDpr = dpr;
}

/// 设备像素比，用于逻辑像素 ↔ 物理像素转换。
///
/// Android WindowManager.LayoutParams.width/height 使用物理像素，
/// 而 Flutter 的尺寸（petSize 等）使用逻辑像素，需要乘以 DPR 转换。
///
/// overlay engine 的 PlatformDispatcher 可能返回 1.0，因此优先使用
/// Kotlin 侧通过 args 传入的真实 DPR。
double get _devicePixelRatio {
  if (_overrideDpr != null) return _overrideDpr!;
  try {
    return PlatformDispatcher.instance.views.first.devicePixelRatio;
  } catch (_) {
    return 1.0;
  }
}

/// 将 Flutter 逻辑像素尺寸转为 Android 物理像素尺寸（取整后 clamp 到 [1, 9999]）。
(int, int) _toPhysicalSize(Size logical) {
  final dpr = _devicePixelRatio;
  return (
    (logical.width * dpr).round().clamp(1, 9999),
    (logical.height * dpr).round().clamp(1, 9999),
  );
}

class WindowControllerAndroid implements WindowController {
  final String _overlayId;

  WindowControllerAndroid({String overlayId = 'default'})
      : _overlayId = overlayId;

  @override
  String get id => _overlayId;

  @override
  double get devicePixelRatio => _devicePixelRatio;

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  @override
  Future<void> init() async {
    if (_overlayId != 'main') return;
    // 主窗口：请求悬浮窗权限后遍历桌宠配置显示悬浮窗
    await MultiFloatingWindowAndroid.requestPermission();
    final appData = StorageService.appData;
    final settings = StorageService.readSettings();
    final dpr = _devicePixelRatio;
    for (final pet in appData.pets) {
      try {
        final scale = settings.baseScale * pet.scaleMultiplier;
        final logical = Size(pet.width * scale, pet.height * scale);
        // 视口逻辑像素 = scaledSize / dpr，使物理窗口 ≈ pet.width * scale
        final viewportLogical = Size(logical.width / dpr, logical.height / dpr);
        final (w, h) = _toPhysicalSize(viewportLogical);
        await MultiFloatingWindowAndroid.showOverlay(
          overlayId: pet.id,
          width: w,
          height: h,
          startPosition: OverlayPosition(
            (pet.positionX * dpr).toInt(),
            (pet.positionY * dpr).toInt(),
          ),
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> show() async {
    final settings = StorageService.readSettings();
    final pet = StorageService.readPet(_overlayId);
    double w = 200, h = 200;
    if (pet != null) {
      final scale = settings.baseScale * pet.scaleMultiplier;
      w = pet.width * scale;
      h = pet.height * scale;
    }
    final dpr = _devicePixelRatio;
    final viewportLogical = Size(w / dpr, h / dpr);
    final (pw, ph) = _toPhysicalSize(viewportLogical);
    try {
      await MultiFloatingWindowAndroid.showOverlay(
        overlayId: _overlayId,
        width: pw,
        height: ph,
      );
    } catch (_) {}
  }

  @override
  Future<void> hide() async {
    await MultiFloatingWindowAndroid.closeOverlay(_overlayId);
  }

  @override
  Future<void> close() async {
    await MultiFloatingWindowAndroid.closeOverlay(_overlayId);
  }

  @override
  void dispose() {
    MultiFloatingWindowAndroid.closeOverlay(_overlayId);
  }

  // ─── Window operations ─────────────────────────────────────────────────

  @override
  Future<void> setAlwaysOnTop(bool value) async {}

  @override
  Future<void> setIgnoreMouseEvents(bool ignore) async {
    await MultiFloatingWindowAndroid.updateFlag(_overlayId, ignore ? OverlayFlag.clickThrough : OverlayFlag.defaultFlag);
  }

  @override
  Future<Offset> getPosition() async {
    try {
      final overlayPosition = await MultiFloatingWindowAndroid.getOverlayPosition(_overlayId);
      final dpr = _devicePixelRatio;
      return Offset(
        overlayPosition.x / dpr,
        overlayPosition.y / dpr,
      );
    } catch (e) {
      return Offset.zero;
    }
  }

  @override
  Future<void> setPosition(Offset pos) async {
    final dpr = _devicePixelRatio;
    MultiFloatingWindowAndroid.moveOverlay(
      _overlayId,
      OverlayPosition((pos.dx * dpr).round(), (pos.dy * dpr).round()),
    );
  }

  @override
  void setPositionSync(Offset pos) {
    setPosition(pos);
  }

  @override
  Future<void> moveRelative(Offset delta) async {
    try {
      final dpr = _devicePixelRatio;
      var pos = await MultiFloatingWindowAndroid.getOverlayPosition(_overlayId);
      var newPos = OverlayPosition(
        pos.x + (delta.dx * dpr).round(),
        pos.y + (delta.dy * dpr).round(),
      );
      await MultiFloatingWindowAndroid.moveOverlay(_overlayId, newPos);
    } catch (e) {
      // Handle error gracefully
    }
  }

  @override
  Future<void> setSize(Size size) async {
    final (w, h) = _toPhysicalSize(size);
    await MultiFloatingWindowAndroid.resizeOverlay(_overlayId, w, h);
  }

  @override
  Future<Size> getScreenSize() async {
    try {
      final physical = await MultiFloatingWindowAndroid.getScreenSize();
      final dpr = _devicePixelRatio;
      return Size(physical.width / dpr, physical.height / dpr);
    } catch (e) {
      return const Size(360, 640);
    }
  }

  @override
  Future<void> startDragging() async {
    await MultiFloatingWindowAndroid.startDragging(_overlayId);
  }

  @override
  String? getForegroundWindowTitle() => null;

  @override
  Stream<String>? get onForegroundWindowTitle => null;
}