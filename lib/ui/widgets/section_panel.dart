import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 分组面板：标题在面板之外，内容收进一块描边圆角面板。
///
/// 设置页与编辑页共用同一套"分组"语言，避免两处各写一遍标题样式与面板装饰。
class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    this.label,
    required this.child,
  });

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = this.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.xs, 0, Insets.xs, Insets.sm),
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
        SizedBox(
          width: double.infinity,
          // 必须是 Material 而不是带底色的 Container：面板里普遍是 ListTile，
          // 它们把底色与水波纹画在最近的 Material 上，隔着 DecoratedBox 会失效
          // （debug 下还会直接抛断言）。
          child: Material(
            color: scheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.panel),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
