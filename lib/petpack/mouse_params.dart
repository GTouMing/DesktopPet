/// 一条「光标 → 模型参数」映射：把归一化坐标 `[-1, 1]` 乘 [scale] 写进 [param]。
///
/// [scale] 要匹配模型里该参数的取值范围，例如 `ParamAngleX` 约 ±30、`ParamEyeBallX` 约 ±1。
class MouseAxisMapping {
  const MouseAxisMapping({
    required this.param,
    this.scale = 1.0,
    this.raw = false,
  });

  /// 模型参数 id。
  final String param;

  /// 归一化坐标的缩放系数。
  final double scale;

  /// `true` = 用**原始**光标值（不缓动）。
  ///
  /// Bongo 里平滑只作用在 look-at（角度/眼珠），手/鼠标图形是直接跟光标的——给这类
  /// 参数标 `raw: true`。
  final bool raw;
}

/// 鼠标反馈（"光标跟随 + 鼠标按键"）的模型参数映射（仅 Live2D）。
///
/// 清单格式（`pet.json` 顶层），每个轴都是一**组**映射，支持一次驱动多个参数：
/// ```json
/// "mouseParams": {
///   "x":  [ { "param": "ParamAngleX",  "scale": 30 },
///           { "param": "ParamEyeBallX", "scale": 1 } ],
///   "y":  [ { "param": "ParamAngleY",  "scale": 30 },
///           { "param": "ParamEyeBallY", "scale": 1 } ],
///   "xy": [ { "param": "ParamAngleZ", "scale": -30 } ],
///   "left": "ParamMouseLeftDown", "right": "ParamMouseRightDown"
/// }
/// ```
/// - `x`：光标左右（右为正）；`y`：光标上下（上为正）；`xy`：`x*y`（用于头部倾斜那类乘积曲线）。
/// - 每个轴的每一项可以是 `{ "param": ..., "scale": ... }`，也可以只写参数名字符串（`scale` 取 1）。
/// - `left`/`right`：鼠标左/右键按下置 1、松开置 0。
///
/// 全部为空 = 不启用（此时也不会上报全局鼠标位置）。
class MouseParams {
  const MouseParams({
    this.x = const [],
    this.y = const [],
    this.xy = const [],
    this.left,
    this.right,
    this.smooth = 0,
  });

  final List<MouseAxisMapping> x;
  final List<MouseAxisMapping> y;
  final List<MouseAxisMapping> xy;

  /// 缓动速度倍率：`0` = 无缓动（瞬时跟随）；`> 0` = 用 Bongo/`CubismTargetPoint` 那套
  /// **加速度受限**模型跟随（最大速度 4.0/s、0.15s 加到满速、停止阈值 0.01），`1.0` 与
  /// Bongo 完全一致。
  final double smooth;

  /// 鼠标左键参数 id（按下 1 / 松开 0）。
  final String? left;

  /// 鼠标右键参数 id（按下 1 / 松开 0）。
  final String? right;

  /// 是否跟随光标（任一轴有映射）。
  bool get followsCursor => x.isNotEmpty || y.isNotEmpty || xy.isNotEmpty;

  /// 是否需要鼠标按键反馈。
  bool get hasButtons => left != null || right != null;

  /// 是否启用（任一字段非空）。
  bool get enabled => followsCursor || hasButtons;
}
