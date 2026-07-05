import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:styled_widget/styled_widget.dart';

import '../../core/constants.dart';
import '../../skin/import/skin_repository.dart';
import '../../skin/skin_lister.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import '../../storage/models/settings_model.dart';
import '../widgets/pet_list_tile.dart';
import '../widgets/skin_picker_screen.dart';
import 'pet_edit_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 本地滑块状态，避免拖动时频繁写 MMKV
  double _localOpacity = 1.0;
  double _localScale = 1.0;
  double _localSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 每次打开设置页从 MMKV 读取初始值
    final settings = StorageService.readSettings();
    _localOpacity = settings.baseOpacity;
    _localScale = settings.baseScale;
    _localSpeed = settings.baseSpeed;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全局设置'),
            Tab(text: '桌宠设置'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGlobalSettings(theme,
              ref.watch(appDataProvider).global),
          _buildPetSettings(theme,
              ref.watch(appDataProvider).pets),
        ],
      ),
    );
  }

  Widget _buildGlobalSettings(ThemeData theme, SettingsModel settings) {
    return ListView(
      children: [
        const _SectionHeader(title: '外观'),
        _OpacityTile(
            opacity: _localOpacity,
            onChanged: (v) {
              setState(() => _localOpacity = v);
            },
            onChangeEnd: (v) {
              settings.baseOpacity = v;
              StorageService.writeSettings(settings);
              ref.invalidate(appDataProvider);
            }),
        _ScaleTile(
            scale: _localScale,
            onChanged: (v) {
              setState(() => _localScale = v);
            },
            onChangeEnd: (v) {
              if (v > maxFinalScale) {
                setState(() => _localScale = settings.baseScale);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('全局缩放不能超过 ${maxFinalScale.toStringAsFixed(1)}x'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              settings.baseScale = v;
              StorageService.writeSettings(settings);
              ref.invalidate(appDataProvider);
            }),
        _SpeedTile(
            speed: _localSpeed,
            onChanged: (v) {
              setState(() => _localSpeed = v);
            },
            onChangeEnd: (v) {
              settings.baseSpeed = v;
              StorageService.writeSettings(settings);
              ref.invalidate(appDataProvider);
            }),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(),
        ),
        const _SectionHeader(title: '皮肤'),
        _SkinPathTile(
            currentSkinDir: settings.skinDir,
            onChanged: (v) => _onSkinDirChanged(settings, settings.skinDir, v),
            onListSkins: () => _openSkinPicker(),
            ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(),
        ),
        const _SectionHeader(title: '关于'),
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: const ListTile(
            leading: Icon(Icons.pets),
            title: Text('Desktop Pet'),
            subtitle: Text('v1.0.0 — Windows & Android'),
          ),
        ),
      ],
    );
  }

  Widget _buildPetSettings(ThemeData theme, List<PetConfig> pets) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.pets, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '我的桌宠 (${pets.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (pets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Center(child: Icon(Icons.pets, size: 64, color: Colors.grey)),
                const SizedBox(height: 8),
                Center(child: Text('还没有添加桌宠').fontSize(16).textColor(Colors.grey)),
                const SizedBox(height: 4),
                Center(child: Text('点击下方按钮添加').fontSize(14).textColor(Colors.grey)),
              ],
            ),
          )
        else
          ...pets.map((pet) => PetListTile(
                pet: pet,
                onTap: () => _navigateToEditPage(pet),
                onToggleLocked: () => _togglePetLocked(pets, pet),
                onToggleVisible: () => _togglePetVisible(pets, pet),
                onDelete: () => _showDeleteConfirmation(pets, pet),
              )),
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          child: Center(
            child: FilledButton.icon(
              onPressed: () => _createNewPet(),
              icon: const Icon(Icons.add),
              label: const Text('添加桌宠'),
            ),
          ),
        ),
      ],
    );
  }

  // ── 宠物操作（直接读写 MMKV） ────────────────────────────────────────────

  void _togglePetLocked(List<PetConfig> pets, PetConfig pet) {
    final copy = [...pets]; // shallow copy the provider list
    final idx = copy.indexWhere((p) => p.id == pet.id);
    if (idx < 0) return;
    copy[idx] = pet.copyWith(isLocked: !pet.isLocked);
    StorageService.writePets(copy);
    ref.invalidate(appDataProvider);
  }

  void _togglePetVisible(List<PetConfig> pets, PetConfig pet) {
    final copy = [...pets];
    final idx = copy.indexWhere((p) => p.id == pet.id);
    if (idx < 0) return;
    copy[idx] = pet.copyWith(isVisible: !pet.isVisible);
    StorageService.writePets(copy);
    ref.invalidate(appDataProvider);
  }

  Future<void> _createNewPet() async {
    final newPet = PetConfig(
      id: '',
      name: '',
      scaleMultiplier: 1.0,
      opacityMultiplier: 1.0,
      isLocked: true,
      isVisible: true,
    );

    final result = await Navigator.push<PetConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => PetEditScreen(
          pet: newPet,
          isNewPet: true,
        ),
      ),
    );

    if (!mounted || result == null) return;

    // 写入 MMKV 并刷新 UI
    StorageService.addPet(result);
    ref.invalidate(appDataProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('桌宠添加成功'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _navigateToEditPage(PetConfig pet) async {
    final updatedPet = await Navigator.push<PetConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => PetEditScreen(
          pet: pet,
          isNewPet: false,
        ),
      ),
    );

    if (!mounted || updatedPet == null) return;

    StorageService.writePet(updatedPet);
    ref.invalidate(appDataProvider);
  }

  void _showDeleteConfirmation(List<PetConfig> pets, PetConfig pet) {
    if (pets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('至少需要保留一个桌宠'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除桌宠'),
        content: Text(
            '确定要删除「${pet.name}」吗？\n\n缩放: ${(pet.snappedScaleMultiplier * 100).round()}%\n透明度: ${(pet.snappedOpacityMultiplier * 100).round()}%\n速度: ${pet.snappedSpeedMultiplier.toStringAsFixed(1)}x'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (!mounted || confirmed != true) return;
      StorageService.removePet(pet.id);
      ref.invalidate(appDataProvider);
    });
  }

  // ── 皮肤路径管理 ──────────────────────────────────────────────────────

  void _onSkinDirChanged(SettingsModel settings, String? oldDir, String? newDir) {
    final wasDefault = SkinLister.isDefaultPath(oldDir);
    final nowCustom = !SkinLister.isDefaultPath(newDir);

    // 从默认切换到自定路径 → 迁移已导入皮肤
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已迁移已导入的皮肤包'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('迁移皮肤包失败: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSkinPicker() {
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SkinPickerScreen()),
    );
  }
}

// ── 子组件 ─────────────────────────────────────────────────────────────────

class _OpacityTile extends StatelessWidget {
  final double opacity;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  const _OpacityTile({required this.opacity, required this.onChanged, required this.onChangeEnd});

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
  const _ScaleTile({required this.scale, required this.onChanged, required this.onChangeEnd});

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
  const _SpeedTile({required this.speed, required this.onChanged, required this.onChangeEnd});

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
              final result = await FilePicker.platform.getDirectoryPath();
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