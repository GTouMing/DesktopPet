import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_factory.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import '../widgets/pet_list.dart';
import '../widgets/info_overlay.dart';
import 'pet_edit_screen.dart';
import 'pet_launcher.dart';
import 'settings/settings_screen.dart';

/// 主界面/设置窗口 UI(Android = 主 Activity;Windows = 设置窗口内容)。
///
/// 注意: Windows 下该 Widget 运行在**设置窗口引擎**里，与绘制桌宠的悬浮窗引擎
/// 是两个引擎；它只负责 UI 与存储写入，悬浮窗会收到"存储已改"通知后重读
/// (见 ui/host/overlay_scene.dart)。
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Android: 主界面启动即拉起桌宠悬浮窗(与既有行为一致)。
    // Windows: 无需处理——桌宠本来就在悬浮窗场景里,随存储变化自动出现。
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      Future.microtask(() => loadAllPetWindows().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  /// Android：回到前台时补建此前创建失败的悬浮窗。
  ///
  /// 首次安装时没有任何渠道能建悬浮窗：`requestPermission()` 只是拉起系统设置页并
  /// **立刻返回**，本 Activity 不会重建；那一刻建窗会因为没有"显示在其他应用上层"
  /// 权限而失败（原生 `addView` 抛异常），而当时**没有任何地方会重试**——表现就是
  /// "授予权限后桌宠依然不出现"。
  ///
  /// 回到前台时补一次即可：[loadAllPetWindows] 幂等，只补缺失的那些。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isAndroid) return;
    if (state != AppLifecycleState.resumed) return;
    Future.microtask(() => loadAllPetWindows().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    // 订阅设置变更以触发重建(宿主自身的写操作会 invalidate 它)。
    ref.watch(appDataProvider);

    // 但列表始终直接从存储读取最新值:其它引擎(如桌宠窗口被 Alt+F4 隐藏)
    // 写入的 isVisible 也能反映出来。这样每次打开设置即是最新,无需挂载后再
    // invalidate —— 避免紧接着首帧再来一次整树重建(会引发 accessibility
    // bridge 的 "Nodes left pending by the update")。
    final petList = StorageService.readPets();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.appName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: _openSettings,
          ),
          Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: l10n.addPet,
            onPressed: _createNewPet,
          ),
        ],
      ),
      body: PetList(pets: petList, onTap: _navigateToEditPage),
    );
  }

  Future<void> _createNewPet() async {
    final l10n = AppLocalizations.of(context);
    final ok = await createNewPet(context, onCreated: () {
      final pets = StorageService.readPets();
      if (pets.isEmpty) return;
      // 仅 Android 需要额外拉起悬浮窗(创建引擎较重,放到首帧之后,先让列表刷新
      // 出来,避免卡在弹窗上)。Windows 上桌宠是悬浮窗场景里的条目,
      // spawnPetWindow 直接返回,写存储后场景会自己重建。
      final pet = pets.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        spawnPetWindow(pet);
      });
    });
    if (ok && mounted) {
      InfoOverlay.show(context, title: l10n.petAdded);
    }
  }

  void _navigateToEditPage(PetConfig pet) async {
    final updatedPet = await Navigator.push<PetConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => PetEditScreen(pet: pet, isNewPet: false),
      ),
    );
    if (updatedPet != null && mounted) {
      StorageService.writePet(updatedPet);
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}
