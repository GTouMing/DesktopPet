import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../storage/models/settings_model.dart';
import '../../widgets/info_overlay.dart';
import 'settings_common.dart';

/// 外观分区：全局缩放 / 不透明度（对所有桌宠生效）。
///
/// 拖动过程只改本地值，松手（onChangeEnd）才写存储——滑杆每帧都变，逐帧写盘没有
/// 意义，而且会在拖动时反复重建所有桌宠。
class AppearanceSection extends StatefulWidget {
  const AppearanceSection({super.key, required this.settings});

  final SettingsModel settings;

  @override
  State<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<AppearanceSection> {
  late double _opacity;
  late double _scale;

  @override
  void initState() {
    super.initState();
    _opacity = widget.settings.baseOpacity;
    _scale = widget.settings.baseScale;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SectionHeader(title: l10n.sectionAppearance),
        SliderTile(
          icon: Icons.opacity,
          label: l10n.globalOpacity((_opacity * 100).round()),
          value: _opacity,
          min: 0.2,
          max: 1.0,
          divisions: 8,
          onChanged: (v) => setState(() => _opacity = v),
          onChangeEnd: (v) => applySettings((s) => s.copyWith(baseOpacity: v)),
        ),
        SliderTile(
          icon: Icons.zoom_in,
          label: l10n.globalScale(_scale.toStringAsFixed(1)),
          value: _scale,
          min: 0.3,
          max: 3.0,
          divisions: 27,
          onChanged: (v) => setState(() => _scale = v),
          onChangeEnd: _commitScale,
        ),
      ],
    );
  }

  /// 缩放超过全局上限时拒绝写入并把滑杆弹回已保存的值。
  void _commitScale(double value) {
    final l10n = AppLocalizations.of(context);
    if (value > maxFinalScale) {
      setState(() => _scale = widget.settings.baseScale);
      InfoOverlay.show(context,
          title: l10n.scaleLimitExceeded(maxFinalScale.toStringAsFixed(1)));
      return;
    }
    applySettings((s) => s.copyWith(baseScale: value));
  }
}

/// 统一的「图标 + 标题 + 滑杆」行。
class SliderTile extends StatelessWidget {
  const SliderTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}
