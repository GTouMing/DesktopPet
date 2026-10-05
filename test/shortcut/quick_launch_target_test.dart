import 'dart:ui';

import 'package:desktop_pet/core/hit_shape.dart';
import 'package:desktop_pet/core/overlay_controller.dart';
import 'package:desktop_pet/shortcut/quick_launch_target.dart';
import 'package:flutter_test/flutter_test.dart';

PetHit _pet(String id, Rect rect, {bool locked = false}) =>
    (id: id, rect: rect, locked: locked, shape: const HitShape.rect());

void main() {
  const a = Rect.fromLTWH(0, 0, 100, 100);
  const b = Rect.fromLTWH(500, 500, 100, 100);

  test('光标在桌宠内 → 选中它', () {
    final target =
        findTargetPet([_pet('a', a), _pet('b', b)], const Offset(50, 50));
    expect(target?.petId, 'a');
  });

  test('光标在重叠区 → 选上层(列表靠后)', () {
    final target = findTargetPet(
      [
        _pet('lower', const Rect.fromLTWH(0, 0, 100, 100)),
        _pet('upper', const Rect.fromLTWH(50, 50, 100, 100)),
      ],
      const Offset(80, 80),
    );
    expect(target?.petId, 'upper');
  });

  test('光标不在任何桌宠内 → 取最近的', () {
    final target =
        findTargetPet([_pet('a', a), _pet('b', b)], const Offset(560, 560));
    expect(target?.petId, 'b');
  });

  test('锁定中的桌宠同样可作目标', () {
    final target =
        findTargetPet([_pet('a', a, locked: true)], const Offset(50, 50));
    expect(target?.petId, 'a');
  });

  test('场景里没有桌宠 → null', () {
    expect(findTargetPet(const [], const Offset(50, 50)), isNull);
  });
}
