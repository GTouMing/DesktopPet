import 'dart:convert';
import 'dart:io';

import '../../core/enums.dart';
import '../pet_pack.dart';

/// 宠物包结构校验结果。
class PetPackValidationResult {
  final bool isValid;
  final String? error;

  const PetPackValidationResult({required this.isValid, this.error});
}

/// 校验解压后的宠物包目录结构与资源。
///
/// 按 [PetPackDetector] 判别的类型分支：
/// - **精灵图包**：`animations` 每个动画目录至少一张 PNG；
/// - **Live2D 包**：`.model3.json` 存在，且其引用的 `.moc3` 与贴图都在。
///
/// 约束：Live2D 的 `.model3.json` 必须位于**包根目录**（`model` 只给文件名）。
/// 这样 `modelDir` 恒等于包根，插件要求的“目录 + 文件名”与模型内部的相对引用
/// 都能对上；放进子目录会同时打乱这两者，明确拒绝而不是猜。
class PetPackValidator {
  static Future<PetPackValidationResult> validate(String extractedPath) async {
    final dir = Directory(extractedPath);
    if (!await dir.exists()) {
      return const PetPackValidationResult(
          isValid: false, error: 'Extracted directory not found');
    }

    final json =
        await PetPack.readManifest(extractedPath, PetPackSource.filesystem);
    if (json == null) {
      return const PetPackValidationResult(
          isValid: false, error: 'pet.json not found');
    }

    for (final field in ['name', 'version', 'frameWidth', 'frameHeight']) {
      if (!json.containsKey(field)) {
        return PetPackValidationResult(
            isValid: false, error: 'Missing required field: $field');
      }
    }

    final type =
        PetPackDetector.detect(json, extractedPath, PetPackSource.filesystem);
    return type == PetPackType.live2d
        ? _validateLive2D(json, extractedPath)
        : _validateSprite(json, extractedPath);
  }

  static Future<PetPackValidationResult> _validateSprite(
    Map<String, dynamic> json,
    String path,
  ) async {
    final anims = json['animations'];
    if (anims is! Map<String, dynamic> || anims.isEmpty) {
      return const PetPackValidationResult(
          isValid: false, error: 'No animations defined');
    }

    for (final entry in anims.entries) {
      final anim = entry.value as Map<String, dynamic>;
      final folder = anim['folder'] as String?;
      if (folder == null || folder.isEmpty) {
        return PetPackValidationResult(
            isValid: false, error: 'Animation "${entry.key}" missing folder');
      }

      final animDir = Directory('$path/$folder');
      if (!await animDir.exists()) {
        return PetPackValidationResult(
            isValid: false, error: 'Animation folder not found: $folder');
      }

      final hasPng = animDir
          .listSync()
          .whereType<File>()
          .any((f) => f.path.toLowerCase().endsWith('.png'));
      if (!hasPng) {
        return PetPackValidationResult(
            isValid: false, error: 'No frames found in $folder');
      }
    }
    return const PetPackValidationResult(isValid: true);
  }

  static Future<PetPackValidationResult> _validateLive2D(
    Map<String, dynamic> json,
    String path,
  ) async {
    final declared = (json['model'] as String?)?.trim();
    final modelFile = (declared != null && declared.isNotEmpty)
        ? declared
        : PetPackDetector.findModel3FileName(path);

    if (modelFile == null || modelFile.isEmpty) {
      return const PetPackValidationResult(
          isValid: false, error: 'No *.model3.json found');
    }
    if (modelFile.contains('/') || modelFile.contains('\\')) {
      return const PetPackValidationResult(
          isValid: false,
          error: 'model must be a .model3.json file name at the pack root');
    }

    final modelFileHandle = File('$path/$modelFile');
    if (!await modelFileHandle.exists()) {
      return PetPackValidationResult(
          isValid: false, error: 'Model file not found: $modelFile');
    }

    final Map<String, dynamic> modelJson;
    try {
      modelJson = jsonDecode(await modelFileHandle.readAsString())
          as Map<String, dynamic>;
    } catch (e) {
      return PetPackValidationResult(
          isValid: false, error: 'Invalid $modelFile: $e');
    }

    final refs = modelJson['FileReferences'];
    if (refs is! Map<String, dynamic>) {
      return PetPackValidationResult(
          isValid: false, error: '$modelFile missing FileReferences');
    }

    final moc = refs['Moc'] as String?;
    if (moc == null || moc.isEmpty || !await File('$path/$moc').exists()) {
      return PetPackValidationResult(
          isValid: false, error: 'Model moc3 not found: $moc');
    }

    final textures = refs['Textures'];
    if (textures is List) {
      for (final texture in textures) {
        if (texture is String && !await File('$path/$texture').exists()) {
          return PetPackValidationResult(
              isValid: false, error: 'Texture not found: $texture');
        }
      }
    }

    return const PetPackValidationResult(isValid: true);
  }
}
