import 'dart:ui';

import '../core/overlay_controller.dart';

/// 环心目标：选中的桌宠，或兜底开环时没有目标宠物（`petId` 为 null）。
typedef RingTarget = ({String? petId, Rect rect});

/// 命中的桌宠（一定有 id）。
typedef PetTarget = ({String petId, Rect rect});

/// 在 [pets] 里挑环心：光标所在优先，否则取最近；[pets] 为空时返回 null。
///
/// 锁定中的桌宠同样可作目标——"锁定"只影响能否抓取，不影响选环心。
PetTarget? findTargetPet(List<PetHit> pets, Offset cursor) {
  if (pets.isEmpty) return null;

  // 光标所在优先：列表按绘制顺序，所以从上层往下找。
  for (final pet in pets.reversed) {
    if (pet.rect.contains(cursor)) return (petId: pet.id, rect: pet.rect);
  }

  PetTarget? nearest;
  var best = double.infinity;
  for (final pet in pets) {
    final distance = (pet.rect.center - cursor).distance;
    if (distance < best) {
      best = distance;
      nearest = (petId: pet.id, rect: pet.rect);
    }
  }
  return nearest;
}
