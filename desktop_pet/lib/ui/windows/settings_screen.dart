import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../skin/import/skin_repository.dart';
import '../../skin/skin_lister.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import '../../storage/models/settings_model.dart';
import '../screens/pet_edit_screen.dart';
import '../widgets/pet_list_tile.dart';
import '../widgets/skin_picker_screen.dart';

class WindowsSettingsScreen extends ConsumerStatefulWidget {
  const WindowsSettingsScreen({super.key});

  @override
  ConsumerState<WindowsSettingsScreen> createState() => _WindowsSettingsScreenState();
}

class _WindowsSettingsScreenState extends ConsumerState<WindowsSettingsScreen> {
  double _localOpacity = 1.0;
  double _localScale = 1.0;
  double _localSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    final settings = StorageService.readSettings();
    _localOpacity = settings.baseOpacity;
    _localScale = settings.baseScale;
    _localSpeed = settings.baseSpeed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Desktop Pet — 设置'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _SectionHeader(title: '外观'),
          const SizedBox(height: 8),
          _OpacityTile(opacity: _localOpacity, onChanged: (v) => setState(() => _localOpacity = v), onChangeEnd: (v) {
            settings.global.baseOpacity = v;
            StorageService.writeSettings(settings.global);
            ref.invalidate(appDataProvider);
          }),
          const SizedBox(height: 4),
          _ScaleTile(scale: _localScale, onChanged: (v) => setState(() => _localScale = v), onChangeEnd: (v) {
            if (v > maxFinalScale) {
              setState(() => _localScale = settings.global.baseScale);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('全局缩放不能超过 ${maxFinalScale.toStringAsFixed(1)}x'), behavior: SnackBarBehavior.floating));
              return;
            }
            settings.global.baseScale = v;
            StorageService.writeSettings(settings.global);
            ref.invalidate(appDataProvider);
          }),
          const SizedBox(height: 4),
          _SpeedTile(speed: _localSpeed, onChanged: (v) => setState(() => _localSpeed = v), onChangeEnd: (v) {
            settings.global.baseSpeed = v;
            StorageService.writeSettings(settings.global);
            ref.invalidate(appDataProvider);
          }),
          const Divider(height: 32),
          _SectionHeader(title: '皮肤'),
          const SizedBox(height: 8),
          _SkinPathTile(currentSkinDir: settings.global.skinDir, onChanged: (v) => _onSkinDirChanged(settings.global, settings.global.skinDir, v), onListSkins: () => _openSkinPicker()),
          const Divider(height: 32),
          _SectionHeader(title: '桌宠'),
          const SizedBox(height: 8),
          if (settings.pets.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('还没有桌宠，点击下方添加', style: TextStyle(color: Colors.grey[500]))))
          else
            ...settings.pets.map((pet) => PetListTile(pet: pet, onTap: () => _navigateToEditPage(pet), onToggleLocked: () => _togglePetLocked(settings.pets, pet), onToggleVisible: () => _togglePetVisible(settings.pets, pet), onDelete: () => _showDeleteConfirmation(settings.pets, pet))),
          const SizedBox(height: 16),
          Center(child: FilledButton.icon(onPressed: () => _createNewPet(), icon: const Icon(Icons.add), label: const Text('添加桌宠'))),
          const Divider(height: 32),
          ListTile(leading: const Icon(Icons.pets), title: const Text('Desktop Pet'), subtitle: const Text('v1.0.0 — Windows')),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _togglePetLocked(List<PetConfig> pets, PetConfig pet) {
    final copy = [...pets];
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
    final newPet = PetConfig(id: '', name: '', scaleMultiplier: 1.0, opacityMultiplier: 1.0, isLocked: true, isVisible: true);
    final result = await Navigator.push<PetConfig>(context, MaterialPageRoute(builder: (_) => PetEditScreen(pet: newPet, isNewPet: true)));
    if (!mounted || result == null) return;
    StorageService.addPet(result);
    ref.invalidate(appDataProvider);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('桌宠添加成功'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)));
  }

  void _navigateToEditPage(PetConfig pet) async {
    final updatedPet = await Navigator.push<PetConfig>(context, MaterialPageRoute(builder: (_) => PetEditScreen(pet: pet, isNewPet: false)));
    if (!mounted || updatedPet == null) return;
    StorageService.writePet(updatedPet);
    ref.invalidate(appDataProvider);
  }

  void _showDeleteConfirmation(List<PetConfig> pets, PetConfig pet) {
    if (pets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('至少需要保留一个桌宠'), behavior: SnackBarBehavior.floating));
      return;
    }
    showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('删除桌宠'),
      content: Text('确定要删除「${pet.name}」吗？\n\n缩放: ${(pet.snappedScaleMultiplier * 100).round()}%\n透明度: ${(pet.snappedOpacityMultiplier * 100).round()}%\n速度: ${pet.snappedSpeedMultiplier.toStringAsFixed(1)}x'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除')),
      ],
    )).then((confirmed) {
      if (!mounted || confirmed != true) return;
      StorageService.removePet(pet.id);
      ref.invalidate(appDataProvider);
    });
  }

  void _onSkinDirChanged(SettingsModel s, String? oldDir, String? newDir) {
    if (!SkinLister.isDefaultPath(oldDir) && SkinLister.isDefaultPath(newDir)) {
      _migrateSkins(newDir!);
    }
    s.skinDir = newDir;
    StorageService.writeSettings(s);
    ref.invalidate(appDataProvider);
  }

  Future<void> _migrateSkins(String targetDir) async {
    try {
      await SkinRepository().migrateTo(targetDir);
      if (!mounted) return;
      ref.invalidate(appDataProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已迁移已导入的皮肤包'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('迁移皮肤包失败: $e'), behavior: SnackBarBehavior.floating));
    }
  }

  void _openSkinPicker() {
    Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const SkinPickerScreen()));
  }
}

