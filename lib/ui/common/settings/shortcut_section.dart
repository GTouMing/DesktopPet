import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../storage/models/app_shortcut.dart';
import '../../../storage/models/settings_model.dart';
import '../../../storage/storage_service.dart';
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
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SectionHeader(title: l10n.sectionShortcut),
        _HotkeyTile(
          keyName: settings.quickLaunchKey,
          modifiers: settings.quickLaunchModifiers,
          onChanged: (key, mods) => applySettings(
            (s) => s.copyWith(
              quickLaunchKey: key,
              quickLaunchModifiers: mods,
            ),
          ),
        ),
        SectionHeader(title: l10n.sectionQuickLaunch),
        const _QuickLaunchList(),
      ],
    );
  }
}

/// 快捷键行：显示当前组合键，可编辑或清除。
class _HotkeyTile extends StatelessWidget {
  const _HotkeyTile({
    required this.keyName,
    required this.modifiers,
    required this.onChanged,
  });

  final String keyName;
  final List<String> modifiers;
  final void Function(String key, List<String> mods) onChanged;

  String _display(AppLocalizations l10n) {
    if (keyName.isEmpty) return l10n.disable;
    return [...modifiers, keyName.toUpperCase()].join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.keyboard),
      title: Text(l10n.quickLaunchTitle),
      subtitle: Text(_display(l10n)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            tooltip: l10n.setShortcut,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => HotkeyPickerDialog(
                initialKey: keyName,
                initialMods: modifiers,
                onConfirm: onChanged,
              ),
            ),
          ),
          if (keyName.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: l10n.disable,
              onPressed: () => onChanged('', []),
            ),
        ],
      ),
    );
  }
}

/// 快捷启动应用列表：增删改 + 拖拽排序。
class _QuickLaunchList extends StatefulWidget {
  const _QuickLaunchList();

  @override
  State<_QuickLaunchList> createState() => _QuickLaunchListState();
}

class _QuickLaunchListState extends State<_QuickLaunchList> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_shortcuts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(l10n.noShortcuts,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: l10n.addShortcut,
              onPressed: _add,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: l10n.addShortcut,
              onPressed: _add,
            ),
          ],
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _shortcuts.length,
          onReorderItem: _reorder,
          itemBuilder: (context, index) {
            final shortcut = _shortcuts[index];
            return ListTile(
              key: ValueKey(shortcut.executablePath + shortcut.name),
              leading: const Icon(Icons.launch, size: 18),
              title: Text(shortcut.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(shortcut.executablePath,
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _edit(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _delete(index),
                  ),
                ],
              ),
              onTap: () => _edit(index),
            );
          },
        ),
      ],
    );
  }
}
