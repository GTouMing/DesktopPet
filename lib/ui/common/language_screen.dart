import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../storage/storage_service.dart';

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
      appBar: AppBar(title: Text(l10n.language), centerTitle: true),
      body: ListView(
        children: [
          _option(context, localeSystem, l10n.languageSystem),
          _option(context, localeZh, l10n.languageChinese),
          _option(context, localeEn, l10n.languageEnglish),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, String value, String label) {
    return ListTile(
      title: Text(label),
      trailing: _locale == value ? const Icon(Icons.check) : null,
      onTap: () => _select(value),
    );
  }
}
