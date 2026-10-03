import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'settings_common.dart';

/// 关于分区：应用名与版本行。
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SectionHeader(title: l10n.sectionAbout),
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: ListTile(
            leading: const Icon(Icons.pets),
            title: Text(l10n.appName),
            subtitle:
                Text(l10n.versionLine(Platform.isAndroid ? 'Android' : 'Windows')),
          ),
        ),
      ],
    );
  }
}
