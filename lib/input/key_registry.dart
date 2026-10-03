import 'dart:async';

import 'key_event.dart';

/// 按键回调。
typedef KeyCallback = void Function(InputKeyEvent event);

/// 一个按键的回调字段。
class KeyHandler {
  final KeyCallback? onDown;
  final KeyCallback? onUp;

  const KeyHandler({this.onDown, this.onUp});
}

/// 按键注册表: `Map<KeyIdentifier, KeyHandler>` + 事件广播。
///
/// - 注册 = 往映射表写入按键及其 down/up 回调;
/// - 派发 = 命中回调, 并广播给所有订阅者([events]);
/// - 其他系统可订阅 [events] 进入自定义方法, 也可直接用回调字段。
class KeyRegistry {
  final Map<KeyIdentifier, KeyHandler> _bindings = {};
  final StreamController<InputKeyEvent> _events =
      StreamController<InputKeyEvent>.broadcast();
  bool _disposed = false;

  /// 当前已注册的按键映射(只读)。
  Map<KeyIdentifier, KeyHandler> get bindings => Map.unmodifiable(_bindings);

  /// 事件广播流(多订阅者)。
  Stream<InputKeyEvent> get events => _events.stream;

  void register(KeyIdentifier id, {KeyCallback? onDown, KeyCallback? onUp}) {
    _bindings[id] = KeyHandler(onDown: onDown, onUp: onUp);
  }

  void unregister(KeyIdentifier id) {
    _bindings.remove(id);
  }

  /// 派发: 按 [InputKeyEvent.state] 调用 onDown/onUp, 并广播给所有订阅者。
  void dispatch(InputKeyEvent event) {
    final handler = _bindings[event.id];
    if (handler != null) {
      switch (event.state) {
        case KeyState.down:
          handler.onDown?.call(event);
        case KeyState.up:
          handler.onUp?.call(event);
      }
    }
    if (!_disposed) {
      _events.add(event);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bindings.clear();
    _events.close();
  }
}
