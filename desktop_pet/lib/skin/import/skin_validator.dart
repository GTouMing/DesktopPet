import 'dart:convert';
import 'dart:io';

/// Result of a skin package structure validation check.
class SkinValidationResult {
  final bool isValid;
  final String? error;

  const SkinValidationResult({required this.isValid, this.error});
}

/// Validates that an extracted skin folder has correct structure and assets.
class SkinValidator {
  static Future<SkinValidationResult> validate(String extractedPath) async {
    final dir = Directory(extractedPath);
    if (!await dir.exists()) {
      return const SkinValidationResult(isValid: false, error: 'Extracted directory not found');
    }

    // Check skin.json
    final skinJsonFile = File('$extractedPath/skin.json');
    if (!await skinJsonFile.exists()) {
      return const SkinValidationResult(isValid: false, error: 'skin.json not found');
    }

    Map<String, dynamic> json;
    try {
      final content = await skinJsonFile.readAsString();
      json = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return SkinValidationResult(isValid: false, error: 'Invalid skin.json: $e');
    }

    // Required fields
    final requiredFields = ['name', 'version', 'frameWidth', 'frameHeight', 'animations'];
    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        return SkinValidationResult(isValid: false, error: 'Missing required field: $field');
      }
    }

    // Validate animations
    final anims = json['animations'] as Map<String, dynamic>;
    if (anims.isEmpty) {
      return const SkinValidationResult(isValid: false, error: 'No animations defined');
    }

    for (final entry in anims.entries) {
      final anim = entry.value as Map<String, dynamic>;
      final folder = anim['folder'] as String?;
      if (folder == null) {
        return SkinValidationResult(isValid: false, error: 'Animation "${entry.key}" missing folder');
      }

      final animDir = Directory('$extractedPath/$folder');
      if (!await animDir.exists()) {
        return SkinValidationResult(isValid: false, error: 'Animation folder not found: $folder');
      }

      // Check for at least one PNG
      final pngs = animDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .toList();

      if (pngs.isEmpty) {
        return SkinValidationResult(isValid: false, error: 'No frames found in $folder');
      }
    }

    return const SkinValidationResult(isValid: true);
  }
}
