import 'package:desktop_pet/input/input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyIdentifier', () {
    test('键盘: 修饰键排序, 复合标识稳定且大小写归一', () {
      final a = KeyIdentifier.key('G', modifiers: ['shift', 'alt']);
      final b = KeyIdentifier.key('g', modifiers: ['alt', 'shift']);

      expect(a.composite, 'g+alt+shift');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('鼠标: mouse:middle', () {
      final id = KeyIdentifier.mouse(MouseButton.middle);

      expect(id.composite, 'mouse:middle');
      expect(id.device, KeyDevice.mouse);
      expect(id, KeyIdentifier.mouse(MouseButton.middle));
      expect(id == KeyIdentifier.mouse(MouseButton.left), isFalse);
    });
  });

  group('KeyRegistry', () {
    test('register 后 dispatch 分别命中 onDown/onUp', () {
      final registry = KeyRegistry();
      final id = KeyIdentifier.key('g', modifiers: ['alt']);
      KeyState? downState;
      KeyState? upState;

      registry.register(
        id,
        onDown: (event) => downState = event.state,
        onUp: (event) => upState = event.state,
      );

      registry.dispatch(InputKeyEvent(id, KeyState.down));
      registry.dispatch(InputKeyEvent(id, KeyState.up));

      expect(downState, KeyState.down);
      expect(upState, KeyState.up);
      registry.dispose();
    });

    test('events 广播可被多个订阅者收到', () async {
      final registry = KeyRegistry();
      final id = KeyIdentifier.mouse(MouseButton.middle);
      final first = <InputKeyEvent>[];
      final second = <InputKeyEvent>[];
      final sub1 = registry.events.listen(first.add);
      final sub2 = registry.events.listen(second.add);

      registry.dispatch(InputKeyEvent(id, KeyState.down));
      await Future<void>.delayed(Duration.zero);

      expect(first.single.id, id);
      expect(second.single.state, KeyState.down);
      await sub1.cancel();
      await sub2.cancel();
      registry.dispose();
    });

    test('unregister 后不再回调, 但事件仍广播', () async {
      final registry = KeyRegistry();
      final id = KeyIdentifier.key('h');
      var called = 0;
      final received = <InputKeyEvent>[];
      final sub = registry.events.listen(received.add);

      registry.register(id, onDown: (_) => called++);
      registry.unregister(id);
      registry.dispatch(InputKeyEvent(id, KeyState.down));
      await Future<void>.delayed(Duration.zero);

      expect(called, 0);
      expect(received.single.id, id);
      await sub.cancel();
      registry.dispose();
    });

    test('未注册的按键 dispatch 不回调且映射表为空', () {
      final registry = KeyRegistry();

      registry.dispatch(InputKeyEvent(KeyIdentifier.key('z'), KeyState.down));

      expect(registry.bindings, isEmpty);
      registry.dispose();
    });
  });
}
