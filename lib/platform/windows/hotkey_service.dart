// import 'dart:io';
//
// import 'package:flutter/services.dart';
// import 'package:hid_monitor/hid_monitor.dart';
//
// /// Maps global hotkeys to state machine trigger events.
// /// 映射全局快捷键到状态机触发事件
// class HotkeyService {
//   void Function(String triggerName)? onHotkey;
//
//   Future<void> registerAll(Map<String, HotKey> bindings) async {
//     if (!Platform.isWindows) return;
//     await hotKeyManager.unregisterAll();
//
//     for (final entry in bindings.entries) {
//       await hotKeyManager.register(
//         entry.value,
//         keyDownHandler: (_) => onHotkey?.call(entry.key),
//       );
//     }
//   }
//
//   Future<void> unregisterAll() async {
//     await hotKeyManager.unregisterAll();
//   }
//
//   /// 注册一个同时监听 keyDown 和 keyUp 的快捷键。
//   ///
//   /// 用于快捷启动等需要"按下显示、松开触发"模式的场景。
//   Future<void> registerWithUpHandler(
//     HotKey hotKey, {
//     required VoidCallback onDown,
//     required VoidCallback onUp,
//   }) async {
//     if (!Platform.isWindows) return;
//     await hotKeyManager.register(
//       hotKey,
//       keyDownHandler: (_) => onDown(),
//       keyUpHandler: (_) => onUp(),
//     );
//   }
//
//   // ── 字符串 → HotKey 转换 ──────────────────────────────────────────────
//
//   /// 从字符串键名和修饰键列表创建 [HotKey]。
//   static HotKey fromStrings(String key, List<String> modifiers) {
//     return HotKey(
//       key: parseKey(key),
//       modifiers: modifiers.map((m) => parseMod(m)).toList(),
//     );
//   }
//
//   /// 公开的键名解析。
//   static LogicalKeyboardKey parseKey(String raw) => _parseKey(raw);
//
//   /// 公开的修饰键解析。
//   static HotKeyModifier parseMod(String raw) => _parseMod(raw);
//
//   // ── 内部解析 ──────────────────────────────────────────────────────────
//
//   static HotKeyModifier _parseMod(String raw) {
//     switch (raw.toLowerCase()) {
//       case 'alt': return HotKeyModifier.alt;
//       case 'ctrl': case 'control': return HotKeyModifier.control;
//       case 'shift': return HotKeyModifier.shift;
//       case 'meta': case 'win': case 'windows':
//       case 'command': case 'cmd': case 'super':
//         return HotKeyModifier.meta;
//       default: return HotKeyModifier.control;
//     }
//   }
//
//   static LogicalKeyboardKey _parseKey(String raw) {
//     final lower = raw.toLowerCase();
//     const letters = <String, LogicalKeyboardKey>{
//       'a': LogicalKeyboardKey.keyA, 'b': LogicalKeyboardKey.keyB,
//       'c': LogicalKeyboardKey.keyC, 'd': LogicalKeyboardKey.keyD,
//       'e': LogicalKeyboardKey.keyE, 'f': LogicalKeyboardKey.keyF,
//       'g': LogicalKeyboardKey.keyG, 'h': LogicalKeyboardKey.keyH,
//       'i': LogicalKeyboardKey.keyI, 'j': LogicalKeyboardKey.keyJ,
//       'k': LogicalKeyboardKey.keyK, 'l': LogicalKeyboardKey.keyL,
//       'm': LogicalKeyboardKey.keyM, 'n': LogicalKeyboardKey.keyN,
//       'o': LogicalKeyboardKey.keyO, 'p': LogicalKeyboardKey.keyP,
//       'q': LogicalKeyboardKey.keyQ, 'r': LogicalKeyboardKey.keyR,
//       's': LogicalKeyboardKey.keyS, 't': LogicalKeyboardKey.keyT,
//       'u': LogicalKeyboardKey.keyU, 'v': LogicalKeyboardKey.keyV,
//       'w': LogicalKeyboardKey.keyW, 'x': LogicalKeyboardKey.keyX,
//       'y': LogicalKeyboardKey.keyY, 'z': LogicalKeyboardKey.keyZ,
//     };
//     if (letters.containsKey(lower)) return letters[lower]!;
//
//     const digits = <String, LogicalKeyboardKey>{
//       '0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1,
//       '2': LogicalKeyboardKey.digit2, '3': LogicalKeyboardKey.digit3,
//       '4': LogicalKeyboardKey.digit4, '5': LogicalKeyboardKey.digit5,
//       '6': LogicalKeyboardKey.digit6, '7': LogicalKeyboardKey.digit7,
//       '8': LogicalKeyboardKey.digit8, '9': LogicalKeyboardKey.digit9,
//     };
//     if (digits.containsKey(lower)) return digits[lower]!;
//
//     const named = <String, LogicalKeyboardKey>{
//       'space': LogicalKeyboardKey.space, 'enter': LogicalKeyboardKey.enter,
//       'escape': LogicalKeyboardKey.escape, 'tab': LogicalKeyboardKey.tab,
//       '`': LogicalKeyboardKey.backquote, 'backquote': LogicalKeyboardKey.backquote,
//       'backspace': LogicalKeyboardKey.backspace, 'delete': LogicalKeyboardKey.delete,
//       'insert': LogicalKeyboardKey.insert, 'home': LogicalKeyboardKey.home,
//       'end': LogicalKeyboardKey.end, 'pageup': LogicalKeyboardKey.pageUp,
//       'pagedown': LogicalKeyboardKey.pageDown, 'up': LogicalKeyboardKey.arrowUp,
//       'down': LogicalKeyboardKey.arrowDown, 'left': LogicalKeyboardKey.arrowLeft,
//       'right': LogicalKeyboardKey.arrowRight,
//       'f1': LogicalKeyboardKey.f1, 'f2': LogicalKeyboardKey.f2,
//       'f3': LogicalKeyboardKey.f3, 'f4': LogicalKeyboardKey.f4,
//       'f5': LogicalKeyboardKey.f5, 'f6': LogicalKeyboardKey.f6,
//       'f7': LogicalKeyboardKey.f7, 'f8': LogicalKeyboardKey.f8,
//       'f9': LogicalKeyboardKey.f9, 'f10': LogicalKeyboardKey.f10,
//       'f11': LogicalKeyboardKey.f11, 'f12': LogicalKeyboardKey.f12,
//     };
//     return named[lower] ?? LogicalKeyboardKey.space;
//   }
// }
