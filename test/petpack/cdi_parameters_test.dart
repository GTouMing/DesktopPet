import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_pet/core/enums.dart';
import 'package:desktop_pet/petpack/live2d/cdi_parameters.dart';
import 'package:desktop_pet/petpack/live2d_pet_pack.dart';
import 'package:flutter_test/flutter_test.dart';

Live2DPetPack _pack(String basePath, String modelFile) => Live2DPetPack(
      name: 't',
      version: 1,
      baseSize: const Size(400, 400),
      basePath: basePath,
      source: PetPackSource.filesystem,
      modelDir: basePath,
      modelFileName: modelFile,
    );

void main() {
  test('读 model3.json 的 DisplayInfo → cdi3 清单（名缺省回 id、带分组）', () async {
    final dir = Directory.systemTemp.createTempSync('cdi_test');
    try {
      File('${dir.path}/m.model3.json').writeAsStringSync(jsonEncode({
        'FileReferences': {'DisplayInfo': 'sub/p.cdi3.json'},
      }));
      Directory('${dir.path}/sub').createSync();
      File('${dir.path}/sub/p.cdi3.json').writeAsStringSync(jsonEncode({
        'Parameters': [
          {'Id': 'ParamAngleX', 'Name': '角度 X', 'GroupId': 'ParamGroup2'},
          {'Id': 'NoName', 'GroupId': 'ParamGroup2'},
          {'Id': ''},
        ],
        'ParameterGroups': [
          {'Id': 'ParamGroup2', 'Name': '基础参数'},
        ],
      }));

      final cdi = await loadModelParameters(_pack(dir.path, 'm.model3.json'));
      expect(cdi.parameters.map((p) => p.id), ['ParamAngleX', 'NoName']);
      expect(cdi.parameters.first.name, '角度 X');
      expect(cdi.parameters.first.groupId, 'ParamGroup2');
      expect(cdi.parameters.last.name, 'NoName', reason: '无名回退 id');
      expect(cdi.groupNames['ParamGroup2'], '基础参数');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('无 DisplayInfo / 文件缺失 → 空表', () async {
    final dir = Directory.systemTemp.createTempSync('cdi_empty');
    try {
      File('${dir.path}/m.model3.json')
          .writeAsStringSync(jsonEncode({'FileReferences': <String, dynamic>{}}));
      expect(
          (await loadModelParameters(_pack(dir.path, 'm.model3.json'))).isEmpty,
          isTrue);
      expect(
          (await loadModelParameters(_pack(dir.path, 'missing.model3.json')))
              .isEmpty,
          isTrue);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
