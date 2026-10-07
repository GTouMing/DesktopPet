import 'model_parameter.dart';

/// 一条「光标轴 → 模型参数」映射，由模型的标准跟随参数生成。
///
/// 下发的值是 `base + norm × 跟随强度 × scale`：[base] 是模型里该参数的默认值，
/// 光标居中（`norm = 0`）时参数回到中性姿态，而不是被压成 0。
class FollowMapping {
  const FollowMapping({
    required this.param,
    required this.scale,
    required this.base,
  });

  /// 模型参数 id。
  final String param;

  /// 归一化光标（±1）到参数增量的系数（含方向符号）。
  final double scale;

  /// 中性基线：该参数在模型里的默认值。
  final double base;
}

/// 光标跟随映射：`x` / `y` / `xy` 三组，`xy` 用 `x*y`（头部倾斜那类乘积曲线）。
class MouseFollow {
  const MouseFollow({
    this.x = const [],
    this.y = const [],
    this.xy = const [],
  });

  final List<FollowMapping> x;
  final List<FollowMapping> y;
  final List<FollowMapping> xy;

  bool get isEmpty => x.isEmpty && y.isEmpty && xy.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// 标准 Cubism「跟随」参数集：参数 id → 轴。引擎的"自动"即取其中**模型存在**的那些。
///
/// 也是编辑页下拉的**预填**来源（把标准集里存在的参数按此轴预选）。
const Map<String, String> standardFollowAxes = {
  'ParamAngleX': 'x',
  'ParamAngleY': 'y',
  'ParamAngleZ': 'xy',
  'ParamBodyAngleX': 'x',
  'ParamEyeBallX': 'x',
  'ParamEyeBallY': 'y',
};

/// 引擎约定符号：`ParamAngleZ`（头部倾斜）取负，其余 `+1`。无法从模型推断，写在引擎里。
double standardFollowSign(String id) => id == 'ParamAngleZ' ? -1 : 1;

final RegExp _axisLetter = RegExp('[XYZ]');

/// 轴向参数的特征：**id 或显示名里含大写 X/Y/Z**（如 `ParamAngleX` / `角度 X`）。
///
/// 大小写敏感：小写不算（否则 `_xk4`、`hair` 之类会被误判成轴向参数）。
bool hasFollowAxisLetter(String id, String name) =>
    _axisLetter.hasMatch(id) || _axisLetter.hasMatch(name);

enum _Axis { x, y, xy }

class _Standard {
  const _Standard(this.param, this.axis, this.sign);
  final String param;
  final _Axis axis;

  /// 方向符号。`ParamAngleZ` 取负是标准 look-at 的头部倾斜约定，无法从模型推断。
  final double sign;
}

/// 标准 Cubism「跟随」参数集：模型里存在哪个就绑哪个。
const List<_Standard> _standardFollowParams = [
  _Standard('ParamAngleX', _Axis.x, 1),
  _Standard('ParamAngleY', _Axis.y, 1),
  _Standard('ParamAngleZ', _Axis.xy, -1),
  _Standard('ParamBodyAngleX', _Axis.x, 1),
  _Standard('ParamEyeBallX', _Axis.x, 1),
  _Standard('ParamEyeBallY', _Axis.y, 1),
];

/// 按**显式绑定**（参数 id → 轴）构造跟随映射。
///
/// 只取模型里实际存在的参数；`scale` 取范围半径、`base` 取默认值（同自动集）。
/// 未列出的参数不跟随。空 bindings → 空映射（调用方此时回退到 [buildMouseFollow]）。
MouseFollow buildMouseFollowFromBindings(
    Map<String, String> bindings, List<ModelParameter> parameters) {
  if (bindings.isEmpty || parameters.isEmpty) return const MouseFollow();
  final byId = {for (final p in parameters) p.id: p};

  final x = <FollowMapping>[];
  final y = <FollowMapping>[];
  final xy = <FollowMapping>[];
  for (final entry in bindings.entries) {
    final parameter = byId[entry.key];
    if (parameter == null) continue;
    final mapping = FollowMapping(
      param: parameter.id,
      scale: _scaleOf(parameter) * standardFollowSign(parameter.id),
      base: parameter.defaultValue,
    );
    switch (entry.value) {
      case 'x':
        x.add(mapping);
      case 'y':
        y.add(mapping);
      case 'xy':
        xy.add(mapping);
    }
  }
  return MouseFollow(x: x, y: y, xy: xy);
}

/// 从模型参数元数据构造光标跟随映射：只取标准集里**模型实际存在**的参数，
/// `scale` 取其范围半径，`base` 取其默认值。
MouseFollow buildMouseFollow(List<ModelParameter> parameters) {
  if (parameters.isEmpty) return const MouseFollow();
  final byId = {for (final p in parameters) p.id: p};

  final x = <FollowMapping>[];
  final y = <FollowMapping>[];
  final xy = <FollowMapping>[];
  for (final standard in _standardFollowParams) {
    final parameter = byId[standard.param];
    if (parameter == null) continue;
    final mapping = FollowMapping(
      param: parameter.id,
      scale: _scaleOf(parameter) * standard.sign,
      base: parameter.defaultValue,
    );
    switch (standard.axis) {
      case _Axis.x:
        x.add(mapping);
      case _Axis.y:
        y.add(mapping);
      case _Axis.xy:
        xy.add(mapping);
    }
  }
  return MouseFollow(x: x, y: y, xy: xy);
}

/// 跟随幅度 = 参数范围半径；退化范围（`min == max`）回退到默认值的量级或 1，
/// 免得映射恒为 0、看起来"这个参数是死的"。
double _scaleOf(ModelParameter parameter) {
  final radius = parameter.range;
  if (radius > 0) return radius;
  final fallback = parameter.defaultValue.abs();
  return fallback > 0 ? fallback : 1.0;
}
