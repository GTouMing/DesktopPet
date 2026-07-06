import 'dart:ui';

import 'package:desktop_pet/core/enums.dart';

/// 桌宠运行时瞬间快照。
///
/// ## 字段说明
/// - 行为状态：`[currentState, direction, position, targetPosition, isDragging, isVisible, lastInteractionTime, isReady]`
///   由 [PetNotifier] 维护和驱动（行为循环、交互事件）。
/// - 渲染状态：`[skinError, currentAnim, opacity, petSize, baseFrameSize, remainingRepeats]`
///   供 [PetWidget] 消费
///
/// ## WindowController 关系
/// [windowController] 由 [PetResources] 持有，[PetNotifier] 主动同步状态到物理窗口。
class PetState {
  // ── 行为逻辑 ─────────────────────────────────────────────────────────
  final String currentState;
  final Direction direction;
  final Offset position;
  final Offset? targetPosition;
  final bool isDragging;
  final bool isVisible;
  final DateTime lastInteractionTime;

  // ── 渲染状态 ─────────────────────────────────────────────────────────

  /// 皮肤加载状态：`null`=加载中，`''`=正常，非空字符串=错误描述。
  ///
  /// 由 [PetNotifier._initAsync] 在初始化完成后设置。
  final String? skinError;

  /// 当前播放的动画名，由 PetWidget 在切换动画时更新。
  final String currentAnim;

  /// 最终不透明度（baseOpacity × opacityMultiplier），由 PetNotifier 定期更新。
  /// 应用层（PetWidget）使用此值包裹 Opacity widget。
  final double finalOpacity;

  /// 最终动画播放速度（baseSpeed × speedMultiplier），由 PetNotifier 定期更新。
  /// PetWidget 据此调整 AnimationController.duration。
  final double finalSpeed;

  /// 宠物在屏幕上的渲染尺寸，由 PetNotifier 根据缩放计算后同步。
  final Size finalPetSize;

  /// 皮肤原生帧尺寸（缩放前），由 [PetNotifier.initStateFromSkin] 设置。
  final Size? basePetSize;

  /// 当前动画剩余重复次数，由 PetWidget 管理。
  final int remainingRepeats;

  const PetState({
    this.currentState = '',
    this.direction = Direction.none,
    this.position = Offset.zero,
    this.targetPosition,
    this.isDragging = false,
    this.isVisible = true,
    required this.lastInteractionTime,
    this.skinError,
    this.currentAnim = '',
    this.finalOpacity = 1.0,
    this.finalSpeed = 1.0,
    this.finalPetSize = Size.zero,
    this.basePetSize,
    this.remainingRepeats = 0,
  });

  PetState copyWith({
    String? currentState,
    Direction? direction,
    Offset? position,
    bool clearTarget = false,
    Offset? targetPosition,
    bool? isDragging,
    bool? isVisible,
    DateTime? lastInteractionTime,
    bool? isReady,
    String? skinError,
    bool clearSkinError = false,
    String? currentAnim,
    double? finalOpacity,
    double? finalSpeed,
    Size? finalPetSize,
    Size? basePetSize,
    int? remainingRepeats,
  }) {
    return PetState(
      currentState: currentState ?? this.currentState,
      direction: direction ?? this.direction,
      position: position ?? this.position,
      targetPosition: clearTarget ? null : (targetPosition ?? this.targetPosition),
      isDragging: isDragging ?? this.isDragging,
      isVisible: isVisible ?? this.isVisible,
      lastInteractionTime: lastInteractionTime ?? this.lastInteractionTime,
      skinError: clearSkinError ? null : (skinError ?? this.skinError),
      currentAnim: currentAnim ?? this.currentAnim,
      finalOpacity: finalOpacity ?? this.finalOpacity,
      finalSpeed: finalSpeed ?? this.finalSpeed,
      finalPetSize: finalPetSize ?? this.finalPetSize,
      basePetSize: basePetSize ?? this.basePetSize,
      remainingRepeats: remainingRepeats ?? this.remainingRepeats,
    );
  }
}