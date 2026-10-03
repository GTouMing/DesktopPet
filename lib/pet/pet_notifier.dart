import 'dart:async';
import 'dart:math';

import 'package:desktop_pet/pet/hotkey_engine.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/constants.dart';
import '../core/overlay_controller.dart';
import '../input/key_input.dart';
import '../skin/audio/audio_service.dart';
import '../skin/skin_package.dart';
import '../storage/models/pet_config.dart';
import '../storage/storage_service.dart';
import 'behavior_engine.dart';
import 'pet_context.dart';
import 'pet_metrics.dart';
import 'pet_state.dart';
import 'pet_window_binding.dart';

/// 桌宠状态管理器。
///
/// ## 职责
/// 1. 持有 [PetState]（桌宠的逻辑状态：位置、方向、可见性等）
/// 2. 驱动行为循环，把位置变化写回 [PetState]
/// 3. 状态跳转的副作用：定时器、音效、快捷键（音效见 [AudioService]，快捷键见
///    [HotkeyEngine]）
///
/// 拆出去的两块：[PetWindowBinding]（仅 Android 的悬浮窗同步，Windows 退化为
/// 空操作）、[pet_metrics]（渲染值的纯计算）。
///
/// ## 位置的语义
/// [PetState.position] 是桌宠在**悬浮窗场景坐标**里的落点。单引擎改造前它同时兼任
/// "OS 窗口矩形"，于是走路要 `SetWindowPos`、拖拽要走系统模态移动循环、显隐要
/// `ShowWindow`。现在它只是一个几何量：渲染由 `PetView` 用 `Positioned` 完成，
/// 走路/拖拽就是改动这个值本身。
class PetNotifier extends StateNotifier<PetState> implements PetContext {
  final String petId;

  /// 输入层（进程级服务；由 `keyInputProvider` 注入，见"状态归属"第 3 条）。
  /// 只用于构造 [hotkey]——快捷键要注册到全局输入层。
  final KeyInput keyInput;

  /// 平台窗口同步。仅 Android 有真实窗口；Windows 下所有方法都是空操作。
  late final PetWindowBinding _window = PetWindowBinding(petId);

  late final SkinPackage skin;

  /// 皮肤是否已就绪（[skin] 是 late final，未就绪前不可读）。
  bool _skinReady = false;

  /// 音效（每只桌宠一个播放器，见 [AudioService]）。
  final AudioService _audio = AudioService();

  late final BehaviorEngine engine = BehaviorEngine(context: this);
  late final HotkeyEngine hotkey = HotkeyEngine(keyInput);

  bool _tickBusy = false;

  /// 状态定时器的最小间隔(自定义皮肤可能给出 0ms,直接使用会自激忙循环)。
  static const Duration _minStateTimerDelay = Duration(milliseconds: 16);

  /// 当前状态最短 delay 的 timer。
  Timer? _stateTimer;

  /// 行为循环定时器（moveToTarget/moveAroundEdge 状态下每 behaviorTickMs 触发一次移动刻）。
  Timer? _behaviorTimer;

  PetNotifier(this.petId, {required this.keyInput})
      : super(PetState(lastInteractionTime: DateTime.now())) {
    _init();
  }

  // ── 状态变化监听 ───────────────────────────────────────────────────────

  @override
  set state(PetState value) {
    final oldValue = state;
    super.state = value;
    if (oldValue.currentState != value.currentState) {
      _cancelStateTimer();
      _checkStateTimer();
      _checkBehaviorTimer();
      _playStateAudio(value.currentState);
    }
  }

  // ── 初始化 ────────────────────────────────────────────────────────────

