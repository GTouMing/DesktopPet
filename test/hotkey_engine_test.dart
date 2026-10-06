import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/core/enums.dart';
import 'package:desktop_pet/input/input.dart';
import 'package:desktop_pet/pet/hotkey_engine.dart';
import 'package:desktop_pet/petpack/hotkey_action.dart';
import 'package:desktop_pet/petpack/pet_pack.dart';
import 'package:desktop_pet/petpack/sprite_pet_pack.dart';
import 'package:desktop_pet/petpack/state/state_define.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StateDef _state(String name, Map<String, Map<String, TransitionRule>> transitions) =>
    StateDef(name: name, animation: name, transitions: transitions);

TransitionRule _hotkey(String key, List<String> modifiers) =>
    TransitionRule(trigger: Trigger.hotkey, key: key, modifiers: modifiers);

SpritePetPack _pack(List<StateDef> states,
        {List<HotkeyAction> hotkeys = const [],
        Map<String, String> keyParams = const {}}) =>
    SpritePetPack(
      name: 'test',
      version: 1,
      baseSize: const Size(100, 100),
      basePath: '',
      anims: const {},
      states: {for (final s in states) s.name: s},
      source: PetPackSource.asset,
      hotkeys: hotkeys,
      keyParams: keyParams,
    );

