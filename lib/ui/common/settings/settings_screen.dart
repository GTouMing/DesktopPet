import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../storage/storage_service.dart';
import 'about_section.dart';
import 'appearance_section.dart';
import 'language_section.dart';
import 'settings_common.dart';
import 'shortcut_section.dart';
import 'pet_pack_section.dart';

/// 设置页：只负责按顺序拼装各分区。
///
/// 每个分区自带本地状态与写入逻辑（一律经 [applySettings]），页面本身不再持有任何
/// 设置状态，也不再直接操作 [StorageService]。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appDataProvider).global;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          AppearanceSection(settings: settings),
          const SectionDivider(),
          PetPackSection(settings: settings),
          // 全局热键与鼠标中键是桌面端独有能力，Android 整段隐藏。
          if (Platform.isWindows) ...[
            const SectionDivider(),
            ShortcutSection(settings: settings),
          ],
          const SectionDivider(),
          LanguageSection(locale: settings.locale),
          const SectionDivider(),
          const AboutSection(),
        ],
      ),
    );
  }
}
