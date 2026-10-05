
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_factory.dart';
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
    final l10n = AppLocalizations.of(context);
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
                    if (pet.packPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l10n.petPackLabel(pet.packPath.split('/').last),
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
                    tooltip: pet.isLocked ? l10n.locked : l10n.unlocked,
                    onPressed: () => _toggleLock(),
                  ),
                  IconButton(
                    icon: Icon(
                        pet.isVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 20),
                    color: pet.isVisible ? Colors.green : Colors.grey,
                    tooltip: pet.isVisible ? l10n.shown : l10n.hidden,
                    onPressed: () => _toggleVisible(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 30),
                    color: Colors.red.shade400,
                    tooltip: l10n.delete,
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

  void _toggleLock() {
    final updated = pet.copyWith(isLocked: !pet.isLocked);
    StorageService.writePet(updated);
  }

  void _toggleVisible() {
    // 以**存储里的当前值**为基准翻转,而不是 widget 上的 `pet`:
    // 后者是上一次重建的快照,重建被拖慢时连续快速点击会反复算出同一个目标值,
    // 于是点 N 次只生效一次、甚至方向相反。
    final current = StorageService.readPet(pet.id);
    if (current == null) return;
    final updated = current.copyWith(isVisible: !current.isVisible);
    StorageService.writePet(updated);
  }

  void _delete(BuildContext context, WidgetRef ref) {
    final pets = ref.read(appDataProvider).pets;
    if (pets.length <= 1) {
      InfoOverlay.show(context,
          title: AppLocalizations.of(context).keepOnePet);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.deletePetTitle),
          content: Text(l10n.deletePetBody(
            pet.name,
            (pet.snappedScaleMultiplier * 100).round(),
            (pet.snappedOpacityMultiplier * 100).round(),
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                StorageService.removePet(pet.id);
                Navigator.pop(ctx);
                // 仅 Android 需要回收悬浮窗引擎;Windows 上桌宠是悬浮窗场景里的
                // 条目,随存储广播一起消失。
                closePetWindow(pet.id);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }
}
