import 'package:desktop_pet/pet/live2d/mouse_follow.dart';
import 'package:desktop_pet/pet/live2d/model_parameter.dart';
import 'package:flutter_test/flutter_test.dart';

ModelParameter _p(
  String id, {
  double min = 0,
  double max = 0,
  double def = 0,
}) =>
    ModelParameter(id: id, minimum: min, maximum: max, defaultValue: def);

void main() {
  test('只挑模型存在的标准跟随参数，scale 取范围、base 取默认', () {
    final follow = buildMouseFollow([
      _p('ParamAngleX', min: -30, max: 30),
      _p('ParamAngleY', min: -30, max: 30, def: 5),
      _p('ParamAngleZ', min: -30, max: 30),
      _p('ParamEyeBallX', min: -1, max: 1),
      _p('ParamMouthOpenY', min: 0, max: 1), // 非标准：忽略
    ]);

    expect(follow.x.map((m) => m.param), ['ParamAngleX', 'ParamEyeBallX']);
    expect(follow.x.first.scale, 30.0);
    expect(follow.x.last.scale, 1.0);
    expect(follow.y.single.param, 'ParamAngleY');
    expect(follow.y.single.base, 5.0, reason: '默认值作中性基线');
    expect(follow.xy.single.param, 'ParamAngleZ');
    expect(follow.xy.single.scale, -30.0, reason: 'AngleZ 取负号（头部倾斜约定）');
  });

  test('ParamBodyAngleX 归到 x 轴', () {
    final follow =
        buildMouseFollow([_p('ParamBodyAngleX', min: -10, max: 10)]);
    expect(follow.x.single.param, 'ParamBodyAngleX');
    expect(follow.x.single.scale, 10.0);
  });

  test('模型没有标准参数 → 三轴皆空', () {
    final follow = buildMouseFollow([_p('ParamMouthOpenY', min: 0, max: 1)]);
    expect(follow.isEmpty, isTrue);
  });

  test('空入参 → 空映射', () {
    expect(buildMouseFollow(const []).isEmpty, isTrue);
  });

  test('退化范围兜底：半径 0 时用默认值量级，再不行用 1', () {
    final zero = buildMouseFollow([_p('ParamAngleX')]);
    expect(zero.x.single.scale, 1.0);

    final fromDefault = buildMouseFollow([_p('ParamAngleX', def: 3)]);
    expect(fromDefault.x.single.scale, 3.0);
  });

  test('显式绑定：只取被绑且模型存在的参数，scale 取范围、base 取默认', () {
    final params = [
      _p('ParamAngleX', min: -30, max: 30),
      _p('ParamMouthForm', min: -1, max: 1),
      _p('ParamMouthOpenY', min: 0, max: 1, def: 0),
      _p('ParamAngleZ', min: -30, max: 30),
    ];
    final follow = buildMouseFollowFromBindings({
      'ParamMouthForm': 'x',
      'ParamMouthOpenY': 'y',
      'ParamAngleZ': 'xy',
      'ParamAngleX': 'x',
      'NotInModel': 'x', // 模型没有：跳过
    }, params);

    expect(follow.x.map((m) => m.param), ['ParamMouthForm', 'ParamAngleX']);
    expect(follow.x.first.scale, 1.0);
    expect(follow.x.last.scale, 30.0);
    expect(follow.y.single.param, 'ParamMouthOpenY');
    expect(follow.xy.single.param, 'ParamAngleZ');
    expect(follow.xy.single.scale, -30.0, reason: 'ParamAngleZ 归 xy 仍取负号');
  });

  test('显式绑定：空表或空模型 → 空映射', () {
    expect(buildMouseFollowFromBindings(const {}, [_p('ParamAngleX')]).isEmpty,
        isTrue);
    expect(
        buildMouseFollowFromBindings({'ParamAngleX': 'x'}, const []).isEmpty,
        isTrue);
  });

  test('轴向标记：id 或名含大写 X/Y/Z（小写不算）', () {
    expect(hasFollowAxisLetter('ParamAngleX', '角度 X'), isTrue);
    expect(hasFollowAxisLetter('ParamEyeBallY', '眼珠 Y'), isTrue);
    expect(hasFollowAxisLetter('Param', '角度 Z2'), isTrue, reason: '名带 Z');
    expect(hasFollowAxisLetter('ParamMouthOpenY', '嘴　张开和闭合'), isTrue);
    // 小写不算；无轴字母不算。
    expect(hasFollowAxisLetter('Param_Angle_Rotation_1_xk4', '[0]xk'), isFalse);
    expect(hasFollowAxisLetter('ParamMouthForm', '嘴　变形'), isFalse);
    expect(hasFollowAxisLetter('ParamHairFront5', 'hair_f_mA'), isFalse);
  });
}
