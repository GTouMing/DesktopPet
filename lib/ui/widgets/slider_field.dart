import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'icon_plate.dart';

/// 「图标 + 标题 + 当前值 + 滑杆」的一行控件。
///
/// 外观设置与桌宠编辑页共用；当前值用胶囊徽标呈现，替代原先散落的灰字。
class SliderField extends StatelessWidget {
  const SliderField({
    super.key,
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.onChangeEnd,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.md + 2, Insets.lg, Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconPlate(
                icon: icon,
                tone: PlateTone.accent,
                size: 32,
                iconSize: 17,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Insets.sm),
              _ValueBadge(text: valueLabel),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            // 焦点态单独给：取得键盘焦点时墨色明显加重，和悬停区分开。
            overlayColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.focused)
                  ? context.appColors.focusRing.withValues(alpha: 0.30)
                  : Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12);
            }),
          ),
        ],
      ),
    );
  }
}

class _ValueBadge extends StatelessWidget {
  const _ValueBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm + 2, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
