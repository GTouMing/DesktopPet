import 'package:desktop_pet/l10n/app_localizations.dart';
import 'package:desktop_pet/storage/models/app_shortcut.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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

  /// 是否已经尝试提交过：只有提交失败后才把"必填"标在字段上。
  bool _showErrors = false;

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

  bool get _nameValid => _nameCtrl.text.trim().isNotEmpty;
  bool get _pathValid => _pathCtrl.text.trim().isNotEmpty;

  void _pickExecutable() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    _pathCtrl.text = path;
    setState(() {});
  }

  /// 校验并提交。
  ///
  /// 确认键**始终可点**：缺什么就直接标在对应字段上，而不是把按钮灰掉让用户
  /// 自己猜哪里没填。
  void _submit() {
    if (!_nameValid || !_pathValid) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.pop(
      context,
      AppShortcut(
        name: _nameCtrl.text.trim(),
        executablePath: _pathCtrl.text.trim(),
        order: widget.initial?.order ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(isNew ? l10n.addShortcutTitle : l10n.editShortcutTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                hintText: l10n.nameHintShortcut,
                errorText:
                    _showErrors && !_nameValid ? l10n.requiredField : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Insets.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.pathLabel,
                      hintText: l10n.pathHint,
                      errorText:
                          _showErrors && !_pathValid ? l10n.requiredField : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Padding(
                  padding: const EdgeInsets.only(top: Insets.xs),
                  child: IconButton(
                    icon: const Icon(Icons.folder_open_rounded, size: 20),
                    tooltip: l10n.browseFile,
                    onPressed: _pickExecutable,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
