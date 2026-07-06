import 'dart:io';

import 'package:hotkey_manager/hotkey_manager.dart';

/// Maps global hotkeys to state machine trigger events.
/// 映射全局快捷键到状态机触发事件
class HotkeyService {
  void Function(String triggerName)? onHotkey;

  Future<void> registerAll(Map<String, HotKey> bindings) async {
    if (!Platform.isWindows) return;
    await hotKeyManager.unregisterAll();

    for (final entry in bindings.entries) {
      await hotKeyManager.register(
        entry.value,
        keyDownHandler: (_) => onHotkey?.call(entry.key),
      );
    }
  }

  Future<void> unregisterAll() async {
    await hotKeyManager.unregisterAll();
  }
}
