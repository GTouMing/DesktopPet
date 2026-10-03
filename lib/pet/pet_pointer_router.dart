import 'dart:async';
import 'dart:ui';

import '../core/constants.dart';
import '../core/overlay_controller.dart';
import '../input/input.dart';
import '../pet/pet_notifier.dart';

/// 把全局钩子转发来的鼠标事件路由到具体某只桌宠。
///
/// 为什么需要它：悬浮窗常驻整窗穿透（`WS_EX_TRANSPARENT`，这是"桌面永远可用"的
/// 前提），所以它**收不到任何鼠标消息**——Flutter 的 GestureDetector 拿不到指针。
/// 桌宠的点击与拖拽只能由进程级钩子驱动：钩子在"光标落在桌宠矩形内按下"后开始
/// 转发 down/move/up（见 windows/runner/global_input.cpp），这里做逐宠命中与
/// 拖拽状态机。
///
/// 点击与拖拽的区分沿用 Flutter 的语义：按下后移动超过 [_dragThreshold] 才算拖拽，
/// 否则松手即"点击"。
class PetPointerRouter {
  PetPointerRouter({required this.resolve});

  /// 按宠物 id 取状态管理器（取不到说明该宠物已被删除/隐藏）。
  final PetNotifier? Function(String petId) resolve;

  /// 拖拽判定阈值（逻辑像素）。
  ///
  /// 取一个很小的值：鼠标操作没有触摸的抖动问题，点一下不动就是点击，稍有移动
  /// 立刻进入拖拽，避免拖拽起步发黏。
  static const double _dragThreshold = 3.0;

  /// 本次按下抓到的桌宠（null = 没抓到，事件全部忽略）。
  String? _petId;

  /// 按下时光标与桌宠落点之差（场景坐标）。
  ///
  /// 拖拽全程用"光标 + 该偏移"算出桌宠落点，而不是逐帧累加增量：落点会被
  /// clamp 收敛进场景，累加会把这部分越界位移永久丢掉——桌宠贴边后光标再多走
  /// 多远，松手前桌宠就与手错开多远（越快越明显）。换成绝对落点后 clamp 只是
  /// 限位，光标一回到界内桌宠立刻跟手。
  Offset? _grabOffset;

  Offset? _downPos;
  bool _dragging = false;

  /// 处理一次全局指针事件。
  ///
  /// [dpr] 把物理像素换算成场景逻辑像素；[physicalOrigin] 是场景原点（虚拟桌面
  /// 左上角）在屏幕上的物理像素位置——多显示器下副屏在主屏左/上方时它是负的，
  /// 不减掉会让光标到场景的换算整体错位。
  void handle(InputPointerEvent event, double dpr, Offset physicalOrigin) {
    final scenePos = (event.position - physicalOrigin) / dpr;
    switch (event.phase) {
      case PointerPhase.down:
        _onDown(scenePos);
      case PointerPhase.move:
        _onMove(scenePos);
      case PointerPhase.up:
        _onUp();
    }
  }

  /// 最上层优先：列表按绘制顺序，靠后者在上，故取最后一个命中项。
  void _onDown(Offset scenePos) {
    String? hit;
    Offset? hitPosition;
    for (final pet in OverlayController.pets.value) {
      if (pet.locked) continue;
      if (pet.rect.contains(scenePos)) {
        hit = pet.id;
        hitPosition = pet.rect.topLeft;
      }
    }
    _petId = hit;
    // 抓取偏移与命中取自同一份矩形（即用户点下去时看到的那一帧）。
    _grabOffset = hitPosition == null ? null : hitPosition - scenePos;
    _downPos = scenePos;
    _dragging = false;
  }

  void _onMove(Offset scenePos) {
    final petId = _petId;
    final grabOffset = _grabOffset;
    if (petId == null || grabOffset == null) return;
    final notifier = resolve(petId);
    if (notifier == null) {
      _reset();
      return;
    }

    if (!_dragging) {
      final moved = (scenePos - (_downPos ?? scenePos)).distance;
      if (moved < _dragThreshold) return;
      _dragging = true;
      notifier.onDragStart();
    }

    notifier.onDragTo(scenePos + grabOffset);
  }

  void _onUp() {
    final petId = _petId;
    final notifier = petId == null ? null : resolve(petId);
    if (notifier != null) {
      if (_dragging) {
        unawaited(notifier.onDragEnd());
      } else {
        notifier.onEvent(Trigger.click);
      }
    }
    _reset();
  }

  void _reset() {
    _petId = null;
    _grabOffset = null;
    _downPos = null;
    _dragging = false;
  }
}