void main() {
  test('收集宠物包声明的 hotkey 组合键', () {
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
    // （key 在前，`h+alt`），宠物包侧用 TransitionRule.compositeKey（全部参与排序，
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

  test('解析清单 hotkeys 表（跳过无 key 项）', () {
    final actions = parsePetPackHotkeys({
      'hotkeys': {
        'ear': {
          'key': '1',
          'modifiers': ['ctrl', 'alt'],
          'animation': 'CAT_motion_lock',
          'motionIndex': 1,
          'motionPriority': 2,
          'durationMs': 517,
        },
        'cry': {'key': '2', 'expression': 3},
        'bad': {'animation': 'X'},
      },
    });

    expect(actions.length, 2);
    expect(actions.first.composite, '1+alt+ctrl');
    expect(actions.first.animation, 'CAT_motion_lock');
    expect(actions.first.motionIndex, 1);
    expect(actions.first.motionPriority, 2);
    expect(actions.first.hasMotion, isTrue);
    expect(actions.first.durationMs, 517);
    expect(actions.last.expression, 3);
    expect(actions.last.hasMotion, isFalse);
    expect(actions.last.durationMs, 0, reason: '缺省不串行');
  });

  test('解析动作的 requires / sets（前提与参数改动）', () {
    final actions = parsePetPackHotkeys({
      'hotkeys': {
        'selfie': {
          'key': '5',
          'animation': 'Selfie',
          'durationMs': 3300,
          'requires': {
            'rhand': ['掏出手机'],
            'blush': true,
          },
          'sets': {'selfie': '自拍', 'heart': false},
        },
        'single': {
          'key': '1',
          'requires': {'whale': '头顶鲸'},
        },
      },
    });

    expect(actions.first.requires, {
      'rhand': ['掏出手机'],
      'blush': ['on'],
    });
    expect(actions.first.sets, {'selfie': '自拍', 'heart': 'off'});
    expect(actions.first.durationMs, 3300);
    // 单字符串前提归一成列表；未声明 sets 时为空。
    expect(actions.last.requires, {'whale': ['头顶鲸']});
    expect(actions.last.sets, isEmpty);
  });

  test('解析清单 keyParams 表（键名小写，跳过非字符串）', () {
    final params = parsePetPackKeyParams({
      'keyParams': {'Q': 'Q1', 'space': 'Space', 'bad': 5},
    });
    expect(params, {'q': 'Q1', 'space': 'Space'});
  });

  test('解析清单 mouseParams 表（多组映射 + 字符串简写；全空返回 null）', () {
    final mp = parsePetPackMouseParams({
      'mouseParams': {
        'x': [
          {'param': 'ParamAngleX', 'scale': 30},
          'ParamEyeBallX',
          {'param': 'ParamMouseX', 'scale': 30, 'raw': true},
        ],
        'y': 'ParamAngleY',
        'xy': [
          {'param': 'ParamAngleZ', 'scale': -30},
        ],
        'left': 'LDown',
        'right': 'RDown',
        'smooth': 1.0,
      },
    });
    expect(mp, isNotNull);
    expect(mp!.followsCursor, isTrue);
    expect(mp.hasButtons, isTrue);
    expect(mp.smooth, 1.0);
    expect(mp.x.length, 3);
    expect(mp.x[0].param, 'ParamAngleX');
    expect(mp.x[0].scale, 30.0);
    expect(mp.x[0].raw, isFalse);
    expect(mp.x[1].param, 'ParamEyeBallX');
    expect(mp.x[1].scale, 1.0, reason: '字符串简写 → scale 1');
    expect(mp.x[2].param, 'ParamMouseX');
    expect(mp.x[2].raw, isTrue, reason: 'raw: true → 不缓动');
    expect(mp.y.single.param, 'ParamAngleY');
    expect(mp.xy.single.scale, -30.0);

    expect(parsePetPackMouseParams({'mouseParams': {}}), isNull);
    expect(parsePetPackMouseParams(const {}), isNull);
  });

  test('打字反应：按键 down/up 驱动参数 1/0', () async {
    final input = _FakeKeyInput();
    final engine = HotkeyEngine(input);
    final events = <String>[];

    await engine.bind(
      pack: _pack([_state('idle', const {})], keyParams: {'q': 'Q1'}),
      currentState: () => 'idle',
      onStateChange: (_) => fail('不应发生状态迁移'),
      onKeyParam: (id, down) => events.add('$id=${down ? 1 : 0}'),
    );

    expect(input.registered, ['q']);
    input.press('q');
    input.release('q');
    expect(events, ['Q1=1', 'Q1=0']);

    engine.dispose();
    expect(input.unregistered, ['q']);
  });

  test('包级 hotkey 直接触发动作（不经状态机）', () async {
    final input = _FakeKeyInput();
    final engine = HotkeyEngine(input);
    HotkeyAction? fired;

    await engine.bind(
      pack: _pack(
        [_state('idle', const {})],
        hotkeys: [
          const HotkeyAction(
              key: 'q', animation: 'CAT_motion_lock', motionIndex: 3),
        ],
      ),
      currentState: () => 'idle',
      onStateChange: (_) => fail('不应发生状态迁移'),
      onHotkeyAction: (a) => fired = a,
    );

    expect(input.registered, ['q']);
    input.press('q');
    expect(fired?.animation, 'CAT_motion_lock');
    expect(fired?.motionIndex, 3);

    engine.dispose();
    expect(input.unregistered, ['q']);
  });

  test('同一组合键：状态迁移优先于包级动作', () async {
    final input = _FakeKeyInput();
    final engine = HotkeyEngine(input);
    String? next;
    HotkeyAction? fired;

    await engine.bind(
      pack: _pack(
        [
          _state('idle', {
            'happy': {Trigger.hotkey: _hotkey('h', ['alt'])},
          }),
          _state('happy', const {}),
        ],
        hotkeys: [
          const HotkeyAction(key: 'h', modifiers: ['alt'], animation: 'X'),
        ],
      ),
      currentState: () => 'idle',
      onStateChange: (v) => next = v,
      onHotkeyAction: (a) => fired = a,
    );

    input.press('h+alt');
    expect(next, 'happy');
    expect(fired, isNull, reason: '命中了状态迁移就不该再触发包级动作');

    engine.dispose();
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
  final Map<String, void Function()> _up = {};

  @override
  Future<void> register(KeyIdentifier id,
      {KeyCallback? onDown, KeyCallback? onUp}) async {
    registered.add(id.composite);
    if (onDown != null) {
      _down[id.composite] = () => onDown(InputKeyEvent(id, KeyState.down));
    }
    if (onUp != null) {
      _up[id.composite] = () => onUp(InputKeyEvent(id, KeyState.up));
    }
  }

  @override
  Future<void> unregister(KeyIdentifier id) async =>
      unregistered.add(id.composite);

  @override
  Future<void> flush() async => flushes++;

  /// 模拟按下某个组合键。
  void press(String composite) => _down[composite]?.call();

  /// 模拟松开某个组合键。
  void release(String composite) => _up[composite]?.call();
}
