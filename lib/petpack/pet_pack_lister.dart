import 'dart:io';

import '../core/constants.dart';
import '../core/enums.dart';
import '../l10n/l10n.dart';
import '../storage/storage_service.dart';
import 'import/pet_pack_repository.dart';
import 'pet_pack.dart';

/// 发现的一个宠物包（名称 / 路径 / 是否内置 / 渲染类型）。
class DiscoveredPetPack {
  final String name;
  final String path;
  final bool isBuiltIn;
  final PetPackType type;

  const DiscoveredPetPack({
    required this.name,
    required this.path,
    this.isBuiltIn = false,
    this.type = PetPackType.sprite,
  });
}

/// 扫描全局宠物包目录，收集可用宠物包。
class PetPackLister {
  /// 是否使用默认路径（内置 asset）。
  static bool isDefaultPath(String? dir) =>
      dir == null || dir == defaultPackPath;

  /// 列出所有可用宠物包。
  ///
  /// - 默认路径下：列出已导入的 + 内置默认宠物包
  /// - 自定义路径下：扫描该目录下的宠物包 + 始终显示内置默认选项
  static Future<List<DiscoveredPetPack>> listAvailable() async {
    final settings = StorageService.readSettings();
    final dir = settings.packDir;
    final builtInName = l10nFor(settings.locale).defaultPetPackName;
    final packs = <DiscoveredPetPack>[];
    final seen = <String>{};

    if (isDefaultPath(dir)) {
      // ── 默认路径：仅显示已导入的 ──────────────────────────────────────
      final repo = PetPackRepository();
      for (final entry in repo.listPacks()) {
        packs.add(DiscoveredPetPack(
          name: entry.name,
          path: entry.folderPath,
          type: await _detectType(entry.folderPath),
        ));
        seen.add(entry.folderPath);
      }
      // 内置默认宠物包始终在列表末尾
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
              final info = await _readPack(entity.path);
              if (info != null) {
                packs.add(DiscoveredPetPack(
                    name: info.name, path: entity.path, type: info.type));
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
            packs.add(DiscoveredPetPack(
              name: entry.name,
              path: entry.folderPath,
              type: await _detectType(entry.folderPath),
            ));
            seen.add(entry.folderPath);
          }
        }
      }

      // 内置默认宠物包始终在列表末尾
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

  /// 读取宠物包清单（`pet.json`）里的 name 与类型。
  static Future<({String name, PetPackType type})?> _readPack(String dir) async {
    try {
      final json = await PetPack.readManifest(dir, PetPackSource.filesystem);
      final name = json?['name'];
      if (json == null || name is! String) return null;
      return (
        name: name,
        type: PetPackDetector.detect(json, dir, PetPackSource.filesystem),
      );
    } catch (_) {
      return null;
    }
  }

  /// 推断目录里宠物包的类型；清单缺失或异常时按精灵图处理。
  static Future<PetPackType> _detectType(String dir) async {
    final info = await _readPack(dir);
    return info?.type ?? PetPackType.sprite;
  }
}
