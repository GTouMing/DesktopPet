/// 按键检测模块: 按键身份与事件模型。
library;

/// 输入设备类型。
enum KeyDevice { keyboard, mouse }

/// 触发点: 按下 / 松开。
enum KeyState { down, up }

/// 鼠标键索引(与原生 WH_MOUSE_LL 约定一致)。
enum MouseButton { left, right, middle, x1, x2 }

/// 一个按键身份(注册表 map 的 key)。
///
/// - keyboard: [key] 为规范化键名(小写, 如 `g` / `space` / `f5`),
///   [modifiers] 为小写修饰键名且已排序;
/// - mouse: [key] 为鼠标键名(`left`..`x2`),[modifiers] 恒为空。
class KeyIdentifier {
  final KeyDevice device;
  final String key;
  final List<String> modifiers;

  KeyIdentifier._(this.device, this.key, this.modifiers);

  factory KeyIdentifier.key(String key, {List<String> modifiers = const []}) {
    final normalized = modifiers.map((m) => m.toLowerCase()).toList()..sort();
    return KeyIdentifier._(
      KeyDevice.keyboard,
      key.toLowerCase(),
      List.unmodifiable(normalized),
    );
  }

  factory KeyIdentifier.mouse(MouseButton button) {
    return KeyIdentifier._(KeyDevice.mouse, button.name, const []);
  }

  /// 复合标识: keyboard = `key+mod1+mod2`(排序后); mouse = `mouse:middle`。
  ///
  /// **注意**：它和皮肤侧的 `TransitionRule.compositeKey` **不是同一个字符串**——
  /// 这里 key 在前（`h+alt`），那边连 key 一起排序（`alt+h`）。两边各自内部一致即可
  /// 工作，但**不要**把它们互相比较：皮肤规则与组合键的匹配一律用
  /// `TransitionRule.compositeKey`（见 `SkinPackage.findTransition`），本标识只用于
  /// 输入层自己的映射表（`KeyRegistry`、`WindowsInputSource._byId`）。
  String get composite {
    if (device == KeyDevice.mouse) return 'mouse:$key';
    return [key, ...modifiers].join('+');
  }

  @override
  bool operator ==(Object other) =>
      other is KeyIdentifier && other.composite == composite;

  @override
  int get hashCode => composite.hashCode;

  @override
  String toString() => composite;
}

/// 一次按键事件(down / up)。
///
/// 命名带 `Input` 前缀, 避免与 Flutter `package:flutter/services.dart`
/// 导出的 `KeyEvent` 冲突。
class InputKeyEvent {
  final KeyIdentifier id;
  final KeyState state;

  InputKeyEvent(this.id, this.state);

  @override
  String toString() => 'InputKeyEvent(${id.composite}, ${state.name})';
}
