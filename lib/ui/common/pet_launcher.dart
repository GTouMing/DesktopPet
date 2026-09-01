import 'package:flutter/material.dart';

import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import 'pet_edit_screen.dart';

/// 打开编辑页创建新桌宠，保存后自动创建窗口并刷新列表。
///
/// [onCreated] 中应调用 [PetManager.open] 打开新宠物的窗口。
/// 返回 `true` 表示创建成功，`false` 表示用户取消。
Future<bool> createNewPet(
  BuildContext context, {
  required VoidCallback onCreated,
}) async {
  final newPet = PetConfig(id: '', name: '');

  final result = await Navigator.push<PetConfig>(
    context,
    MaterialPageRoute(
      builder: (_) => PetEditScreen(pet: newPet, isNewPet: true),
    ),
  );

  if (result == null) return false;

  final petToAdd = result.id.isEmpty
      ? result.copyWith(id: 'pet_${DateTime.now().millisecondsSinceEpoch}')
      : result;
  StorageService.addPet(petToAdd);
  onCreated();
  return true;
}
