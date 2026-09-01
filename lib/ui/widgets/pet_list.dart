import 'package:flutter/material.dart';

import '../../storage/models/pet_config.dart';
import 'pet_card.dart';

/// 桌宠列表组件（含空状态处理）。
///
/// 显示标题头「我的桌宠 (N)」+ 桌宠卡片列表或空状态提示。
/// 卡片内的锁定/可见性切换和删除由 [PetCard] 自行处理。
class PetList extends StatelessWidget {
  final List<PetConfig> pets;
  final void Function(PetConfig pet) onTap;

  const PetList({
    super.key,
    required this.pets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.pets, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '我的桌宠 (${pets.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pets.isEmpty)
          _buildEmptyState(theme)
        else
          ...pets.map((pet) => PetCard(
                pet: pet,
                onTap: () => onTap(pet),
              )),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.pets, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('还没有添加桌宠',
                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 8),
            Text('点击右上角 + 按钮添加',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
