import 'package:desktop_pet/core/enums.dart';
import 'package:desktop_pet/petpack/live2d_pet_pack.dart';
import 'package:flutter_test/flutter_test.dart';

/// 最小可用清单：只带 [Live2DPetPack.fromJson] 需要的必填项。
Map<String, dynamic> manifest({Object? scale, Object? translate}) => {
      'name': 'pack',
      'type': 'live2d',
      'version': 1,
      'frameWidth': 400,
      'frameHeight': 400,
      'model': 'm.model3.json',
      'scale': ?scale,
      'translate': ?translate,
    };

Live2DPetPack parse(Map<String, dynamic> json) =>
    Live2DPetPack.fromJson(json, '/tmp/pack', PetPackSource.filesystem);

void main() {
  test('构图缺省：scale = 1、translate = 0', () {
    final pack = parse(manifest());
    expect(pack.scale, 1);
    expect(pack.translateX, 0);
    expect(pack.translateY, 0);
  });

  test('构图按清单解析：scale 乘在自动适配之上，translate 是盒子逻辑像素', () {
    final pack = parse(manifest(scale: 1.25, translate: {'x': -12, 'y': 30.5}));
    expect(pack.scale, 1.25);
    expect(pack.translateX, -12);
    expect(pack.translateY, 30.5);
  });

  test('构图非法值回默认：scale 必须 >0 且 ≤10，translate 非数字按 0', () {
    expect(parse(manifest(scale: 0)).scale, 1);
    expect(parse(manifest(scale: 11)).scale, 1);
    expect(parse(manifest(scale: 'big')).scale, 1);

    final odd = parse(manifest(translate: {'x': 'left', 'y': 4}));
    expect(odd.translateX, 0);
    expect(odd.translateY, 4);

    final notAMap = parse(manifest(translate: 'nope'));
    expect(notAMap.translateX, 0);
    expect(notAMap.translateY, 0);
  });
}
