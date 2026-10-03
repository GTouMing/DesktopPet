import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:styled_widget/styled_widget.dart';

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../petpack/import/pet_pack_importer.dart';
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
  late double _speedMultiplier;
  late String _packPath;

  static const double _stepSize = 0.1;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _scaleMultiplier = widget.pet.snappedScaleMultiplier;
    _opacityMultiplier = widget.pet.snappedOpacityMultiplier;
    _speedMultiplier = widget.pet.snappedSpeedMultiplier;
    _packPath = widget.pet.packPath;
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
          _buildSpeedSlider(context, theme),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildMultiplierHint(l10n, isScale: false, isSpeed: true),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildPackPathField(context, theme),
          ),
          _buildDeleteButton(context),
        ],
      ),
    );
  }

  Widget _buildMultiplierHint(AppLocalizations l10n,
      {required bool isScale, bool isSpeed = false}) {
    final text = isSpeed
        ? l10n.finalSpeedFormula
        : isScale
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
                child: Text(l10n.skinLabel(_packPath.split('/').last))
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

  Widget _buildSpeedSlider(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.speedMultiplier, style: theme.textTheme.labelLarge),
              Text('${_speedMultiplier.toStringAsFixed(1)}x')
                  .bold().fontSize(14).textColor(theme.colorScheme.primary),
            ],
          ),
        ),
        Row(
          children: [
            const Icon(Icons.speed, size: 20, color: Colors.grey),
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

  Widget _buildPackPathField(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final isDefault = _packPath.isEmpty || _packPath == defaultPackPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l10n.skin, style: theme.textTheme.labelLarge),
        ),
        Card(
          child: ListTile(
            leading: Icon(
              isDefault ? Icons.auto_awesome : Icons.folder,
              color: isDefault ? theme.colorScheme.primary : null,
            ),
            title: Text(
              isDefault ? l10n.defaultSkinName : _packPath.split('/').last,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              isDefault ? l10n.useGlobalSkin : _packPath,
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
                    onPressed: () => setState(() => _packPath = ''),
                  ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  tooltip: l10n.importZipSkin,
                  onPressed: _importZipPack,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  tooltip: l10n.chooseSkin,
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
      if (path != null && mounted) setState(() => _packPath = path);
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
          content: Text(l10n.importingSkin),
          duration: const Duration(seconds: 1),
        ),
      );

      final importedPath = await PetPackImporter.importZip(
        zipPath: zipPath,
        petId: petId,
      );

      if (!mounted) return;
      setState(() => _packPath = importedPath);

      InfoOverlay.show(
        context,
        title: l10n.skinImportSuccess,
        message: importedPath.split('/').last,
      );
    } catch (e) {
      if (!mounted) return;
      InfoOverlay.show(
        context,
        title: l10n.skinImportFailed,
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
      speedMultiplier: _speedMultiplier,
      packPath: _packPath,
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
