import 'package:desktop_pet/petpack/live2d/l2d_param_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('枚举组：选项与默认值按 label 解析', () {
    final groups = L2dParamGroup.parse({
      'glasses': {
        'label': '眼镜',
        'default': '方眼镜',
        'options': [
          {'label': '无'},
          {'label': '圆眼镜', 'params': {'ParamCheek70': 1}},
          {'label': '方眼镜', 'params': {'ParamCheek72': 1}},
        ],
      },
    });

    expect(groups.length, 1);
    final g = groups.single;
    expect(g.id, 'glasses');
    expect(g.label, '眼镜');
    expect(g.isBool, isFalse);
    expect(g.options.map((o) => o.label), ['无', '圆眼镜', '方眼镜']);
    expect(g.defaultIndex, 2);
    expect(g.options[0].params, isEmpty);
    expect(g.options[1].params, {'ParamCheek70': 1.0});
    expect(g.allParamIds, {'ParamCheek70', 'ParamCheek72'});
  });

  test('枚举组：默认值按下标 / 缺省回退 0', () {
    final groups = L2dParamGroup.parse({
      'a': {
        'options': [
          {'label': 'x'},
          {'label': 'y'},
        ],
        'default': 1,
      },
      'b': {
        'options': [
          {'label': 'x'},
          {'label': 'y'},
        ],
      },
    });
    expect(groups[0].defaultIndex, 1);
    expect(groups[1].defaultIndex, 0);
    // 缺省 label 回退为 id。
    expect(groups[0].label, 'a');
  });

  test('bool 组：合成开/关两项，default 为布尔', () {
    final groups = L2dParamGroup.parse({
      'whale_top': {
        'label': '头顶鲸',
        'type': 'bool',
        'default': false,
        'params': {'jingyu': 1},
      },
      'on_by_params_only': {
        'params': {'foo': 0.5},
        'default': true,
      },
    });

    final whale = groups[0];
    expect(whale.isBool, isTrue);
    expect(whale.options.length, 2);
    expect(whale.options[0].params, isEmpty);
    expect(whale.options[1].params, {'jingyu': 1.0});
    expect(whale.defaultIndex, 0);
    // 只给 params 不给 options 也按 bool 处理。
    expect(groups[1].isBool, isTrue);
    expect(groups[1].defaultIndex, 1);
  });

  test('bool 组：offParams 显式给出"关"态参数（默认值本身是开时才能关掉）', () {
    final groups = L2dParamGroup.parse({
      'ear': {
        'label': '猫耳',
        'type': 'bool',
        'default': false,
        'params': {'Param23': 1},
        'offParams': {'Param23': 0},
      },
    });

    final ear = groups.single;
    expect(ear.isBool, isTrue);
    expect(ear.options.length, 2);
    expect(ear.options[0].params, {'Param23': 0.0});
    expect(ear.options[1].params, {'Param23': 1.0});
    expect(ear.defaultIndex, 0);
    expect(ear.allParamIds, {'Param23'});
  });

  test('effectiveIndex：状态覆盖按 label，覆盖不到用用户选择，再退回默认', () {
    final groups = L2dParamGroup.parse({
      'expression': {
        'label': '表情',
        'default': '默认',
        'options': [
          {'label': '默认'},
          {'label': '昏迷', 'params': {'Param10': 1}},
          {'label': '放松', 'params': {'Param11': 1}},
        ],
      },
      'ear': {'label': '猫耳', 'type': 'bool', 'default': false, 'params': {'Param23': 1}},
    });
    final expr = groups[0];
    final ear = groups[1];

    expect(expr.effectiveIndex(const {}, const {}), 0); // 默认
    expect(expr.effectiveIndex({'expression': 2}, const {}), 2); // 用户选择
    expect(expr.effectiveIndex({'expression': 2}, {'expression': '昏迷'}), 1); // 状态优先
    expect(expr.effectiveIndex({'expression': 2}, {'expression': '不存在'}), 2); // 解析不了→用户
    expect(expr.effectiveIndex({'expression': 99}, const {}), 2); // 越界收敛

    expect(ear.indexOfLabel('on'), 1);
    expect(ear.indexOfLabel('off'), 0);
    expect(ear.indexOfLabel('bogus'), -1);
    expect(ear.effectiveIndex(const {}, {'ear': 'on'}), 1);
    expect(ear.effectiveIndex(const {}, {'ear': 'off'}), 0);
  });

  test('跳过无法识别的组', () {
    final groups = L2dParamGroup.parse({
      'empty_options': {'options': []},
      'bad': 'nope',
      'no_options': {'label': 'x'},
    });
    expect(groups, isEmpty);
  });
}
