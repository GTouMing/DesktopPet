import 'dart:io';

import 'package:desktop_pet/platform/windows/windows_channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../input_source.dart';
import '../key_event.dart';
import '../pointer_event.dart';

/// 诊断日志(Debug 构建可见)。
void _hk(String message) {
  if (kDebugMode) debugPrint('[input] $message');
}

/// Windows 全局输入源。
///
/// 对接 runner 内联原生模块 `windows/runner/global_input.cpp`
/// (MethodChannel `desktop_pet/global_input`):
/// - WH_KEYBOARD_LL 钩子: 支持多绑定组合键, 带 down/up 语义;
/// - WH_MOUSE_LL 钩子: 支持鼠标按键绑定(如中键), 以及**桌宠指针事件**
///   (`onMouse`)。后者是桌宠唯一的输入来源: 悬浮窗整窗穿透, 收不到鼠标消息。
class WindowsInputSource extends InputSource {
  static const MethodChannel _channel =
      MethodChannel(GlobalInputChannel.name);

  WindowsInputSource() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  @override
  bool get supported => Platform.isWindows;

  /// arm 时建立 `composite → KeyIdentifier` 映射, 按键事件按 id 回查。
  final Map<String, KeyIdentifier> _byId = {};

  // ── 修饰键名 → 需要按下的虚拟键 ────────────────────────────────────
  //
  // 原生不再持有"哪个 VK 是修饰键"的表：这里把修饰键翻译成具体的 VK 组发下去，
  // 原生只判断"这些 VK 是否按下"。组内任一按下即满足(左/右 Win 键是两个 VK)。

  /// 修饰键名 → 候选虚拟键(任一按下即认为该修饰键生效)。
  static const Map<String, List<int>> _modVks = {
    'alt': [0x12], // VK_MENU
    'ctrl': [0x11], // VK_CONTROL
    'control': [0x11],
    'shift': [0x10], // VK_SHIFT
    'meta': [0x5B, 0x5C], // VK_LWIN / VK_RWIN
    'win': [0x5B, 0x5C],
    'windows': [0x5B, 0x5C],
    'cmd': [0x5B, 0x5C],
    'super': [0x5B, 0x5C],
  };

  /// 修饰键名 → VK 组。每组都必须满足,组内任一 VK 按下即算满足。
  static List<List<int>> modifiersToVkGroups(List<String> modifiers) {
    final groups = <List<int>>[];
    for (final m in modifiers) {
      final group = _modVks[m.toLowerCase()];
      if (group != null) groups.add(group);
    }
    return groups;
  }

  /// 键名 → Windows 虚拟键码(0 = 无法识别, 视为禁用)。
  static int keyToVk(String raw) {
    final lower = raw.toLowerCase();
    if (lower.length == 1) {
      final c = lower.codeUnitAt(0);
      if (c >= 0x30 && c <= 0x39) return c; // 0-9
      if (c >= 0x61 && c <= 0x7a) return c - 0x20; // a-z → VK_A..
      const specials = <String, int>{
        '`': 0xC0,
        '-': 0xBD,
        '=': 0xBB,
        '[': 0xDB,
        ']': 0xDD,
        '\\': 0xDC,
        ';': 0xBA,
        "'": 0xDE,
        ',': 0xBC,
        '.': 0xBE,
        '/': 0xBF,
      };
      if (specials.containsKey(lower)) return specials[lower]!;
    }
    const named = <String, int>{
      'space': 0x20,
      'tab': 0x09,
      'enter': 0x0D,
      'escape': 0x1B,
      'esc': 0x1B,
      'backspace': 0x08,
      'delete': 0x2E,
      'insert': 0x2D,
      'home': 0x24,
      'end': 0x23,
      'pageup': 0x21,
      'pagedown': 0x22,
      'up': 0x26,
      'down': 0x28,
      'left': 0x25,
      'right': 0x27,
    };
    if (named.containsKey(lower)) return named[lower]!;
    final fMatch = RegExp(r'^f(\d{1,2})$').firstMatch(lower);
    if (fMatch != null) {
      final n = int.parse(fMatch.group(1)!);
      if (n >= 1 && n <= 24) return 0x70 + (n - 1);
    }
    return 0;
  }

