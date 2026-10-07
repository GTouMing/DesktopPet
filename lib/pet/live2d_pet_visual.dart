import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../petpack/hotkey_action.dart';
import '../petpack/live2d/l2d_param_group.dart';
import '../petpack/live2d_pet_pack.dart';
import '../petpack/state/state_define.dart';
import 'live2d/live2d_channel.dart';
import 'live2d/model_parameter.dart';
import 'pet_visual.dart';

/// Live2D 渲染实现（自研渲染器，见 `plugins/pet_live2d`）。
///
/// 与旧 `live2d_flutter` 路径的关键差别（都是踩过的坑换来的）：
///
///  * **身份是 `petId`**：模型归原生运行时所有，widget 重建/显隐/缩放都不重载；
///  * **渲染目标跟随盒子尺寸**：只在盒子尺寸变化超过余量时才重建纹理，并由引擎
///    "新注册的纹理才认"这一行为（`textureChanged`）把新 `textureId` 推回来——
///    这样模型分辨率≈显示分辨率，不会因大比例下采样把细节糊掉；
///  * **命令按入队顺序执行**：`create` 之后立刻下发初始动作是安全的，不需要
///    "等模型加载完成"的往返；
///  * 因此宿主不需要 `recreateOnSizeChange` 那套重建机制。
///
/// 会话在**首次 `build`** 时创建：那里才知道宠物盒子的真实尺寸，渲染目标可以
/// 一次就按正确尺寸分配（避免启动时多一次重注册）。
///
/// 渲染目标带**对称外扩余量**：原生按 `盒子 × (1 + 2×kLive2dOverscan)` 分配，
/// 再把模型缩放到**中间的盒子**（宠物像素尺寸不变），余量用来容纳露到盒外的
/// 道具/动作姿势，于是它们**被渲染而不是被裁**（见 `live2d_instance.cpp` 的
/// `kOverscan`）。这边把含余量的整张纹理按同一比例、居中**溢出**盒子显示
/// （[OverflowBox]，不缩放映射），而不是压进盒子——两者必须一致。
const double kLive2dOverscan = 0.25;

class Live2DPetVisual implements PetVisual {
  Live2DPetVisual({
    required this.petId,
    required this._pack,
    this.motionPriority = 3,
  });

  /// 该桌宠的持久 id（对应 `PetConfig.id`）：原生用它标识模型实例。
  final String petId;

  final Live2DPetPack _pack;

  /// 动作优先级：`0` none / `1` idle / `2` normal / `3` force。
  final int motionPriority;

  /// 当前要显示的纹理。原生重建渲染目标（盒子尺寸变化）后会推到新 id。
  final ValueNotifier<int?> _textureId = ValueNotifier<int?>(null);

  Live2DSession? _session;
  bool _creating = false;
  bool _disposed = false;

  /// 最近一次请求的动作组名（写回 `PetState.currentAnim`）。
  String? _current;

  /// 最近一次请求的状态名。会话就绪前到达的状态不能丢，就绪后补播。
  String? _pendingState;

  /// 上一次报给原生的盒子尺寸（物理像素），避免每帧重复下发。
  int? _boxWidthPx;
  int? _boxHeightPx;

  /// 清单 `translate` 换算成原生适配单位的偏移（见 [build]）：`1` = 盒子短边的一半。
  /// 每次 build 刷新，供建会话与预热下发。
  double _fitOffsetX = 0;
  double _fitOffsetY = 0;

  /// 用户在编辑页选的槽位（组 id → 选项下标）；来自 `PetConfig.paramChoices`。
  Map<String, int> _baseChoices = const {};

  /// 当前状态携带的参数集（组 id → 选项 label，见 `StateDef.params`）：一层
  /// **运行时覆盖**，压在 [_baseChoices] 之上；进入新状态即替换，离开即恢复。
  Map<String, String> _stateParams = const {};

  /// 动作 `sets` 改动了参数时回调宿主，把新的选择写回 `PetConfig`。
  void Function(Map<String, int> choices)? onChoicesChanged;

  /// 模型参数元数据就绪时回调宿主（构建光标跟随映射，见 `mouse_follow.dart`）。
  void Function(List<ModelParameter> parameters)? onModelParameters;

  /// Generation counter: each instance gets its own native key so a warm-up does
  /// not disturb the instance still on screen.
  int _generation = 0;

