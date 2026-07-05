import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../platform/window_interface.dart';
import '../storage/storage_service.dart';
import '../skin/state/state_define.dart';
import 'pet_state.dart';
import 'pet_resources.dart';
import '../skin/skin_package.dart';
import '../skin/sheet/sprite_sheet_generator.dart';

/// 桌宠状态管理器。
///
/// ## 职责
/// 1. 持有 [PetState]（桌宠的逻辑状态：位置、方向、可见性等）。
/// 2. 持有 [PetResources]（运行时资源：皮肤包、行为引擎、快捷键、窗口控制器等）。
/// 3. 负责将逻辑状态同步到物理窗口：
///    - `position` → `controller.setPosition()`
///    - `petSize` → `controller.setSize()`
///    - 拖拽/点击穿透 → `controller.setIgnoreMouseEvents()`
/// 4. 监听 [currentState] 变化，自动调度：
///    - **状态机定时器**：当进入拥有 Timer 触发器的状态时，启动一次性定时器
///    - **行为定时器**：当进入 `moveToTarget` 状态时，启动周期性移动刻
class PetNotifier extends StateNotifier<PetState> {
  final String _petId;
  final PetResources resources;
  bool _tickBusy = false;
  bool _disposed = false;

  /// 一次性状态机定时器（timer 触发器 → 跳转目标状态）。
  Timer? _stateTimer;

  /// 当前状态定时器选中的跳转目标，回调时消费。
  String? _pendingTimerTarget;

  /// 行为循环定时器（moveToTarget 状态下每 behaviorTickMs 触发一次移动刻）。
  Timer? _behaviorTimer;

  /// 窗口标题检测订阅（仅 Windows，通过 WinEvent hook 事件驱动）。
  StreamSubscription<String>? _windowSub;

  String get id => _petId;

  PetNotifier(this._petId, WindowController controller)
      : resources = PetResources(windowController: controller),
        super(PetState(lastInteractionTime: DateTime.now())) {
    _initAsync();
  }

  // ── 状态变化监听 ─────────────────────────────────────────────────────────

  /// 覆写 [StateNotifier.state] setter，拦截 [currentState] 变更。
  ///
  /// 每次 [currentState] 变化时自动调用 [_onCurrentStateChanged]，
  /// 此处驱动状态机定时器与行为定时器的启停。
  @override
  set state(PetState value) {
    final oldState = state.currentState;
    super.state = value;
    if (oldState != value.currentState) {
      _onCurrentStateChanged(value.currentState);
    }
  }

  // ── 异步初始化 ──────────────────────────────────────────────────────

  /// 从预加载数据初始化皮肤包、状态机及初始动画精灵图。
  ///
  /// - 预加载数据可用：初始化皮肤 → 绑定状态机 → 预加载初始精灵图 → 通知就绪
  /// - 预加载数据不可用：设置 [skinError] 描述，由 PetWidget 展示错误
  Future<void> _initAsync() async {
    try {
      final pet = StorageService.readPet(id);
      if (pet == null) {
        state = state.copyWith(skinError: 'pet_not_found');
        return;
      }

      final skin = await SkinPackage.load(pet.skinPath);
      if (skin == null) {
        state = state.copyWith(skinError: 'skin_not_found',);
        return;
      }
      resources.skin = skin;
      state = state.copyWith(basePetSize: skin.frameSize);

      // 绑定状态机到行为引擎
      final initialStateDef = skin.states[skin.initialState];
      if (initialStateDef != null) {
        final machine = StateMachine(def: initialStateDef, allDefs: skin.states);
        resources.engine.bind(machine);
      }

      // 将窗口尺寸与 petSize 同步（窗口在 init() 中已按 scale 创建）
      _applyWindowScale();

      _applyOpacity();

      _applySpeed();

      // 同步 MMKV 中的锁定状态到窗口
      _applyLockStatus();

      // 后台预加载所有动画精灵图
      _preloadAllSheets(skin);
    } catch (e) {
      state = state.copyWith(skinError: 'init_error: $e');
    }
  }

