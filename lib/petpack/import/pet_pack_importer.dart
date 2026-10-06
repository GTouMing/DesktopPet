import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'pet_pack_validator.dart';
import 'pet_pack_repository.dart';
import 'zip_layout.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_pack_entry.dart';
import '../pet_pack_lister.dart';

/// 宠物包导入工具。
///
/// 支持将 `.zip` 文件解压到指定目录并注册到 [PetPackRepository]。
///
/// ## 导入目标
/// - 全局路径为默认（asset）：解压到 `<app_documents>/imported_pet_packs/<petId>/`
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
      destDir = '${(await getApplicationDocumentsDirectory()).path}/imported_pet_packs/$petId';
    } else {
      destDir = '${settings.packDir}/$petId';
    }

    // 3. 清理旧目录
    final dest = Directory(destDir);
    if (await dest.exists()) {
      await dest.delete(recursive: true);
    }

    // 4. 解压
    //
    // 条目名统一规范化（`\`→`/`，挡掉越界路径，见 [normalizeZipEntryName]），并在
    // 解压前剥掉"整包再套一层同名目录"的包装层（见 [singleRootPrefix]）——否则
    // pet.json 会落在多出来的那一层之下，校验随即以 "pet.json not found" 失败。
    final names = <String>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = normalizeZipEntryName(entry.name);
      if (name != null) names.add(name);
    }
    final stripPrefix = singleRootPrefix(names);

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final normalized = normalizeZipEntryName(entry.name);
      if (normalized == null) continue;

      final name = normalized.substring(stripPrefix.length);
      if (name.isEmpty) continue;

      final outFile = File('$destDir/$name');
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>);
    }

    // 5. 校验（透出校验器的具体原因，别用一句笼统的“缺 pet.json”盖掉）
    final validation = await PetPackValidator.validate(destDir);
    if (!validation.isValid) {
      await dest.delete(recursive: true);
      throw Exception('Invalid pet pack: ${validation.error ?? 'unknown error'}');
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