  // ── InputSource ──────────────────────────────────────────────────────

  @override
  Future<void> arm(List<KeyIdentifier> keys) async {
    if (!supported) return;
    _byId.clear();

    final bindings = <Map<String, Object?>>[];
    for (final id in keys) {
      if (id.device == KeyDevice.mouse) {
        _byId[id.composite] = id;
        bindings.add({
          GlobalInputChannel.id: id.composite,
          GlobalInputChannel.type: GlobalInputChannel.typeMouse,
          GlobalInputChannel.button: MouseButton.values.byName(id.key).index,
        });
        continue;
      }
      final vk = keyToVk(id.key);
      if (vk == 0) {
        _hk('skip unrecognized key "${id.key}"');
        continue;
      }
      _byId[id.composite] = id;
      bindings.add({
        GlobalInputChannel.id: id.composite,
        GlobalInputChannel.type: GlobalInputChannel.typeKey,
        GlobalInputChannel.vk: vk,
        GlobalInputChannel.mods: modifiersToVkGroups(id.modifiers),
      });
    }

    _hk('arm bindings=${bindings.length}');
    await _channel.invokeMethod(
        GlobalInputChannel.configure, {GlobalInputChannel.bindings: bindings});
    await _channel.invokeMethod(GlobalInputChannel.start);
  }

  @override
  Future<void> setWatchRects(List<Rect> physicalRects) async {
    if (!supported) return;
    await _channel.invokeMethod(GlobalInputChannel.setWatchRects, [
      for (final rect in physicalRects)
        {
          GlobalInputChannel.left: rect.left.round(),
          GlobalInputChannel.top: rect.top.round(),
          GlobalInputChannel.right: rect.right.round(),
          GlobalInputChannel.bottom: rect.bottom.round(),
        },
    ]);
  }

  @override
  Future<void> disarm() async {
    if (!supported) return;
    _byId.clear();
    _hk('disarm');
    await _channel.invokeMethod(GlobalInputChannel.stop);
  }

  Future<Object?> _onMethodCall(MethodCall call) async {
    if (call.method == GlobalInputChannel.onTrigger) {
      return _onTrigger(call);
    }
    if (call.method == GlobalInputChannel.onMouse) {
      return _onMouse(call);
    }
    return null;
  }

  /// 全局钩子转发来的桌宠指针事件(物理屏幕像素)。
  Object? _onMouse(MethodCall call) {
    final args = (call.arguments as Map?)?.cast<String, dynamic>();
    if (args == null) return null;

    final x = (args[GlobalInputChannel.x] as num?)?.toDouble();
    final y = (args[GlobalInputChannel.y] as num?)?.toDouble();
    if (x == null || y == null) return null;

    final phase = switch (args[GlobalInputChannel.event] as String?) {
      GlobalInputChannel.phaseDown => PointerPhase.down,
      GlobalInputChannel.phaseUp => PointerPhase.up,
      _ => PointerPhase.move,
    };
    onPointer?.call(InputPointerEvent(phase, Offset(x, y)));
    return null;
  }

  Object? _onTrigger(MethodCall call) {
    final args = (call.arguments as Map?)?.cast<String, dynamic>();
    if (args == null) return null;

    final id = _byId[args[GlobalInputChannel.id] as String?];
    final stateName = args[GlobalInputChannel.state] as String?;
    if (id == null || stateName == null) return null;

    final event = InputKeyEvent(
      id,
      stateName == GlobalInputChannel.phaseDown
          ? KeyState.down
          : KeyState.up,
    );
    _hk('trigger ${id.composite} ${event.state.name}');
    onEvent?.call(event);
    return null;
  }
}