  Future<void> _init() async {
    if (kDebugMode) debugPrint('[pet] init $petId start');
    try {
      final pet = StorageService.readPet(petId);
      if (pet == null) throw Exception('pet config not found: $petId');

      final skin = await SkinPackage.load(pet.skinPath);
      if (!mounted) return;
      if (skin == null) throw Exception();

      this.skin = skin;
      _skinReady = true;
      state = state.copyWith(
          basePetSize: skin.frameSize, currentState: skin.initialState);

      // 注册快捷键(皮肤里声明的 hotkey 规则 → 全局输入层)。
      await hotkey.bind(
        skin: skin,
        currentState: () => state.currentState,
        onStateChange: (next) {
          state = state.copyWith(
              currentState: next, lastInteractionTime: DateTime.now());
        },
      );
      if (!mounted) return;

      await _window.init();
      if (!mounted) return;

      await refreshScreenSize();
      if (!mounted) return;

      await _applyScale();
      if (!mounted) return;
      _applyOpacity();
      _applySpeed();

      // 尺寸就绪后才能把落点收敛进场景(换屏/改缩放后旧坐标可能落在屏幕外)。
      state = state.copyWith(position: _clampToScene(pet.position));
      await _window.setPosition(state.position);
      if (!mounted) return;

      await _window.applyLocked(_petConfig);
      await _window.applyVisible(_petConfig);
      if (!mounted) return;

      // 动画由 PetWidget 管理生命周期
      state = state.copyWith(skinError: '');
    } catch (e) {
      if (kDebugMode) debugPrint('[pet] init $petId ERROR: $e');
      // 若初始化期间已被 dispose,写 state 会抛未捕获异常,需守卫。
      if (mounted) {
        state = state.copyWith(skinError: 'init_error: $e');
      }
    }
  }

  /// 当前桌宠的配置（尚未落库 / 已被删除时为 null）。
  ///
  /// 直接按 id 读单键，不再把全部桌宠读出来再筛。
  PetConfig? get _petConfig => StorageService.readPet(petId);

  /// 由皮肤帧尺寸 × 全局缩放 × 该宠缩放得出最终渲染尺寸，并收敛到场景内。
  ///
  /// 这就是全部：不再需要把它写进任何窗口。
  Future<void> _applyScale() async {
    final baseFrameSize = state.basePetSize;
    if (baseFrameSize == null) return;
    final size = petRenderSize(
      baseFrame: baseFrameSize,
      global: StorageService.readSettings(),
      pet: _petConfig,
      screen: screenSize,
    );
    state = state.copyWith(finalPetSize: size);
    await _window.setSize(size);
  }

  void _applyOpacity() {
    state = state.copyWith(
        finalOpacity: petOpacity(StorageService.readSettings(), _petConfig));
  }

  void _applySpeed() {
    state = state.copyWith(
        finalSpeed: petSpeed(StorageService.readSettings(), _petConfig));
  }

  /// 进入新状态时播放该状态声明的音效（见 [AudioService]）。
  ///
  /// 状态机的每一处跳转（点击 / 定时 / 热键 / 到达…）都经过 [state] setter，
  /// 所以这就是唯一的发声点。
  void _playStateAudio(String stateName) {
    if (!_skinReady) return;
    _audio.playForState(skin.states[stateName], cue: stateName);
  }

  /// 应用设置（本引擎内）：缩放 / 透明度 / 速度 + 窗口侧的显隐与穿透。
  Future<void> refreshSettings() async {
    await _applyScale();
    _applyOpacity();
    _applySpeed();
    await _window.applyLocked(_petConfig);
    await _window.applyVisible(_petConfig);
  }

  // ── 接口 ──────────────────────────────────────────────────────────

  @override
  Size get screenSize {
    if (_window.isAttached) return _window.screenSize ?? Size.zero;
    return OverlayController.sceneBounds.value.size;
  }

  @override
  Size get finalPetSize => state.finalPetSize;

  /// 当前动画名（透传 state，供 PetWidget 在动画管理中读取）。
  String get currentAnim => state.currentAnim;

  /// 当前状态名（透传 state，供 PetWidget 在动画管理中读取）。
  String get currentState => state.currentState;

  /// 设置当前动画名（透传 state.copyWith，供 PetWidget 在动画管理中使用）。
  void setCurrentAnim(String animName) {
    state = state.copyWith(currentAnim: animName);
  }

  // ── 状态驱动定时器 ───────────────────────────────────────────────────────

  /// 扫描当前状态所有目标，找出最短 delay 的 timer 规则，启动单一定时器。
  void _checkStateTimer() {
    final (Duration? bestDelay, String? bestTarget) =
        skin.findBestTimer(state.currentState);

    if (bestTarget == null || bestDelay == null) return;
    final delay =
        bestDelay < _minStateTimerDelay ? _minStateTimerDelay : bestDelay;
    _stateTimer = Timer(delay, () {
      state = state.copyWith(currentState: bestTarget);
    });
  }

