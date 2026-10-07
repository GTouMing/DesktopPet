import 'dart:async';
import 'dart:math';

import 'package:desktop_pet/pet/hotkey_engine.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/constants.dart';
import '../core/overlay_controller.dart';
import '../input/input.dart';
import '../petpack/audio/audio_service.dart';
import '../petpack/hotkey_action.dart';
import '../petpack/mouse_params.dart';
import '../petpack/pet_pack.dart';
import '../storage/models/pet_config.dart';
import '../storage/storage_service.dart';
import 'behavior_engine.dart';
import 'live2d/mouse_follow.dart';
import 'live2d/model_parameter.dart';
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

  /// 当前宠物包；尚未加载（加载中/失败）时为 null。
  PetPack? _pack;

  /// 当前宠物包（就绪后非 null，内部与 [PetWidget] 都从这里取）。
  PetPack get pack => _pack!;

  /// [pack] 是从哪个路径加载的；换包时据此判定（见 [_reloadPackIfChanged]）。
  String? _loadedPackPath;

  /// 宠物包是否已就绪（[pack] 未就绪前不可读）。
  bool _packReady = false;

  /// 音效（每只桌宠一个播放器，见 [AudioService]）。
  final AudioService _audio = AudioService();

  late final BehaviorEngine engine = BehaviorEngine(context: this);
  late final HotkeyEngine hotkey = HotkeyEngine(keyInput);

  /// 包级快捷键 → 瞬时动作：由 [PetWidget] 在渲染器就绪后挂上。
  ///
  /// 与状态迁移不同，这类动作**不改变状态机**，只让渲染器直接播一次动作；渲染器
  /// 尚未就绪（或已销毁）时为 null，事件被丢弃。
  void Function(HotkeyAction action)? onHotkeyAction;

  /// 模型参数出口（"打字反应" + 鼠标反馈），由 [PetWidget] 挂到渲染器。
  void Function(String parameterId, double value)? onParameter;

  /// 鼠标按键反馈与缓动（见 [MouseParams]）。光标跟随的参数/幅度**读自模型**。
  MouseParams? _mouseParams;
  StreamSubscription<({MouseButton button, bool down})>? _mouseSub;
  bool _mouseTracking = false;

  /// 是否已订阅 [OverlayController.cursorNorm]（模型参数到了、且有跟随映射才订）。
  bool _cursorSubscribed = false;

  /// 由模型标准跟随参数生成的光标跟随映射（见 `buildMouseFollow`）。
  MouseFollow _follow = const MouseFollow();

  /// 模型参数元数据（`setModelParameters` 时缓存）；构建跟随映射用。
  List<ModelParameter> _modelParams = const [];

  /// 光标跟随的缓动状态（[MouseParams.smooth] > 0 时启用）。
  ///
  /// 照搬 Cubism 官方 `CubismTargetPoint`（Bongo 用的同一套）：不是指数缓动，而是
  /// **加速度受限**的伺服——按上限速度朝目标移动、0.15s 加到满速、接近时刹车。
  Timer? _mouseTimer;
  double _faceTargetX = 0, _faceTargetY = 0;
  double _faceX = 0, _faceY = 0;
  double _faceVX = 0, _faceVY = 0;
  double _userTimeSeconds = 0, _lastTimeSeconds = 0;
  bool _mouseInited = false;

  /// 最近一次原始光标值（强度变了要立即重下发时用得到）。
  Offset _mouseRaw = Offset.zero;

  /// 本宠的鼠标跟随强度（乘在模型的跟随映射之上）。
  ///
  /// 缓存自 [PetConfig]——[_applyMouseNorm] 在缓动时以 60Hz 调用，不能每帧读 MMKV。
  double _followX = 1.0;
  double _followY = 1.0;

  // `CubismTargetPoint.cpp` 里的常量。
  static const double _faceFrameRate = 30.0;
  static const double _faceMaxParamV = 4.0; // 归一化 ±1 下的最大速度（/秒）
  static const double _faceTimeToMaxSpeed = 0.15; // 秒
  static const double _faceEpsilon = 0.01;

  bool _tickBusy = false;

  /// 状态定时器的最小间隔(自定义宠物包可能给出 0ms,直接使用会自激忙循环)。
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

      final pack = await PetPack.load(pet.packPath);
      if (!mounted) return;
      if (pack == null) throw Exception();

      _pack = pack;
      _loadedPackPath = pet.packPath;
      _packReady = true;
      _setupMouseParams();
      _syncFollowStrength();
      state = state.copyWith(
          basePetSize: pack.baseSize, currentState: pack.initialState);

      // 注册快捷键(宠物包里声明的 hotkey 规则 → 全局输入层)。
      await hotkey.bind(
        pack: pack,
        currentState: () => state.currentState,
        onStateChange: (next) {
          state = state.copyWith(
              currentState: next, lastInteractionTime: DateTime.now());
        },
        onHotkeyAction: (action) => onHotkeyAction?.call(action),
        onKeyParam: (id, down) => onParameter?.call(id, down ? 1.0 : 0.0),
      );
      if (!mounted) return;

      await _window.init();
      if (!mounted) return;

      await refreshScreenSize();
      if (!mounted) return;

      await _applyScale();
      if (!mounted) return;
      _applyOpacity();

      // 尺寸就绪后才能把落点收敛进场景(换屏/改缩放后旧坐标可能落在屏幕外)。
      state = state.copyWith(position: _clampToScene(pet.position));
      await _window.setPosition(state.position);
      if (!mounted) return;

      await _window.applyLocked(_petConfig);
      await _window.applyVisible(_petConfig);
      if (!mounted) return;

      // 动画由 PetWidget 管理生命周期
      state = state.copyWith(packError: '');
    } catch (e) {
      if (kDebugMode) debugPrint('[pet] init $petId ERROR: $e');
      // 若初始化期间已被 dispose,写 state 会抛未捕获异常,需守卫。
      if (mounted) {
        state = state.copyWith(packError: 'init_error: $e');
      }
    }
  }

  /// 宠物包路径被改（编辑宠物时换了包）→ 重新加载，并让渲染器重建视图。
  ///
  /// 不只是重算尺寸：精灵图 ↔ Live2D 之间换包时渲染器**类型**都变了，所以这里把
  /// `state.packGeneration` +1，[PetWidget] 据此丢弃旧渲染器、按新包重建。
  Future<void> _reloadPackIfChanged() async {
    final pet = StorageService.readPet(petId);
    if (pet == null) return; // 已被删除：交给 provider 释放
    if (pet.packPath == _loadedPackPath) return;

    final pack = await PetPack.load(pet.packPath);
    if (!mounted) return;
    if (pack == null) {
      state = state.copyWith(packError: 'pack_load_failed: ${pet.packPath}');
      return;
    }

    // 旧包的产物先卸掉（鼠标反馈订阅、全局快捷键）。
    _teardownMouseParams();
    hotkey.dispose();

    _pack = pack;
    _loadedPackPath = pet.packPath;
    _packReady = true;
    _setupMouseParams();
    _syncFollowStrength();
    state = state.copyWith(
      basePetSize: pack.baseSize,
      currentState: pack.initialState,
      cleanTarget: true,
      currentAnim: '',
      packError: '',
      packGeneration: state.packGeneration + 1,
    );
    await hotkey.bind(
      pack: pack,
      currentState: () => state.currentState,
      onStateChange: (next) {
        state = state.copyWith(
            currentState: next, lastInteractionTime: DateTime.now());
      },
      onHotkeyAction: (action) => onHotkeyAction?.call(action),
      onKeyParam: (id, down) => onParameter?.call(id, down ? 1.0 : 0.0),
    );
    if (!mounted) return;
    await _applyScale();
    _applyOpacity();
    // 新包尺寸不同，落点重新收敛进场景。
    state = state.copyWith(position: _clampToScene(state.position));
  }

  /// 从本宠配置缓存鼠标跟随强度（见 [PetConfig.mouseFollowX]）。
  ///
  /// 与 `paramChoices` 一样按 id 读单宠配置；缺省 `1.0` = 不改变模型本身的幅度。
  void _syncFollowStrength() {
    final pet = _petConfig;
    _followX = pet?.mouseFollowX ?? 1.0;
    _followY = pet?.mouseFollowY ?? 1.0;
  }

  /// 模型加载完成，原生回传了参数元数据 → 生成跟随映射并接上光标。
  ///
  /// 参数/幅度**读自模型**（标准跟随参数的范围与默认值，见 [buildMouseFollow]），
  /// 与宠物包清单无关；清单只提供鼠标按键（[MouseParams.left]/[MouseParams.right]）与缓动。
  void setModelParameters(List<ModelParameter> parameters) {
    if (!mounted) return;
    _modelParams = parameters;
    _rebuildFollow();
    if (_follow.isNotEmpty && !_cursorSubscribed) {
      OverlayController.cursorNorm.addListener(_onCursorNorm);
      _cursorSubscribed = true;
      if (HotkeyEngine.supported) {
        _mouseTracking = true;
        unawaited(InputService.instance.setMouseTracking(true));
      }
    }
    _refreshMouseFollow();
  }

  /// 按本宠的逐参数绑定重建跟随映射；未配置（空表）时回退到引擎的标准集。
  ///
  /// 设置页改完跟随轴保存后由 [refreshSettings] 调到这里，**无需重载模型**即时生效。
  void _rebuildFollow() {
    final bindings = _petConfig?.mouseBindings ?? const {};
    _follow = bindings.isEmpty
        ? buildMouseFollow(_modelParams)
        : buildMouseFollowFromBindings(bindings, _modelParams);
  }

  /// 用当前强度立即重下发一次跟随值。
  ///
  /// 单独调强度而光标不在动时，缓动到点就停了、不会再走 [_applyMouseNorm]，
  /// 所以设置改动后要主动补这一下。
  void _refreshMouseFollow() {
    if (_follow.isEmpty) return;
    final eased = _mouseInited ? Offset(_faceX, _faceY) : _mouseRaw;
    _applyMouseNorm(eased);
  }

  /// 装配鼠标反馈：鼠标按键订 [InputService.mouseButtons]。
  ///
  /// 光标跟随不在这里订阅——要等模型参数元数据到了（[setModelParameters]）才知道
  /// 该驱动哪些参数、幅度多大。
  void _setupMouseParams() {
    _mouseParams = pack.mouseParams;
    if (_mouseParams?.hasButtons ?? false) {
      _mouseSub = InputService.instance.mouseButtons.listen(_onMouseButton);
    }
  }

  /// 缓动倍率：来自包的 `smooth`，缺省 `1.0`（Bongo 那套）。
  double get _mouseSmooth => _mouseParams?.smooth ?? 1.0;

  void _onCursorNorm() {
    final norm = OverlayController.cursorNorm.value;
    if (norm == null || _follow.isEmpty) return;

    _mouseRaw = norm;
    final smooth = _mouseSmooth;
    if (smooth <= 0) {
      _applyMouseNorm(norm);
      return;
    }
    // 缓动：只记目标，由 60Hz 定时器按 CubismTargetPoint 逐步逼近。
    if (!_mouseInited) {
      _mouseInited = true;
      _faceX = norm.dx;
      _faceY = norm.dy;
      _faceVX = 0;
      _faceVY = 0;
      _userTimeSeconds = 0;
      _lastTimeSeconds = 0;
    }
    _faceTargetX = norm.dx;
    _faceTargetY = norm.dy;
    _applyMouseNorm(Offset(_faceX, _faceY));
    _mouseTimer ??=
        Timer.periodic(const Duration(milliseconds: 16), (_) => _tickMouseEase());
  }

  /// 一帧的缓动积分（`CubismTargetPoint::Update` 的 Dart 版，`dt` 固定 1/60）。
  void _tickMouseEase() {
    const dt = 1 / 60;
    final maxV = _faceMaxParamV * _mouseSmooth / _faceFrameRate; // 每帧最大速度

    _userTimeSeconds += dt;
    if (_lastTimeSeconds == 0) {
      _lastTimeSeconds = _userTimeSeconds;
      return;
    }
    final deltaWeight = (_userTimeSeconds - _lastTimeSeconds) * _faceFrameRate;
    _lastTimeSeconds = _userTimeSeconds;

    final frameToMaxSpeed = _faceTimeToMaxSpeed * _faceFrameRate;
    final maxA = deltaWeight * maxV / frameToMaxSpeed; // 每帧最大加速度

    final dx = _faceTargetX - _faceX;
    final dy = _faceTargetY - _faceY;
    if (dx.abs() <= _faceEpsilon && dy.abs() <= _faceEpsilon) {
      // 到目标附近：停止（与原实现一致，保留当前值）。
      _applyMouseNorm(Offset(_faceX, _faceY));
      _mouseTimer?.cancel();
      _mouseTimer = null;
      return;
    }

    final d = sqrt(dx * dx + dy * dy);
    final vx = maxV * dx / d;
    final vy = maxV * dy / d;
    var ax = vx - _faceVX;
    var ay = vy - _faceVY;
    final a = sqrt(ax * ax + ay * ay);
    if (maxA > 0 && a > maxA) {
      ax *= maxA / a;
      ay *= maxA / a;
    }
    _faceVX += ax;
    _faceVY += ay;

    // 接近目标时按刹车距离限制速度（原公式 `0.5*(sqrt(a²+16ah-8ah)-a)`）。
    if (maxA > 0) {
      final maxVBrake =
          0.5 * (sqrt(maxA * maxA + 16 * maxA * d - 8 * maxA * d) - maxA);
      final curV = sqrt(_faceVX * _faceVX + _faceVY * _faceVY);
      if (maxVBrake > 0 && curV > maxVBrake) {
        _faceVX *= maxVBrake / curV;
        _faceVY *= maxVBrake / curV;
      }
    }

    _faceX += _faceVX;
    _faceY += _faceVY;
    _applyMouseNorm(Offset(_faceX, _faceY));
  }

  /// 下发跟随值：`value = base + eased × 跟随强度 × scale`。
  ///
  /// [FollowMapping.base] 是参数在模型里的默认值——光标居中时回到中性姿态，
  /// 而不是被压成 0。每轴再乘本宠的跟随强度 [_followX]/[_followY]（`xy` 乘两者之积）。
  void _applyMouseNorm(Offset eased) {
    for (final m in _follow.x) {
      onParameter?.call(m.param, m.base + eased.dx * _followX * m.scale);
    }
    for (final m in _follow.y) {
      onParameter?.call(m.param, m.base + eased.dy * _followY * m.scale);
    }
    if (_follow.xy.isNotEmpty) {
      final both = eased.dx * eased.dy;
      final follow = _followX * _followY;
      for (final m in _follow.xy) {
        onParameter?.call(m.param, m.base + both * follow * m.scale);
      }
    }
  }

  void _onMouseButton(({MouseButton button, bool down}) event) {
    final mp = _mouseParams;
    if (mp == null) return;
    final id = event.button == MouseButton.left ? mp.left : mp.right;
    if (id != null) onParameter?.call(id, event.down ? 1.0 : 0.0);
  }

  void _teardownMouseParams() {
    OverlayController.cursorNorm.removeListener(_onCursorNorm);
    _cursorSubscribed = false;
    _mouseTimer?.cancel();
    _mouseTimer = null;
    unawaited(_mouseSub?.cancel());
    _mouseSub = null;
    if (_mouseTracking) {
      _mouseTracking = false;
      unawaited(InputService.instance.setMouseTracking(false));
    }
    _mouseParams = null;
    _follow = const MouseFollow();
    _modelParams = const [];
    _mouseInited = false;
    _mouseRaw = Offset.zero;
  }

  /// 当前桌宠的配置（尚未落库 / 已被删除时为 null）。
  ///
  /// 直接按 id 读单键，不再把全部桌宠读出来再筛。
  PetConfig? get _petConfig => StorageService.readPet(petId);

  /// 该桌宠的 Live2D 可调参数选择（组 id → 选项下标）；未配置时为空表（用清单默认）。
  Map<String, int> get paramChoices => _petConfig?.paramChoices ?? const {};

  /// 动作改动了参数（`HotkeyAction.sets`）→ 写回该桌宠的 `paramChoices`；
  /// 存储广播会把新选择再送回渲染器，设置界面也会同步。
  void setParamChoices(Map<String, int> choices) {
    StorageService.updatePet(petId, (pet) => pet.copyWith(paramChoices: choices));
  }

  /// 由宠物包帧尺寸 × 全局缩放 × 该宠缩放得出最终渲染尺寸，并收敛到场景内。
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

  /// 进入新状态时播放该状态声明的音效（见 [AudioService]）。
  ///
  /// 状态机的每一处跳转（点击 / 定时 / 热键 / 到达…）都经过 [state] setter，
  /// 所以这就是唯一的发声点。
  void _playStateAudio(String stateName) {
    if (!_packReady) return;
    _audio.playForState(pack.states[stateName], cue: stateName);
  }

  /// 应用设置（本引擎内）：**换包重建** / 缩放 / 透明度 + 窗口侧的显隐与穿透。
  ///
  /// 由 `appDataProvider` 的变更驱动（见 `PetView`），所以设置窗口里改这只宠物
  /// ——包括换宠物包——都会立刻作用到正在运行的桌宠。
  Future<void> refreshSettings() async {
    await _reloadPackIfChanged();
    _syncFollowStrength();
    _rebuildFollow();
    await _applyScale();
    _applyOpacity();
    await _window.applyLocked(_petConfig);
    await _window.applyVisible(_petConfig);
    // 跟随强度改了就立即重下发一次（光标不动时看不出变化）。
    _refreshMouseFollow();
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
        pack.findBestTimer(state.currentState);

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
    final needsBehavior = pack.hasBehavior(state.currentState);
    if (!needsBehavior) {
      _cancelBehaviorTimer();
      return;
    }
    // 场景尺寸未就绪时不能生成目标:maxX/maxY 会变成负数,clamp 直接抛错。
    if (screenSize.isEmpty) return;
    if (state.targetPosition == null) {
      final def = pack.states[state.currentState];
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
    final next = pack.findTransition(state.currentState, trigger);
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
    _teardownMouseParams();
    hotkey.dispose();
    _audio.dispose();
    _savePosition();
    super.dispose();
  }

  Future<void> refreshScreenSize() => _window.refreshScreenSize();
}
