import 'package:flutter/material.dart';

import '../../storage/models/pet_config.dart';

class PetListTile extends StatelessWidget {
  final PetConfig pet;
  final VoidCallback onTap;
  final VoidCallback onToggleLocked;
  final VoidCallback onToggleVisible;
  final VoidCallback onDelete;

  const PetListTile({
    super.key,
    required this.pet,
    required this.onTap,
    required this.onToggleLocked,
    required this.onToggleVisible,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                    Text(pet.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${(pet.snappedScaleMultiplier * 100).round()}% · ${(pet.snappedOpacityMultiplier * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (pet.skinPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '皮肤: ${pet.skinPath.split('/').last}',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
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
                    icon: Icon(pet.isLocked ? Icons.lock : Icons.lock_open, size: 20),
                    color: pet.isLocked ? Colors.red : Colors.green,
                    tooltip: pet.isLocked ? '已锁定' : '已解锁',
                    onPressed: onToggleLocked,
                  ),
                  IconButton(
                    icon: Icon(pet.isVisible ? Icons.visibility : Icons.visibility_off, size: 20),
                    color: pet.isVisible ? Colors.green : Colors.grey,
                    tooltip: pet.isVisible ? '已显示' : '已隐藏',
                    onPressed: onToggleVisible,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 30),
                    color: Colors.red.shade400,
                    tooltip: '删除',
                    onPressed: onDelete,
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
        color: pet.isLocked && pet.isVisible ? theme.colorScheme.primaryContainer : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.auto_awesome,
        color: pet.isLocked && pet.isVisible ? theme.colorScheme.onPrimaryContainer : Colors.grey,
      ),
    );
  }
}
