import 'dart:convert';
import 'dart:io';

import '../core/constants.dart';
import '../storage/storage_service.dart';
import 'import/skin_repository.dart';

/// 发现的皮肤包信息。
class DiscoveredSkin {
  final String name;
  final String path;
  final bool isBuiltIn;

  const DiscoveredSkin({
    required this.name,
    required this.path,
    this.isBuiltIn = false,
  });
}

/// 扫描全局皮肤目录，收集可用皮肤包。
class SkinLister {
  /// 是否使用默认路径（内置 asset）。
  static bool isDefaultPath(String? dir) =>
      dir == null || dir == defaultSkinPath;

  /// 列出所有可用皮肤包。
  ///
  /// - 默认路径下：列出已导入的 + 内置默认皮肤
  /// - 自定义路径下：扫描该目录下的皮肤包 + 始终显示内置默认选项
  static Future<List<DiscoveredSkin>> listAvailable() async {
    final settings = StorageService.readSettings();
    final dir = settings.skinDir;
    final skins = <DiscoveredSkin>[];
    final seen = <String>{};

    if (isDefaultPath(dir)) {
      // ── 默认路径：仅显示已导入的 ──────────────────────────────────────
      final repo = SkinRepository();
      for (final entry in repo.listSkins()) {
        skins.add(DiscoveredSkin(name: entry.name, path: entry.folderPath));
        seen.add(entry.folderPath);
      }
      // 内置默认皮肤始终在列表末尾
      if (!seen.contains(defaultSkinPath)) {
        skins.add(const DiscoveredSkin(
          name: '默认皮肤',
          path: defaultSkinPath,
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
              final name = await _readSkinName(File('${entity.path}/skin.json'));
              if (name != null) {
                skins.add(DiscoveredSkin(name: name, path: entity.path));
                seen.add(entity.path);
              }
            }
          }
        }
      }

      // 避免重复：排除已在列表中或路径不存在的
      final repo = SkinRepository();
      for (final entry in repo.listSkins()) {
        if (!seen.contains(entry.folderPath)) {
          final dirObj = Directory(entry.folderPath);
          if (await dirObj.exists()) {
            skins.add(DiscoveredSkin(name: entry.name, path: entry.folderPath));
            seen.add(entry.folderPath);
          }
        }
      }

      // 内置默认皮肤始终在列表末尾
      if (!seen.contains(defaultSkinPath)) {
        skins.add(const DiscoveredSkin(
          name: '默认皮肤',
          path: defaultSkinPath,
          isBuiltIn: true,
        ));
      }
    }

    return skins;
  }

  /// 读取 skin.json 中的 name 字段，失败返回 null。
  static Future<String?> _readSkinName(File skinJson) async {
    try {
      if (!await skinJson.exists()) return null;
      final json = jsonDecode(await skinJson.readAsString());
      return json['name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
