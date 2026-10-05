import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../petpack/pet_pack_lister.dart';
import '../../../storage/models/settings_model.dart';
import '../pet_pack_picker_screen.dart';
import 'settings_common.dart';

/// 宠物包分区：宠物包目录的选择、恢复默认与查看可用宠物包。
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
        SectionHeader(title: l10n.sectionPetPack),
        ListTile(
          leading: Icon(
            isDefault ? Icons.auto_awesome : Icons.folder_open,
            color: isDefault ? Theme.of(context).colorScheme.primary : null,
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
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: l10n.restoreDefault,
                  onPressed: () => _changeDir(null),
                ),
              IconButton(
                icon: const Icon(Icons.list, size: 18),
                tooltip: l10n.viewAvailablePetPacks,
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

  void _changeDir(String? newDir) {
    applySettings((s) => s.copyWith(packDir: newDir));
  }

  void _openPackPicker() {
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PetPackPickerScreen()),
    );
  }
}
