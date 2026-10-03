import 'dart:ui';

import 'key_event.dart';
import 'pointer_event.dart';

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

  /// 按 [keys] 初始化并设置监听器(注册/重挂时调用)。
  Future<void> arm(List<KeyIdentifier> keys);

  /// 声明"光标落在哪些矩形内才算抓到桌宠"([physicalRects] 为**物理屏幕像素**)。
  ///
  /// 悬浮窗整窗穿透、收不到鼠标消息，桌宠的点击/拖拽只能由全局钩子驱动；钩子
  /// 用这份矩形决定"左键按下算不算抓到了桌宠"，从而避免转发桌面上的每次移动。
  Future<void> setWatchRects(List<Rect> physicalRects);

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
  Future<void> setWatchRects(List<Rect> physicalRects) async {}

  @override
  Future<void> disarm() async {}
}
