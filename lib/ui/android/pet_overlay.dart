import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../pet/pet_notifier.dart';
import '../../pet/pet_widget.dart';
import '../widgets/quick_launch_overlay.dart';

class AndroidPetOverlay extends ConsumerStatefulWidget {
  const AndroidPetOverlay({super.key});

  @override
  ConsumerState<AndroidPetOverlay> createState() => _AndroidOverlayEntryState();
}

class _AndroidOverlayEntryState extends ConsumerState<AndroidPetOverlay>
    with WidgetsBindingObserver {
  PetNotifier? notifier;

  @override
  void initState() {
    super.initState();
    notifier = ref.read(petStateProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _setupSettingsHandler();
  }

  /// 注册 MethodChannel 处理器，接收来自原生层（主窗口）的 settings_updated 通知。
  void _setupSettingsHandler() {
    final channel = const MethodChannel('multi_floating_window_android');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'settings_updated') {
        if (!mounted) return;
        notifier?.refreshSettings();
      }
    });
  }

  @override
  void didChangeMetrics() {
    // Android 横竖屏切换时刷新屏幕尺寸缓存
    ref.read(petStateProvider.notifier).refreshScreenSize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => notifier?.onEvent(Trigger.click),
          onPanStart: (_) {
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