  /// Instance being warmed up at a new size; swapped in when it reports ready.
  Live2DSession? _warming;
  Timer? _resizeDebounce;
  /// Polls the platform side for model readiness + parameter metadata (see
  /// [_pollReady]); the native `modelReady` push does not reach child engines.
  Timer? _readyTimer;
  int? _pendingBoxWidthPx;
  int? _pendingBoxHeightPx;


  /// 动作串行化：上一个动作还在播（[HotkeyAction.durationMs] 未到）时，后续动作排队
  /// （后来的覆盖先前的），到点才播下一个——Bongo 就是"当前动作播完才允许下一个"。
  Timer? _actionTimer;
  HotkeyAction? _pendingAction;

  @override
  String? get animationName => _current;

  @override
  Future<void> prepare(String currentState) async {
    if (_disposed) return;
    _pendingState = currentState;
  }

  @override
  void playState(String stateName, StateDef? stateDef) {
    if (_disposed) return;
    _pendingState = stateName;
    if (_session == null) return; // 会话就绪时会补播 _pendingState。
    _setStateParams(stateDef);
    _play(stateDef, stateName);
    _applyParams();
  }

  /// 包级快捷键 → 瞬时动作：直接播动作（可选先设表情），**不改变状态机**。
  ///
  /// 见 [HotkeyAction]：`requires` 是门禁（当前参数不满足就忽略），`sets` 会改动
  /// 参数，`durationMs` 用于**互斥**——一个动作播完才轮得到下一个（后来的覆盖先前的）。
  @override
  void playAction(HotkeyAction action) {
    if (_disposed || _session == null) return;
    if (!_meetsRequires(action)) {
      _report('skip "${action.animation}": precondition not met');
      return;
    }
    if (_actionTimer != null) {
      _pendingAction = action; // 上一个还没播完：排队，后来的覆盖先前的。
      return;
    }
    _beginAction(action);
  }

  /// 真正开始一次动作：先落参数改动，再播动作，并按 [HotkeyAction.durationMs] 排它。
  void _beginAction(HotkeyAction action) {
    _applySets(action);
    _startAction(action);
    if (action.durationMs > 0) {
      _actionTimer = Timer(
          Duration(milliseconds: action.durationMs), _onActionFinished);
    }
  }

