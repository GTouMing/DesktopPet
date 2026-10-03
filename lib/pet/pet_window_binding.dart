import 'dart:ui';

import '../platform/platform_factory.dart';
import '../platform/window_interface.dart';
import '../storage/models/pet_config.dart';

/// 桌宠与**系统悬浮窗**之间的同步（仅 Android）。
///
/// Windows 单引擎下桌宠只是场景里的一个条目——位置、显隐、锁定都由场景表达，
/// 根本没有对应的窗口，[createWindowController] 返回 null，于是本对象整体退化为
/// 空操作，调用方不必到处判空。
///
/// [applyVisible] / [applyLocked] 会缓存"已应用值"：设置写入会对所有桌宠广播
/// `settings_updated`，而 `show()/hide()`（ShowWindow 会抢焦点、改变 z 序）与穿透
/// 样式不该被重复下发。
class PetWindowBinding {
  PetWindowBinding(String petId)
      : _window = createWindowController(windowId: petId);

  final WindowController? _window;

  Size? _screenSize;
  bool? _appliedVisible;
  bool? _appliedLocked;

  /// 是否存在真实窗口（仅 Android 为 true）。
  bool get isAttached => _window != null;

  /// 窗口所在屏幕的尺寸（逻辑像素）；尚未取到时为 null。
  Size? get screenSize => _screenSize;

  Future<void> init() async => _window?.petInit();

  Future<void> refreshScreenSize() async {
    final window = _window;
    if (window == null) return;
    _screenSize = await window.getScreenSize();
  }

  Future<void> setSize(Size size) async => _window?.setSize(size);

  void setPositionSync(Offset position) => _window?.setPositionSync(position);

  Future<void> setPosition(Offset position) async =>
      _window?.setPosition(position);

  /// 回读窗口位置（拖拽结束后收敛落点用）。
  Future<Offset> readPosition() async =>
      await _window?.getPosition() ?? Offset.zero;

  /// 把整只宠物交给系统拖拽（系统移动整个悬浮窗）。
  Future<void> startDragging() async => _window?.startDragging();

  /// 按 [pet] 的 `isLocked` 设置整窗鼠标穿透——这就是"锁定"在窗口侧的语义。
  Future<void> applyLocked(PetConfig? pet) async {
    final window = _window;
    if (window == null || pet == null || _appliedLocked == pet.isLocked) return;
    _appliedLocked = pet.isLocked;
    try {
      await window.setIgnoreMouseEvents(pet.isLocked);
    } catch (_) {}
  }

  /// 按 [pet] 的 `isVisible` 开关悬浮窗。
  Future<void> applyVisible(PetConfig? pet) async {
    final window = _window;
    if (window == null || pet == null || _appliedVisible == pet.isVisible) {
      return;
    }
    _appliedVisible = pet.isVisible;
    try {
      if (pet.isVisible) {
        await window.show();
      } else {
        await window.hide();
      }
    } catch (_) {}
  }
}
