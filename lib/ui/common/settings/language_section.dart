import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../language_screen.dart';
import 'settings_common.dart';

/// 语言分区：显示当前语言，点进去选择。
class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key, required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SectionHeader(title: l10n.sectionLanguage),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.language),
          subtitle: Text(localeLabel(l10n, locale)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LanguageScreen()),
          ),
        ),
      ],
    );
  }
}

/// 语言值 → 显示名。
String localeLabel(AppLocalizations l10n, String value) {
  switch (value) {
    case localeZh:
      return l10n.languageChinese;
    case localeEn:
      return l10n.languageEnglish;
    default:
      return l10n.languageSystem;
  }
}
