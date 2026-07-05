import 'package:flutter/widgets.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../features/app_launcher/hotkey_service.dart';
import 'behavior_engine.dart';

/// 桌宠专属快捷键注册与派发。
///
/// 包装 [HotkeyService] 并绑定到当前桌宠的 [BehaviorEngine]，
/// 桌面端（仅 Windows）注册一组预设快捷键：
/// - Alt+Space → 菜单
/// - Alt+F     → 投喂
/// - Alt+H     → 点击
class PetHotkeyBindings {
  final HotkeyService _hotkey = HotkeyService();

  /// 注册快捷键并绑定到 [engine]。
  ///
  /// [onStateChange] 在快捷键触发状态机跳转后被调用，用于更新 [PetState]。
  void bind(
    BehaviorEngine engine, {
    required VoidCallback? onMenu,
    required void Function(String) onStateChange,
  }) {
    _hotkey.onHotkey = (trigger) {
      if (trigger == 'menu') {
        onMenu?.call();
        return;
      }
      final next = engine.onEvent(trigger);
      if (next != null) onStateChange(next);
    };
    _hotkey.registerAll({
      'eat': HotKey(KeyCode.keyF, modifiers: [KeyModifier.alt]),
      'click': HotKey(KeyCode.keyH, modifiers: [KeyModifier.alt]),
      'menu': HotKey(KeyCode.space, modifiers: [KeyModifier.alt]),
    });
  }

  void dispose() {
    _hotkey.onHotkey = null;
  }
}