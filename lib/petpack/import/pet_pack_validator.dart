import 'dart:convert';
import 'dart:io';

/// Result of a pet pack structure validation check.
class PetPackValidationResult {
  final bool isValid;
  final String? error;

  const PetPackValidationResult({required this.isValid, this.error});
}

/// Validates that an extracted pet pack folder has correct structure and assets.
class PetPackValidator {
  static Future<PetPackValidationResult> validate(String extractedPath) async {
    final dir = Directory(extractedPath);
    if (!await dir.exists()) {
      return const PetPackValidationResult(isValid: false, error: 'Extracted directory not found');
    }

    // Check skin.json
    final packJsonFile = File('$extractedPath/skin.json');
    if (!await packJsonFile.exists()) {
      return const PetPackValidationResult(isValid: false, error: 'skin.json not found');
    }

    Map<String, dynamic> json;
    try {
      final content = await packJsonFile.readAsString();
      json = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return PetPackValidationResult(isValid: false, error: 'Invalid skin.json: $e');
    }

    // Required fields
    final requiredFields = ['name', 'version', 'frameWidth', 'frameHeight', 'animations'];
    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        return PetPackValidationResult(isValid: false, error: 'Missing required field: $field');
      }
    }

    // Validate animations
    final anims = json['animations'] as Map<String, dynamic>;
    if (anims.isEmpty) {
      return const PetPackValidationResult(isValid: false, error: 'No animations defined');
    }

    for (final entry in anims.entries) {
      final anim = entry.value as Map<String, dynamic>;
      final folder = anim['folder'] as String?;
      if (folder == null) {
        return PetPackValidationResult(isValid: false, error: 'Animation "${entry.key}" missing folder');
      }

      final animDir = Directory('$extractedPath/$folder');
      if (!await animDir.exists()) {
        return PetPackValidationResult(isValid: false, error: 'Animation folder not found: $folder');
      }

      // Check for at least one PNG
      final pngs = animDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .toList();

      if (pngs.isEmpty) {
        return PetPackValidationResult(isValid: false, error: 'No frames found in $folder');
      }
    }

    return const PetPackValidationResult(isValid: true);
  }
}
