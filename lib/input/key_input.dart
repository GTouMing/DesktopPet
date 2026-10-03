import 'key_event.dart';
import 'key_registry.dart';

/// 按键注册入口（业务层依赖的**最小**接口）。
///
/// [InputService] 是它唯一的实现。抽成接口是为了让 `HotkeyEngine` 这类消费者可以
/// 注入假实现做单测——`InputService` 是必须在 `runApp` 之前就绪的**进程级单例**
/// （见其类文档"状态归属"第 3 条），测试里起不来真实的全局钩子。
abstract interface class KeyInput {
  /// 注册一个按键（具体何时挂载由实现决定，见 [flush]）。
  Future<void> register(KeyIdentifier id,
      {KeyCallback? onDown, KeyCallback? onUp});

  /// 注销一个按键。
  Future<void> unregister(KeyIdentifier id);

  /// 等待当前批次的注册/注销生效（同批次合并为一次挂载）。
  Future<void> flush();
}
