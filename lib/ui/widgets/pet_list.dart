import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../storage/models/pet_config.dart';
import '../theme/app_theme.dart';
import 'pet_card.dart';

/// 桌宠住客清单（含空状态处理）。
///
/// 只负责排布与空状态；磁贴内的锁定/显隐切换和删除由 [PetCard] 自行处理。
class PetList extends StatelessWidget {
  final List<PetConfig> pets;
  final void Function(PetConfig pet) onTap;
  final VoidCallback onAdd;

  const PetList({
    super.key,
    required this.pets,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) return _EmptyState(onAdd: onAdd);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      itemCount: pets.length,
      separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
      itemBuilder: (context, index) {
        final pet = pets[index];
        return PetCard(
          key: ValueKey(pet.id),
          pet: pet,
          onTap: () => onTap(pet),
        );
      },
    );
  }
}

/// 空状态：说明这里该有什么，并直接给出唯一该做的动作。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.xl, vertical: Insets.xxl),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Radii.panel),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pets_rounded,
                  size: 32,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: Insets.lg),
              Text(
                l10n.noPets,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                l10n.noPetsHint,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.xl),
              FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.addPet),
                // 唯一的 tonal 调用点：浅橄榄填充用它的前景色做环。主题里那条
                // 白环是给蜜色主填充的，落在浅底上会消失。
                style: ButtonStyle(
                  side: AppTheme.focusRing(scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
