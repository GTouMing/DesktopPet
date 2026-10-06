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

  test('跳过无法识别的组', () {
    final groups = L2dParamGroup.parse({
      'empty_options': {'options': []},
      'bad': 'nope',
      'no_options': {'label': 'x'},
    });
    expect(groups, isEmpty);
  });
}
