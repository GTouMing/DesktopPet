import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../storage/models/app_shortcut.dart';
import '../../../storage/models/settings_model.dart';
import '../../../storage/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/icon_plate.dart';
import '../../widgets/keycap_row.dart';
import '../../widgets/section_panel.dart';
import '../hotkey_picker_dialog.dart';
import '../shortcut_edit_dialog.dart';
import 'settings_common.dart';

/// 快捷启动分区（仅 Windows）。
///
/// 全局输入是桌面端独有能力：Android 既没有全局热键也没有鼠标中键，所以整段只在
/// Windows 下由 [SettingsScreen] 拼进来（见那里的说明）。
class ShortcutSection extends StatelessWidget {
  const ShortcutSection({super.key, required this.settings});

  final SettingsModel settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HotkeyPanel(settings: settings),
        const SizedBox(height: Insets.xl),
        const _QuickLaunchPanel(),
      ],
    );
  }
}

/// 全局快捷键：当前组合键以键帽呈现，可编辑或清除。
class _HotkeyPanel extends StatelessWidget {
  const _HotkeyPanel({required this.settings});

  final SettingsModel settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final keyName = settings.quickLaunchKey;

    return SectionPanel(
      label: l10n.sectionShortcut,
      child: ListTile(
        leading: const IconPlate(icon: Icons.keyboard_rounded),
        title: Text(l10n.quickLaunchTitle),
        subtitle: KeycapRow(
          keys: keyName.isEmpty
              ? const []
              : [...settings.quickLaunchModifiers, keyName],
          placeholder: l10n.disable,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18),
              tooltip: l10n.setShortcut,
              onPressed: () => showDialog(
                context: context,
                builder: (_) => HotkeyPickerDialog(
                  initialKey: keyName,
                  initialMods: settings.quickLaunchModifiers,
                  onConfirm: (key, mods) => applySettings(
                    (s) => s.copyWith(
                      quickLaunchKey: key,
                      quickLaunchModifiers: mods,
                    ),
                  ),
                ),
              ),
            ),
            if (keyName.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: scheme.onSurfaceVariant,
                tooltip: l10n.disable,
                onPressed: () => applySettings(
                  (s) => s.copyWith(
                    quickLaunchKey: '',
                    quickLaunchModifiers: const [],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 快捷启动应用列表：增删改 + 拖拽排序。
class _QuickLaunchPanel extends StatefulWidget {
  const _QuickLaunchPanel();

  @override
  State<_QuickLaunchPanel> createState() => _QuickLaunchPanelState();
}

class _QuickLaunchPanelState extends State<_QuickLaunchPanel> {
  List<AppShortcut> _shortcuts = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _shortcuts = StorageService.readShortcuts()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SectionPanel(
      label: l10n.sectionQuickLaunch,
      child: Column(
        children: [
          if (_shortcuts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.lg, Insets.lg, Insets.lg, Insets.md),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(l10n.noShortcuts,
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              itemCount: _shortcuts.length,
              onReorderItem: _reorder,
              itemBuilder: (context, index) =>
                  _shortcutTile(context, index, _shortcuts[index]),
            ),
          const Divider(height: 1),
          ListTile(
            leading:
                const IconPlate(icon: Icons.add_rounded, tone: PlateTone.accent),
            title: Text(
              l10n.addShortcut,
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
            ),
            onTap: _add,
          ),
        ],
      ),
    );
  }

  Widget _shortcutTile(BuildContext context, int index, AppShortcut shortcut) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: ValueKey(shortcut.executablePath + shortcut.name),
      leading: const IconPlate(icon: Icons.launch_rounded),
      title: Text(shortcut.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        shortcut.executablePath,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            tooltip: l10n.editShortcutTitle,
            onPressed: () => _edit(index),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: scheme.onSurfaceVariant,
            tooltip: l10n.delete,
            onPressed: () => _delete(index),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
              child: Icon(
                Icons.drag_handle_rounded,
                size: 18,
                color: scheme.outline,
              ),
            ),
          ),
        ],
      ),
      onTap: () => _edit(index),
    );
  }

  Future<void> _add() async {
    final result = await showDialog<AppShortcut>(
      context: context,
      builder: (_) => const ShortcutEditDialog(),
    );
    if (result == null) return;
    final shortcuts = StorageService.readShortcuts();
    StorageService.writeShortcuts([
      ...shortcuts,
      AppShortcut(
        name: result.name,
        executablePath: result.executablePath,
        order: shortcuts.length,
      ),
    ]);
    _afterWrite();
  }

  Future<void> _edit(int index) async {
    final existing = _shortcuts[index];
    final result = await showDialog<AppShortcut>(
      context: context,
      builder: (_) => ShortcutEditDialog(initial: existing),
    );
    if (result == null) return;

    final shortcuts = StorageService.readShortcuts();
    final at = shortcuts.indexWhere((s) =>
        s.name == existing.name && s.executablePath == existing.executablePath);
    if (at >= 0) {
      shortcuts[at] = AppShortcut(
        name: result.name,
        executablePath: result.executablePath,
        order: existing.order,
      );
      StorageService.writeShortcuts(shortcuts);
    }
    _afterWrite();
  }

  void _delete(int index) {
    final shortcuts = StorageService.readShortcuts();
    if (index >= shortcuts.length) return;
    shortcuts.removeAt(index);
    StorageService.writeShortcuts(AppShortcut.reindexed(shortcuts));
    _afterWrite();
  }

  void _reorder(int oldIndex, int newIndex) {
    final shortcuts = StorageService.readShortcuts();
    shortcuts.insert(newIndex, shortcuts.removeAt(oldIndex));
    StorageService.writeShortcuts(AppShortcut.reindexed(shortcuts));
    _afterWrite();
  }

  /// 列表改动后：重读并重建。
  void _afterWrite() {
    _reload();
    if (mounted) setState(() {});
  }
}
