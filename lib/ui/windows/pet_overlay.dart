import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../pet/pet_widget.dart';
import '../../storage/storage_service.dart';

class WindowsPetOverlay extends ConsumerStatefulWidget {
  const WindowsPetOverlay({super.key});

  @override
  ConsumerState<WindowsPetOverlay> createState() => _PetOverlayContainerState();
}

class _PetOverlayContainerState extends ConsumerState<WindowsPetOverlay> {
  @override
  void initState() {
    super.initState();
    _setupDmwHandler();
  }

  /// 注册 desktop_multi_window 跨引擎通信处理器。
  ///
  /// 主窗口写入 MMKV 后通过 [PetWindowChannel] 推送消息，
  /// 处理器收到后立即刷新对应设置，实现即时响应。
  void _setupDmwHandler() {
    dmw.WindowController.fromCurrentEngine().then((ctrl) {
      ctrl.setWindowMethodHandler((call) async {
        if (call.method == 'settings_updated') {
          ref.read(petStateProvider.notifier).refreshSettings();
          _syncLockState();
        } else if (call.method == 'lock_updated') {
          _syncLockState();
        }
      });
    }).catchError((_) {});
  }

  /// 从 MMKV 读取当前桌宠的锁定状态，同步到窗口控制器。
  void _syncLockState() {
    final petId = ref.read(petIdProvider);
    final pet = StorageService.readPet(petId);
    if (pet == null) return;
    ref.read(petStateProvider.notifier).onLock(pet.isLocked);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(petStateProvider.notifier);
    return ExcludeSemantics(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => notifier.onEvent(Trigger.click),
          onPanStart: (details) {
            notifier.onDragStart();
            notifier.resources.windowController.startDragging().then((_) {
              notifier.onDragEnd();
            });
          },
          child: const PetWidget(),
        ),
      ),
    );
  }
}