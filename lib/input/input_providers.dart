import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'input_service.dart';
import 'key_input.dart';

/// 键盘输入层（进程级单例；见 `InputService` 类文档的"状态归属"第 3 条）。
///
/// 业务层依赖 [KeyInput] 这个最小接口，不对着 `InputService.instance` 硬编码；
/// 测试里 `overrideWithValue(keyInputProvider, 假实现)` 即可。
final keyInputProvider = Provider<KeyInput>((ref) => InputService.instance);