  /// 后台加载剩余所有动画的精灵图。
  Future<void> _preloadAllSheets(SkinPackage skin) async {
    final initialState = skin.initialState;
    if (!resources.sheets.containsKey(initialState)) {
      resources.sheets[initialState] = await SpriteSheetGenerator.generateFromSkin(skin, initialState);
    }
    // 初始精灵图已就绪，通知 PetWidget 渲染并启动状态机定时器
    state = state.copyWith(currentState: skin.initialState, skinError: '');

    try {
      final tasks = <Future<void>>[];
      for (final animName in skin.anims.keys) {
        if (resources.sheets.containsKey(animName)) continue;
        tasks.add(
          SpriteSheetGenerator.generateFromSkin(skin, animName)
              .then((sheet) => resources.sheets[animName] = sheet),
        );
      }
      await Future.wait(tasks);
    } catch (_) {
      // 后台预加载失败不影响已就绪的初始渲染
    }
  }

  // ── 窗口同步 ──────────────────────────────────────────────────────────

  /// 将缩放应用到窗口尺寸（缩放由窗口负责）。
  void _applyWindowScale() {
    final baseFrameSize = state.basePetSize;
    if (baseFrameSize == null) return;
    final dpr = resources.windowController.devicePixelRatio;
    final appData = StorageService.appData;
    final petConfig = appData.pets.where((p) => p.id == _petId).firstOrNull;
    final scale = min(
        appData.global.baseScale * (petConfig?.scaleMultiplier ?? 1.0),
        maxFinalScale);
    final scaledSize = Size((baseFrameSize.width * scale), (baseFrameSize.height * scale),);
    // 以逻辑像素为基准的视口尺寸。Android 上 setSize 会乘以 DPR 转为物理像素，
    // 因此这里需要先除 DPR 使物理窗口 ≈ scaledSize 像素。
    final viewportSize = Size((scaledSize.width / dpr), (scaledSize.height / dpr),);
    resources.windowController.setSize(viewportSize);
    state = state.copyWith(finalPetSize: viewportSize);
  }

  /// 应用不透明度（从 MMKV 读取最新值，写入 PetState 供 PetWidget 使用）。
  void _applyOpacity() {
    final appData = StorageService.appData;
    final petConfig = appData.pets.where((p) => p.id == _petId).firstOrNull;
    final opacity = appData.global.baseOpacity * (petConfig?.opacityMultiplier ?? 1.0);
    state = state.copyWith(finalOpacity: opacity);
  }

  /// 应用动画速度（baseSpeed × speedMultiplier）。
  void _applySpeed() {
    final appData = StorageService.appData;
    final petConfig = appData.pets.where((p) => p.id == _petId).firstOrNull;
    final speed = appData.global.baseSpeed * (petConfig?.speedMultiplier ?? 1.0);
    state = state.copyWith(finalSpeed: speed);
  }

  /// 从 MMKV 同步锁定状态到窗口控制器。
  ///
  /// 确保窗口启动时与持久化状态一致（如上次退出前锁定）。
  void _applyLockStatus() {
    final pet = StorageService.readPet(_petId);
    if (pet == null) return;
    resources.windowController.setIgnoreMouseEvents(pet.isLocked);
  }

  /// 应用可见性（从 MMKV 读取最新值，写入 PetState 供 PetWidget 使用）。
  void _applyVisibility() {
    final pet = StorageService.readPet(_petId);
    if (pet == null) return;
    state = state.copyWith(isVisible: pet.isVisible);
  }

  /// 刷新设置：从 MMKV 重新读取并应用到窗口。
  void refreshSettings() {
    _applyWindowScale();
    _applyOpacity();
    _applySpeed();
    _applyVisibility();
  }

  // ── 屏幕尺寸 ──────────────────────────────────────────────────────────

  static Size get finalScreenSize {
    return Platform.isAndroid ? const Size(360, 640) : Platform.isWindows ? const Size(1920, 1080) : const Size(1920, 1080);
  }

