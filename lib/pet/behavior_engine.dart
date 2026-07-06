import 'dart:math';
import 'dart:ui';

import '../core/constants.dart';
import '../core/enums.dart';
import 'pet_state.dart';
import '../skin/state/state_define.dart';

/// Drives pet movement and state transitions via a JSON-configured StateMachine.
///
/// ## 职责边界
/// - 目标位置生成、位置插值、事件驱动跳转（arrived、direction）
/// - **不负责** Timer 调度——由 [PetNotifier] 统一管理
class BehaviorEngine {
  final Random _random = Random();
  StateMachine? _machine;

  /// Bind to the state machine from the current skin. Must be called after skin loads.
  void bind(StateMachine machine) {
    _machine = machine;
  }

  /// Main tick: advance toward target, detect arrival & direction.
  PetState tick(PetState state, Size screenSize) {
    if (_machine == null) return state;

    // 1. Walking: advance toward target
    if (_machine!.shouldMove && state.targetPosition != null) {
      final dx = state.targetPosition!.dx - state.position.dx;
      final dy = state.targetPosition!.dy - state.position.dy;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance < 5) {
        // Arrived: fire "arrived" event into state machine
        final next = _machine!.onEvent(Trigger.arrived);
        if (next != null) {
          _machine!.transitionTo(next);
          return state.copyWith(currentState: next, clearTarget: true);
        }
        return state.copyWith(clearTarget: true);
      }
      Direction direction = state.direction;
      if (dx < -1) {
        direction = Direction.left;
      } else if (dx > 1) {
        direction = Direction.right;
      }
      // Fire direction trigger to state machine for mirror states
      String trigger = direction == Direction.left ? 'moveLeft' : 'moveRight';
      final nextState = _machine?.onEvent(trigger);
      if (nextState != null) {
        _machine!.transitionTo(nextState);
      }
      final speed = petWalkSpeed * state.finalSpeed * (behaviorTickMs / 1000.0);
      final newX = (state.position.dx + (dx / distance) * speed).clamp(0.0, screenSize.width - state.finalPetSize.width);
      final newY = (state.position.dy + (dy / distance) * speed).clamp(0.0, screenSize.height - state.finalPetSize.height);
      final effectiveState = nextState ?? state.currentState;
      return state.copyWith(currentState: effectiveState, position: Offset(newX, newY), direction: direction);
    }

    // No transition, no movement
    return state;
  }

  String? onEvent(String trigger) {
    final next = _machine?.onEvent(trigger);
    if (next != null) _machine?.transitionTo(next);
    return next;
  }

  void transitionTo(String stateName) {
    _machine?.transitionTo(stateName);
  }

  /// 用当前活动窗口标题匹配 `window` 触发器规则，返回目标状态名。
  String? matchWindow(String title) => _machine?.matchWindow(title);

  /// Dispose the state machine (cancels any pending timers).
  void dispose() {
    _machine = null;
  }

  /// 生成随机移动的目标坐标。
  Offset randomTargetPosition(Size screenSize, Size petSize) {
    final x = _random.nextDouble() * (screenSize.width - petSize.width);
    final y = _random.nextDouble() * (screenSize.height - petSize.height);
    return Offset(x, y);
  }
}
