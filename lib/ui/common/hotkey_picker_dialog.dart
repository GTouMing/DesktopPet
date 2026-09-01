import 'package:flutter/material.dart';

/// 快捷键选择对话框。
///
/// 用户可选择键名和修饰键（Alt / Ctrl / Shift），
/// 确认后通过 [onConfirm] 回调返回结果。
class HotkeyPickerDialog extends StatefulWidget {
  final String initialKey;
  final List<String> initialMods;
  final void Function(String key, List<String> modifiers) onConfirm;

  const HotkeyPickerDialog({
    super.key,
    this.initialKey = '',
    this.initialMods = const [],
    required this.onConfirm,
  });

  @override
  State<HotkeyPickerDialog> createState() => _HotkeyPickerDialogState();
}

class _HotkeyPickerDialogState extends State<HotkeyPickerDialog> {
  late String _key;
  late bool _alt;
  late bool _ctrl;
  late bool _shift;

  @override
  void initState() {
    super.initState();
    _key = widget.initialKey;
    _alt = widget.initialMods.contains('alt');
    _ctrl = widget.initialMods.contains('ctrl');
    _shift = widget.initialMods.contains('shift');
  }

  List<String> get _modifiers {
    final list = <String>[];
    if (_alt) list.add('alt');
    if (_ctrl) list.add('ctrl');
    if (_shift) list.add('shift');
    return list;
  }

  String get _displayValue {
    if (_key.isEmpty) return '（点击下方按钮选择）';
    final parts = [
      ..._modifiers
          .map((m) => m[0].toUpperCase() + m.substring(1)),
      _key.toUpperCase(),
    ];
    return parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置快捷键'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 当前选择显示
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _displayValue,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 20),

          // 修饰键勾选
          const Text('修饰键（可多选）',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              FilterChip(
                label: const Text('Alt'),
                selected: _alt,
                onSelected: (v) => setState(() => _alt = v),
              ),
              FilterChip(
                label: const Text('Ctrl'),
                selected: _ctrl,
                onSelected: (v) => setState(() => _ctrl = v),
              ),
              FilterChip(
                label: const Text('Shift'),
                selected: _shift,
                onSelected: (v) => setState(() => _shift = v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 键名选择
          const Text('按键',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in _commonKeys)
                ActionChip(
                  label: Text(k.toUpperCase(),
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _key = k),
                  backgroundColor: _key == k
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
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
          onPressed: _key.isEmpty
              ? null
              : () {
                  widget.onConfirm(_key, _modifiers);
                  Navigator.pop(context);
                },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 常用可选的按键列表。
const _commonKeys = [
  '`', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
  'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
  'space', 'enter', 'escape', 'tab',
];
