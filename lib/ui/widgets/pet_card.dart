
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import 'info_overlay.dart';

/// 桌宠卡片，内置锁定/可见性切换和删除逻辑。
class PetCard extends ConsumerWidget {
  final PetConfig pet;
  final VoidCallback onTap;

  const PetCard({super.key, required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildPetIcon(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${(pet.snappedScaleMultiplier * 100).round()}% · ${(pet.snappedOpacityMultiplier * 100).round()}%',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (pet.skinPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '皮肤: ${pet.skinPath.split('/').last}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                        pet.isLocked ? Icons.lock : Icons.lock_open,
                        size: 20),
                    color: pet.isLocked ? Colors.red : Colors.green,
                    tooltip: pet.isLocked ? '已锁定' : '已解锁',
                    onPressed: () => _toggleLock(ref),
                  ),
                  IconButton(
                    icon: Icon(
                        pet.isVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 20),
                    color: pet.isVisible ? Colors.green : Colors.grey,
                    tooltip: pet.isVisible ? '已显示' : '已隐藏',
                    onPressed: () => _toggleVisible(ref),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 30),
                    color: Colors.red.shade400,
                    tooltip: '删除',
                    onPressed: () => _delete(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetIcon(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: pet.isLocked && pet.isVisible
            ? theme.colorScheme.primaryContainer
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.auto_awesome,
        color: pet.isLocked && pet.isVisible
            ? theme.colorScheme.onPrimaryContainer
            : Colors.grey,
      ),
    );
  }

  void _toggleLock(WidgetRef ref) {
    final updated = pet.copyWith(isLocked: !pet.isLocked);
    StorageService.writePet(updated);
    ref.invalidate(appDataProvider);
    StorageService.onSettingsChanged?.call();
  }

  void _toggleVisible(WidgetRef ref) {
    final updated = pet.copyWith(isVisible: !pet.isVisible);
    StorageService.writePet(updated);
    ref.invalidate(appDataProvider);
    StorageService.onSettingsChanged?.call();
  }

  void _delete(BuildContext context, WidgetRef ref) {
    final pets = ref.read(appDataProvider).pets;
    if (pets.length <= 1) {
      InfoOverlay.show(context, title: '至少需要保留一个桌宠');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除桌宠'),
        content: Text('确定要删除「${pet.name}」吗？\n\n'
            '缩放: ${(pet.snappedScaleMultiplier * 100).round()}%'
            '\n透明度: ${(pet.snappedOpacityMultiplier * 100).round()}%'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              StorageService.removePet(pet.id);
              ref.invalidate(appDataProvider);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
