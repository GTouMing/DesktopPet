import 'dart:async';

import 'package:desktop_pet/l10n/app_localizations.dart';
import 'package:desktop_pet/pet/pet_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../petpack/live2d_pet_pack.dart';
import '../petpack/sprite_pet_pack.dart';
import 'live2d_pet_visual.dart';
import 'pet_providers.dart';
import 'pet_visual.dart';
import 'sprite_pet_visual.dart';

/// 桌宠渲染组件。
///
/// 职责被压到两点：
/// 1. 把该桌宠的 [petStateProvider] 画出来（错误态 / 未就绪 / 正常渲染）；
/// 2. 在「宠物包就绪」「状态变化」「销毁」三个时点驱动 [PetVisual]。
///
/// 具体像素由 [PetVisual] 的实现产出，按宠物包类型选择：
/// [SpritePetPack] → [SpritePetVisual]，[Live2DPetPack] → [Live2DPetVisual]。
/// 这里不认识精灵图、也不认识原生纹理。
///
/// Windows 单引擎下同一个引擎里会同时存在多只桌宠的实例，因此必须由 [petId]
/// 指明状态来源（不再有“每个引擎一只”的隐含前提）。
class PetWidget extends ConsumerStatefulWidget {
  const PetWidget({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends ConsumerState<PetWidget>
    with TickerProviderStateMixin {
  PetNotifier get _notifier =>
      ref.read(petStateProvider(widget.petId).notifier);

  /// 渲染器。宠物包就绪后按类型创建（[PetNotifier.pack] 是 late final）。
  PetVisual? _visual;

  /// 上一次下发的播放速度，用于只在变化时通知渲染器。
  double? _lastSpeed;

  @override
  void initState() {
    super.initState();
    // 如果宠物包已就绪（非首次创建，例如快捷启动层切换后重建），在下一帧初始化
    // 渲染器，避免 ref.listen 因状态未变化而无法触发。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(petStateProvider(widget.petId));
      if (state.packError == '') {
        _prepareVisual();
      }
    });
  }

  @override
  void dispose() {
    // 必须在 super.dispose() 前释放 AnimationController（依赖 TickerProvider）。
    _visual?.dispose();
    _visual = null;
    super.dispose();
  }

  /// 宠物包就绪后创建渲染器并让它准备资源。
  void _prepareVisual() {
    var visual = _visual;
    if (visual == null) {
      final pack = _notifier.pack;
      if (pack is SpritePetPack) {
        visual = SpritePetVisual(
          pack: pack,
          vsync: this,
          onAnimChanged: _notifier.setCurrentAnim,
          onAnimationComplete: () => _notifier.onEvent(Trigger.complete),
        );
      } else if (pack is Live2DPetPack) {
        visual = Live2DPetVisual(petId: widget.petId, pack: pack);
      } else {
        return;
      }
      _visual = visual;
      _lastSpeed = null; // 新渲染器要补发一次当前速度
      // 包级快捷键 → 渲染器瞬时动作（渲染器销毁后 _visual 为 null，自动丢弃）。
      _notifier.onHotkeyAction = (action) => _visual?.playAction(action);
      // "打字反应" + 鼠标反馈 → 模型参数。
      _notifier.onParameter = (id, value) => _visual?.setParameter(id, value);
    }
    unawaited(visual.prepare(_notifier.currentState));
  }

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petStateProvider(widget.petId));

    // ── 状态变化 → 驱动渲染器 ──────────────────────────────────────────
    ref.listen(petStateProvider(widget.petId), (prev, next) {
      if (next.packError != '') return;

      // 宠物包首次就绪 → 创建渲染器。
      if (prev?.packError != '' && next.packError == '') {
        _prepareVisual();
        return;
      }

      // 状态变化 → 切换动作。
      if (prev?.currentState != next.currentState) {
        _visual?.playState(
          next.currentState,
          _notifier.pack.states[next.currentState],
        );
      }
    });

    // ── 宠物包加载失败 ────────────────────────────────────────────────
    if (petState.packError?.isNotEmpty ?? false) {
      return ColoredBox(
        color: Colors.red,
        child: Center(
          child: Text(
            AppLocalizations.of(context).petPackError(petState.packError ?? ''),
          ),
        ),
      );
    }

    // ── 尚未就绪 ──────────────────────────────────────────────────────
    final visual = _visual;
    if (petState.packError == null || visual == null) {
      return const SizedBox.shrink();
    }

    // ── 播放速度（全局 × 本宠）→ 渲染器 ───────────────────────────────
    if (_lastSpeed != petState.finalSpeed) {
      _lastSpeed = petState.finalSpeed;
      visual.setSpeed(petState.finalSpeed);
    }

    // ── 渲染 ──────────────────────────────────────────────────────────
    return RepaintBoundary(
      child: Opacity(
        opacity: petState.finalOpacity,
        child: visual.build(
          context,
          petState.finalPetSize,
          _notifier.pack.states[petState.currentState],
        ),
      ),
    );
  }
}
