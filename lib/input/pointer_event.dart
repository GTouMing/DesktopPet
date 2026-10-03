import 'dart:ui';

/// 全局鼠标指针事件阶段。
enum PointerPhase { down, move, up }

/// 一次全局鼠标指针事件。
///
/// [position] 为**物理屏幕像素**，与原生 `GetCursorPos` / 低层钩子的 `pt` 同一
/// 坐标空间；调用方按需除以 DPR 换算成悬浮窗内容坐标。
///
/// 之所以走全局钩子而不是窗口鼠标消息：悬浮窗常驻整窗穿透（这是"桌面永远可用"
/// 的前提），它收不到任何鼠标消息，见 windows/runner/global_input.cpp。
class InputPointerEvent {
  final PointerPhase phase;
  final Offset position;

  const InputPointerEvent(this.phase, this.position);

  @override
  String toString() => 'InputPointerEvent(${phase.name}, $position)';
}
