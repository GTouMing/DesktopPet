import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../input/input.dart';
import '../petpack/hotkey_action.dart';
import '../petpack/pet_pack.dart';
import '../petpack/state/state_define.dart';

/// 诊断日志(Debug 构建可见)。
void _hk(String message) {
  if (kDebugMode) debugPrint('[hotkey] $message');
}

/// 某个组合键在输入层的注册项：注册一次，触发时广播给所有订阅它的桌宠。
class _Binding {
  _Binding(this.id);

  final KeyIdentifier id;
  final Set<HotkeyEngine> subscribers = {};
}

/// 桌宠快捷键：把宠物包里声明的 hotkey 规则接到全局输入层。
///
/// 平台能力守卫：全局快捷键仅 Windows 可用（Android 走 `NoopInputSource`），
/// [supported] 为 false 时整条注册链路被剔除。
///
/// 工作方式（二维查找）：
/// 1. 收集两类规则并注册进 [InputService]：
///    - 状态机：扫描宠物包的**所有状态**，收集 `trigger == Trigger.hotkey` 且写了
///      `key` 的规则；
///    - 包级动作：宠物包顶层 `hotkeys`（[HotkeyAction]）；
///    两者按 `key+modifiers` 去重。
/// 2. 该组合键按下时：先用**当前状态**加该组合键去 [PetPack.findTransition] 查目标
///    状态，命中就回调 `onStateChange`；**没有**状态迁移匹配时，再看有没有包级动作，
///    有就回调 `onHotkeyAction`（直接播动作、不改状态机）。
///
/// 也就是说"哪个键在哪个状态下生效"完全由宠物包数据决定，本类不含任何键位映射表。
///
/// 宿主引擎同时承载多只桌宠，不同宠物包可能声明同一个组合键；而 `KeyRegistry` 的
/// 映射表是"一键一回调"，各自注册会互相覆盖。因此注册在引擎内**按组合键共享**：
/// 首个订阅者真正注册，触发时广播给全部订阅者。
class HotkeyEngine {
  /// [input] 是输入层（生产环境为 `InputService.instance`，见 `keyInputProvider`）。
  HotkeyEngine(this._input);

  final KeyInput _input;

  /// 当前平台是否支持全局热键(仅 Windows)。
  static bool get supported => Platform.isWindows;

  /// 按输入层共享的注册项：`KeyInput → (composite → 注册信息)`。
  ///
  /// 宿主引擎同时承载多只桌宠，不同宠物包可能声明同一个组合键；而 `KeyRegistry` 的
  /// 映射表是"一键一回调"，各自注册会互相覆盖。因此注册**按组合键共享**：首个
  /// 订阅者真正注册，触发时广播给全部订阅者。
  ///
  /// 按 [KeyInput] 分表是为了测试：注入假输入层的引擎彼此互不干扰。
  static final Map<KeyInput, Map<String, _Binding>> _registries = {};

  Map<String, _Binding> get _registry =>
      _registries.putIfAbsent(_input, () => {});

  /// 引擎内共享的注册项：`composite → 注册信息`。
  final Set<String> _mine = {};

  PetPack? _pack;
  String Function()? _currentState;
  void Function(String state)? _onStateChange;

  /// 包级动作：`composite → HotkeyAction`（状态迁移未命中时的兜底）。
  Map<String, HotkeyAction> _actions = const {};

  void Function(HotkeyAction action)? _onHotkeyAction;

  /// "打字反应"：`复合键 → 模型参数 id`（down 置 1 / up 置 0）。
  Map<String, String> _keyParams = const {};

  void Function(String parameterId, bool down)? _onKeyParam;

