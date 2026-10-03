import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../petpack/import/pet_pack_repository.dart';
import '../../../petpack/pet_pack_lister.dart';
import '../../../storage/models/settings_model.dart';
import '../../widgets/info_overlay.dart';
import '../pet_pack_picker_screen.dart';
import 'settings_common.dart';

/// 皮肤分区：皮肤目录的选择、恢复默认、查看可用皮肤与迁移。
class PetPackSection extends StatefulWidget {
  const PetPackSection({super.key, required this.settings});

  final SettingsModel settings;

  @override
  State<PetPackSection> createState() => _PetPackSectionState();
}

class _PetPackSectionState extends State<PetPackSection> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final packDir = widget.settings.packDir;
    final isDefault = PetPackLister.isDefaultPath(packDir);

    return Column(
      children: [
        SectionHeader(title: l10n.sectionSkin),
        ListTile(
          leading: Icon(
            isDefault ? Icons.auto_awesome : Icons.folder_open,
            color: isDefault ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(isDefault ? l10n.skinDirDefaultPath : l10n.skinDir),
          subtitle: Text(
            isDefault ? l10n.skinBuiltInValue : packDir!,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (packDir != null && !isDefault)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: l10n.restoreDefault,
                  onPressed: () => _changeDir(null),
                ),
              IconButton(
                icon: const Icon(Icons.list, size: 18),
                tooltip: l10n.viewAvailableSkins,
                onPressed: _openPackPicker,
              ),
              IconButton(
                icon: const Icon(Icons.folder_open, size: 18),
                tooltip: l10n.browseDirectory,
                onPressed: () async {
                  final dir = await FilePicker.getDirectoryPath();
                  if (dir != null) _changeDir(dir);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 从内置目录切到自定义目录时，把已导入的皮肤搬过去。
  void _changeDir(String? newDir) {
    final wasDefault = PetPackLister.isDefaultPath(widget.settings.packDir);
    final nowCustom = !PetPackLister.isDefaultPath(newDir);
    if (wasDefault && nowCustom && newDir != null) {
      _migratePacks(newDir);
    }
    applySettings((s) => s.copyWith(packDir: newDir));
  }

  Future<void> _migratePacks(String targetDir) async {
    final l10n = AppLocalizations.of(context);
    try {
      await PetPackRepository().migrateTo(targetDir);
      if (!mounted) return;
      InfoOverlay.show(context, title: l10n.skinMigrated);
    } catch (e) {
      if (!mounted) return;
      InfoOverlay.show(context, title: l10n.skinMigrateFailed('$e'));
    }
  }

  void _openPackPicker() {
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PetPackPickerScreen()),
    );
  }
}
