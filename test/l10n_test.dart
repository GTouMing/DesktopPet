import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/l10n/app_localizations.dart';
import 'package:desktop_pet/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zh/en 翻译解析且互不相同', () {
    final zh = lookupAppLocalizations(const Locale(localeZh));
    final en = lookupAppLocalizations(const Locale(localeEn));

    expect(zh.settings, '设置');
    expect(en.settings, 'Settings');
    expect(zh.appName, '桌面宠物');
    expect(en.appName, 'Desktop Pet');
  });

  test('带参数的占位符消息', () {
    final zh = lookupAppLocalizations(const Locale(localeZh));
    final en = lookupAppLocalizations(const Locale(localeEn));

    expect(zh.myPets(3), '我的桌宠 (3)');
    expect(en.myPets(3), 'My pets (3)');
    expect(zh.globalOpacity(50), '全局透明度 — 50%');
    expect(en.skinLabel('foo'), 'Skin: foo');
  });

  test('语言设置解析: system 回退中文, 显式 zh/en 生效', () {
    expect(settingsLocale(localeSystem), isNull);
    expect(settingsLocale(localeEn), const Locale(localeEn));
    expect(settingsLocale(localeZh), const Locale(localeZh));
    expect(effectiveLocale(localeEn).languageCode, localeEn);
  });

  test('无 context 解析(l10nFor)', () {
    expect(l10nFor(localeEn).settings, 'Settings');
    expect(l10nFor(localeZh).settings, '设置');
  });
}
