import 'dart:io';

import 'package:desktop_pet/petpack/live2d_pet_pack.dart';
import 'package:desktop_pet/petpack/pet_pack.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可调参数槽位（原先清单顶层 `params`）已拆到包根的 `params.json`。
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('petpack_params_');
    // 清单里**故意**留了一份内联 `params`：拆分后它不再被读取。
    File('${dir.path}/pet.json').writeAsStringSync('''
{
  "name": "t",
  "type": "live2d",
  "version": 1,
  "frameWidth": 400,
  "frameHeight": 400,
  "model": "m.model3.json",
  "params": { "inline_only": { "type": "bool", "params": { "P": 1 } } }
}
''');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('params.json 提供可调槽位组（清单内联 params 被忽略）', () async {
    File('${dir.path}/params.json').writeAsStringSync('''
{
  "eye": { "label": "眼", "type": "bool", "default": false, "params": { "ParamEyeLOpen": 0 } }
}
''');

    final pack = await PetPack.load(dir.path) as Live2DPetPack;

    expect(pack.paramGroups.map((g) => g.id), ['eye']);
    expect(pack.paramGroups.single.label, '眼');
    expect(pack.paramGroups.single.isBool, isTrue);
  });

  test('没有 params.json ⇒ 没有可调项', () async {
    final pack = await PetPack.load(dir.path) as Live2DPetPack;
    expect(pack.paramGroups, isEmpty);
  });

  test('params.json 非法 JSON ⇒ 视为没有可调项，不抛异常', () async {
    File('${dir.path}/params.json').writeAsStringSync('{ not json');
    final pack = await PetPack.load(dir.path) as Live2DPetPack;
    expect(pack.paramGroups, isEmpty);
  });
}
