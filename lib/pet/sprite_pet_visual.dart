import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../petpack/pet_pack.dart';
import '../petpack/sheet/sprite_renderer.dart';
import '../petpack/state/state_define.dart';
import 'pet_animation.dart';
import 'pet_visual.dart';

/// 精灵图渲染实现。
///
/// 等价于改造前 `PetWidget` 内部那套 `PetAnimation` + `SpriteRenderer`，只是搬到
/// 了 [PetVisual] 之后：宿主不再认识精灵图，只认识「状态 → 画面」。
class SpritePetVisual implements PetVisual {
  SpritePetVisual({
    required this._pack,
    required this._vsync,
    required this._onAnimChanged,
    required this._onAnimationComplete,
  });

  final PetPack _pack;
  final TickerProvider _vsync;
  final void Function(String animName) _onAnimChanged;
  final void Function() _onAnimationComplete;

  /// 已加载的动画实例。
  final Map<String, PetAnimation> _animations = {};

  /// 正在加载中的动画（并发去重，避免为同一动画重复创建实例与图集）。
  final Map<String, Future<PetAnimation?>> _loading = {};

  bool _ready = false;
  bool _disposed = false;
  String? _current;

  @override
  String? get animationName => _current;

  @override
  Future<void> prepare(String currentState) async {
    if (_ready || _disposed) return;

    // 先加载当前状态所需的动画（可能因交互已不同于 pack.initialState）。
    await _playForState(currentState);
    if (_disposed) return;

    _ready = true;
    _preloadRemaining();
  }

  @override
  void playState(String stateName, StateDef? stateDef) {
    if (!_ready || _disposed || stateName.isEmpty) return;

    final animName = stateDef?.animation ?? stateName;
    if (animName.isEmpty || _current == animName) return;

    _animations[_current]?.stop();

    final next = _animations[animName];
    if (next == null) {
      unawaited(_playForState(stateName));
      return;
    }

    next.play(playCount: stateDef?.playCount);
    _current = animName;
    _onAnimChanged(animName);
  }

  @override
  Widget build(BuildContext context, Size size, StateDef? stateDef) {
    final anim = _current == null ? null : _animations[_current];
    if (anim == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: anim.controller,
      builder: (context, child) {
        final sheet = anim.sheet;
        final controller = anim.controller;
        final frame = (controller.value * sheet.frameCount)
            .floor()
            .clamp(0, sheet.frameCount - 1);
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
        return Opacity(
          opacity: stateDef.computeOpacity(t),
          child: childWidget,
        );
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    for (final anim in _animations.values) {
      anim.dispose();
    }
    _animations.clear();
    _loading.clear();
    _ready = false;
    _current = null;
  }

  // ── 内部 ─────────────────────────────────────────────────────────────

  Future<void> _playForState(String stateName) async {
    final stateDef = _pack.states[stateName];
    final animName = stateDef?.animation ?? stateName;
    if (animName.isEmpty) return;

    final anim = await _ensure(animName);
    if (anim == null || _disposed) return;

    anim.play(playCount: stateDef?.playCount);
    _current = animName;
    _onAnimChanged(animName);
  }

  Future<PetAnimation?> _ensure(String animName) {
    final existing = _animations[animName];
    if (existing != null) return Future.value(existing);
    return _loading.putIfAbsent(animName, () => _load(animName));
  }

  Future<PetAnimation?> _load(String animName) async {
    try {
      final anim = await PetAnimation.load(
        pack: _pack,
        animName: animName,
        vsync: _vsync,
        onAnimationComplete: () {
          // 完成通知可能是过期的（已经切走了），丢弃。
          if (_disposed || _current != animName) return;
          _onAnimationComplete();
        },
      );
      if (_disposed) {
        anim.dispose();
        return null;
      }
      _animations[animName] = anim;
      return anim;
    } catch (e, s) {
      // 图集加载失败（缺帧 / 解码失败 / 磁盘问题）不该变成未捕获的异步错误：
      // 那会让这个动画永远加载不出来，宠物表现为“永久透明”，原因却看着与渲染无关。
      if (kDebugMode) {
        debugPrint('[pet] animation "$animName" failed: $e\n$s');
      }
      return null;
    } finally {
      _loading.remove(animName);
    }
  }

  void _preloadRemaining() {
    for (final animName in _pack.anims.keys) {
      if (_animations.containsKey(animName) || _loading.containsKey(animName)) {
        continue;
      }
      _ensure(animName);
    }
  }
}
