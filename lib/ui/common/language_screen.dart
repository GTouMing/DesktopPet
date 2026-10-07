import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../storage/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_plate.dart';
import '../widgets/section_panel.dart';

/// 语言选择界面(设置 → 语言)。
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _locale;

  @override
  void initState() {
    super.initState();
    _locale = StorageService.readSettings().locale;
  }

  Future<void> _select(String value) async {
    if (_locale != value) {
      setState(() => _locale = value);
      // 托盘菜单的语言由悬浮窗引擎自己跟着设置变更刷新（见 AppHost），此处只是
      // 一次普通写入：设置窗口写完会通知悬浮窗重读。
      StorageService.updateSettings((s) => s.copyWith(locale: value));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(l10n.language)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.sm, Insets.lg, Insets.xxl),
        children: [
          SectionPanel(
            label: l10n.sectionLanguage,
            child: Column(
              children: [
                _option(context, localeSystem, l10n.languageSystem),
                const Divider(height: 1),
                _option(context, localeZh, l10n.languageChinese),
                const Divider(height: 1),
                _option(context, localeEn, l10n.languageEnglish),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _locale == value;

    return ListTile(
      onTap: () => _select(value),
      leading: IconPlate(
        icon: Icons.language_rounded,
        tone: selected ? PlateTone.accent : PlateTone.neutral,
      ),
      title: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: selected ? scheme.primary : scheme.onSurface,
        ),
      ),
      trailing: selected
          ? Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  size: 16, color: scheme.onPrimary),
            )
          : null,
    );
  }
}
