import 'package:desktop_pet/pet/pet_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/providers.dart';
import '../pet/pet_resources.dart';
import '../skin/sheet/sprite_renderer.dart';
import '../skin/sheet/sprite_sheet_generator.dart';
import '../skin/state/state_define.dart';

/// 桌宠渲染组件。
///
/// 皮肤包加载和初始精灵图预加载由 [PetNotifier] 在构造时完成，
/// PetWidget 只需监听 [skinError] 状态：就绪后创建 [AnimationController] 并渲染。
class PetWidget extends ConsumerStatefulWidget {
  const PetWidget({super.key});

  @override
  ConsumerState<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends ConsumerState<PetWidget>
    with TickerProviderStateMixin {
  AnimationController? _activeController;
  SpriteSheetData? _activeSheet;

  PetNotifier get _notifier => ref.read(petStateProvider.notifier);
  PetResources get _resources => _notifier.resources;

  // ── 动画管理 ─────────────────────────────────────────────────────────

  /// 激活指定动画：暂停/重置上一个，切换到新的并开始播放。
  void _activateAnimation(String animName) {
    final res = _resources;
    final prev = _activeController;
    if (prev != null && prev != res.controllers[animName]) {
      prev.stop();
      prev.reset();
    }
    _notifier.currentAnim = animName;
    _activeSheet = res.sheets[animName];
    _activeController = res.controllers[animName];

    final stateName = ref.read(petStateProvider).currentState;
    final stateDef = res.skin!.states[stateName];
    _notifier.remainingRepeats = stateDef?.repeatCount ?? 0;

    _activeController!.forward();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    final petState = ref.read(petStateProvider);
    final stateDef = _resources.skin?.states[petState.currentState];
    // 状态不存在（如 currentState 为空时），按旧逻辑直接用 _activeController 处理
    if (stateDef == null) {
      if (_activeController != null) {
        _activeController!.forward(from: 0);
      }
      return;
    }
    // 如果当前状态已切换，忽略上一个动画的 stale 完成回调
    final expectedAnim = stateDef.animation;
    if (petState.currentAnim != expectedAnim) return;

    if (stateDef.isInfinite) {
      _activeController!.forward(from: 0);
      return;
    }

    if (stateDef.repeatCount > 0 && petState.remainingRepeats > 0) {
      _notifier.decrementRepeats();
      _activeController!.forward(from: 0);
      return;
    }

    Future.microtask(() {
      if (mounted) _notifier.onEvent(Trigger.complete);
    });
  }

  // ── 生命周期 ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    final res = _resources;
    for (final c in res.controllers.values) {
      c.removeStatusListener(_onAnimationStatus);
      c.dispose();
    }
    res.controllers.clear();
    super.dispose();
  }

  // ── 构建 ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petStateProvider);
    final res = _resources;

    ref.listen(petStateProvider, (prev, next) {
      final skin = res.skin;
      if (skin == null) return;

      // 初始加载完成 → 播放初始动画
      if (prev?.skinError == null && next.skinError == '') {
        _switchAnimation(skin.initialState);
        return;
      }

      // 状态变更 → 动画切换
      final stateDef = skin.states[next.currentState];
      final anim = stateDef?.animation ?? next.currentState;
      if (next.currentAnim != anim) {
        _switchAnimation(anim);
      }
    });

    // 皮肤加载失败
    if (petState.skinError?.isNotEmpty ?? false) {
      return Center(
        child: Text('error: ${petState.skinError}'),
      );
    }

    // 尚未就绪（skinError==null 仍初始化中，或 skinError=='' 但控制器未创建）
    if (petState.skinError == null ||
        !petState.isVisible ||
        petState.finalPetSize.isEmpty ||
        _activeSheet == null ||
        _activeController == null) {
      return const SizedBox.shrink();
    }

    final sheet = _activeSheet!;
    final controller = _activeController!;
    final stateDef = res.skin!.states[petState.currentState];

    return RepaintBoundary(
      child: Opacity(
        opacity: petState.finalOpacity,
        child: _buildAnimation(sheet, controller, petState.finalPetSize, stateDef),
      ),
    );
  }

  /// 切换动画：按需加载精灵图，创建控制器，然后激活。
  void _switchAnimation(String animName) {
    final res = _resources;
    if (res.skin == null) return;
    final animDef = res.skin!.anims[animName];
    final sheet = res.sheets[animName];
    if (animDef == null || sheet == null) return;

    if (!res.controllers.containsKey(animName)) {
      final controller = AnimationController(
        duration: Duration(
          milliseconds: ((1000 / animDef.fps) * sheet.frameCount).round(),
        ),
        vsync: this,
      );
      controller.addStatusListener(_onAnimationStatus);
      res.controllers[animName] = controller;
    }
    _activateAnimation(animName);
    if (mounted) setState(() {});
  }

  Widget _buildAnimation(
    SpriteSheetData sheet,
    AnimationController controller,
    Size size,
    StateDef? stateDef,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
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
}