import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 组合键 / 按键的键帽呈现。
///
/// 空列表时显示 [placeholder]（弱化文字）；否则每个键渲染成一块小键帽。
/// 快捷键设置行与热键选择对话框共用同一套呈现，不再各写一遍。
class KeycapRow extends StatelessWidget {
  const KeycapRow({super.key, required this.keys, this.placeholder});

  final List<String> keys;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (keys.isEmpty) {
      final placeholder = this.placeholder;
      if (placeholder == null) return const SizedBox.shrink();
      return Text(placeholder, style: theme.textTheme.bodySmall);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final key in keys) _Keycap(label: key),
      ],
    );
  }
}

class _Keycap extends StatelessWidget {
  const _Keycap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
