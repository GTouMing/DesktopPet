//import 'package:hotkey_manager/hotkey_manager.dart';

import '../core/constants.dart';
import '../platform/windows/hotkey_service.dart';
import '../skin/skin_package.dart';
import '../skin/state/state_define.dart';

/// 桌宠快捷键注册与派发。
///
/// 所有 state 中定义了 `key` 的 hotkey 规则均注册为全局快捷键，
/// bind() 时建立二维查找表 [compositeKey × fromState → targetState]，
/// 按下时 O(1) 查表确定目标，无需动态遍历。
class HotkeyEngine {
  //final HotkeyService _hotkey = HotkeyService();

  String Function()? _currentState;
  void Function(String)? _onStateChange;

  /// 快捷键二维查找表：compositeKey → (当前状态 → 目标状态)。
  ///
  /// 在 [bind] 时构建，onHotkey 回调通过此表 O(1) 确定目标，
  /// 避免运行时遍历 transitions 造成的不确定性。
  Map<String, Map<String, String>> _hotkeyTable = {};

  /// 注册快捷键。
  ///
  /// [skin] 皮肤包，用于扫描各状态中的 hotkey 规则并建立查找表。
  /// [currentState] 返回当前状态名的函数。
  /// [onStateChange] 快捷键触发后调用，传入目标状态名。
  void bind({
    required SkinPackage skin,
    required String Function() currentState,
    required void Function(String) onStateChange,
  }) {
    // _currentState = currentState;
    // _onStateChange = onStateChange;
    //
    // // 构建二维查找表 + 收集唯一快捷键用于物理注册
    // final Map<String, Map<String, String>> table = {};
    // final Map<String, HotKey> bindings = {};
    //
    // for (final stateEntry in skin.states.entries) {
    //   final stateName = stateEntry.key;
    //   final stateDef = stateEntry.value;
    //   for (final transEntry in stateDef.transitions.entries) {
    //     final targetName = transEntry.key;
    //     final rules = transEntry.value;
    //     for (final rule in rules.entries) {
    //       if (rule.key != Trigger.hotkey) continue;
    //
    //       final composite = TransitionRule.compositeKey(
    //           rule.value.key!, rule.value.modifiers);
    //
    //       // 二维表：compositeKey → fromState → targetState
    //       // ??= 保证同 (compositeKey, fromState) 第一条 wins
    //       table.putIfAbsent(composite, () => {});
    //       table[composite]![stateName] ??= targetName;
    //
    //       // 每组合键只注册一次物理快捷键
    //       if (!bindings.containsKey(composite)) {
    //         bindings[composite] = HotkeyService.fromStrings(
    //             rule.value.key!, rule.value.modifiers);
    //       }
    //     }
    //   }
    // }
    // _hotkeyTable = table;
    //
    // _hotkey.onHotkey = (compositeKey) {
    //   final state = _currentState?.call();
    //   if (state == null) return;
    //
    //   final target = _hotkeyTable[compositeKey]?[state];
    //   if (target != null) {
    //     _onStateChange?.call(target);
    //   }
    // };
    //
    // _hotkey.registerAll(bindings);
  }

  void dispose() {
    //_hotkey.onHotkey = null;
  }
}
