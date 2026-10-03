import 'package:flutter/material.dart';

import '../../../storage/models/settings_model.dart';
import '../../../storage/storage_service.dart';

/// 设置分区的标题。
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// 分区之间的缩进分隔线。
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(),
      );
}

/// 设置写入的**唯一入口**。
///
/// 各分区一律经由它改设置，不再各自 `settings.xxx = v; writeSettings(settings)`——
/// 那样会改到 provider 缓存着的那份实例。
///
/// 写完就够了：[StorageService.changes] 会让 `appDataProvider` 自动重算，调用方
/// 不需要（也不应该）自己 invalidate。
void applySettings(SettingsModel Function(SettingsModel settings) transform) {
  StorageService.updateSettings(transform);
}
