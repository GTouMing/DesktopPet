import 'dart:convert';
import 'dart:io';

import '../core/constants.dart';
import '../l10n/l10n.dart';
import '../storage/storage_service.dart';
import 'import/pet_pack_repository.dart';

/// 发现的皮肤包信息。
class DiscoveredPetPack {
  final String name;
  final String path;
  final bool isBuiltIn;

  const DiscoveredPetPack({
    required this.name,
    required this.path,
    this.isBuiltIn = false,
  });
}

/// 扫描全局皮肤目录，收集可用皮肤包。
class PetPackLister {
  /// 是否使用默认路径（内置 asset）。
  static bool isDefaultPath(String? dir) =>
      dir == null || dir == defaultPackPath;

  /// 列出所有可用皮肤包。
  ///
  /// - 默认路径下：列出已导入的 + 内置默认皮肤
  /// - 自定义路径下：扫描该目录下的皮肤包 + 始终显示内置默认选项
  static Future<List<DiscoveredPetPack>> listAvailable() async {
    final settings = StorageService.readSettings();
    final dir = settings.packDir;
    final builtInName = l10nFor(settings.locale).defaultSkinName;
    final packs = <DiscoveredPetPack>[];
    final seen = <String>{};

    if (isDefaultPath(dir)) {
      // ── 默认路径：仅显示已导入的 ──────────────────────────────────────
      final repo = PetPackRepository();
      for (final entry in repo.listPacks()) {
        packs.add(DiscoveredPetPack(name: entry.name, path: entry.folderPath));
        seen.add(entry.folderPath);
      }
      // 内置默认皮肤始终在列表末尾
      if (!seen.contains(defaultPackPath)) {
        packs.add(DiscoveredPetPack(
          name: builtInName,
          path: defaultPackPath,
          isBuiltIn: true,
        ));
      }
    } else {
      // ── 自定义路径：扫描目录 + 内置默认选项 ────────────────────────────
      if (dir != null) {
        final dirObj = Directory(dir);
        if (await dirObj.exists()) {
          await for (final entity in dirObj.list()) {
            if (entity is Directory) {
              final name = await _readPackName(File('${entity.path}/skin.json'));
              if (name != null) {
                packs.add(DiscoveredPetPack(name: name, path: entity.path));
                seen.add(entity.path);
              }
            }
          }
        }
      }

      // 避免重复：排除已在列表中或路径不存在的
      final repo = PetPackRepository();
      for (final entry in repo.listPacks()) {
        if (!seen.contains(entry.folderPath)) {
          final dirObj = Directory(entry.folderPath);
          if (await dirObj.exists()) {
            packs.add(DiscoveredPetPack(name: entry.name, path: entry.folderPath));
            seen.add(entry.folderPath);
          }
        }
      }

      // 内置默认皮肤始终在列表末尾
      if (!seen.contains(defaultPackPath)) {
        packs.add(DiscoveredPetPack(
          name: builtInName,
          path: defaultPackPath,
          isBuiltIn: true,
        ));
      }
    }

    return packs;
  }

  /// 读取 skin.json 中的 name 字段，失败返回 null。
  static Future<String?> _readPackName(File packJson) async {
    try {
      if (!await packJson.exists()) return null;
      final json = jsonDecode(await packJson.readAsString());
      return json['name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