  /// 注册宠物包声明的快捷键（幂等：只做增量增删，不整表重挂）。
  ///
  /// [onKeyParam] 用于"打字反应"：包顶层 `keyParams` 把键映射到模型参数，按下/松开
  /// 分别回调 `(参数 id, true/false)`。
  Future<void> bind({
    required PetPack pack,
    required String Function() currentState,
    required void Function(String) onStateChange,
    void Function(HotkeyAction action)? onHotkeyAction,
    void Function(String parameterId, bool down)? onKeyParam,
  }) async {
    _pack = pack;
    _currentState = currentState;
    _onStateChange = onStateChange;
    _onHotkeyAction = onHotkeyAction;
    _onKeyParam = onKeyParam;
    _actions = {for (final a in pack.hotkeys) a.composite: a};
    _keyParams = pack.keyParams;

    if (!supported) return; // 移动端剔除: 不注册任何全局快捷键

    // 状态机的 hotkey 迁移 + 包级 hotkey 动作 + "打字反应"键，合并成一份待注册集合。
    final wanted = collectRules(pack);
    for (final action in pack.hotkeys) {
      wanted.putIfAbsent(action.composite,
          () => KeyIdentifier.key(action.key, modifiers: action.modifiers));
    }
    for (final key in pack.keyParams.keys) {
      final id = KeyIdentifier.key(key);
      wanted.putIfAbsent(id.composite, () => id);
    }

    for (final composite in _mine.toList()) {
      if (wanted.containsKey(composite)) continue;
      _mine.remove(composite);
      _release(composite);
    }
    for (final entry in wanted.entries) {
      if (!_mine.add(entry.key)) continue;
      _subscribe(entry.key, entry.value);
    }

    await _input.flush();
    if (_mine.isNotEmpty) {
      _hk('bindings=${_mine.join(",")}');
    }
  }

  void dispose() {
    for (final composite in _mine.toList()) {
      _release(composite);
    }
    _mine.clear();
    _pack = null;
    _currentState = null;
    _onStateChange = null;
    _onHotkeyAction = null;
    _onKeyParam = null;
    _actions = const {};
    _keyParams = const {};
  }

  // ── 宠物包规则 ─────────────────────────────────────────────────────────

  /// 扫描宠物包的每个状态，返回 `composite → KeyIdentifier`。
  ///
  /// 对外可见仅为测试：它产出的 composite 必须与
  /// `PetPack.findTransition(hotkeyComposite:)` 接受的格式完全一致，这是宠物包
  /// 数据与输入层之间唯一的耦合点。
  @visibleForTesting
  static Map<String, KeyIdentifier> collectRules(PetPack pack) {
    final found = <String, KeyIdentifier>{};
    for (final state in pack.states.values) {
      for (final rules in state.transitions.values) {
        final rule = rules[Trigger.hotkey];
        final key = rule?.key;
        if (rule == null || key == null || key.isEmpty) continue;
        final composite = TransitionRule.compositeKey(key, rule.modifiers);
        found.putIfAbsent(
            composite, () => KeyIdentifier.key(key, modifiers: rule.modifiers));
      }
    }
    return found;
  }

  // ── 引擎内共享注册 ───────────────────────────────────────────────────

  void _subscribe(String composite, KeyIdentifier id) {
    final registry = _registry;
    var binding = registry[composite];
    if (binding == null) {
      binding = _Binding(id);
      registry[composite] = binding;
      unawaited(_input.register(id,
          onDown: (_) => _dispatch(composite, true),
          onUp: (_) => _dispatch(composite, false)));
    }
    binding.subscribers.add(this);
  }

  void _release(String composite) {
    final registry = _registry;
    final binding = registry[composite];
    if (binding == null) return;
    binding.subscribers.remove(this);
    if (binding.subscribers.isNotEmpty) return;
    registry.remove(composite);
    unawaited(_input.unregister(binding.id));
  }

  void _dispatch(String composite, bool down) {
    final binding = _registry[composite];
    if (binding == null) return;
    for (final engine in binding.subscribers.toList()) {
      engine._fire(composite, down);
    }
  }

  /// 组合键按下 / 松开。
  ///
  /// - **down**：先按「当前状态 + 组合键」做状态迁移；没有匹配的状态迁移时，再看
  ///   包级 hotkey 动作（[HotkeyAction]，直接播动作、不改状态机）；最后交给"打字
  ///   反应"参数（同一个键也可以只是参数）。
  /// - **up**：只处理"打字反应"参数（松开置 0）。
  void _fire(String composite, bool down) {
    if (!down) {
      final paramId = _keyParams[composite];
      if (paramId != null) _onKeyParam?.call(paramId, false);
      return;
    }

    final pack = _pack;
    final currentState = _currentState;
    if (pack != null && currentState != null) {
      final from = currentState();
      final next =
          pack.findTransition(from, Trigger.hotkey, hotkeyComposite: composite);
      if (next != null) {
        _hk('$composite: $from -> $next');
        _onStateChange?.call(next);
      } else {
        final action = _actions[composite];
        if (action != null) {
          _hk('$composite -> action "${action.animation}" #${action.motionIndex}');
          _onHotkeyAction?.call(action);
        }
      }
    }

    final paramId = _keyParams[composite];
    if (paramId != null) {
      _hk('$composite -> param $paramId = 1');
      _onKeyParam?.call(paramId, true);
    }
  }
}
