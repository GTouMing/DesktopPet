import 'dart:ui';

import '../core/hit_shape.dart';
import 'key_event.dart';
import 'pointer_event.dart';

/// 一条下发给全局钩子的命中区域（**物理屏幕像素**）。
///
/// [rect] 是包围盒；[shape] 说明矩形内哪一部分算命中（v1 恒为整矩形）。
/// 这是为 Live2D 预留的可扩展 payload（`single-engine-overlay.md` §13.2）。
typedef WatchRegion = ({Rect rect, HitShape shape});

/// 平台全局输入源抽象。
///
/// 负责把平台(Windows 全局钩子)的按键 down/up 转成 [InputKeyEvent]、
/// 把鼠标指针事件转成 [InputPointerEvent]，通过回调交给上层派发。
/// 业务系统不直接接触本接口。
abstract class InputSource {
  /// 当前平台是否支持全局按键检测。
  bool get supported;

  /// 按键事件出口(由 InputService 设置为注册表派发)。
  void Function(InputKeyEvent event)? onEvent;

  /// 鼠标指针事件出口(由 InputService 送往桌宠命中/拖拽路由)。
  void Function(InputPointerEvent event)? onPointer;

  /// 鼠标反馈：光标位置（**物理屏幕像素**）。只在 [setMouseTracking] 为 true 期间上报。
  void Function(Offset physical)? onCursor;

  /// 鼠标反馈：鼠标按键 down/up。只在 [setMouseTracking] 为 true 期间上报。
  void Function(MouseButton button, bool down)? onMouseButton;

  /// 按 [keys] 初始化并设置监听器(注册/重挂时调用)。
  Future<void> arm(List<KeyIdentifier> keys);

  /// 声明"光标落在哪些区域内才算抓到桌宠"（[regions] 为**物理屏幕像素**）。
  ///
  /// 悬浮窗整窗穿透、收不到鼠标消息，桌宠的点击/拖拽只能由全局钩子驱动；钩子
  /// 用这份区域决定"左键按下算不算抓到了桌宠"，从而避免转发桌面上的每次移动。
  /// 每条区域的 [WatchRegion.shape] 是预留的可扩展命中 payload（v1 恒为整矩形）。
  Future<void> setWatchRegions(List<WatchRegion> regions);

  /// 开启/关闭鼠标反馈上报（光标跟随 + 鼠标按键）。与桌宠拖拽的指针事件互不影响。
  Future<void> setMouseTracking(bool on);

  /// 卸载监听器。
  Future<void> disarm();
}

/// 非支持平台的空实现(Android 等,本次不接入原生输入)。
class NoopInputSource extends InputSource {
  @override
  bool get supported => false;

  @override
  Future<void> arm(List<KeyIdentifier> keys) async {}

  @override
  Future<void> setWatchRegions(List<WatchRegion> regions) async {}

  @override
  Future<void> setMouseTracking(bool on) async {}

  @override
  Future<void> disarm() async {}
}