  void _cancelStateTimer() {
    _stateTimer?.cancel();
    _stateTimer = null;
  }

  void _cancelBehaviorTimer() {
    _behaviorTimer?.cancel();
    _behaviorTimer = null;
    state = state.copyWith(cleanTarget: true);
  }

  void _checkBehaviorTimer() {
    // 行为定时器
    final needsBehavior = skin.hasBehavior(state.currentState);
    if (!needsBehavior) {
      _cancelBehaviorTimer();
      return;
    }
    // 场景尺寸未就绪时不能生成目标:maxX/maxY 会变成负数,clamp 直接抛错。
    if (screenSize.isEmpty) return;
    if (state.targetPosition == null) {
      final def = skin.states[state.currentState];
      state = state.copyWith(
          targetPosition: engine.randomTarget(def, state.position));
    }
    _behaviorTimer ??= Timer.periodic(
          const Duration(milliseconds: behaviorTickMs), (_) => _onTick());
  }

  Future<void> _onTick() async {
    if (_tickBusy || state.isDragging) return;
    // 环形菜单展开期间冻结目标宠物,避免环与宠物错位。
    if (OverlayController.frozenPet.value == petId) return;
    if (screenSize.isEmpty) return;
    _tickBusy = true;
    try {
      final target = engine.tick(state);

      if (target == null) {
        _cancelBehaviorTimer();
        return;
      }

      state = state.copyWith(position: target);
      _window.setPositionSync(target);
    } finally {
      _tickBusy = false;
    }
  }

  // ── 交互事件 ──────────────────────────────────────────────────────────

  void onDragStart() {
    if (!state.isDragging) {
      onEvent(Trigger.drag);
      state = state.copyWith(isDragging: true);
    }
  }

  /// 拖拽中：把桌宠落点摆到 [position]（场景坐标，已含按下时的抓取偏移）。
  ///
  /// 传绝对落点而不是增量：[_clampToScene] 会丢弃越界的那部分位移，逐帧累加会让
  /// 桌宠与光标永久错开（贴边后光标越界多远就错开多远）。
  ///
  /// 仅 Windows 需要——那里桌宠是场景内的一个条目，拖拽就是改 [PetState.position]。
  /// Android 的拖拽由原生悬浮窗完成，见 [startWindowDrag]。
  void onDragTo(Offset position) {
    if (!state.isDragging) return;
    state = state.copyWith(position: _clampToScene(position));
  }

  /// 仅 Android：把整只宠物交给原生拖拽（系统移动整个悬浮窗），返回后收敛落点。
  Future<void> startWindowDrag() async {
    if (!_window.isAttached) return;
    onDragStart();
    await _window.startDragging();
    await onDragEnd();
  }

  Future<void> onDragEnd() async {
    if (!state.isDragging) return;
    // Android：拖拽由系统完成，窗口位置已由原生更新，回读后收敛到屏幕内；
    // Windows：位置已由 onDragTo 逐帧写入，直接用当前值。
    final raw = _window.isAttached
        ? await _window.readPosition()
        : state.position;
    final clamped = _clampToScene(raw);
    onEvent(Trigger.arrived);
    state = state.copyWith(position: clamped, isDragging: false);
    await _window.setPosition(clamped);
  }

  @override
  void onEvent(String trigger) {
    final next = skin.findTransition(state.currentState, trigger);
    state = state.copyWith(
        currentState: next, lastInteractionTime: DateTime.now());
  }

  /// 把落点收敛到场景内，保证桌宠整体可见（贴边时不越界）。
  Offset _clampToScene(Offset position) {
    final scene = screenSize;
    if (scene.isEmpty) return position;
    final size = state.finalPetSize;
    return Offset(
      position.dx.clamp(0.0, max(0.0, scene.width - size.width)),
      position.dy.clamp(0.0, max(0.0, scene.height - size.height)),
    );
  }

  void _savePosition() {
    StorageService.updatePet(petId, (pet) => pet.copyWith(
      positionX: state.position.dx,
      positionY: state.position.dy,
    ));
  }

  @override
  void dispose() {
    _cancelStateTimer();
    _cancelBehaviorTimer();
    hotkey.dispose();
    _audio.dispose();
    _savePosition();
    super.dispose();
  }

  Future<void> refreshScreenSize() => _window.refreshScreenSize();
}