  Future<Size> get screenSize async {
    final controller = resources.windowController;
    try {
      return await controller.getScreenSize();
    } catch (_) {}
    return finalScreenSize;
  }

  // ── 状态驱动定时器 ───────────────────────────────────────────────────────

  /// 当 [currentState] 变化时自动调用。
  ///
  /// 1. 取消上一状态的定时器
  /// 2. 若新状态拥有 Timer 触发器 → 启动状态机定时器
  /// 3. 若新状态拥有 moveToTarget 行为 → 启动行为定时器
  void _onCurrentStateChanged(String stateName) {
    // 取消旧定时器
    _stateTimer?.cancel();
    _stateTimer = null;
    _pendingTimerTarget = null;

    final skin = resources.skin;
    if (skin == null) return;
    final stateDef = skin.states[stateName];
    if (stateDef == null) return;

    // 状态机定时器：状态定义了 timer 触发器时，选最短延迟启动
    if (stateDef.timers.isNotEmpty) {
      _startStateTimer(stateDef.timers);
    }

    // 行为定时器：moveToTarget 状态启动，非 moveToTarget 状态停止
    final needsBehavior = stateDef.behavior == 'moveToTarget';
    if (needsBehavior && _behaviorTimer == null) {
      _startBehaviorLoop();
    } else if (!needsBehavior && _behaviorTimer != null) {
      _behaviorTimer?.cancel();
      _behaviorTimer = null;
    }

    // 窗口标题触发器：状态定义了 window 触发器时订阅事件流
    final hasWindowTrigger = stateDef.transitions.any((t) => t.trigger == Trigger.window);
    if (hasWindowTrigger && _windowSub == null) {
      _startWindowDetect();
    } else if (!hasWindowTrigger && _windowSub != null) {
      _windowSub?.cancel();
      _windowSub = null;
    }
  }

  /// 从 [timers] 中选取延迟最短的 Timer，启动一次性状态机定时器。
  void _startStateTimer(List<StateTimer> timers) {
    StateTimer? selected;
    Duration? earliestDelay;

    for (final t in timers) {
      final delay = _timerDelay(t);
      if (earliestDelay == null || delay < earliestDelay) {
        earliestDelay = delay;
        selected = t;
      }
    }

    if (selected == null || earliestDelay == null) return;

    _pendingTimerTarget = selected.target;
    _stateTimer = Timer(earliestDelay, _onStateTimerFired);
  }

  /// 将 [StateTimer] 配置转为具体 [Duration]。
  ///
  /// 优先级：afterMs > minMs+maxMs 随机 > minMs > maxMs > 0
  Duration _timerDelay(StateTimer t) {
    if (t.afterMs != null) return Duration(milliseconds: t.afterMs!);
    if (t.minMs != null && t.maxMs != null) {
      final range = t.maxMs! - t.minMs!;
      if (range <= 0) return Duration(milliseconds: t.minMs!);
      return Duration(milliseconds: t.minMs! + Random().nextInt(range));
    }
    if (t.minMs != null) return Duration(milliseconds: t.minMs!);
    return Duration(milliseconds: t.maxMs ?? 0);
  }

  /// 状态机定时器回调：跳转到目标状态。
  Future<void> _onStateTimerFired() async {
    if (_disposed) return;

    final target = _pendingTimerTarget;
    _pendingTimerTarget = null;
    if (target == null) return;

    resources.engine.transitionTo(target);

    // 若目标状态需要移动，先生成随机目标坐标再跳转
    final stateDef = resources.skin?.states[target];
    if (stateDef?.behavior == 'moveToTarget') {
      final ss = await screenSize;
      if (_disposed) return;
      final pos = resources.engine.randomTargetPosition(ss, state.finalPetSize);
      state = state.copyWith(currentState: target, targetPosition: pos);
    } else {
      state = state.copyWith(currentState: target, clearTarget: true);
    }
  }

  // ── 行为循环（moveToTarget） ──────────────────────────────────────────────

