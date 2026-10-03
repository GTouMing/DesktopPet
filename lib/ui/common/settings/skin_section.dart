import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../skin/import/skin_repository.dart';
import '../../../skin/skin_lister.dart';
import '../../../storage/models/settings_model.dart';
import '../../widgets/info_overlay.dart';
import '../skin_picker_screen.dart';
import 'settings_common.dart';

/// 皮肤分区：皮肤目录的选择、恢复默认、查看可用皮肤与迁移。
class SkinSection extends StatefulWidget {
  const SkinSection({super.key, required this.settings});

  final SettingsModel settings;

  @override
  State<SkinSection> createState() => _SkinSectionState();
}

class _SkinSectionState extends State<SkinSection> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skinDir = widget.settings.skinDir;
    final isDefault = SkinLister.isDefaultPath(skinDir);

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
            isDefault ? l10n.skinBuiltInValue : skinDir!,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (skinDir != null && !isDefault)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: l10n.restoreDefault,
                  onPressed: () => _changeDir(null),
                ),
              IconButton(
                icon: const Icon(Icons.list, size: 18),
                tooltip: l10n.viewAvailableSkins,
                onPressed: _openSkinPicker,
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
    final wasDefault = SkinLister.isDefaultPath(widget.settings.skinDir);
    final nowCustom = !SkinLister.isDefaultPath(newDir);
    if (wasDefault && nowCustom && newDir != null) {
      _migrateSkins(newDir);
    }
    applySettings((s) => s.copyWith(skinDir: newDir));
  }

  Future<void> _migrateSkins(String targetDir) async {
    final l10n = AppLocalizations.of(context);
    try {
      await SkinRepository().migrateTo(targetDir);
      if (!mounted) return;
      InfoOverlay.show(context, title: l10n.skinMigrated);
    } catch (e) {
      if (!mounted) return;
      InfoOverlay.show(context, title: l10n.skinMigrateFailed('$e'));
    }
  }

  void _openSkinPicker() {
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SkinPickerScreen()),
    );
  }
}
