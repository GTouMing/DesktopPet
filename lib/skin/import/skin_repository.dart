import 'dart:io';

import '../../storage/storage_service.dart';
import '../../storage/models/skin_entry.dart';

/// Repository for querying and managing installed pet skin packages.
class SkinRepository {
  List<SkinEntry> listSkins() {
    return StorageService.readSkins();
  }

  Future<void> addSkin(SkinEntry entry) async {
    StorageService.addSkin(entry);
  }

  /// 将全部已导入皮肤复制到 [targetDir]。
  ///
  /// 仅在全局路径从默认切换到自定义时调用。复制后更新 SkinRepository 中的路径。
  Future<void> migrateTo(String targetDir) async {
    final entries = listSkins();
    final targetBase = Directory(targetDir);
    if (!await targetBase.exists()) {
      await targetBase.create(recursive: true);
    }

    for (final entry in entries) {
      final src = Directory(entry.folderPath);
      if (!await src.exists()) continue;

      final folderName = entry.folderPath.split('/').last;
      final dstPath = '$targetDir/$folderName';
      final dst = Directory(dstPath);

      // 同名目录已存在则跳过
      if (await dst.exists()) continue;

      // 递归复制
      await _copyDir(src, dst);

      // 更新注册路径
      StorageService.removeSkinByPath(entry.folderPath);
      StorageService.addSkin(SkinEntry(
        name: entry.name,
        folderPath: dstPath,
        isBuiltIn: entry.isBuiltIn,
        importedAt: entry.importedAt,
      ));
    }
  }

  static Future<void> _copyDir(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    await for (final entity in src.list()) {
      if (entity is File) {
        await entity.copy('${dst.path}/${entity.uri.pathSegments.last}');
      } else if (entity is Directory) {
        await _copyDir(
          entity,
          Directory('${dst.path}/${entity.uri.pathSegments.last}'),
        );
      }
    }
  }
}