  /// 启动周期性移动刻（仅当未运行时）。
  void _startBehaviorLoop() {
    assert(_behaviorTimer == null);
    _behaviorTimer = Timer.periodic(
        const Duration(milliseconds: behaviorTickMs), (_) => _onTick());
  }

  Future<void> _onTick() async {
    if (_tickBusy || state.isDragging) return;
    _tickBusy = true;
    try {
      final ss = await screenSize;
      final newState = resources.engine.tick(state, ss);
      if (newState != state) {
        state = newState;
        resources.windowController.setPositionSync(newState.position);
      }
    } finally {
      _tickBusy = false;
    }
  }

  // ── 窗口标题检测（window 触发器） ─────────────────────────────────────────

  /// 订阅前台窗口标题事件流（仅当未订阅时）。
  ///
  /// Windows 使用 [SetWinEventHook] 事件驱动，无轮询开销；
  /// Android 平台 stream 为 null，静默跳过。
  void _startWindowDetect() {
    assert(_windowSub == null);
    final stream = resources.windowController.onForegroundWindowTitle;
    if (stream == null) return;
    _windowSub = stream.listen(_onWindowTitle);
  }

  /// 前台窗口标题变更回调 → 匹配 stateDef 的 window 触发器。
  void _onWindowTitle(String title) {
    if (_disposed) return;
    final next = resources.engine.matchWindow(title);
    if (next != null) {
      state = state.copyWith(currentState: next);
    }
  }

  // ── 交互事件 ──────────────────────────────────────────────────────────

  void onDragStart() {
    if (!state.isDragging) {
      final next = resources.engine.onEvent(Trigger.drag);
      state = state.copyWith(isDragging: true, currentState: next);
    }
  }

  Future<void> onDragEnd() async {
    if (!state.isDragging) return;
    final controller = resources.windowController;
    var pos = await controller.getPosition();
    final ss = await screenSize;
    final sw = ss.width;
    final sh = ss.height;
    final clamped = Offset(
      pos.dx.clamp(0, sw - state.finalPetSize.width),
      pos.dy.clamp(0, sh - state.finalPetSize.height),
    );
    final next = resources.engine.onEvent(Trigger.arrived);
    state = state.copyWith(
      position: clamped,
      isDragging: false,
      currentState: next,
    );
    _persistPosition(clamped);
  }

  /// 统一事件入口：处理除拖拽、锁定之外的交互事件。
  ///
  /// [trigger] 为 [Trigger] 中的事件名（click / eat / complete 等）。
  void onEvent(String trigger) {
    final next = resources.engine.onEvent(trigger);
    if (next != null) {
      state = state.copyWith(currentState: next, lastInteractionTime: DateTime.now());
    }
  }

  void onLock(bool lock) {
    resources.windowController.setIgnoreMouseEvents(lock);
  }

  /// 由 PetWidget 在切换动画时调用，同步当前动画名到 PetState。
  set currentAnim(String anim) {
    state = state.copyWith(currentAnim: anim);
  }


  /// 由 PetWidget 在激活动画时调用，设置剩余重复次数。
  set remainingRepeats(int count) {
    state = state.copyWith(remainingRepeats: count);
  }

  /// 由 PetWidget 在动画完成时调用，递减剩余重复次数。
  void decrementRepeats() {
    state = state.copyWith(remainingRepeats: state.remainingRepeats - 1);
  }

  // ── 持久化 ────────────────────────────────────────────────────────────

  /// 将拖拽后的位置写回 PetConfig（直接写入 MMKV）。
  void _persistPosition(Offset pos) {
    StorageService.updatePet(_petId, (pet) => pet.copyWith(
      positionX: pos.dx,
      positionY: pos.dy,
    ));
  }

  @override
  void dispose() {
    _disposed = true;
    _stateTimer?.cancel();
    _behaviorTimer?.cancel();
    _windowSub?.cancel();
    resources.engine.dispose();
    resources.hotkey.dispose();
    super.dispose();
  }
}