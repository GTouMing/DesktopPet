import 'dart:ui' show Locale, PlatformDispatcher;

import '../core/constants.dart';
import 'app_localizations.dart';

/// 支持的界面语言。
///
/// 顺序即回退顺序:系统语言不在其中时,Flutter 取列表首项(中文)。
const List<Locale> appSupportedLocales = [Locale(localeZh), Locale(localeEn)];

/// 设置里的语言值 → `MaterialApp.locale`(null = 跟随系统)。
Locale? settingsLocale(String value) =>
    value == localeSystem ? null : Locale(value);

/// 解析实际生效的 locale(用于无 BuildContext 的场景:托盘、种子数据)。
Locale effectiveLocale(String value) {
  if (value == localeZh || value == localeEn) return Locale(value);
  final system = PlatformDispatcher.instance.locale;
  if (system.languageCode == localeZh) return const Locale(localeZh);
  if (system.languageCode == localeEn) return const Locale(localeEn);
  return const Locale(localeZh); // 回退中文
}

/// 无 BuildContext 获取翻译(托盘菜单、默认命名等)。
AppLocalizations l10nFor(String value) =>
    lookupAppLocalizations(effectiveLocale(value));
