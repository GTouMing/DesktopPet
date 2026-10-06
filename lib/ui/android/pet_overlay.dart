import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_floating_window/pet_floating_window.dart';
import '../../core/constants.dart';
import '../../pet/pet_notifier.dart';
import '../../pet/pet_widget.dart';
import '../../pet/pet_providers.dart';
import '../../storage/storage_service.dart';

/// 单只桌宠的系统悬浮窗内容（Android）。
///
/// 该引擎由启动参数指定唯一一只宠物，故用 [petIdProvider] 定位它。
/// Windows 没有对应组件：那里所有桌宠同处一个悬浮窗场景，见 `lib/pet/pet_view.dart`。
class AndroidPetOverlay extends ConsumerStatefulWidget {
  const AndroidPetOverlay({super.key});

  @override
  ConsumerState<AndroidPetOverlay> createState() => _AndroidOverlayEntryState();
}

class _AndroidOverlayEntryState extends ConsumerState<AndroidPetOverlay>
    with WidgetsBindingObserver {
  late final String _petId = ref.read(petIdProvider);

  PetNotifier get _notifier => ref.read(petStateProvider(_petId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupSettingsHandler();
  }

  /// 注册 MethodChannel 处理器，接收来自原生层（主窗口）的 settings_updated 通知。
  ///
  /// 只把"存储变了"转成 [StorageService.changes] 这一个信号——缩放/不透明度的
  /// 重算由 [PetWidget] 监听 `appDataProvider` 完成，与 Windows 完全同一条路径。
  void _setupSettingsHandler() {
    const channel = MethodChannel(PetFloatingWindow.channelName);
    channel.setMethodCallHandler((call) async {
      if (call.method == PetFloatingWindow.settingsUpdatedEvent) {
        if (!mounted) return;
        StorageService.notifySettingsChanged();
      }
    });
  }

  @override
  void didChangeMetrics() {
    // Android 横竖屏切换时刷新屏幕尺寸缓存
    _notifier.refreshScreenSize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 设置变更 → 重算本宠的派生值（与 Windows 的 PetView 同一套）。
    //
    // 原生推来的 `settings_updated` 只负责把它转成 `StorageService.changes` 这一个
    // 信号（见 [_setupSettingsHandler]），真正的刷新在这里统一发生。
    ref.listen(appDataProvider, (_, _) => _notifier.refreshSettings());

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _notifier.onEvent(Trigger.click),
          // Android 的拖拽交给原生：系统移动整个悬浮窗，松手后回读位置。
          onPanStart: (_) => _notifier.startWindowDrag(),
          child: PetWidget(petId: _petId),
        ),
      ),
    );
  }
}
