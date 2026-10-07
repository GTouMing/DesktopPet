/// Live2D 可调参数：把"表情/配件"建模成**参数组**。
///
/// 为什么需要它：本应用原先把表情交给 Cubism 表达式管理器（一次只生效一个），
/// 而很多模型（如 ds-whale-girl）的表情是按"每个表情只驱动自己的专属参数、可叠加"
/// 设计的（眼镜 + 情绪 + 配件本应同时存在）。于是改用参数覆盖：清单按**组**声明
/// 互斥选项，用户逐组选择，不同组叠加生效、组内自动互斥。
///
/// 清单格式（`pet.json` 顶层 `params`）：
/// ```json
/// "params": {
///   "glasses": {
///     "label": "眼镜", "default": "无",
///     "options": [
///       { "label": "无" },
///       { "label": "圆眼镜", "params": { "ParamCheek70": 1 } }
///     ]
///   },
///   "whale_top": {
///     "label": "头顶鲸", "type": "bool", "default": false,
///     "params": { "jingyu": 1 }
///   },
///   "ear": {
///     "label": "猫耳", "type": "bool", "default": false,
///     "params": { "Param23": 1 }, "offParams": { "Param23": 0 }
///   }
/// }
/// ```
///
/// bool 组默认「开 = 写 `params`、关 = 复位模型默认值」。但有的部件模型默认值本身就是
/// "开"（例如猫耳 `Param23` 默认 `1`），复位默认值 = 又开回来、关不掉；此时用可选的
/// `offParams` 显式给出"关"态要写的参数。
library;

/// 组内的一个互斥选项：选择它时写入 [params]（空 = "无"，不写任何参数）。
class L2dParamOption {
  const L2dParamOption({required this.label, required this.params});

  final String label;
  final Map<String, double> params;
}

/// 一个可调参数组（对应编辑 UI 里的一个控件）。
class L2dParamGroup {
  const L2dParamGroup({
    required this.id,
    required this.label,
    required this.isBool,
    required this.options,
    required this.defaultIndex,
  });

  /// 组 id（也用作 `PetConfig.paramChoices` 的 key）。
  final String id;

  /// 显示名（清单缺省时回退为 [id]）。
  final String label;

  /// `true` = 二态开关（UI 用 Switch）；否则为枚举（UI 用下拉）。
  final bool isBool;

  /// 互斥选项；bool 组固定为两项（0 关 / 1 开，label 为空）。
  final List<L2dParamOption> options;

  /// 未选择时的默认选项下标。
  final int defaultIndex;

  /// 该组**所有**选项写入的参数 id 并集。切换选项时，未选中的那些要复位为 0，
  /// 组内互斥才成立。
  Set<String> get allParamIds =>
      {for (final o in options) ...o.params.keys};

  /// 解析清单里的 `params`（map），跳过无法识别的组。
  static List<L2dParamGroup> parse(Object? raw) {
    if (raw is! Map) return const [];
    final groups = <L2dParamGroup>[];
    for (final entry in raw.entries) {
      final group = _parseGroup(entry.key.toString(), entry.value);
      if (group != null) groups.add(group);
    }
    return groups;
  }

  static L2dParamGroup? _parseGroup(String id, Object? spec) {
    if (id.isEmpty || spec is! Map) return null;
    final label = spec['label'] is String && (spec['label'] as String).isNotEmpty
        ? spec['label'] as String
        : id;

    final isBool = spec['type'] == 'bool' ||
        (spec.containsKey('params') && !spec.containsKey('options'));
    if (isBool) {
      final on = _parseParams(spec['params']);
      final off = _parseParams(spec['offParams']);
      return L2dParamGroup(
        id: id,
        label: label,
        isBool: true,
        options: [
          L2dParamOption(label: '', params: off),
          L2dParamOption(label: '', params: on),
        ],
        defaultIndex: spec['default'] == true ? 1 : 0,
      );
    }

    final rawOptions = spec['options'];
    if (rawOptions is! List || rawOptions.isEmpty) return null;
    final options = <L2dParamOption>[];
    for (final o in rawOptions) {
      if (o is! Map) continue;
      final oLabel = o['label'] is String ? o['label'] as String : '';
      options.add(L2dParamOption(label: oLabel, params: _parseParams(o['params'])));
    }
    if (options.isEmpty) return null;
    return L2dParamGroup(
      id: id,
      label: label,
      isBool: false,
      options: options,
      defaultIndex: _resolveDefault(spec['default'], options),
    );
  }

  /// `default` 可以是选项 label（优先）或下标；无法解析时回退 0。
  static int _resolveDefault(Object? raw, List<L2dParamOption> options) {
    if (raw is String) {
      final i = options.indexWhere((o) => o.label == raw);
      if (i >= 0) return i;
      return 0;
    }
    if (raw is num) {
      final i = raw.toInt();
      return i >= 0 && i < options.length ? i : 0;
    }
    return 0;
  }

  static Map<String, double> _parseParams(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, double>{};
    for (final e in raw.entries) {
      final key = e.key.toString();
      final value = e.value;
      if (key.isEmpty || value is! num) continue;
      out[key] = value.toDouble();
    }
    return out;
  }
}
