import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/icon_plate.dart';
import '../../widgets/section_panel.dart';

/// 关于分区：应用名与版本行。
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionPanel(
      label: l10n.sectionAbout,
      child: ListTile(
        leading: const IconPlate(icon: Icons.pets_rounded, tone: PlateTone.accent),
        title: Text(l10n.appName),
        subtitle: Text(
            l10n.versionLine(Platform.isAndroid ? 'Android' : 'Windows')),
      ),
    );
  }
}
