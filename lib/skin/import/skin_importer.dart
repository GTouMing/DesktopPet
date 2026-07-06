import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'skin_validator.dart';
import 'skin_repository.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/skin_entry.dart';
import '../skin_lister.dart';

/// 皮肤包导入工具。
///
/// 支持将 `.zip` 文件解压到指定目录并注册到 [SkinRepository]。
///
/// ## 导入目标
/// - 全局路径为默认（asset）：解压到 `<app_documents>/imported_skins/<petId>/`
/// - 全局路径为自定义：解压到 `<skinDir>/<petId>/`
class SkinImporter {
  static Future<String> importZip({
    required String zipPath,
    required String petId,
  }) async {
    // 1. 读取 ZIP 文件
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('ZIP file not found: $zipPath');
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 2. 确定目标目录
    final settings = StorageService.readSettings();
    String destDir;
    if (SkinLister.isDefaultPath(settings.skinDir)) {
      destDir = '${(await getApplicationDocumentsDirectory()).path}/imported_skins/$petId';
    } else {
      destDir = '${settings.skinDir}/$petId';
    }

    // 3. 清理旧目录
    final dest = Directory(destDir);
    if (await dest.exists()) {
      await dest.delete(recursive: true);
    }

    // 4. 解压
    for (final entry in archive) {
      if (entry.isFile) {
        final outPath = '$destDir/${entry.name}';
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>);
      }
    }

    // 5. 校验
    final validation = await SkinValidator.validate(destDir);
    if (!validation.isValid) {
      await dest.delete(recursive: true);
      throw Exception('Invalid skin package: missing or malformed skin.json');
    }

    // 6. 注册到 Repository
    final skinRepo = SkinRepository();
    skinRepo.addSkin(SkinEntry(
      name: destDir.split('/').last,
      folderPath: destDir,
      isBuiltIn: false,
      importedAt: DateTime.now(),
    ));

    return destDir;
  }
}
