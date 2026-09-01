import 'dart:io';

import 'package:desktop_pet/storage/models/app_shortcut.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../skin/import/skin_repository.dart';
import '../../skin/skin_lister.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/settings_model.dart';
import '../widgets/info_overlay.dart';
import 'hotkey_picker_dialog.dart';
import 'shortcut_edit_dialog.dart';
import 'skin_picker_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _localOpacity = 1.0;
  double _localScale = 1.0;
  double _localSpeed = 1.0;
  String _localQuickLaunchKey = '';
  List<String> _localQuickLaunchMods = [];

  @override
  void initState() {
    super.initState();
    final settings = StorageService.readSettings();
    _localOpacity = settings.baseOpacity;
    _localScale = settings.baseScale;
    _localSpeed = settings.baseSpeed;
    _localQuickLaunchKey = settings.quickLaunchKey;
    _localQuickLaunchMods = List.from(settings.quickLaunchModifiers);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appDataProvider).global;

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        children: [
          const _SectionHeader(title: '外观'),
          _OpacityTile(
              opacity: _localOpacity,
              onChanged: (v) => setState(() => _localOpacity = v),
              onChangeEnd: (v) {
                settings.baseOpacity = v;
                StorageService.writeSettings(settings);
                ref.invalidate(appDataProvider);
              }),
          _ScaleTile(
              scale: _localScale,
              onChanged: (v) => setState(() => _localScale = v),
              onChangeEnd: (v) {
                if (v > maxFinalScale) {
                  setState(() => _localScale = settings.baseScale);
                  InfoOverlay.show(context,
                      title: '全局缩放不能超过 ${maxFinalScale.toStringAsFixed(1)}x');
                  return;
                }
                settings.baseScale = v;
                StorageService.writeSettings(settings);
                ref.invalidate(appDataProvider);
              }),
          _SpeedTile(
              speed: _localSpeed,
              onChanged: (v) => setState(() => _localSpeed = v),
              onChangeEnd: (v) {
                settings.baseSpeed = v;
                StorageService.writeSettings(settings);
                ref.invalidate(appDataProvider);
              }),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider()),
          const _SectionHeader(title: '皮肤'),
          _SkinPathTile(
            currentSkinDir: settings.skinDir,
            onChanged: (v) => _onSkinDirChanged(settings, settings.skinDir, v),
            onListSkins: () => _openSkinPicker(),
          ),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider()),
          const _SectionHeader(title: '快捷键'),
          _QuickLaunchHotkeyTile(
            keyName: _localQuickLaunchKey,
            modifiers: _localQuickLaunchMods,
            onChanged: (key, mods) {
              setState(() {
                _localQuickLaunchKey = key;
                _localQuickLaunchMods = mods;
              });
              settings.quickLaunchKey = key;
              settings.quickLaunchModifiers = mods;
              StorageService.writeSettings(settings);
              ref.invalidate(appDataProvider);
            },
          ),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider()),
          const _SectionHeader(title: '快捷启动应用'),
          _ShortcutListSection(
            onChanged: () => ref.invalidate(appDataProvider),
          ),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider()),
          const _SectionHeader(title: '关于'),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: ListTile(
              leading: const Icon(Icons.pets),
              title: const Text('Desktop Pet'),
              subtitle: Text(
                  'v1.0.0 — ${Platform.isAndroid ? 'Android' : 'Windows'}'),
            ),
          ),
        ],
      ),
    );
  }

  // ── 皮肤路径管理 ──────────────────────────────────────────────────────

  void _onSkinDirChanged(
      SettingsModel settings, String? oldDir, String? newDir) {
    final wasDefault = SkinLister.isDefaultPath(oldDir);
    final nowCustom = !SkinLister.isDefaultPath(newDir);

    if (wasDefault && nowCustom && newDir != null) {
      _migrateSkins(newDir);
    }

    settings.skinDir = newDir;
    StorageService.writeSettings(settings);
    ref.invalidate(appDataProvider);
  }

  Future<void> _migrateSkins(String targetDir) async {
    try {
      await SkinRepository().migrateTo(targetDir);
      if (!mounted) return;
      ref.invalidate(appDataProvider);
      InfoOverlay.show(context, title: '已迁移已导入的皮肤包');
    } catch (e) {
      if (!mounted) return;
      InfoOverlay.show(
          context, title: '迁移皮肤包失败', message: '$e');
    }
  }

  void _openSkinPicker() {
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SkinPickerScreen()),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  快捷键选择
// ═══════════════════════════════════════════════════════════════════════════

class _QuickLaunchHotkeyTile extends StatelessWidget {
  final String keyName;
  final List<String> modifiers;
  final void Function(String key, List<String> mods) onChanged;

  const _QuickLaunchHotkeyTile({
    required this.keyName,
    required this.modifiers,
    required this.onChanged,
  });

