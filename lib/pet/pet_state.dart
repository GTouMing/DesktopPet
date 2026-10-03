import 'dart:ui';

/// 桌宠运行时瞬间快照。
///
/// ## 字段说明
/// - 行为状态：`[currentState, position, targetPosition, isDragging, lastInteractionTime]`
///   由 [PetNotifier] 维护和驱动（行为循环、交互事件）。
/// - 渲染状态：`[skinError, currentAnim, opacity, petSize, baseFrameSize]`
///   供 [PetWidget] 消费
class PetState {
  // ── 行为逻辑 ─────────────────────────────────────────────────────────
  final String currentState;
  final Offset position;
  final Offset? targetPosition;
  final bool isDragging;
  final DateTime lastInteractionTime;

  // ── 渲染状态 ─────────────────────────────────────────────────────────

  /// 皮肤加载状态：`null`=加载中，`''`=正常，非空字符串=错误描述。
  final String? skinError;

  /// 当前播放的动画名，由 PetNotifier 在切换动画时更新。
  final String currentAnim;

  /// 最终不透明度（baseOpacity × opacityMultiplier），由 PetNotifier 定期更新。
  final double finalOpacity;

  /// 最终动画播放速度（baseSpeed × speedMultiplier），由 PetNotifier 定期更新。
  final double finalSpeed;

  /// 宠物在屏幕上的渲染尺寸，由 PetNotifier 根据缩放计算后同步。
  final Size finalPetSize;

  /// 皮肤原生帧尺寸（缩放前），由 [PetNotifier._init] 设置。
  final Size? basePetSize;

  const PetState({
    this.currentState = '',
    this.position = Offset.zero,
    this.targetPosition,
    this.isDragging = false,
    required this.lastInteractionTime,
    this.skinError,
    this.currentAnim = '',
    this.finalOpacity = 1.0,
    this.finalSpeed = 1.0,
    this.finalPetSize = Size.zero,
    this.basePetSize,
  });

  PetState copyWith({
    String? currentState,
    Offset? position,
    bool cleanTarget = false,
    Offset? targetPosition,
    bool? isDragging,
    DateTime? lastInteractionTime,
    String? skinError,
    String? currentAnim,
    double? finalOpacity,
    double? finalSpeed,
    Size? finalPetSize,
    Size? basePetSize,
  }) {
    return PetState(
      currentState: currentState ?? this.currentState,
      position: position ?? this.position,
      targetPosition: cleanTarget ? null : (targetPosition ?? this.targetPosition),
      isDragging: isDragging ?? this.isDragging,
      lastInteractionTime: lastInteractionTime ?? this.lastInteractionTime,
      skinError: skinError ?? this.skinError,
      currentAnim: currentAnim ?? this.currentAnim,
      finalOpacity: finalOpacity ?? this.finalOpacity,
      finalSpeed: finalSpeed ?? this.finalSpeed,
      finalPetSize: finalPetSize ?? this.finalPetSize,
      basePetSize: basePetSize ?? this.basePetSize,
    );
  }
}
