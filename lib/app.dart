import 'dart:io';

import 'package:desktop_pet/l10n/app_localizations.dart';
import 'package:desktop_pet/l10n/l10n.dart';
import 'package:desktop_pet/storage/storage_service.dart';
import 'package:desktop_pet/ui/android/pet_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main.dart';
import 'ui/common/main_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/window_frame.dart';

/// 设置界面。
///
/// 两个平台共用同一套 UI，只是承载它们的窗口不同：
/// - Windows：独立的设置窗口（`ui/host/settings_window_root.dart`），自带自定义标题栏；
/// - Android：主 Activity。
class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ensureSupport();

    final locale = ref.watch(appDataProvider).global.locale;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: settingsLocale(locale),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      home: const MainScreen(),
      builder: (context, child) {
        return Platform.isWindows
            ? WindowFrame(child: child!)
            : child!;
      },
    );
  }
}

/// 单只桌宠悬浮窗的内容（仅 Android）。
///
/// Windows 下单只桌宠不是窗口，而是悬浮窗场景里的一个条目（见
/// `lib/pet/pet_view.dart`），没有对应的应用根。
class PetApp extends StatelessWidget {
  const PetApp({super.key});

  @override
  Widget build(BuildContext context) {
    ensureSupport();

    // 宠物窗口无界面文案(仅错误兜底),语言读一次即可,不做热切换。
    final locale = StorageService.readSettings().locale;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: settingsLocale(locale),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const AndroidPetOverlay(),
    );
  }
}
