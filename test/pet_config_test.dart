import 'dart:convert';

import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/storage/models/pet_config.dart';
import 'package:flutter_test/flutter_test.dart';

PetConfig _roundTrip(PetConfig pet) =>
    PetConfig.fromJson(jsonDecode(jsonEncode(pet.toJson())) as Map<String, dynamic>);

void main() {
  test('鼠标跟随强度 JSON 往返保留', () {
    final pet = PetConfig(id: 'p', name: 'p')
      ..mouseFollowX = 1.7
      ..mouseFollowY = 0.3;

    final restored = _roundTrip(pet);

    expect(restored.mouseFollowX, closeTo(1.7, 1e-9));
    expect(restored.mouseFollowY, closeTo(0.3, 1e-9));
  });

  test('缺省与非法跟随强度回 1.0', () {
    final restored = PetConfig.fromJson({'id': 'p', 'name': 'p'});

    expect(restored.mouseFollowX, 1.0);
    expect(restored.mouseFollowY, 1.0);
  });

  test('跟随强度越界被收敛到 [0, maxMouseFollow]', () {
    final tooLow = PetConfig.fromJson(
        {'id': 'p', 'name': 'p', 'mouseFollowX': -3.0});
    final tooHigh = PetConfig.fromJson(
        {'id': 'p', 'name': 'p', 'mouseFollowY': 9.0});

    expect(tooLow.mouseFollowX, 0.0);
    expect(tooHigh.mouseFollowY, maxMouseFollow);
  });

  test('snapped 跟随时按 0.1 步进取整', () {
    final pet = PetConfig(id: 'p', name: 'p')
      ..mouseFollowX = 1.234
      ..mouseFollowY = 0.96;

    expect(pet.snappedMouseFollowX, closeTo(1.2, 1e-9));
    expect(pet.snappedMouseFollowY, closeTo(1.0, 1e-9));
  });

  test('跟随轴绑定 JSON 往返；非法轴被过滤', () {
    final pet = PetConfig(id: 'p', name: 'p')
      ..mouseBindings = {'ParamMouthForm': 'x', 'ParamAngleZ': 'xy'};

    expect(_roundTrip(pet).mouseBindings,
        {'ParamMouthForm': 'x', 'ParamAngleZ': 'xy'});

    final filtered = PetConfig.fromJson({
      'id': 'p',
      'name': 'p',
      'mouseBindings': {'A': 'x', 'B': 'bogus', 'C': 3, 'D': 'xy'},
    });
    expect(filtered.mouseBindings, {'A': 'x', 'D': 'xy'});
  });
}
