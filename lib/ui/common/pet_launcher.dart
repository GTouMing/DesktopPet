import 'package:flutter/material.dart';

import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import 'pet_edit_screen.dart';

/// 打开编辑页创建新桌宠，保存后自动创建窗口并刷新列表。
///
/// [onCreated] 中应调用 platform_factory 的 spawnPetWindow 打开新宠物的窗口。
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

  final withId = result.id.isEmpty
      ? result.copyWith(id: newPetId())
      : result;

  // 新桌宠默认坐标是 (0,0),多个会完全重叠成"只显示一个";按已有数量依次错开。
  final offset = 60.0 * StorageService.readPets().length;
  final petToAdd = withId.copyWith(
    positionX: 80 + offset,
    positionY: 80 + offset,
  );
  StorageService.addPet(petToAdd);
  onCreated();
  return true;
}