  L2dParamGroup? _groupById(String id) {
    for (final g in _pack.paramGroups) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// 某组当前选项的 label；bool 组用 `on` / `off`。
  String _currentLabel(L2dParamGroup group) {
    final idx = group.effectiveIndex(_baseChoices, _stateParams);
    return group.isBool ? (idx == 1 ? 'on' : 'off') : group.options[idx].label;
  }

  /// 参数前提是否成立（[HotkeyAction.requires]，空 = 无前提）。
  bool _meetsRequires(HotkeyAction action) {
    for (final entry in action.requires.entries) {
      final group = _groupById(entry.key);
      if (group == null) return false;
      if (!entry.value.contains(_currentLabel(group))) return false;
    }
    return true;
  }

  /// 动作改动的参数（[HotkeyAction.sets]）：更新用户选择、下发生效、并回调持久化。
  void _applySets(HotkeyAction action) {
    if (action.sets.isEmpty) return;
    final next = Map<String, int>.of(_baseChoices);
    var changed = false;
    for (final entry in action.sets.entries) {
      final group = _groupById(entry.key);
      if (group == null) continue;
      final idx = group.indexOfLabel(entry.value);
      if (idx < 0 || next[group.id] == idx) continue;
      next[group.id] = idx;
      changed = true;
    }
    if (!changed) return;
    _baseChoices = next;
    _applyParams();
    onChoicesChanged?.call(next);
  }

  /// "打字反应"：直接改模型参数（按住 1 / 松开 0）。
  @override
  void setParameter(String parameterId, double value) {
    if (_disposed) return;
    _session?.setParameter(parameterId, value);
  }

  /// 应用用户在该桌宠设置里的槽位选择（组 id → 选项下标）。
  @override
  void applyParams(Map<String, int> choices) {
    _baseChoices = choices;
    _applyParams();
  }

  /// 记下当前状态携带的参数集（运行时覆盖层），下一次 [_applyParams] 生效。
  void _setStateParams(StateDef? stateDef) {
    _stateParams = stateDef?.params ?? const {};
  }

  void _applyParams() {
    final session = _session;
    if (session == null || _pack.paramGroups.isEmpty) return;
    for (final group in _pack.paramGroups) {
      final idx = group.effectiveIndex(_baseChoices, _stateParams);
      final chosen = group.options[idx].params;
      // Un-chosen options are undone by restoring the MODEL's default, not by
      // writing 0: 0 is not the neutral value in general. This pack's base hands
      // live at `ParamCheek5x = 1`, so writing 0 hid the hands whenever the slot
      // was left at its "none" default.
      for (final id in group.allParamIds) {
        if (!chosen.containsKey(id)) session.resetParameter(id);
      }
      chosen.forEach(session.setParameter);
    }
  }

  @override
  Widget build(BuildContext context, Size size, StateDef? stateDef) {
    // 渲染目标**超采样**：至少 2×、至多 3× 设备像素比。参考实现
    // （dsh-pet-live2d）就是这么定的（`resolution = clamp(DPR, 2, 3)`）：1× 屏也按
    // 2× 渲染，再由 Flutter 缩进盒子，宠物缩小时线条才不会糊；极高 DPI 屏封顶 3×，
    // 免得白白多画。引擎对同一尺寸的纹理不重读描述符，所以这里只影响目标像素数。
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final renderScale = devicePixelRatio.clamp(2.0, 3.0);
    final boxWidthPx = math.max(1, (size.width * renderScale).round());
    final boxHeightPx = math.max(1, (size.height * renderScale).round());

    // 清单的 translate 是**逻辑像素**且 +y 向下；原生适配矩阵的单位是"盒子短边的一半"，
    // 所以在这里换算（换算结果与 DPR 无关，用物理像素算同一比值）。符号的翻转在原生做。
    final halfShortSide = math.max(1.0, math.min(boxWidthPx, boxHeightPx) / 2);
    _fitOffsetX = _pack.translateX * renderScale / halfShortSide;
    _fitOffsetY = _pack.translateY * renderScale / halfShortSide;

    _ensureSession(boxWidthPx, boxHeightPx);

    return ValueListenableBuilder<int?>(
      valueListenable: _textureId,
      builder: (context, textureId, _) {
        if (textureId == null) return const SizedBox.shrink();
        // 纹理带外扩余量，按同一比例居中铺开、溢出盒子（不缩放映射）：这样
        // 宠物的像素尺寸不变，露到盒外的道具也画得出来（由 OverflowBox 的
        // Clip.none 保证不被裁）。
        return SizedBox(
          width: size.width,
          height: size.height,
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: 0,
            maxHeight: double.infinity,
            child: SizedBox(
              width: size.width * (1 + 2 * kLive2dOverscan),
              height: size.height * (1 + 2 * kLive2dOverscan),
              child: Texture(textureId: textureId),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _resizeDebounce?.cancel();
    _resizeDebounce = null;
    _readyTimer?.cancel();
    _readyTimer = null;
    _warming?.dispose();
    _warming = null;
    _actionTimer?.cancel();
    _actionTimer = null;
    _pendingAction = null;
    final session = _session;
    _session = null;
    session?.dispose();
    _textureId.dispose();
  }

  // ── 内部 ─────────────────────────────────────────────────────────────

  void _ensureSession(int widthPx, int heightPx) {
    if (_creating || _disposed) return;
    if (_session == null) {
      _creating = true;
      unawaited(_createSession('$petId#${_generation++}', widthPx, heightPx,
          warmUp: false));
      return;
    }
    // A native renderer bakes its render-target size in when it is CREATED
    // (CubismRenderer_D3D11 keeps _modelRenderTargetWidth/Height for its
    // offscreen/mask passes, and there is no setter), so a resize means a new
    // instance - there is no way around the model load. What we CAN avoid is the
    // blank: warm the new instance up while the current one keeps drawing, and
    // swap when it reports ready. Debounced, so dragging the scale slider warms
    // up once it settles.
    if ((_boxWidthPx != widthPx || _boxHeightPx != heightPx) &&
        _warming == null) {
      _pendingBoxWidthPx = widthPx;
      _pendingBoxHeightPx = heightPx;
      _resizeDebounce?.cancel();
      _resizeDebounce = Timer(const Duration(milliseconds: 250), _startWarmUp);
    }
  }

  void _startWarmUp() {
    final widthPx = _pendingBoxWidthPx;
    final heightPx = _pendingBoxHeightPx;
    if (_disposed || _warming != null || widthPx == null || heightPx == null) {
      return;
    }
    // A distinct key so the native side does NOT tear the displayed one down.
    unawaited(_createSession('$petId#${_generation++}', widthPx, heightPx,
        warmUp: true));
  }

  Future<void> _createSession(String key, int widthPx, int heightPx,
      {required bool warmUp}) async {
    final session = await Live2DChannel.create(
      petId: key,
      modelDir: _pack.modelDir,
      modelFileName: _pack.modelFileName,
      widthPx: widthPx,
      heightPx: heightPx,
      fitScale: _pack.scale,
      fitOffsetX: _fitOffsetX,
      fitOffsetY: _fitOffsetY,
      breathScale: _pack.breathScale,
    );
    if (!warmUp) _creating = false;
    if (_disposed) {
      session?.dispose();
      return;
    }
    if (session == null) {
      _report('native renderer unavailable for ${_pack.modelFileName}');
      return;
    }
    _boxWidthPx = widthPx;
    _boxHeightPx = heightPx;

    if (warmUp) {
      _warming = session;
      _pollReady(session, warmUp: true);
      return;
    }

    _session = session;
    _textureId.value = session.textureId;
    _emitModelParameters(session);
    _pollReady(session, warmUp: false);
    final state = _pendingState ?? _pack.initialState;
    final def = _pack.states[state];
    _setStateParams(def);
    _play(def, state);
    _applyParams();
  }

  /// The warmed instance finished loading: show it and drop the old one. Until
  /// this moment the previous instance kept rendering, so nothing ever blanks.
  void _swapToWarm() {
    final warm = _warming;
    if (_disposed || warm == null) return;
    _warming = null;
    final old = _session;
    _session = warm;
    _textureId.value = warm.textureId;
    // 新实例是一份新模型：参数元数据与状态都要重发。
    _emitModelParameters(warm);
    // The new instance is a fresh model: re-apply the current state.
    final state = _pendingState ?? _pack.initialState;
    final def = _pack.states[state];
    _setStateParams(def);
    _play(def, state);
    _applyParams();
    old?.dispose();
  }

  /// 会话就绪后把模型参数元数据交给宿主（构建光标跟随映射）。
  void _emitModelParameters(Live2DSession session) {
    if (_disposed) return;
    final parameters = session.parameters;
    if (parameters.isEmpty) return;
    onModelParameters?.call(parameters);
  }

  /// 轮询平台侧直到模型就绪，然后取参数元数据并触发就绪动作。
  ///
  /// 原生 `modelReady` 推送到不了子窗口引擎（其窗口过程不转发给引擎的 proc 委托），
  /// 所以改成拉取：平台侧返回渲染线程存下的参数快照。见 `pet_live2d_plugin.cpp`。
  /// **不设短上限**：模型加载可能很慢（首次 D3D/着色器初始化），轮询到就绪或销毁为止。
  void _pollReady(Live2DSession session, {required bool warmUp}) {
    _readyTimer?.cancel();
    _readyTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }
      final info = await Live2DChannel.getModelInfo(session.petId);
      if (info == null || !info.ready) return; // 还没好：等下一拍
      timer.cancel();
      _readyTimer = null;
      session.parameters = info.parameters;
      if (warmUp) {
        _swapToWarm();
      } else {
        _emitModelParameters(session);
      }
    });
  }

  void _onActionFinished() {
    _actionTimer = null;
    final next = _pendingAction;
    if (next == null) return;
    _pendingAction = null;
    playAction(next);
  }

  /// 真正下发一次动作（表情 + 动作组），不做串行化。
  void _startAction(HotkeyAction action) {
    final session = _session;
    if (session == null) return;

    final expression = action.expression;
    if (expression != null) session.setExpression(expression);
    if (!action.hasMotion) return;

    _current = action.animation;
    session.setMotion(
      group: action.animation,
      index: action.motionIndex,
      priority: action.motionPriority,
    );
  }

  void _play(StateDef? stateDef, String stateName) {
    final group = stateDef?.animation ?? stateName;
    if (group.isEmpty) return;

    _current = group;
    final session = _session;
    if (session == null) return;

    // 组内索引：一只"跟着按键做动作"的模型会把各键的按下/松开都放在同一组里，
    // 没有 idx 就只能播到第 0 个动作（见 StateDef.motionIndex）。
    session.setMotion(
      group: group,
      index: stateDef?.motionIndex ?? 0,
      priority: stateDef?.motionPriority ?? motionPriority,
      // playCount 0 = 循环；由原生显式控制，不靠插件硬编码重播。
      loop: (stateDef?.playCount ?? 0) == 0,
    );
  }

  void _report(String message) {
    if (kDebugMode) debugPrint('[live2d] ${_pack.name}: $message');
  }
}
