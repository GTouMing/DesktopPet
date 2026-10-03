import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/core/enums.dart';
import 'package:desktop_pet/input/input.dart';
import 'package:desktop_pet/pet/hotkey_engine.dart';
import 'package:desktop_pet/petpack/sprite_pet_pack.dart';
import 'package:desktop_pet/petpack/state/state_define.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StateDef _state(String name, Map<String, Map<String, TransitionRule>> transitions) =>
    StateDef(name: name, animation: name, transitions: transitions);

TransitionRule _hotkey(String key, List<String> modifiers) =>
    TransitionRule(trigger: Trigger.hotkey, key: key, modifiers: modifiers);

SpritePetPack _pack(List<StateDef> states) => SpritePetPack(
  name: 'test',
  version: 1,
  baseSize: const Size(100, 100),
  basePath: '',
  anims: const {},
  states: {for (final s in states) s.name: s},
  source: PetPackSource.asset,
);

void main() {
  test('收集皮肤声明的 hotkey 组合键', () {
    final pack = _pack([
      _state('idle', {
        'happy': {Trigger.hotkey: _hotkey('h', ['alt'])},
      }),
    ]);

    expect(HotkeyEngine.collectRules(pack).keys, ['alt+h']);
  });

  test('收集到的组合键能被 findTransition 直接命中(两侧规范化一致)', () {
    final pack = _pack([
      _state('idle', {
        'happy': {Trigger.hotkey: _hotkey('h', ['alt'])},
      }),
      _state('happy', const {}),
    ]);

    final composite = HotkeyEngine.collectRules(pack).keys.single;

    // 这正是 HotkeyEngine 触发时走的查找；两侧若各用一套规范化就会查不到。
    expect(
      pack.findTransition('idle', Trigger.hotkey, hotkeyComposite: composite),
      'happy',
    );
    expect(
      pack.findTransition('idle', Trigger.hotkey, hotkeyComposite: 'alt+g'),
      isNull,
    );
  });

  test('同一组合键跨状态只注册一次，修饰键顺序无关', () {
    final pack = _pack([
      _state('idle', {
        'a': {Trigger.hotkey: _hotkey('h', ['ctrl', 'alt'])},
      }),
      _state('walk', {
        'b': {Trigger.hotkey: _hotkey('h', ['alt', 'ctrl'])},
      }),
    ]);

    final rules = HotkeyEngine.collectRules(pack);
    expect(rules.keys, ['alt+ctrl+h']);
    expect(rules.length, 1);
  });

  test('没有 key 的 hotkey 规则不注册', () {
    final pack = _pack([
      _state('idle', {
        'a': {Trigger.hotkey: const TransitionRule(trigger: Trigger.hotkey)},
      }),
    ]);

    expect(HotkeyEngine.collectRules(pack), isEmpty);
  });

  test('bind 把组合键注册到输入层，dispose 时注销', () async {
    final input = _FakeKeyInput();
    final engine = HotkeyEngine(input);

    await engine.bind(
      pack: _pack([
        _state('idle', {
          'happy': {Trigger.hotkey: _hotkey('h', ['alt'])},
        }),
      ]),
      currentState: () => 'idle',
      onStateChange: (_) {},
    );

    // 注意：同一个组合键在两个世界里**不同名**——输入层用 KeyIdentifier.composite
    // （key 在前，`h+alt`），皮肤侧用 TransitionRule.compositeKey（全部参与排序，
    // `alt+h`）。见 key_event.dart 的说明。
    expect(input.registered, ['h+alt']);
    expect(input.flushes, 1);

    engine.dispose();
    expect(input.unregistered, ['h+alt']);
  });

  test('按下组合键 → 按「当前状态 + 组合键」跳转', () async {
    final input = _FakeKeyInput();
    final engine = HotkeyEngine(input);
    var current = 'idle';
    String? next;

    await engine.bind(
      pack: _pack([
        _state('idle', {
          'happy': {Trigger.hotkey: _hotkey('h', ['alt'])},
        }),
        _state('happy', const {}),
      ]),
      currentState: () => current,
      onStateChange: (v) => next = v,
    );

    input.press('h+alt');
    expect(next, 'happy');

    // 当前状态没有该规则时不该跳转。
    next = null;
    current = 'happy';
    input.press('h+alt');
    expect(next, isNull);

    engine.dispose();
  });

  test('同一输入层上多引擎共享一次注册，退订一个不影响另一个', () async {
    final input = _FakeKeyInput();
    final pack = _pack([
      _state('idle', {
        'happy': {Trigger.hotkey: _hotkey('h', ['alt'])},
      }),
    ]);
    final a = HotkeyEngine(input);
    final b = HotkeyEngine(input);
    await a.bind(pack: pack, currentState: () => 'idle', onStateChange: (_) {});
    await b.bind(pack: pack, currentState: () => 'idle', onStateChange: (_) {});

    expect(input.registered, ['h+alt'], reason: '同一组合键只注册一次');

    a.dispose();
    expect(input.unregistered, isEmpty, reason: 'b 还订阅着，不能注销');

    b.dispose();
    expect(input.unregistered, ['h+alt']);
  });

  test('触发时广播给全部订阅者，各自按自己的当前状态查表', () async {
    final input = _FakeKeyInput();
    final pack = _pack([
      _state('idle', {
        'happy': {Trigger.hotkey: _hotkey('h', ['alt'])},
      }),
      _state('happy', const {}),
    ]);
    final a = HotkeyEngine(input);
    final b = HotkeyEngine(input);
    String? aNext;
    String? bNext;

    await a.bind(
        pack: pack, currentState: () => 'idle', onStateChange: (v) => aNext = v);
    await b.bind(
        pack: pack, currentState: () => 'happy', onStateChange: (v) => bNext = v);

    input.press('h+alt');
    expect(aNext, 'happy', reason: 'idle 声明了这条规则');
    expect(bNext, isNull, reason: 'happy 没有这条规则');

    a.dispose();
    b.dispose();
  });
}

/// 假输入层：记录注册/注销，并允许手动"按键"。
///
/// [InputService] 必须在 `runApp` 之前就绪、且会去装真实的全局钩子，测试里用不了；
/// 这正是把输入层收成 [KeyInput] 接口的原因。
class _FakeKeyInput implements KeyInput {
  final List<String> registered = [];
  final List<String> unregistered = [];
  int flushes = 0;

  final Map<String, void Function()> _down = {};

  @override
  Future<void> register(KeyIdentifier id,
      {KeyCallback? onDown, KeyCallback? onUp}) async {
    registered.add(id.composite);
    if (onDown != null) {
      _down[id.composite] = () => onDown(InputKeyEvent(id, KeyState.down));
    }
  }

  @override
  Future<void> unregister(KeyIdentifier id) async =>
      unregistered.add(id.composite);

  @override
  Future<void> flush() async => flushes++;

  /// 模拟按下某个组合键。
  void press(String composite) => _down[composite]?.call();
}
