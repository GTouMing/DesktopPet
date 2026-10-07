import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../pet/live2d/mouse_follow.dart';
import '../../petpack/import/pet_pack_importer.dart';
import '../../petpack/live2d/cdi_parameters.dart';
import '../../petpack/live2d/l2d_param_group.dart';
import '../../petpack/live2d_pet_pack.dart';
import '../../petpack/pet_pack.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_plate.dart';
import '../widgets/info_overlay.dart';
import '../widgets/section_panel.dart';
import '../widgets/slider_field.dart';
import 'pet_pack_picker_screen.dart';

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

  /// 当前包是不是 Live2D——决定是否显示「鼠标跟随」区。
  ///
  /// 跟随参数/幅度读自模型，编辑页无法预知，所以只要 Live2D 就显示（无标准参数的
  /// 模型滑杆不产生效果）。
  bool _hasMouseFollow = false;

  /// 鼠标跟随强度（乘在模型的跟随映射之上）。
  late double _followX;
  late double _followY;

  /// 该模型的参数清单 + 分组（读自包的 `cdi3.json`）；空 = 不显示「跟随参数」区。
  CdiParameters _cdi = CdiParameters.empty;

  /// 逐参数跟随轴：参数 id → `'x' | 'y' | 'xy'`（缺项 = 不跟随）。
  Map<String, String> _bindings = const {};

  /// 打开时的跟随轴快照，用于 [dirty] 判断。
  Map<String, String> _initialBindings = const {};

  static const double _stepSize = 0.1;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _scaleMultiplier = widget.pet.snappedScaleMultiplier;
    _opacityMultiplier = widget.pet.snappedOpacityMultiplier;
    _packPath = widget.pet.packPath;
    _paramChoices = Map.of(widget.pet.paramChoices);
    _followX = widget.pet.snappedMouseFollowX;
    _followY = widget.pet.snappedMouseFollowY;
    _bindings = Map.of(widget.pet.mouseBindings);
    _initialBindings = Map.of(widget.pet.mouseBindings);
    unawaited(_loadParamGroups(_packPath));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 有未保存改动时先在返回路径上确认。编辑页横跨多个字段，手滑一次全丢且没有撤销。
    return PopScope<PetConfig>(
      canPop: !_dirty,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = StorageService.readSettings();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.editPet),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Insets.lg),
            child: FilledButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(l10n.save),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.sm, Insets.lg, Insets.xxl),
        children: [
          _PreviewStage(
            scale: _scaleMultiplier,
            opacity: _opacityMultiplier,
            packName: _packPath.isEmpty ? null : _packPath.split('/').last,
            finalScale: rawFinalScale(settings.baseScale, _scaleMultiplier),
            finalOpacity: settings.baseOpacity * _opacityMultiplier,
          ),
          const SizedBox(height: Insets.xl),
          SectionPanel(
            label: l10n.sectionAppearance,
            child: Column(
              children: [
                _nameField(context),
                const Divider(height: 1),
                SliderField(
                  icon: Icons.zoom_in_rounded,
                  label: l10n.scaleMultiplier,
                  valueLabel: '${_scaleMultiplier.toStringAsFixed(1)}x',
                  value: _scaleMultiplier,
                  min: 0.1,
                  max: 3.0,
                  divisions: 29,
                  onChanged: (value) =>
                      setState(() => _scaleMultiplier = _snapValue(value)),
                ),
                const Divider(height: 1),
                SliderField(
                  icon: Icons.opacity_rounded,
                  label: l10n.opacityMultiplier,
                  valueLabel: '${(_opacityMultiplier * 100).round()}%',
                  value: _opacityMultiplier,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: (value) =>
                      setState(() => _opacityMultiplier = _snapValue(value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          SectionPanel(
            label: l10n.petPack,
            child: _packRow(context),
          ),
          if (_paramGroups.isNotEmpty) ...[
            const SizedBox(height: Insets.xl),
            SectionPanel(
              label: l10n.l2dParamsSection,
              child: Column(
                children: [
                  for (var i = 0; i < _paramGroups.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _paramRow(_paramGroups[i]),
                  ],
                ],
              ),
            ),
          ],
          if (_hasMouseFollow) ...[
            const SizedBox(height: Insets.xl),
            SectionPanel(
              label: l10n.mouseFollowSection,
              child: Column(
                children: [
                  SliderField(
                    icon: Icons.open_with_rounded,
                    label: l10n.mouseFollowX,
                    valueLabel: 'x${_followX.toStringAsFixed(1)}',
                    value: _followX,
                    min: 0.0,
                    max: maxMouseFollow,
                    divisions: 20,
                    onChanged: (value) =>
                        setState(() => _followX = _snapValue(value)),
                  ),
                  const Divider(height: 1),
                  SliderField(
                    icon: Icons.swap_vert_rounded,
                    label: l10n.mouseFollowY,
                    valueLabel: 'x${_followY.toStringAsFixed(1)}',
                    value: _followY,
                    min: 0.0,
                    max: maxMouseFollow,
                    divisions: 20,
                    onChanged: (value) =>
                        setState(() => _followY = _snapValue(value)),
                  ),
                ],
              ),
            ),
          ],
          if (_cdi.parameters.isNotEmpty) ...[
            const SizedBox(height: Insets.xl),
            SectionPanel(
              label: l10n.mouseFollowParamsSection,
              child: _followParamsSection(context),
            ),
          ],
          const SizedBox(height: Insets.xxl),
          _deleteButton(context),
        ],
      ),
    );
  }

  // ── 预览 ─────────────────────────────────────────────────────────────

  Widget _nameField(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.name, style: theme.textTheme.labelSmall),
          const SizedBox(height: Insets.sm),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: l10n.nameHint,
              prefixIcon: const Icon(Icons.edit_rounded, size: 20),
            ),
            // 需要重建才能让 _dirty 跟上输入，否则返回键的拦截会停在旧值上。
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ── 宠物包 ───────────────────────────────────────────────────────────

  Widget _packRow(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDefault = _packPath.isEmpty || _packPath == defaultPackPath;

    return ListTile(
      onTap: _openPackPicker,
      leading: IconPlate(
        icon: isDefault ? Icons.auto_awesome_rounded : Icons.folder_rounded,
        tone: isDefault ? PlateTone.accent : PlateTone.neutral,
      ),
      title: Text(
        isDefault ? l10n.defaultPetPackName : _packPath.split('/').last,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isDefault ? l10n.useGlobalPetPack : _packPath,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDefault)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: l10n.restoreDefault,
              onPressed: () {
                setState(() => _packPath = '');
                unawaited(_loadParamGroups(''));
              },
            ),
          IconButton(
            icon: const Icon(Icons.archive_rounded, size: 18),
            color: scheme.onSurfaceVariant,
            tooltip: l10n.importZipPetPack,
            onPressed: _importZipPack,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: scheme.onSurfaceVariant,
            tooltip: l10n.choosePetPack,
            onPressed: _openPackPicker,
          ),
        ],
      ),
    );
  }

  Widget _paramRow(L2dParamGroup group) {
    final theme = Theme.of(context);
    var idx = _paramChoices[group.id] ?? group.defaultIndex;
    if (idx < 0) idx = 0;
    if (idx >= group.options.length) idx = group.options.length - 1;

    if (group.isBool) {
      return SwitchListTile(
        title: Text(group.label),
        value: idx == 1,
        onChanged: (v) => setState(() => _paramChoices[group.id] = v ? 1 : 0),
      );
    }
    return ListTile(
      title: Text(group.label),
      trailing: DropdownButton<int>(
        value: idx,
        style: theme.textTheme.titleMedium,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(Radii.control),
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
    );
  }

  // ── 跟随参数 ─────────────────────────────────────────────────────────

  static const String _axisNone = 'none';

  /// 「跟随参数」区：只列**标准跟随参数所在分组**里的参数（作者把跟随相关的放在
  /// 同一组），逐参数选轴（不跟随 / X / Y / XY）；组名当小标题。
  Widget _followParamsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = <Widget>[];
    String? lastGroup;
    for (final parameter in _followCandidates()) {
      if (parameter.groupId != lastGroup) {
        lastGroup = parameter.groupId;
        final name = _cdi.groupNames[parameter.groupId];
        if (name != null) {
          rows.add(Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.lg, Insets.md, Insets.lg, Insets.sm),
            child: Text(name, style: theme.textTheme.labelMedium),
          ));
        }
      }
      rows.add(_followParamRow(l10n, parameter));
    }
    return Column(children: rows);
  }

  /// 候选参数：标准跟随参数所在的 cdi3 分组里、**id 或名带大写 X/Y/Z** 的参数
  /// （轴向参数都带这个标记）。模型没有标准跟随参数时回退到全部参数。
  List<L2dModelParameter> _followCandidates() {
    final byId = {for (final p in _cdi.parameters) p.id: p};
    final groups = <String>{};
    for (final id in standardFollowAxes.keys) {
      final parameter = byId[id];
      if (parameter != null && parameter.groupId.isNotEmpty) {
        groups.add(parameter.groupId);
      }
    }
    final scope = groups.isEmpty
        ? _cdi.parameters
        : _cdi.parameters.where((p) => groups.contains(p.groupId));
    return scope.where((p) => hasFollowAxisLetter(p.id, p.name)).toList();
  }

  Widget _followParamRow(AppLocalizations l10n, L2dModelParameter parameter) {
    final axis = _bindings[parameter.id] ?? _axisNone;
    return ListTile(
      dense: true,
      title: Text(parameter.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        parameter.id,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: DropdownButton<String>(
        value: axis,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(Radii.control),
        items: [
          DropdownMenuItem(
              value: _axisNone, child: Text(l10n.mouseFollowNone)),
          DropdownMenuItem(value: 'x', child: Text(l10n.mouseFollowAxisX)),
          DropdownMenuItem(value: 'y', child: Text(l10n.mouseFollowAxisY)),
          DropdownMenuItem(value: 'xy', child: Text(l10n.mouseFollowAxisXY)),
        ],
        onChanged: (value) => setState(() {
          if (value == null || value == _axisNone) {
            _bindings.remove(parameter.id);
          } else {
            _bindings[parameter.id] = value;
          }
        }),
      ),
    );
  }

  /// 保存用：与自动标准集等价 → 存空（继续自动）；否则存当前表。
  Map<String, String> _bindingsToStore() {
    final auto = _autoBindings(_cdi.parameters);
    return mapEquals(_bindings, auto) ? const {} : Map.of(_bindings);
  }

  // ── 危险操作 ─────────────────────────────────────────────────────────

  Widget _deleteButton(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showDeleteDialog,
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: Text(l10n.deletePetTitle),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.error,
          side: BorderSide(color: scheme.error.withValues(alpha: 0.45)),
        ),
      ),
    );
  }

  // ── 加载与保存 ───────────────────────────────────────────────────────

  /// 读取当前宠物包的参数组（Live2D 才有），并剪掉不属于该包的旧选择。
  Future<void> _loadParamGroups(String path) async {
    var groups = const <L2dParamGroup>[];
    var hasMouseFollow = false;
    var cdi = CdiParameters.empty;
    if (path.isNotEmpty) {
      try {
        final pack = await PetPack.load(path);
        if (pack is Live2DPetPack) {
          groups = pack.paramGroups;
          hasMouseFollow = true;
          cdi = await loadModelParameters(pack);
        }
      } catch (_) {
        // 包缺失/不可读：当作没有可调参数。
      }
    }
    if (!mounted) return;
    final ids = {for (final g in groups) g.id};
    setState(() {
      _paramGroups = groups;
      _hasMouseFollow = hasMouseFollow;
      _cdi = cdi;
      _bindings = _storedOrAutoBindings(cdi.parameters);
      _initialBindings = Map.of(_bindings);
      _paramChoices = {
        for (final e in _paramChoices.entries)
          if (ids.contains(e.key)) e.key: e.value,
      };
    });
  }

  /// 自动标准集 ∩ 该模型参数——编辑页下拉的预填。
  Map<String, String> _autoBindings(List<L2dModelParameter> parameters) {
    final ids = {for (final p in parameters) p.id};
    return {
      for (final e in standardFollowAxes.entries)
        if (ids.contains(e.key)) e.key: e.value,
    };
  }

  /// 存储的绑定（剪掉不属于该模型的）优先；无存储则回退自动标准集。
  Map<String, String> _storedOrAutoBindings(List<L2dModelParameter> parameters) {
    final stored = widget.pet.mouseBindings;
    if (stored.isEmpty) return _autoBindings(parameters);
    final ids = {for (final p in parameters) p.id};
    return {
      for (final e in stored.entries)
        if (ids.contains(e.key)) e.key: e.value,
    };
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
      name: _nameController.text.isNotEmpty
          ? _nameController.text
          : widget.pet.name,
      scaleMultiplier: _scaleMultiplier,
      opacityMultiplier: _opacityMultiplier,
      packPath: _packPath,
      paramChoices: _paramChoices,
      mouseFollowX: _followX,
      mouseFollowY: _followY,
      mouseBindings: _bindingsToStore(),
    );
    final resultPet = widget.isNewPet && widget.pet.id.isEmpty
        ? updatedPet.copyWith(id: newPetId())
        : updatedPet;

    Navigator.pop(context, resultPet);
  }

  /// 是否已偏离打开时的值。
  bool get _dirty =>
      _nameController.text != widget.pet.name ||
      _scaleMultiplier != widget.pet.snappedScaleMultiplier ||
      _opacityMultiplier != widget.pet.snappedOpacityMultiplier ||
      _packPath != widget.pet.packPath ||
      !mapEquals(_paramChoices, widget.pet.paramChoices) ||
      _followX != widget.pet.snappedMouseFollowX ||
      _followY != widget.pet.snappedMouseFollowY ||
      !mapEquals(_bindings, _initialBindings);

  Future<void> _onPopInvokedWithResult(bool didPop, PetConfig? result) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    if (await _confirmDiscard(context)) navigator.pop();
  }

  /// 放弃修改前的确认。
  ///
  /// 破坏性的一方（放弃）放在右侧且不是焦点默认落点——对话框打开时第一个可聚焦
  /// 元素是「取消」。
  Future<bool> _confirmDiscard(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.unsavedChanges),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.discardChanges),
          ),
        ],
      ),
    );
    return discard ?? false;
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  double _snapValue(double value) {
    return (value / _stepSize).round() * _stepSize;
  }
}

/// 预览舞台：把乘数效果直接画出来，并在下面给出最终生效值。
class _PreviewStage extends StatelessWidget {
  const _PreviewStage({
    required this.scale,
    required this.opacity,
    required this.packName,
    required this.finalScale,
    required this.finalOpacity,
  });

  final double scale;
  final double opacity;
  final String? packName;
  final double finalScale;
  final double finalOpacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SectionPanel(
      label: l10n.preview,
      child: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.55),
                  scheme.surfaceContainerLow,
                ],
              ),
            ),
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      Icons.pets_rounded,
                      size: 48,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    _Readout(
                      icon: Icons.zoom_in_rounded,
                      text: '${scale.toStringAsFixed(1)}x',
                    ),
                    _Readout(
                      icon: Icons.opacity_rounded,
                      text: '${(opacity * 100).round()}%',
                    ),
                    if (packName != null)
                      _Readout(
                        icon: Icons.folder_rounded,
                        text: packName!,
                      ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                Text(
                  '${l10n.finalScaleFormula}  →  '
                  '${finalScale.toStringAsFixed(1)}x',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.finalOpacityFormula}  →  '
                  '${(finalOpacity * 100).round()}%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.md, vertical: Insets.xs + 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
