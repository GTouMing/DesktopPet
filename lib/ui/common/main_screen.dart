import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_factory.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import '../theme/app_theme.dart';
import '../widgets/info_overlay.dart';
import '../widgets/pet_list.dart';
import 'pet_edit_screen.dart';
import 'pet_launcher.dart';
import 'settings/settings_screen.dart';

/// 主界面/设置窗口 UI(Android = 主 Activity;Windows = 设置窗口内容)。
///
/// 布局是"饲养台"：顶部身份与操作、中间一眼可读的状态条、下方住客清单。
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ConsoleHeader(
              petCount: petList.length,
              onOpenSettings: _openSettings,
              onAddPet: _createNewPet,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.lg, 0, Insets.lg, Insets.lg),
              child: _VitalsStrip(pets: petList),
            ),
            Expanded(
              child: PetList(
                pets: petList,
                onTap: _navigateToEditPage,
                onAdd: _createNewPet,
              ),
            ),
          ],
        ),
      ),
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

/// 顶部身份区：徽记 + 住客计数 + 全局操作。
class _ConsoleHeader extends StatelessWidget {
  const _ConsoleHeader({
    required this.petCount,
    required this.onOpenSettings,
    required this.onAddPet,
  });

  /// 行内布局里不随文字缩放的部分：徽记 46 + 两处间距 12/8、设置按钮 48、
  /// 添加按钮的内边距与图标 74。不含左右各 16 的内边距——`LayoutBuilder`
  /// 量到的已经是扣掉内边距之后的宽度。
  static const double _fixedWidth = 196;

  /// 随文字缩放的部分：标题「My pets (0)」约 118px + 主操作文字（实测 "Add pet"
  /// 约 102px，中文「添加桌宠」更窄，取宽的那一支兜底）。
  ///
  /// 这个估值必须够宽：标题是 `Expanded`，估窄了它会去当缓冲、被压成两行再截断。
  static const double _scaledWidth = 220;

  final int petCount;
  final VoidCallback onOpenSettings;
  final VoidCallback onAddPet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final fits =
              _fixedWidth + scale * _scaledWidth <= constraints.maxWidth;

          final title = Text(
            l10n.myPets(petCount),
            style: theme.textTheme.headlineSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );

          final settingsButton = IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: l10n.settings,
            onPressed: onOpenSettings,
          );

          // 主操作带文字标签：只有一个「+」时，用户得靠猜才知道它是"添加桌宠"。
          // 用 FilledButton 而不是 IconButton.filled，前景色由 M3 自己按蜜色填充
          // 解析为 onPrimary（5.53:1），不再受图标按钮主题影响。
          final addButton = FilledButton.icon(
            onPressed: onAddPet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              l10n.addPet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

          // 放不下时让出徽记、把操作换到第二行，主操作占满剩余宽度。
          // 宁可多占一行，也不把标题或按钮压到截断。
          if (!fits) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: Insets.md),
                Row(
                  children: [
                    settingsButton,
                    const SizedBox(width: Insets.sm),
                    Expanded(child: addButton),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(Radii.control + 3),
                ),
                child: Icon(
                  Icons.pets_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(child: title),
              const SizedBox(width: Insets.sm),
              settingsButton,
              const SizedBox(width: Insets.sm),
              addButton,
            ],
          );
        },
      ),
    );
  }
}

/// 状态条：显示 / 隐藏 / 锁定 三项计数，一眼看清整群桌宠的状态。
///
/// 每列放不下时改为纵向堆叠。判据是**按文字缩放折算后的每列宽度**——窗口变窄和
/// 文字放大会同时压窄列宽，只按窗口宽度判断就会在 200% 文字下把「Hidden / Locked」
/// 截成「Hidd… / Lock…」。宁可多占两行，也不截断。
class _VitalsStrip extends StatelessWidget {
  const _VitalsStrip({required this.pets});

  /// 最长标签（Locked）在 11px 下的宽度。
  static const double _labelBaseWidth = 58;
  static const double _separatorWidth = 1;
  static const double _columnPadding = Insets.md * 2;

  final List<PetConfig> pets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final visible = pets.where((p) => p.isVisible).length;
    final locked = pets.where((p) => p.isLocked).length;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.xs, vertical: Insets.md + 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.panel),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final perColumn =
              (constraints.maxWidth - 2 * _separatorWidth) / 3;
          final inline = perColumn >= _columnPadding + scale * _labelBaseWidth;

          final vitals = <Widget>[
            _Vital(
              icon: Icons.visibility_rounded,
              label: l10n.shown,
              value: visible,
              accent: context.appColors.positive,
              inline: inline,
            ),
            _Vital(
              icon: Icons.visibility_off_rounded,
              label: l10n.hidden,
              value: pets.length - visible,
              accent: scheme.onSurfaceVariant,
              inline: inline,
            ),
            _Vital(
              icon: Icons.lock_rounded,
              label: l10n.locked,
              value: locked,
              accent: scheme.primary,
              inline: inline,
            ),
          ];

          if (inline) {
            return Row(
              children: [
                for (var i = 0; i < vitals.length; i++) ...[
                  if (i > 0) _separator(scheme),
                  Expanded(child: vitals[i]),
                ],
              ],
            );
          }
          return Column(
            children: [
              for (var i = 0; i < vitals.length; i++) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                vitals[i],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _separator(ColorScheme scheme) => Container(
        width: _separatorWidth,
        height: 34,
        color: scheme.outlineVariant,
      );
}

class _Vital extends StatelessWidget {
  const _Vital({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.inline,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;

  /// 三列横排时为 false（图标+数值在上、标签在下）；
  /// 纵向堆叠时为 true（图标+数值+标签同一行）。
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final reading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$value',
            style: theme.textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final labelText = Text(
      label,
      style: theme.textTheme.labelSmall,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    if (inline) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Row(
          children: [
            reading,
            const SizedBox(width: Insets.md),
            Expanded(child: labelText),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          reading,
          const SizedBox(height: 2),
          labelText,
        ],
      ),
    );
  }
}
