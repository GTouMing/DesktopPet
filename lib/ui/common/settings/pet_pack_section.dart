import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../petpack/pet_pack_lister.dart';
import '../../../storage/models/settings_model.dart';
import '../../widgets/icon_plate.dart';
import '../../widgets/section_panel.dart';
import '../pet_pack_picker_screen.dart';
import 'settings_common.dart';

/// 宠物包分区：宠物包目录的选择、恢复默认与查看可用宠物包。
class PetPackSection extends StatelessWidget {
  const PetPackSection({super.key, required this.settings});

  final SettingsModel settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final packDir = settings.packDir;
    final isDefault = PetPackLister.isDefaultPath(packDir);

    return SectionPanel(
      label: l10n.sectionPetPack,
      child: ListTile(
        leading: IconPlate(
          icon: isDefault ? Icons.auto_awesome_rounded : Icons.folder_open_rounded,
          tone: isDefault ? PlateTone.accent : PlateTone.neutral,
        ),
        title: Text(isDefault ? l10n.petPackDirDefaultPath : l10n.petPackDir),
        subtitle: Text(
          isDefault ? l10n.petPackBuiltInValue : packDir!,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (packDir != null && !isDefault)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: l10n.restoreDefault,
                onPressed: () => _changeDir(null),
              ),
            IconButton(
              icon: const Icon(Icons.list_rounded, size: 20),
              color: scheme.onSurfaceVariant,
              tooltip: l10n.viewAvailablePetPacks,
              onPressed: () => _openPackPicker(context),
            ),
            IconButton(
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              color: scheme.onSurfaceVariant,
              tooltip: l10n.browseDirectory,
              onPressed: () async {
                final dir = await FilePicker.getDirectoryPath();
                if (dir != null) _changeDir(dir);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _changeDir(String? newDir) {
    applySettings((s) => s.copyWith(packDir: newDir));
  }

  void _openPackPicker(BuildContext context) {
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PetPackPickerScreen()),
    );
  }
}
