import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:styled_widget/styled_widget.dart';

import '../../core/constants.dart';
import '../../skin/import/skin_importer.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import 'skin_picker_screen.dart';
import '../widgets/info_overlay.dart';

class PetEditScreen extends ConsumerStatefulWidget {
  final PetConfig pet;
  final bool isNewPet;

  const PetEditScreen({super.key, required this.pet, this.isNewPet = false});

  @override
  ConsumerState<PetEditScreen> createState() => _PetEditScreenState();
}

class _PetEditScreenState extends ConsumerState<PetEditScreen> {
  late TextEditingController _nameController;
  late double _scaleMultiplier;
  late double _opacityMultiplier;
  late double _speedMultiplier;
  late String _skinPath;

  static const double _stepSize = 0.1;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _scaleMultiplier = widget.pet.snappedScaleMultiplier;
    _opacityMultiplier = widget.pet.snappedOpacityMultiplier;
    _speedMultiplier = widget.pet.snappedSpeedMultiplier;
    _skinPath = widget.pet.skinPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('修改桌宠'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildPreviewSection(theme),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildNameField(theme),
          ),
          _buildScaleSlider(theme),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildMultiplierHint(theme, isScale: true),
          ),
          _buildOpacitySlider(theme),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildMultiplierHint(theme, isScale: false),
          ),
          _buildSpeedSlider(theme),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildMultiplierHint(theme, isScale: false, isSpeed: true),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildSkinPathField(theme),
          ),
          _buildDeleteButton(theme),
        ],
      ),
    );
  }

  Widget _buildMultiplierHint(ThemeData theme, {required bool isScale, bool isSpeed = false}) {
    final text = isSpeed
        ? '× 全局速度 = 最终速度'
        : isScale
            ? '× 全局缩放 = 最终缩放'
            : '× 全局透明度 = 最终透明度';
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(text).fontSize(11).textColor(Colors.grey),
    );
  }

  Widget _buildPreviewSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('预览', style: theme.textTheme.labelLarge),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Transform.scale(
                  scale: _scaleMultiplier,
                  child: Opacity(
                    opacity: _opacityMultiplier,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 60,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              '${(_scaleMultiplier * 100).round()}% · ${(_opacityMultiplier * 100).round()}%',
            ).fontSize(12).textColor(Colors.grey),
            if (_skinPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('皮肤: ${_skinPath.split('/').last}')
                    .fontSize(11)
                    .textColor(Colors.blue),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('名称', style: theme.textTheme.labelLarge),
        ),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: '输入桌宠名称',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit),
          ),
        ),
      ],
    );
  }

  Widget _buildScaleSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('缩放乘数', style: theme.textTheme.labelLarge),
              Text('${(_scaleMultiplier * 100).round()}%')
                  .bold().fontSize(14).textColor(theme.colorScheme.primary),
            ],
          ),
        ),
        Row(
          children: [
            Icon(Icons.zoom_out, size: 20, color: Colors.grey),
            Expanded(
              child: Slider(
                value: _scaleMultiplier,
                min: 0.1,
                max: 3.0,
                divisions: 29,
                label: '${(_scaleMultiplier * 100).round()}%',
                onChanged: (value) {
                  setState(() {
                    _scaleMultiplier = _snapValue(value);
                  });
                },
              ),
            ),
            Icon(Icons.zoom_in, size: 20, color: Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildOpacitySlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('透明度乘数', style: theme.textTheme.labelLarge),
              Text('${(_opacityMultiplier * 100).round()}%')
                  .bold().fontSize(14).textColor(theme.colorScheme.primary),
            ],
          ),
        ),
        Row(
          children: [
            Icon(Icons.opacity, size: 20, color: Colors.grey),
            Expanded(
              child: Slider(
                value: _opacityMultiplier,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: '${(_opacityMultiplier * 100).round()}%',
                onChanged: (value) {
                  setState(() {
                    _opacityMultiplier = _snapValue(value);
                  });
                },
              ),
            ),
            const Icon(Icons.opacity, size: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('速度乘数', style: theme.textTheme.labelLarge),
              Text('${_speedMultiplier.toStringAsFixed(1)}x')
                  .bold().fontSize(14).textColor(theme.colorScheme.primary),
            ],
          ),
        ),
        Row(
          children: [
            Icon(Icons.speed, size: 20, color: Colors.grey),
            Expanded(
              child: Slider(
                value: _speedMultiplier,
                min: 0.1,
                max: 3.0,
                divisions: 29,
                label: '${_speedMultiplier.toStringAsFixed(1)}x',
                onChanged: (value) {
                  setState(() {
                    _speedMultiplier = _snapValue(value);
                  });
                },
              ),
            ),
            const Icon(Icons.speed, size: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildSkinPathField(ThemeData theme) {
    final isDefault = _skinPath.isEmpty || _skinPath == defaultSkinPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('皮肤', style: theme.textTheme.labelLarge),
        ),
        Card(
          child: ListTile(
            leading: Icon(
              isDefault ? Icons.auto_awesome : Icons.folder,
              color: isDefault ? theme.colorScheme.primary : null,
            ),
            title: Text(
              isDefault ? '默认皮肤' : _skinPath.split('/').last,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              isDefault ? '使用全局设置中的皮肤' : _skinPath,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ).fontSize(12),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDefault)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '恢复默认',
                    onPressed: () => setState(() => _skinPath = ''),
                  ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  tooltip: '导入 ZIP 皮肤包',
                  onPressed: _importZipSkin,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  tooltip: '选择皮肤',
                  onPressed: _openSkinPicker,
                ),
              ],
            ),
            onTap: _openSkinPicker,
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: () => _showDeleteDialog(),
      icon: Icon(Icons.delete, color: Colors.red),
      label: Text('删除此桌宠', style: TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  double _snapValue(double value) {
    return (value / _stepSize).round() * _stepSize;
  }

  void _openSkinPicker() {
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SkinPickerScreen()),
    ).then((path) {
      if (path != null && mounted) setState(() => _skinPath = path);
    });
  }

  Future<void> _importZipSkin() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final zipPath = result?.files.single.path;
    if (zipPath == null || !mounted) return;

    try {
      final petId = widget.pet.id.isNotEmpty
          ? widget.pet.id
          : 'pet_${DateTime.now().millisecondsSinceEpoch}';

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在导入皮肤包...'),
          duration: Duration(seconds: 1),
        ),
      );

      final importedPath = await SkinImporter.importZip(
        zipPath: zipPath,
        petId: petId,
      );

      if (!mounted) return;
      setState(() => _skinPath = importedPath);

      InfoOverlay.show(
        context,
        title: '皮肤导入成功',
        message: importedPath.split('/').last,
      );
    } catch (e) {
      if (!mounted) return;
      InfoOverlay.show(
        context,
        title: '皮肤导入失败',
        message: '$e',
        type: InfoType.error,
      );
    }
  }

  void _saveChanges() {
    final baseScale = StorageService.readSettings().baseScale;
    if (baseScale * _scaleMultiplier > maxFinalScale) {
      InfoOverlay.show(context, title: '缩放乘数过高', message: '请降低乘数或全局缩放');
      return;
    }

    final updatedPet = widget.pet.copyWith(
      name: _nameController.text.isNotEmpty ? _nameController.text : widget.pet.name,
      scaleMultiplier: _scaleMultiplier,
      opacityMultiplier: _opacityMultiplier,
      speedMultiplier: _speedMultiplier,
      skinPath: _skinPath,
    );
    final resultPet = widget.isNewPet && widget.pet.id.isEmpty
        ? updatedPet.copyWith(id: 'pet_${DateTime.now().millisecondsSinceEpoch}')
        : updatedPet;

    Navigator.pop(context, resultPet);
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除桌宠'),
        content: Text('确定要删除「${widget.pet.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, null);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
