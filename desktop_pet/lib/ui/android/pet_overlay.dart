import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../pet/pet_widget.dart';
import '../../storage/storage_service.dart';

class AndroidPetOverlay extends ConsumerStatefulWidget {
  const AndroidPetOverlay({super.key});

  @override
  ConsumerState<AndroidPetOverlay> createState() => _AndroidOverlayEntryState();
}

class _AndroidOverlayEntryState extends ConsumerState<AndroidPetOverlay> {
  late final MethodChannel _channel;

  @override
  void initState() {
    super.initState();
    _setupSettingsHandler();
  }

  /// 注册 MethodChannel 处理器，接收来自原生层（主窗口）的 settings_updated 通知。
  void _setupSettingsHandler() {
    _channel = const MethodChannel('multi_floating_window_android');
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'settings_updated') {
        if (!mounted) return;
        ref.read(petStateProvider.notifier).refreshSettings();
        _syncLockState();
      }
    });
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
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => notifier.onEvent(Trigger.click),
          onPanStart: (_) {
            notifier.onDragStart();
            notifier.resources.windowController.startDragging().then((_) {
              notifier.onDragEnd();
            });
          },
          child: const PetWidget(),
        )
      ),
    );
  }
}