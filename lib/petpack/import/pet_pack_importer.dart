import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'pet_pack_validator.dart';
import 'pet_pack_repository.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_pack_entry.dart';
import '../pet_pack_lister.dart';

/// 皮肤包导入工具。
///
/// 支持将 `.zip` 文件解压到指定目录并注册到 [PetPackRepository]。
///
/// ## 导入目标
/// - 全局路径为默认（asset）：解压到 `<app_documents>/imported_skins/<petId>/`
/// - 全局路径为自定义：解压到 `<packDir>/<petId>/`
class PetPackImporter {
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
    if (PetPackLister.isDefaultPath(settings.packDir)) {
      destDir = '${(await getApplicationDocumentsDirectory()).path}/imported_skins/$petId';
    } else {
      destDir = '${settings.packDir}/$petId';
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
    final validation = await PetPackValidator.validate(destDir);
    if (!validation.isValid) {
      await dest.delete(recursive: true);
      throw Exception('Invalid pet pack: missing or malformed skin.json');
    }

    // 6. 注册到 Repository
    final packRepo = PetPackRepository();
    packRepo.addPack(PetPackEntry(
      name: destDir.split('/').last,
      folderPath: destDir,
      isBuiltIn: false,
      importedAt: DateTime.now(),
    ));

    return destDir;
  }
}
