import 'dart:ui';

/// Abstract interface for platform-specific pet window management.
///
/// Windows 单引擎改造后桌宠不再是独立窗口（位置/显隐由悬浮窗场景表达），因此
/// 只有 Android 提供实现；见 `platform_factory.dart:createWindowController`。
/// 行为循环里"移动桌宠"这一步仍走 [setPosition] / [setPositionSync]。
abstract class WindowController {
  /// 初始化单个桌宠窗口。
  Future<void> petInit();

  Future<void> show();
  Future<void> hide();
  Future<void> setIgnoreMouseEvents(bool ignore);
  Future<Offset> getPosition();

  /// 不等待完成的移动（行为刻每 [behaviorTickMs] 调用一次，避免异步消息堆积）。
  void setPositionSync(Offset pos);

  Future<void> setPosition(Offset pos);
  Future<void> setSize(Size size);
  Future<Size> getScreenSize();

  /// 聊天气泡的预留高度（逻辑像素，仅在桌宠**上方**预留）。
  ///
  /// 窗口高度 +h、纵坐标 -h，使桌宠在屏幕上的可视位置保持不变；0 = 不预留（收回）。
  /// 只影响窗口几何，重下发尺寸/位置由调用方（`PetNotifier._applyBubbleHeadroom`）负责。
  void setHeadroom(double logical);

  /// 设备像素比，用于逻辑/物理像素转换。
  ///
  /// Android 原生悬浮窗用物理像素，而 Flutter 侧一律用逻辑像素，故调用侧需据此
  /// 换算。
  double get devicePixelRatio;

  /// 交给系统接管拖拽循环，返回的 [Future] 完成时表示拖拽结束。
  Future<void> startDragging();
}
