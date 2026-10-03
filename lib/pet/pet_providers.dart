import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../input/input_providers.dart';
import 'pet_notifier.dart';
import 'pet_state.dart';

/// 桌宠相关的 Provider。
///
/// 放在 `pet/` 而不是 `core/`：`petStateProvider` 要构造 [PetNotifier]，留在 core
/// 会让 core 反向依赖 pet。core 只放"被各方依赖的叶子件"（常量、纯数据、通道名）。

/// 当前引擎所承载的桌宠 id（Android 单宠引擎由启动参数覆写）。
final petIdProvider = Provider<String>((ref) => '');

/// 单只桌宠的状态管理器，按宠物 id 分键。
///
/// Windows 单引擎下同一个 isolate 里同时存在 N 个实例（每只桌宠一个：各自的状态
/// 机、行为定时器、动画）；Android 每个悬浮窗引擎里只有一个。
///
/// autoDispose：宠物被删除或隐藏后，场景不再渲染它，对应的 notifier 随之释放，
/// 行为定时器与动画 controller 一并停掉。
final petStateProvider =
    StateNotifierProvider.autoDispose.family<PetNotifier, PetState, String>(
  (ref, petId) =>
      PetNotifier(petId, keyInput: ref.read(keyInputProvider)),
);
