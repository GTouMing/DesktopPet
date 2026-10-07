import 'dart:math' as math;

/// 一个 Live2D 模型参数的元数据，**读自模型本身**（`.moc3`）。
///
/// 原生侧在模型加载完成时把每个参数的 id、`[minimum, maximum]` 与默认值随
/// `modelReady` 一并回传；`MouseFollow` 用标准跟随参数的**范围**推光标跟随的
/// `scale`，用**默认值**作中性基线。
class ModelParameter {
  const ModelParameter({
    required this.id,
    required this.minimum,
    required this.maximum,
    required this.defaultValue,
  });

  /// 参数 id（如 `ParamAngleX`）。
  final String id;

  /// 模型里该参数的下限。
  final double minimum;

  /// 模型里该参数的上限。
  final double maximum;

  /// 模型里该参数的默认值（中性姿态）。
  final double defaultValue;

  /// 范围半径：参数相对静止值两个方向能走的最大幅度。
  double get range => math.max(minimum.abs(), maximum.abs());
}
