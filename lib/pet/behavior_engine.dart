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
      final center = Offset(maxX / 2, maxY / 2);
      if (currentPos.dy <= center.dy) {
        return Offset(currentPos.dx, 0);
      }
      else if (currentPos.dx > center.dx) {
        return Offset(maxX, currentPos.dy);
      }
      else if (currentPos.dy > center.dy) {
        return Offset(currentPos.dx, maxX);
      }
      else {
        return Offset(0, currentPos.dy);
      }
    }
    else {
      return Offset.zero;
    }
  }
}
