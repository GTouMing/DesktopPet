import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_factory.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import '../theme/app_theme.dart';
import 'info_overlay.dart';

/// 桌宠住客磁贴：头像、名称与参数摘要、锁定/显隐切换、删除。
///
/// 状态一律"图标 + 底色"表达，不靠单一颜色；隐藏时名称与头像转为弱化色，
/// 让"没在显示"这件事在一眼扫过时就看得出来。
class PetCard extends ConsumerWidget {
  /// 低于此宽度就把状态开关换到第二行。
  ///
  /// 挤在一行时名字与宠物包会被截得只剩几个字——窄屏宁可多占一行。
  static const double _stackBelowWidth = 440;

  final PetConfig pet;
  final VoidCallback onTap;

  const PetCard({super.key, required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dimmed = !pet.isVisible;

    return Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.panel),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.primary.withValues(alpha: 0.05),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < _stackBelowWidth;
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.md + 2, Insets.md + 2, Insets.sm, Insets.md + 2),
              child: stacked ? _stacked(context, ref, dimmed) : _inline(context, ref, dimmed),
            );
          },
        ),
      ),
    );
  }

  /// 宽屏：头像 + 信息 + 状态开关同处一行。
  Widget _inline(BuildContext context, WidgetRef ref, bool dimmed) {
    return Row(
      children: [
        _Avatar(dimmed: dimmed),
        const SizedBox(width: Insets.md),
        Expanded(child: _identity(context, dimmed)),
        const SizedBox(width: Insets.sm),
        ..._controls(context, ref),
      ],
    );
  }

  /// 窄屏：状态开关另起一行，信息区拿满整行宽度。
  Widget _stacked(BuildContext context, WidgetRef ref, bool dimmed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Avatar(dimmed: dimmed),
            const SizedBox(width: Insets.md),
            Expanded(child: _identity(context, dimmed)),
          ],
        ),
        const SizedBox(height: Insets.sm + 2),
        Row(
          children: [
            const Spacer(),
            ..._controls(context, ref),
          ],
        ),
      ],
    );
  }

  Widget _identity(BuildContext context, bool dimmed) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pack = pet.packPath.split('/').last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pet.name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: dimmed ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${pet.snappedScaleMultiplier.toStringAsFixed(1)}x'
              ' · '
              '${(pet.snappedOpacityMultiplier * 100).round()}%',
              style: theme.textTheme.bodySmall,
            ),
            if (pet.packPath.isNotEmpty) _PackTag(label: pack),
          ],
        ),
      ],
    );
  }

  /// 锁定 / 显隐 / 删除。
  List<Widget> _controls(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return [
      _StatusToggle(
        icon: Icons.lock_rounded,
        active: pet.isLocked,
        activeBackground: scheme.primaryContainer,
        activeForeground: scheme.onPrimaryContainer,
        tooltip: pet.isLocked ? l10n.locked : l10n.unlocked,
        onPressed: _toggleLock,
      ),
      const SizedBox(width: 6),
      _StatusToggle(
        icon: pet.isVisible
            ? Icons.visibility_rounded
            : Icons.visibility_off_rounded,
        active: pet.isVisible,
        activeBackground: context.appColors.positiveContainer,
        activeForeground: context.appColors.onPositiveContainer,
        tooltip: pet.isVisible ? l10n.shown : l10n.hidden,
        onPressed: _toggleVisible,
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        tooltip: l10n.delete,
        onPressed: () => _delete(context, ref),
        style: IconButton.styleFrom(
          foregroundColor: scheme.outline,
          hoverColor: scheme.errorContainer,
        ),
      ),
    ];
  }

  void _toggleLock() {
    final updated = pet.copyWith(isLocked: !pet.isLocked);
    StorageService.writePet(updated);
  }

  void _toggleVisible() {
    // 以**存储里的当前值**为基准翻转,而不是 widget 上的 `pet`:
    // 后者是上一次重建的快照,重建被拖慢时连续快速点击会反复算出同一个目标值,
    // 于是点 N 次只生效一次、甚至方向相反。
    final current = StorageService.readPet(pet.id);
    if (current == null) return;
    final updated = current.copyWith(isVisible: !current.isVisible);
    StorageService.writePet(updated);
  }

  void _delete(BuildContext context, WidgetRef ref) {
    final pets = ref.read(appDataProvider).pets;
    if (pets.length <= 1) {
      InfoOverlay.show(context,
          title: AppLocalizations.of(context).keepOnePet);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.deletePetTitle),
          content: Text(l10n.deletePetBody(
            pet.name,
            pet.snappedScaleMultiplier.toStringAsFixed(1),
            (pet.snappedOpacityMultiplier * 100).round(),
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                StorageService.removePet(pet.id);
                Navigator.pop(ctx);
                // 仅 Android 需要回收悬浮窗引擎;Windows 上桌宠是悬浮窗场景里的
                // 条目,随存储广播一起消失。
                closePetWindow(pet.id);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }
}

/// 住客头像：隐藏时降为中性底。
class _Avatar extends StatelessWidget {
  const _Avatar({required this.dimmed});

  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: dimmed ? scheme.surfaceContainerHigh : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.control + 2),
      ),
      child: Icon(
        Icons.pets_rounded,
        size: 22,
        color: dimmed ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
      ),
    );
  }
}

/// 宠物包标签。
class _PackTag extends StatelessWidget {
  const _PackTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_rounded, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: Insets.xs),
          // 必须 Flexible：窄屏上标签只分到几十像素，写死的最大宽度挡不住
          // 文本的自然宽度，会直接撑破这一行。
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态开关：44×44 的命中区里放一块 36×36 的底板。
///
/// 底板外留出的 4px 正好用来画焦点环，所以环天然是"离开控件本身"的 offset ring，
/// 不需要额外包一层。命中区 44 达到触控目标下限，视觉仍保持 36。
class _StatusToggle extends StatefulWidget {
  const _StatusToggle({
    required this.icon,
    required this.active,
    required this.activeBackground,
    required this.activeForeground,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool active;
  final Color activeBackground;
  final Color activeForeground;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_StatusToggle> createState() => _StatusToggleState();
}

class _StatusToggleState extends State<_StatusToggle> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Tooltip(
      message: widget.tooltip,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control + 4),
          side: _focusNode.hasFocus
              ? BorderSide(color: colors.focusRing, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          focusNode: _focusNode,
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(Radii.control + 4),
          hoverColor: scheme.onSurface.withValues(alpha: 0.06),
          focusColor: colors.focusRing.withValues(alpha: 0.18),
          onFocusChange: (_) => setState(() {}),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: Motion.fast,
                curve: Curves.easeOut,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.active
                      ? widget.activeBackground
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(
                    color: widget.active
                        ? Colors.transparent
                        : scheme.outlineVariant,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: widget.active
                      ? widget.activeForeground
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
