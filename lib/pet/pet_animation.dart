import 'package:desktop_pet/petpack/sheet/sprite_sheet_generator.dart';
import 'package:desktop_pet/petpack/sprite_pet_pack.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';

/// 桌宠动画实例，负责单组动画的播放控制（循环、重复、完成回调）。
///
/// 由 [PetNotifier] 持有和管理生命周期，由 [PetWidget] 消费渲染。
class PetAnimation {
  final String name;
  final SpriteSheetData sheet;
  final AnimationController controller;

  final void Function()? _onComplete;

  /// 总重复次数（来自状态定义）：
  /// - `0` = 无限循环
  /// - `N`  = 播放 N 次
  int _totalCount = 0;

  /// 剩余重复次数（每次完成自动递减）。
  int _remainingCount = 0;

  PetAnimation._({
    required this.name,
    required this.sheet,
    required this.controller,
    this._onComplete,
  }) {
    controller.addStatusListener(_onStatus);
  }

  /// 从皮肤包加载指定动画，生成精灵图和 [AnimationController]。
  static Future<PetAnimation> load({
    required SpritePetPack pack,
    required String animName,
    required TickerProvider vsync,
    void Function()? onAnimationComplete,
  }) async {
    final sheet = await SpriteSheetGenerator.generateFromPack(pack, animName);
    final animDef = pack.anims[animName]!;
    final duration = Duration(
      milliseconds: ((1000 / animDef.fps) * sheet.frameCount).round(),
    );
    final controller = AnimationController(duration: duration, vsync: vsync);
    return PetAnimation._(
      name: animName,
      sheet: sheet,
      controller: controller,
      onComplete: onAnimationComplete,
    );
  }

  /// 开始播放动画（从头开始）。
  ///
  /// [playCount] 来自状态定义，不传则沿用上次的值。
  void play({int? playCount = 0}) {
    _totalCount = playCount!;
    _remainingCount = playCount > 0 ? playCount - 1 : 0;
    controller.forward(from: 0);
  }

  /// 停止并重置动画。
  void stop() {
    controller.stop();
    controller.reset();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    if (_totalCount == 0) {
      // 无限循环
      controller.forward(from: 0);
      return;
    }

    if (_remainingCount > 0) {
      _remainingCount--;
      controller.forward(from: 0);
      return;
    }

    // 所有重复播放完毕，通知外部
    _onComplete?.call();
  }

  void dispose() {
    controller.removeStatusListener(_onStatus);
    controller.dispose();
    sheet.dispose();
  }
}
