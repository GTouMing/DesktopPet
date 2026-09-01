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

    return AlertDialog(
      title: Text(isNew ? '添加快捷启动' : '编辑快捷启动'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '如：记事本',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathCtrl,
                  decoration: const InputDecoration(
                    labelText: '可执行文件路径',
                    hintText: '如：C:\\Windows\\notepad.exe',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: '浏览文件',
                onPressed: _pickExecutable,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
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
          child: const Text('确定'),
        ),
      ],
    );
  }
}
