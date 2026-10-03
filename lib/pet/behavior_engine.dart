import 'dart:math';
import 'dart:ui';

import '../core/constants.dart';
import '../skin/state/state_define.dart';
import 'pet_context.dart';
import 'pet_state.dart';

/// ## 职责边界
/// - 目标位置生成、位置插值、事件驱动跳转（arrived、direction）
class BehaviorEngine {
  final Random _random = Random();
  final PetContext context;

  BehaviorEngine({required this.context});

  /// Main tick: advance toward target, detect arrival & direction.
  Offset? tick(PetState state) {
    final ctx = context;
    if (state.targetPosition == null) return null;

    final target = state.targetPosition!;
    final ss = ctx.screenSize;
    final maxX = ss.width - ctx.finalPetSize.width;
    final maxY = ss.height - ctx.finalPetSize.height;
    final speed = petWalkSpeed * state.finalSpeed * (behaviorTickMs / 1000.0);
    final pos = state.position;

    return _moveDirect(pos, target, speed, maxX, maxY, ctx);
  }

  // ═════════════════════════════════════════════════════════════════════
  //  直线移动（commitToTarget / moveAroundScreen 非边缘共用）
  // ═════════════════════════════════════════════════════════════════════

  Offset? _moveDirect(Offset pos, Offset target, double speed,
                      double maxX, double maxY, PetContext ctx)
  {
    final dx = target.dx - pos.dx;
    final dy = target.dy - pos.dy;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance < speed) {
      ctx.onEvent(Trigger.arrived);
      return null;
    }
    _emitDirection(dx, dy, ctx);
    return Offset(
      (pos.dx + (dx / distance) * speed).clamp(0.0, maxX),
      (pos.dy + (dy / distance) * speed).clamp(0.0, maxY),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //  方向触发器
  // ═════════════════════════════════════════════════════════════════════

  /// 直线移动方向触发器。方向作为触发器名。
  void _emitDirection(double dx, double dy, PetContext ctx) {
    String? trigger;
    if (dx < 0) {
      trigger = Trigger.moveLeft;
    } else if (dx > 0) {
      trigger = Trigger.moveRight;
    } else if (dy < 0) {
      trigger = Trigger.moveUp;
    } else if (dy > 0) {
      trigger = Trigger.moveDown;
    }
    if (trigger != null) ctx.onEvent(trigger);
  }

  // ═════════════════════════════════════════════════════════════════════
  //  目标生成
  // ═════════════════════════════════════════════════════════════════════

  Offset randomTarget(StateDef? stateDef, Offset currentPos) {
    final ctx = context;
    final targetPos = stateDef?.targetPos;
    final maxX = ctx.screenSize.width - ctx.finalPetSize.width;
    final maxY = ctx.screenSize.height - ctx.finalPetSize.height;

    if (stateDef?.behavior == moveToTarget) {
      if (targetPos != null && targetPos.dx >= 0 && targetPos.dy >= 0) {
        return Offset(targetPos.dx.clamp(0.0, maxX), targetPos.dy.clamp(0.0, maxY));
      }
      return Offset(_random.nextDouble() * maxX, _random.nextDouble() * maxY);
    }
    else if (stateDef?.behavior == moveToEdge) {
      if (targetPos != null) {
        if (targetPos.dx == 0 || targetPos.dy == 0 || targetPos.dx >= maxX || targetPos.dy >= maxY) {
          return Offset(
              targetPos.dx.clamp(0.0, maxX), targetPos.dy.clamp(0.0, maxY));
        }
      }
      // 贴到距离最近的一条边。
      //
      // 原实现把 maxX(横向范围)当成了 y 坐标返回,且分支顺序使 left 分支永不命中。
      final toTop = currentPos.dy;
      final toBottom = maxY - currentPos.dy;
      final toLeft = currentPos.dx;
      final toRight = maxX - currentPos.dx;
      final nearest = min(min(toTop, toBottom), min(toLeft, toRight));
      if (nearest == toTop) return Offset(currentPos.dx, 0);
      if (nearest == toBottom) return Offset(currentPos.dx, maxY);
      if (nearest == toLeft) return Offset(0, currentPos.dy);
      return Offset(maxX, currentPos.dy);
    }
    else {
      return Offset.zero;
    }
  }
}