class _OpacityTile extends StatelessWidget {
  final double opacity; final ValueChanged<double> onChanged; final ValueChanged<double> onChangeEnd;
  const _OpacityTile({required this.opacity, required this.onChanged, required this.onChangeEnd});
  @override Widget build(BuildContext context) => ListTile(leading: const Icon(Icons.opacity), title: Text('全局透明度 — ${(opacity * 100).round()}%'), subtitle: Slider(value: opacity, min: 0.2, max: 1.0, divisions: 8, onChanged: onChanged, onChangeEnd: onChangeEnd));
}

class _ScaleTile extends StatelessWidget {
  final double scale; final ValueChanged<double> onChanged; final ValueChanged<double> onChangeEnd;
  const _ScaleTile({required this.scale, required this.onChanged, required this.onChangeEnd});
  @override Widget build(BuildContext context) => ListTile(leading: const Icon(Icons.zoom_in), title: Text('全局缩放 — ${scale.toStringAsFixed(1)}x'), subtitle: Slider(value: scale, min: 0.3, max: 3.0, divisions: 27, onChanged: onChanged, onChangeEnd: onChangeEnd));
}

class _SpeedTile extends StatelessWidget {
  final double speed; final ValueChanged<double> onChanged; final ValueChanged<double> onChangeEnd;
  const _SpeedTile({required this.speed, required this.onChanged, required this.onChangeEnd});
  @override Widget build(BuildContext context) => ListTile(leading: const Icon(Icons.speed), title: Text('全局速度 — ${speed.toStringAsFixed(1)}x'), subtitle: Slider(value: speed, min: 0.25, max: 3.0, divisions: 11, onChanged: onChanged, onChangeEnd: onChangeEnd));
}

class _SkinPathTile extends StatelessWidget {
  final String? currentSkinDir; final ValueChanged<String?> onChanged; final VoidCallback? onListSkins;
  const _SkinPathTile({required this.currentSkinDir, required this.onChanged, this.onListSkins});
  @override Widget build(BuildContext context) {
    final isDefault = SkinLister.isDefaultPath(currentSkinDir);
    return ListTile(
      leading: Icon(isDefault ? Icons.auto_awesome : Icons.folder_open, color: isDefault ? Theme.of(context).colorScheme.primary : null),
      title: Text(isDefault ? '皮肤目录 (默认路径)' : '皮肤目录'),
      subtitle: Text(isDefault ? 'assets/default_skin（内置）' : currentSkinDir!, overflow: TextOverflow.ellipsis, maxLines: 1),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (currentSkinDir != null && !isDefault) IconButton(icon: const Icon(Icons.clear, size: 18), tooltip: '恢复默认', onPressed: () => onChanged(null)),
        IconButton(icon: const Icon(Icons.list, size: 18), tooltip: '查看可用皮肤', onPressed: onListSkins),
        IconButton(icon: const Icon(Icons.folder_open, size: 18), tooltip: '浏览目录', onPressed: () async {
          final result = await FilePicker.platform.getDirectoryPath();
          if (result != null) onChanged(result);
        }),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold));
}
