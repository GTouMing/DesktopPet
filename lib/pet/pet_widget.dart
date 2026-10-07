import 'dart:async';

import 'package:desktop_pet/l10n/app_localizations.dart';
import 'package:desktop_pet/pet/pet_notifier.dart';
import 'package:flutter/foundation.dart';
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

  /// 渲染器。宠物包就绪后按类型创建；换包（状态里的 `packGeneration` 变化）时重建。
  PetVisual? _visual;

  /// 上一次下发的可调参数选择（null = 还没下发过，首次必须下发一次）。
  Map<String, int>? _lastParams;

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
        final live2d = Live2DPetVisual(petId: widget.petId, pack: pack);
        // 动作 `sets` 改动参数时写回本宠的配置。
        live2d.onChoicesChanged = _notifier.setParamChoices;
        // 模型加载完成后回传参数元数据 → 构建光标跟随映射。
        live2d.onModelParameters = _notifier.setModelParameters;
        visual = live2d;
      } else {
        return;
      }
      _visual = visual;
      _lastParams = null; // 新渲染器要补发一次参数选择
      // 包级快捷键 → 渲染器瞬时动作（渲染器销毁后 _visual 为 null，自动丢弃）。
      _notifier.onHotkeyAction = (action) => _visual?.playAction(action);
      // "打字反应" + 鼠标反馈 → 模型参数。
      _notifier.onParameter = (id, value) => _visual?.setParameter(id, value);
    }
    unawaited(visual.prepare(_notifier.currentState));
  }

  /// 换包后重建渲染器：旧实现只创建一次，所以改宠物包路径（尤其精灵图 ↔ Live2D）
  /// 不会生效。这里丢弃旧渲染器（释放其动画 / 原生 Live2D 会话），再按新包创建。
  void _recreateVisual() {
    _visual?.dispose();
    _visual = null;
    _prepareVisual();
  }

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petStateProvider(widget.petId));

    // ── 状态变化 → 驱动渲染器 ──────────────────────────────────────────
    ref.listen(petStateProvider(widget.petId), (prev, next) {
      // 换了宠物包 → 丢弃旧渲染器并按新包重建（精灵图 ↔ Live2D 也是这条路径）。
      if (prev != null && prev.packGeneration != next.packGeneration) {
        _recreateVisual();
      }
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

    // ── Live2D 可调参数选择 → 渲染器（跨引擎：设置窗口写入后经存储广播到达）──
    final choices = _notifier.paramChoices;
    if (!mapEquals(_lastParams, choices)) {
      _lastParams = choices;
      visual.applyParams(choices);
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