  String get _display {
    if (keyName.isEmpty) return '禁用';
    final parts = [...modifiers, keyName.toUpperCase()];
    return parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.keyboard),
      title: const Text('快捷启动'),
      subtitle: Text(_display),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            tooltip: '设置快捷键',
            onPressed: () => _pickHotkey(context),
          ),
          if (keyName.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: '禁用',
              onPressed: () => onChanged('', []),
            ),
        ],
      ),
    );
  }

  void _pickHotkey(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => HotkeyPickerDialog(
        initialKey: keyName,
        initialMods: modifiers,
        onConfirm: onChanged,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  快捷启动应用列表
// ═══════════════════════════════════════════════════════════════════════════

class _ShortcutListSection extends StatefulWidget {
  final VoidCallback onChanged;
  const _ShortcutListSection({required this.onChanged});

  @override
  State<_ShortcutListSection> createState() => _ShortcutListSectionState();
}

class _ShortcutListSectionState extends State<_ShortcutListSection> {
  List<AppShortcut> _shortcuts = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final all = StorageService.readShortcuts();
    all.sort((a, b) => a.order.compareTo(b.order));
    _shortcuts = all;
  }

  void _add() async {
    final result = await showDialog<AppShortcut>(
      context: context,
      builder: (_) => const ShortcutEditDialog(),
    );
    if (result == null) return;
    final shortcuts = StorageService.readShortcuts();
    final updated = AppShortcut(
      name: result.name,
      executablePath: result.executablePath,
      order: shortcuts.length,
    );
    StorageService.writeShortcuts([...shortcuts, updated]);
    _reload();
    widget.onChanged();
    if (mounted) setState(() {});
  }

  void _edit(int index) async {
    final existing = _shortcuts[index];
    final result = await showDialog<AppShortcut>(
      context: context,
      builder: (_) => ShortcutEditDialog(initial: existing),
    );
    if (result == null) return;
    final shortcuts = StorageService.readShortcuts();
    if (index < shortcuts.length) {
      final updated = AppShortcut(
        name: result.name,
        executablePath: result.executablePath,
        order: existing.order,
      );
      shortcuts[index] = updated;
      StorageService.writeShortcuts(shortcuts);
    }
    _reload();
    widget.onChanged();
    if (mounted) setState(() {});
  }

  void _delete(int index) {
    final shortcuts = StorageService.readShortcuts();
    if (index >= shortcuts.length) return;
    shortcuts.removeAt(index);
    // 重新编号
    for (int i = 0; i < shortcuts.length; i++) {
      shortcuts[i] = AppShortcut(
        name: shortcuts[i].name,
        executablePath: shortcuts[i].executablePath,
        order: i,
      );
    }
    StorageService.writeShortcuts(shortcuts);
    _reload();
    widget.onChanged();
    if (mounted) setState(() {});
  }

  void _reorder(int oldIndex, int newIndex) {
    final shortcuts = StorageService.readShortcuts();
    final item = shortcuts.removeAt(oldIndex);
    shortcuts.insert(newIndex, item);
    for (int i = 0; i < shortcuts.length; i++) {
      shortcuts[i] = AppShortcut(
        name: shortcuts[i].name,
        executablePath: shortcuts[i].executablePath,
        order: i,
      );
    }
    StorageService.writeShortcuts(shortcuts);
    _reload();
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_shortcuts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text('暂无快捷启动应用',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '添加快捷启动',
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
              tooltip: '添加快捷启动',
              onPressed: _add,
            ),
          ],
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _shortcuts.length,
          onReorderItem: (oldIndex, newIndex) => _reorder(oldIndex, newIndex),
          itemBuilder: (context, index) {
            final s = _shortcuts[index];
            return ListTile(
              key: ValueKey(s.executablePath + s.name),
              leading: const Icon(Icons.launch, size: 18),
              title: Text(s.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.executablePath,
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

// ═══════════════════════════════════════════════════════════════════════════
//  通用子组件
// ═══════════════════════════════════════════════════════════════════════════

class _OpacityTile extends StatelessWidget {
  final double opacity;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  const _OpacityTile(
      {required this.opacity,
      required this.onChanged,
      required this.onChangeEnd});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.opacity),
      title: Text('全局透明度 — ${(opacity * 100).round()}%'),
      subtitle: Slider(
        value: opacity,
        min: 0.2,
        max: 1.0,
        divisions: 8,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

class _ScaleTile extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  const _ScaleTile(
      {required this.scale,
      required this.onChanged,
      required this.onChangeEnd});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.zoom_in),
      title: Text('全局缩放 — ${scale.toStringAsFixed(1)}x'),
      subtitle: Slider(
        value: scale,
        min: 0.3,
        max: 3.0,
        divisions: 27,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

class _SpeedTile extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  const _SpeedTile(
      {required this.speed,
      required this.onChanged,
      required this.onChangeEnd});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.speed),
      title: Text('全局速度 — ${speed.toStringAsFixed(1)}x'),
      subtitle: Slider(
        value: speed,
        min: 0.25,
        max: 3.0,
        divisions: 11,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

class _SkinPathTile extends StatelessWidget {
  final String? currentSkinDir;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onListSkins;
  const _SkinPathTile({
    required this.currentSkinDir,
    required this.onChanged,
    this.onListSkins,
  });

  @override
  Widget build(BuildContext context) {
    final isDefault = SkinLister.isDefaultPath(currentSkinDir);
    return ListTile(
      leading: Icon(
        isDefault ? Icons.auto_awesome : Icons.folder_open,
        color: isDefault ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(isDefault ? '皮肤目录 (默认路径)' : '皮肤目录'),
      subtitle: Text(
        isDefault ? 'assets/default_skin（内置）' : currentSkinDir!,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentSkinDir != null && !isDefault)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: '恢复默认',
              onPressed: () => onChanged(null),
            ),
          IconButton(
            icon: const Icon(Icons.list, size: 18),
            tooltip: '查看可用皮肤',
            onPressed: onListSkins,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open, size: 18),
            tooltip: '浏览目录',
            onPressed: () async {
              final result = await FilePicker.getDirectoryPath();
              if (result != null) onChanged(result);
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
