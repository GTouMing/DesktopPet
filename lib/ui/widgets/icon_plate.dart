import 'package:flutter/material.dart';

/// 图标底板的语义色调。
enum PlateTone { accent, neutral, danger }

/// 图标底板：把裸图标放进一块圆角底色里，统一各处的"图标锚点"观感。
///
/// 全工程只此一处决定图标的底色/前景配色，避免各屏各自 `Colors.grey[100]`。
class IconPlate extends StatelessWidget {
  const IconPlate({
    super.key,
    required this.icon,
    this.tone = PlateTone.neutral,
    this.size = 36,
    this.iconSize,
  });

  final IconData icon;
  final PlateTone tone;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (Color background, Color foreground) = switch (tone) {
      PlateTone.accent => (scheme.primaryContainer, scheme.onPrimaryContainer),
      PlateTone.neutral => (scheme.surfaceContainerHigh, scheme.onSurfaceVariant),
      PlateTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.52, color: foreground),
    );
  }
}
