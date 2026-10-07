import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/keycap_row.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.hotkeyTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 当前选择：以键帽呈现，与设置页里的显示保持一致。
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg, vertical: Insets.xl),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Center(
                  child: KeycapRow(
                    keys: _key.isEmpty ? const [] : [..._modifiers, _key],
                    placeholder: l10n.hotkeyPlaceholder,
                  ),
                ),
              ),
              const SizedBox(height: Insets.xl),
              _label(theme, l10n.modifiersLabel),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                children: [
                  _modifier('Alt', _alt, (v) => setState(() => _alt = v)),
                  _modifier('Ctrl', _ctrl, (v) => setState(() => _ctrl = v)),
                  _modifier('Shift', _shift, (v) => setState(() => _shift = v)),
                ],
              ),
              const SizedBox(height: Insets.xl),
              _label(theme, l10n.keyLabel),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: [
                  for (final key in _commonKeys)
                    ChoiceChip(
                      label: Text(key.toUpperCase()),
                      selected: _key == key,
                      onSelected: (_) => setState(() => _key = key),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _key.isEmpty
              ? null
              : () {
                  widget.onConfirm(_key, _modifiers);
                  Navigator.pop(context);
                },
          child: Text(l10n.setShortcut),
        ),
      ],
    );
  }

  Widget _label(ThemeData theme, String text) =>
      Text(text, style: theme.textTheme.labelSmall);

  Widget _modifier(String name, bool selected, ValueChanged<bool> onSelected) {
    return FilterChip(
      label: Text(name),
      selected: selected,
      onSelected: onSelected,
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
