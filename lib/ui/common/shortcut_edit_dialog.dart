import 'package:desktop_pet/l10n/app_localizations.dart';
import 'package:desktop_pet/storage/models/app_shortcut.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// 快捷启动应用编辑对话框（新增 / 编辑）。
class ShortcutEditDialog extends StatefulWidget {
  final AppShortcut? initial;

  const ShortcutEditDialog({super.key, this.initial});

  @override
  State<ShortcutEditDialog> createState() => _ShortcutEditDialogState();
}

class _ShortcutEditDialogState extends State<ShortcutEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _pathCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _pathCtrl =
        TextEditingController(text: widget.initial?.executablePath ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty && _pathCtrl.text.trim().isNotEmpty;

  void _pickExecutable() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      _pathCtrl.text = result.files.single.path!;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(isNew ? l10n.addShortcutTitle : l10n.editShortcutTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: l10n.nameLabel,
              hintText: l10n.nameHintShortcut,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.pathLabel,
                    hintText: l10n.pathHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: l10n.browseFile,
                onPressed: _pickExecutable,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                    context,
                    AppShortcut(
                      name: _nameCtrl.text.trim(),
                      executablePath: _pathCtrl.text.trim(),
                      order: widget.initial?.order ?? 0,
                    ),
                  )
              : null,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
