import 'dart:ui';

import 'package:desktop_pet/core/enums.dart';
import 'package:desktop_pet/petpack/live2d_pet_pack.dart';
import 'package:desktop_pet/petpack/state/state_define.dart';
import 'package:flutter_test/flutter_test.dart';

Live2DPetPack _pack(Map<String, StateDef> states) => Live2DPetPack(
      name: 't',
      version: 1,
      baseSize: const Size(400, 400),
      basePath: 'x',
      source: PetPackSource.filesystem,
      modelDir: 'x',
      modelFileName: 'm.model3.json',
      states: states,
    );

void main() {
  final states = {
    'idle': StateDef.fromJson('idle', <String, dynamic>{
      'animation': 'Idle',
      'transitions': <String, dynamic>{
        'morning': <String, dynamic>{'time': '09:00:00'},
        'night': <String, dynamic>{'time': '23:00:00'},
      },
    }),
  };

  test('findNextTimeAt：取最近的一个，已过的顺延到明天，正好到点立即触发', () {
    final pack = _pack(states);
    expect(pack.findNextTimeAt('idle', DateTime(2026, 1, 1, 8, 0, 0)),
        (const Duration(hours: 1), 'morning'));
    expect(pack.findNextTimeAt('idle', DateTime(2026, 1, 1, 10, 0, 0)),
        (const Duration(hours: 13), 'night'));
    expect(pack.findNextTimeAt('idle', DateTime(2026, 1, 1, 9, 0, 0)),
        (Duration.zero, 'morning'));
    expect(
        pack.findNextTimeAt('idle', DateTime(2026, 1, 1, 9, 0, 1)),
        (const Duration(hours: 13, minutes: 59, seconds: 59), 'night'));
  });

  test('findNextTimeAt：一条规则多个时刻时取最近的一个', () {
    final pack = _pack({
      'idle': StateDef.fromJson('idle', <String, dynamic>{
        'animation': 'Idle',
        'transitions': <String, dynamic>{
          'work_time': <String, dynamic>{
            'time': <String>['09:00:00', '14:00:00'],
          },
          'free_time': <String, dynamic>{
            'time': <String>['12:00:00', '18:00:00'],
          },
        },
      }),
    });

    expect(pack.findNextTimeAt('idle', DateTime(2026, 1, 1, 8, 30, 0)),
        (const Duration(minutes: 30), 'work_time'));
    expect(pack.findNextTimeAt('idle', DateTime(2026, 1, 1, 10, 0, 0)),
        (const Duration(hours: 2), 'free_time'));
    expect(pack.findNextTimeAt('idle', DateTime(2026, 1, 1, 13, 0, 0)),
        (const Duration(hours: 1), 'work_time'));
    expect(pack.findNextTimeAt('idle', DateTime(2026, 1, 1, 15, 0, 0)),
        (const Duration(hours: 3), 'free_time'));
  });

  test('findNextTimeAt：没有 time 迁移 / 状态不存在 → (null, null)', () {
    final pack = _pack({
      'idle': StateDef.fromJson('idle', <String, dynamic>{'animation': 'Idle'}),
    });
    expect(pack.findNextTimeAt('idle', DateTime(2026, 1, 1)), (null, null));
    expect(pack.findNextTimeAt('nope', DateTime(2026, 1, 1)), (null, null));
  });
}
