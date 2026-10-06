import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:styled_widget/styled_widget.dart';

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../petpack/import/pet_pack_importer.dart';
import '../../petpack/live2d/l2d_param_group.dart';
import '../../petpack/live2d_pet_pack.dart';
import '../../petpack/pet_pack.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import 'pet_pack_picker_screen.dart';
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
  late String _packPath;

  /// Live2D 可调参数：当前包的参数组（空 = 不显示该区）与本地选择（组 id → 选项下标）。
  List<L2dParamGroup> _paramGroups = const [];
  late Map<String, int> _paramChoices;

  static const double _stepSize = 0.1;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _scaleMultiplier = widget.pet.snappedScaleMultiplier;
    _opacityMultiplier = widget.pet.snappedOpacityMultiplier;
    _packPath = widget.pet.packPath;
    _paramChoices = Map.of(widget.pet.paramChoices);
    unawaited(_loadParamGroups(_packPath));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.editPet),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.check),
            label: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildPreviewSection(context, theme),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildNameField(context, theme),
          ),
          _buildScaleSlider(context, theme),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildMultiplierHint(l10n, isScale: true),
          ),
          _buildOpacitySlider(context, theme),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildMultiplierHint(l10n, isScale: false),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildPackPathField(context, theme),
          ),
          if (_paramGroups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l10n.l2dParamsSection,
                  style: theme.textTheme.labelLarge),
            ),
            for (final group in _paramGroups) _buildParamGroup(group),
            const SizedBox(height: 16),
          ],
          _buildDeleteButton(context),
        ],
      ),
    );
  }

  Widget _buildMultiplierHint(AppLocalizations l10n, {required bool isScale}) {
    final text = isScale
        ? l10n.finalScaleFormula
        : l10n.finalOpacityFormula;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(text).fontSize(11).textColor(Colors.grey),
    );
  }

  Widget _buildPreviewSection(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(l10n.preview, style: theme.textTheme.labelLarge),
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
            if (_packPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.petPackLabel(_packPath.split('/').last))
                    .fontSize(11)
                    .textColor(Colors.blue),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l10n.name, style: theme.textTheme.labelLarge),
        ),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: l10n.nameHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.edit),
          ),
        ),
      ],
    );
  }

  Widget _buildScaleSlider(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.scaleMultiplier, style: theme.textTheme.labelLarge),
              Text('${(_scaleMultiplier * 100).round()}%')
                  .bold().fontSize(14).textColor(theme.colorScheme.primary),
            ],
          ),
        ),
        Row(
          children: [
            const Icon(Icons.zoom_out, size: 20, color: Colors.grey),
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
            const Icon(Icons.zoom_in, size: 20, color: Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildOpacitySlider(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.opacityMultiplier, style: theme.textTheme.labelLarge),
              Text('${(_opacityMultiplier * 100).round()}%')
                  .bold().fontSize(14).textColor(theme.colorScheme.primary),
            ],
          ),
        ),
        Row(
          children: [
            const Icon(Icons.opacity, size: 20, color: Colors.grey),
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

  Widget _buildPackPathField(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final isDefault = _packPath.isEmpty || _packPath == defaultPackPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l10n.petPack, style: theme.textTheme.labelLarge),
        ),
        Card(
          child: ListTile(
            leading: Icon(
              isDefault ? Icons.auto_awesome : Icons.folder,
              color: isDefault ? theme.colorScheme.primary : null,
            ),
            title: Text(
              isDefault ? l10n.defaultPetPackName : _packPath.split('/').last,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              isDefault ? l10n.useGlobalPetPack : _packPath,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ).fontSize(12),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDefault)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: l10n.restoreDefault,
                    onPressed: () {
                      setState(() => _packPath = '');
                      unawaited(_loadParamGroups(''));
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  tooltip: l10n.importZipPetPack,
                  onPressed: _importZipPack,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  tooltip: l10n.choosePetPack,
                  onPressed: _openPackPicker,
                ),
              ],
            ),
            onTap: _openPackPicker,
          ),
        ),
      ],
    );
  }

  /// 读取当前宠物包的参数组（Live2D 才有），并剪掉不属于该包的旧选择。
  Future<void> _loadParamGroups(String path) async {
    var groups = const <L2dParamGroup>[];
    if (path.isNotEmpty) {
      try {
        final pack = await PetPack.load(path);
        if (pack is Live2DPetPack) groups = pack.paramGroups;
      } catch (_) {
        // 包缺失/不可读：当作没有可调参数。
      }
    }
    if (!mounted) return;
    final ids = {for (final g in groups) g.id};
    setState(() {
      _paramGroups = groups;
      _paramChoices = {
        for (final e in _paramChoices.entries)
          if (ids.contains(e.key)) e.key: e.value,
      };
    });
  }

  Widget _buildParamGroup(L2dParamGroup group) {
    var idx = _paramChoices[group.id] ?? group.defaultIndex;
    if (idx < 0) idx = 0;
    if (idx >= group.options.length) idx = group.options.length - 1;

    if (group.isBool) {
      return Card(
        child: SwitchListTile(
          title: Text(group.label),
          value: idx == 1,
          onChanged: (v) => setState(() => _paramChoices[group.id] = v ? 1 : 0),
        ),
      );
    }
    return Card(
      child: ListTile(
        title: Text(group.label),
        trailing: DropdownButton<int>(
          value: idx,
          underline: const SizedBox.shrink(),
          items: [
            for (var i = 0; i < group.options.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(
                  group.options[i].label.isEmpty ? '-' : group.options[i].label,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _paramChoices[group.id] = v);
          },
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      onPressed: () => _showDeleteDialog(),
      icon: const Icon(Icons.delete, color: Colors.red),
      label: Text(l10n.deletePetTitle,
          style: const TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  double _snapValue(double value) {
    return (value / _stepSize).round() * _stepSize;
  }

  void _openPackPicker() {
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PetPackPickerScreen()),
    ).then((path) {
      if (path != null && mounted) {
        setState(() => _packPath = path);
        unawaited(_loadParamGroups(path));
      }
    });
  }

  Future<void> _importZipPack() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final zipPath = result?.files.single.path;
    if (zipPath == null || !mounted) return;

    try {
      final petId = widget.pet.id.isNotEmpty ? widget.pet.id : newPetId();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.importingPetPack),
          duration: const Duration(seconds: 1),
        ),
      );

      final importedPath = await PetPackImporter.importZip(
        zipPath: zipPath,
        petId: petId,
      );

      if (!mounted) return;
      setState(() => _packPath = importedPath);
      unawaited(_loadParamGroups(importedPath));

      InfoOverlay.show(
        context,
        title: l10n.petPackImportSuccess,
        message: importedPath.split('/').last,
      );
    } catch (e) {
      if (!mounted) return;
      InfoOverlay.show(
        context,
        title: l10n.petPackImportFailed,
        message: '$e',
        type: InfoType.error,
      );
    }
  }

  void _saveChanges() {
    final l10n = AppLocalizations.of(context);
    final baseScale = StorageService.readSettings().baseScale;
    if (rawFinalScale(baseScale, _scaleMultiplier) > maxFinalScale) {
      InfoOverlay.show(context,
          title: l10n.scaleTooHigh, message: l10n.scaleTooHighHint);
      return;
    }

    final updatedPet = widget.pet.copyWith(
      name: _nameController.text.isNotEmpty ? _nameController.text : widget.pet.name,
      scaleMultiplier: _scaleMultiplier,
      opacityMultiplier: _opacityMultiplier,
      packPath: _packPath,
      paramChoices: _paramChoices,
    );
    final resultPet = widget.isNewPet && widget.pet.id.isEmpty
        ? updatedPet.copyWith(id: newPetId())
        : updatedPet;

    Navigator.pop(context, resultPet);
  }

  void _showDeleteDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePetTitle),
        content: Text(l10n.deletePetConfirm(widget.pet.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, null);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
