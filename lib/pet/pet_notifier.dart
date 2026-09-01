import 'dart:async';
import 'dart:math';

import 'package:desktop_pet/pet/hotkey_engine.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../core/constants.dart';
import '../core/providers.dart';
import '../platform/platform_factory.dart';
import '../platform/window_interface.dart';
import '../storage/storage_service.dart';
import 'behavior_engine.dart';
import 'pet_context.dart';
import 'pet_state.dart';
import '../skin/skin_package.dart';

/// 桌宠状态管理器。
///
/// ## 职责
/// 1. 持有 [PetState]（桌宠的逻辑状态：位置、方向、可见性等）
class PetNotifier extends StateNotifier<PetState> implements PetContext {
  final Ref _ref;
  late final String _petId = _ref.watch(petIdProvider);
  late final WindowController windowController = createWindowController(windowId: _petId);

  late final Size _screenSize;

  late final SkinPackage skin;

  late final BehaviorEngine engine = BehaviorEngine(context: this);
  final HotkeyEngine hotkey = HotkeyEngine();

  bool _tickBusy = false;

  /// 当前状态最短 delay 的 timer。
  Timer? _stateTimer;

  /// 行为循环定时器（moveToTarget/moveAroundScreen 状态下每 behaviorTickMs 触发一次移动刻）。
  Timer? _behaviorTimer;

  PetNotifier(this._ref) : super(PetState(lastInteractionTime: DateTime.now())) {
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
    }
  }

  // ── 初始化 ────────────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      final pet = StorageService.readPet(_petId);
      if (pet == null) throw Exception();

      final skin = await SkinPackage.load(pet.skinPath);
      if (skin == null) throw Exception();

      this.skin = skin;
      state = state.copyWith(basePetSize: skin.frameSize, currentState: skin.initialState);

      // 注册快捷键
      hotkey.bind(
        skin: skin,
        currentState: () => state.currentState,
        onStateChange: (next) {
          state = state.copyWith(currentState: next, lastInteractionTime: DateTime.now());
        },
      );

      await windowController.petInit();

      await refreshScreenSize();

      // 加载保存的坐标
      state = state.copyWith(position: pet.position);
      await windowController.setPosition(state.position);

      await _applyWindowScale();
      _applyOpacity();
      _applySpeed();
      await _applyLockStatus();

      // 动画由 PetWidget 管理生命周期
      state = state.copyWith(skinError: '');
    } catch (e) {
      state = state.copyWith(skinError: 'init_error: $e');
    }
  }

  // ── 窗口同步 ──────────────────────────────────────────────────────────

  Future<void> _applyWindowScale() async {
    final baseFrameSize = state.basePetSize;
    if (baseFrameSize == null) return;
    final dpr = windowController.devicePixelRatio;
    final appData = StorageService.appData;
    final petConfig = appData.pets.where((p) => p.id == _petId).firstOrNull;
    final scale = min(
        appData.global.baseScale * (petConfig?.scaleMultiplier ?? 1.0),
        maxFinalScale);
    final scaledSize = Size((baseFrameSize.width * scale), (baseFrameSize.height * scale));
    final viewportSize = Size((scaledSize.width / dpr), (scaledSize.height / dpr));
    await windowController.setSize(viewportSize);
    state = state.copyWith(finalPetSize: viewportSize);
  }

  void _applyOpacity() {
    final appData = StorageService.appData;
    final petConfig = appData.pets.where((p) => p.id == _petId).firstOrNull;
    final opacity = appData.global.baseOpacity * (petConfig?.opacityMultiplier ?? 1.0);
    state = state.copyWith(finalOpacity: opacity);
  }

  void _applySpeed() {
    final appData = StorageService.appData;
    final petConfig = appData.pets.where((p) => p.id == _petId).firstOrNull;
    final speed = appData.global.baseSpeed * (petConfig?.speedMultiplier ?? 1.0);
    state = state.copyWith(finalSpeed: speed);
  }

  Future<void> _applyLockStatus() async {
    final pet = StorageService.readPet(_petId);
    if (pet == null) return;
    await windowController.setIgnoreMouseEvents(pet.isLocked);
  }

  Future<void> refreshSettings() async {
    await _applyWindowScale();
    _applyOpacity();
    _applySpeed();
    await _applyLockStatus();
  }

  // ── 接口 ──────────────────────────────────────────────────────────

  @override
  Size get screenSize => _screenSize;
  @override
  Size get finalPetSize => state.finalPetSize;

  /// 当前动画名（透传 state，供 PetWidget 在动画管理中读取）。
  String get currentAnim => state.currentAnim;

  /// 当前状态名（透传 state，供 PetWidget 在动画管理中读取）。
  String get currentState => state.currentState;

  /// 当前坐标（透传 state，供 QuickLaunchOverlay 等外部组件读取）。
  Offset get position => state.position;

  /// 设置当前动画名（透传 state.copyWith，供 PetWidget 在动画管理中使用）。
  void setCurrentAnim(String animName) {
    state = state.copyWith(currentAnim: animName);
  }

  // ── 状态驱动定时器 ───────────────────────────────────────────────────────

  /// 扫描当前状态所有目标，找出最短 delay 的 timer 规则，启动单一定时器。
  void _checkStateTimer() {
    final (Duration? bestDelay, String? bestTarget) = skin.findBestTimer(state.currentState);

    if (bestTarget == null || bestDelay == null) return;
    _stateTimer = Timer(bestDelay, () {state = state.copyWith(currentState: bestTarget);});
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
    if (state.targetPosition == null) {
      final def = skin.states[state.currentState];
      state = state.copyWith(targetPosition: engine.randomTarget(
          def, state.position));
    }
    _behaviorTimer ??= Timer.periodic(
          const Duration(milliseconds: behaviorTickMs), (_) => _onTick());
  }

  Future<void> _onTick() async {
    if (_tickBusy || state.isDragging) return;
    _tickBusy = true;
    try {
      final target = engine.tick(state);

      if (target == null) {
        _cancelBehaviorTimer();
        return;
      }

      state = state.copyWith(position: target);
      windowController.setPositionSync(target);
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

  Future<void> onDragEnd() async {
    if (!state.isDragging) return;
    final controller = windowController;
    var pos = await controller.getPosition();
    final ss = screenSize;
    final sw = ss.width;
    final sh = ss.height;
    final clamped = Offset(
      pos.dx.clamp(0, sw - state.finalPetSize.width),
      pos.dy.clamp(0, sh - state.finalPetSize.height),
    );

    onEvent(Trigger.arrived);
    state = state.copyWith(position: clamped, isDragging: false);

    controller.setPosition(clamped);
  }

  @override
  void onEvent(String trigger) {
    final next = skin.findTransition(state.currentState, trigger);
    state = state.copyWith(currentState: next, lastInteractionTime: DateTime.now());
  }

  void cantMove(bool busy) {
    _tickBusy = busy;
  }

  void _savePosition() {
    StorageService.updatePet(_petId, (pet) => pet.copyWith(
      positionX: state.position.dx,
      positionY: state.position.dy,
    ));
  }

  @override
  void dispose() {
    _cancelStateTimer();
    _cancelBehaviorTimer();
    hotkey.dispose();
    _savePosition();
    super.dispose();
  }

  Future<void> refreshScreenSize() async {
    _screenSize = await windowController.getScreenSize();
  }
}
