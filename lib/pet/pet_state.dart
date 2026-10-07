import 'dart:ui';

import 'chat_bubble_payload.dart';

/// 桌宠运行时瞬间快照。
///
/// ## 字段说明
/// - 行为状态：`[currentState, position, targetPosition, isDragging, lastInteractionTime]`
///   由 [PetNotifier] 维护和驱动（行为循环、交互事件）。
/// - 渲染状态：`[packError, currentAnim, opacity, petSize, baseFrameSize]`
///   供 [PetWidget] 消费
class PetState {
  // ── 行为逻辑 ─────────────────────────────────────────────────────────
  final String currentState;
  final Offset position;
  final Offset? targetPosition;
  final bool isDragging;
  final DateTime lastInteractionTime;

  // ── 渲染状态 ─────────────────────────────────────────────────────────

  /// 宠物包加载状态：`null`=加载中，`''`=正常，非空字符串=错误描述。
  final String? packError;

  /// 当前播放的动画名，由 PetNotifier 在切换动画时更新。
  final String currentAnim;

  /// 最终不透明度（baseOpacity × opacityMultiplier），由 PetNotifier 定期更新。
  final double finalOpacity;

  /// 宠物在屏幕上的渲染尺寸，由 PetNotifier 根据缩放计算后同步。
  final Size finalPetSize;

  /// 宠物包原生帧尺寸（缩放前），由 [PetNotifier._init] 设置。
  final Size? basePetSize;

  /// 宠物包"代数"：换包（编辑宠物时改了宠物包路径）时 +1，[PetWidget] 据此丢弃旧
  /// 渲染器、按新包重建视图（精灵图 ↔ Live2D 也走这条路径）。
  final int packGeneration;

  /// 当前显示的聊天气泡；null = 不显示。由 `PetNotifier.showBubble` /
  /// 状态机的 `StateDef.bubble` 设置，宿主 `ChatBubbleLayer` 消费。
  final ChatBubblePayload? bubble;

  const PetState({
    this.currentState = '',
    this.position = Offset.zero,
    this.targetPosition,
    this.isDragging = false,
    required this.lastInteractionTime,
    this.packError,
    this.currentAnim = '',
    this.finalOpacity = 1.0,
    this.finalPetSize = Size.zero,
    this.basePetSize,
    this.packGeneration = 0,
    this.bubble,
  });

  PetState copyWith({
    String? currentState,
    Offset? position,
    bool cleanTarget = false,
    Offset? targetPosition,
    bool? isDragging,
    DateTime? lastInteractionTime,
    String? packError,
    String? currentAnim,
    double? finalOpacity,
    Size? finalPetSize,
    Size? basePetSize,
    int? packGeneration,
    ChatBubblePayload? bubble,
    bool clearBubble = false,
  }) {
    return PetState(
      currentState: currentState ?? this.currentState,
      position: position ?? this.position,
      targetPosition: cleanTarget ? null : (targetPosition ?? this.targetPosition),
      isDragging: isDragging ?? this.isDragging,
      lastInteractionTime: lastInteractionTime ?? this.lastInteractionTime,
      packError: packError ?? this.packError,
      currentAnim: currentAnim ?? this.currentAnim,
      finalOpacity: finalOpacity ?? this.finalOpacity,
      finalPetSize: finalPetSize ?? this.finalPetSize,
      basePetSize: basePetSize ?? this.basePetSize,
      packGeneration: packGeneration ?? this.packGeneration,
      bubble: clearBubble ? null : (bubble ?? this.bubble),
    );
  }
}
