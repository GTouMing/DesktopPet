import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_service.dart';
import 'pet_providers.dart';
import 'pet_widget.dart';

/// 悬浮窗场景里的**一只**桌宠。
///
/// 单引擎改造后桌宠不再是独立窗口，这里只是 [Stack] 里一个按
/// [PetState.position] 摆放的条目。位置/尺寸来自状态本身。
///
/// **它不吃指针事件**，也不需要 `GestureDetector`：悬浮窗整窗穿透、收不到鼠标
/// 消息，点击与拖拽由进程级钩子经由 `PetPointerRouter` 驱动
/// （见 lib/pet/pet_pointer_router.dart）。
///
/// 必须是 [Stack] 的直接子节点：本组件返回 [Positioned]。
class PetView extends ConsumerWidget {
  const PetView({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petState = ref.watch(petStateProvider(petId));
    final notifier = ref.read(petStateProvider(petId).notifier);
    final size = petState.finalPetSize;

    // 设置变更（缩放/不透明度）后让本宠重算派生值。
    //
    // 与 Android 同一套：设置写入 → `StorageService.changes` → `appDataProvider`
    // 自失效 → 这里刷新（Android 侧对应位置见 `ui/android/pet_overlay.dart`）。
    ref.listen(appDataProvider, (_, _) => notifier.refreshSettings());

    // 始终返回 Positioned（同一个 widget 类型），只在内部换内容。
    //
    // 尺寸未就绪时不能改返回 SizedBox.shrink()：Positioned 是 ParentDataWidget，
    // 挂载/卸载会走祖先链查找，在这个会增删成员的 Stack 里反复切换会触发
    // "Looking up a deactivated widget's ancestor is unsafe"。
    return Positioned(
      left: petState.position.dx,
      top: petState.position.dy,
      width: size.width,
      height: size.height,
      child: size.isEmpty ? const SizedBox.shrink() : PetWidget(petId: petId),
    );
  }
}
