import 'package:desktop_pet/pet/pet_animation.dart';
import 'package:desktop_pet/pet/pet_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/providers.dart';
import '../skin/sheet/sprite_renderer.dart';
import '../skin/state/state_define.dart';

/// 桌宠渲染组件。
///
/// 职责：
/// 1. 持有所有 [PetAnimation] 实例，控制动画切换
/// 2. 监听 [petStateProvider] 状态变化，切换动画
/// 3. 使用 [AnimatedBuilder] 驱动精灵图渲染
class PetWidget extends ConsumerStatefulWidget {
  const PetWidget({super.key});

  @override
  ConsumerState<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends ConsumerState<PetWidget>
    with TickerProviderStateMixin {

  PetNotifier get _notifier => ref.read(petStateProvider.notifier);

  // ── 动画系统 ─────────────────────────────────────────────────────────

  /// 所有预加载的动画实例，由 [initAnimations] 初始化。
  final Map<String, PetAnimation> animations = {};

  /// 动画系统是否已就绪。
  bool _animationsReady = false;

  /// 当前正在播放的动画。
  PetAnimation? get currentAnimation => animations[_notifier.currentAnim];

  // ── 生命周期 ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // 如果皮肤已就绪（非首次创建，例如 QuickLaunchOverlay 切换后重建），
    // 在下一帧初始化动画系统，避免 ref.listen 因状态未变化而无法触发
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(petStateProvider);
      if (state.skinError == '') {
        initAnimations();
      }
    });
  }

  @override
  void dispose() {
    // 必须在 super.dispose() 前释放 AnimationController（依赖 TickerProvider）
    disposeAnimations();
    super.dispose();
  }

  // ── 构建 ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petStateProvider);

    // ── 状态变化 → 动画切换 ────────────────────────────────────────────
    ref.listen(petStateProvider, (prev, next) {
      if (next.skinError != '') return;

      // 皮肤首次就绪 → 初始化动画系统
      if (prev?.skinError != '' && next.skinError == '') {
        initAnimations();
        return;
      }

      // 状态变化 → 切换动画
      if (prev?.currentState != next.currentState) {
        switchToStateAnim(next.currentState);
      }
    });

    // ── 皮肤加载失败 ──────────────────────────────────────────────────
    if (petState.skinError?.isNotEmpty ?? false) {
      return ColoredBox(
        color: Colors.red,
        child: Center(
          child: Text('error: ${petState.skinError}'),
        ),
      );
    }

    // ── 尚未就绪 ──────────────────────────────────────────────────────
    final anim = currentAnimation;
    if (petState.skinError == null || anim == null) {
      return const SizedBox.shrink();
    }

    // ── 渲染 ──────────────────────────────────────────────────────────
    final stateDef = _notifier.skin.states[petState.currentState];

    return RepaintBoundary(
      child: Opacity(
        opacity: petState.finalOpacity,
        child: _buildAnimation(anim, petState.finalPetSize, stateDef),
      ),
    );
  }

  /// 使用 [PetAnimation] 驱动精灵图渲染。
  Widget _buildAnimation(
    PetAnimation anim,
    Size size,
    StateDef? stateDef,
  ) {
    return AnimatedBuilder(
      animation: anim.controller,
      builder: (context, child) {
        final sheet = anim.sheet;
        final controller = anim.controller;
        final rawFrame = (controller.value * sheet.frameCount).floor();
        final frame = rawFrame.clamp(0, sheet.frameCount - 1);
        final t = controller.value;

        Widget childWidget = SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(
            painter: SpriteRenderer(sheet: sheet, currentFrame: frame),
            size: size,
          ),
        );

        if (stateDef == null) return childWidget;

        childWidget = Transform(
          transform: stateDef.computeTransformMatrix(size, t),
          alignment: Alignment.topLeft,
          child: childWidget,
        );
        childWidget = Opacity(
          opacity: stateDef.computeOpacity(t),
          child: childWidget,
        );

        return childWidget;
      },
    );
  }

  // ── 动画系统方法 ──────────────────────────────────────────────────────

  /// 初始化动画系统。在皮肤就绪后调用。
  Future<void> initAnimations() async {
    if (_animationsReady) return;

    // 先加载当前状态所需的动画（可能因交互已不同于 skin.initialState）
    await _loadAnimationForState(_notifier.currentState);

    _animationsReady = true;

    // 后台预加载其余动画
    _preloadRemainingAnimations();
  }

  /// 为指定状态加载所需的动画（如果尚未加载）。
  Future<void> _loadAnimationForState(String stateName) async {
    final stateDef = _notifier.skin.states[stateName];
    final animName = stateDef?.animation ?? stateName;
    if (animName.isEmpty || animations.containsKey(animName)) return;

    final anim = await PetAnimation.load(
      skin: _notifier.skin,
      animName: animName,
      vsync: this,
      onAnimationComplete: () {
        if (_notifier.currentAnim != animName) return; // stale completion
        _notifier.onEvent(Trigger.complete);
      },
    );
    animations[animName] = anim;

    // 开始播放
    anim.play(playCount: stateDef?.playCount);
    _notifier.setCurrentAnim(animName);
  }

  /// 后台预加载所有动画。
  void _preloadRemainingAnimations() {
    for (final animName in _notifier.skin.anims.keys) {
      if (animations.containsKey(animName)) continue;
      final captured = animName;
      PetAnimation.load(
        skin: _notifier.skin,
        animName: animName,
        vsync: this,
        onAnimationComplete: () {
          if (_notifier.currentAnim != captured) return;
          _notifier.onEvent(Trigger.complete);
        },
      ).then((anim) => animations[captured] = anim);
    }
  }

  /// 响应状态变更，切换到对应的动画。
  void switchToStateAnim(String stateName) {
    if (!_animationsReady || stateName.isEmpty) return;

    final stateDef = _notifier.skin.states[stateName];
    final animName = stateDef?.animation ?? stateName;
    if (animName.isEmpty || _notifier.currentAnim == animName) return;

    final prev = animations[_notifier.currentAnim];
    prev?.stop();

    final next = animations[animName];
    if (next == null) {
      _loadAnimationForState(stateName);
      return;
    }

    next.play(playCount: stateDef?.playCount);
    _notifier.setCurrentAnim(animName);
  }

  /// 释放所有动画资源（AnimationController 和精灵图）。
  void disposeAnimations() {
    for (final anim in animations.values) {
      anim.dispose();
    }
    animations.clear();
    _animationsReady = false;
  }
}
