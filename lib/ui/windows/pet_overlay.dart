import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../pet/pet_notifier.dart';
import '../../pet/pet_widget.dart';
import '../widgets/quick_launch_overlay.dart';

class WindowsPetOverlay extends ConsumerStatefulWidget {
  const WindowsPetOverlay({super.key});

  @override
  ConsumerState<WindowsPetOverlay> createState() => _PetOverlayContainerState();
}

class _PetOverlayContainerState extends ConsumerState<WindowsPetOverlay> {
  PetNotifier? notifier;

  @override
  void initState() {
    super.initState();
    notifier = ref.read(petStateProvider.notifier);
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
          notifier?.refreshSettings();
        }
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    notifier = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => notifier?.onEvent(Trigger.click),
          onPanStart: (details) {
            notifier?.onDragStart();
            notifier?.windowController.startDragging().then((_) {
              notifier?.onDragEnd();
            });
          },
          child: QuickLaunchOverlay(child: const PetWidget()),
        ),
      ),
    );
  }
}