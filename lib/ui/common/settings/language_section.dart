import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/icon_plate.dart';
import '../../widgets/section_panel.dart';
import '../language_screen.dart';

/// 语言分区：显示当前语言，点进去选择。
class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key, required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return SectionPanel(
      label: l10n.sectionLanguage,
      child: ListTile(
        leading: const IconPlate(icon: Icons.language_rounded),
        title: Text(l10n.language),
        subtitle: Text(localeLabel(l10n, locale)),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LanguageScreen()),
        ),
      ),
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
