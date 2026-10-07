/// 鼠标反馈（仅 Live2D）里**无法从模型推断**的那两项：鼠标按键与缓动。
///
/// 光标跟随的**参数与幅度不再由清单声明**——渲染器按模型自身的标准跟随参数
/// （`ParamAngleX/Y/Z`、`ParamBodyAngleX`、`ParamEyeBallX/Y`）自动绑定，`scale` 取该参数
/// 的范围、`base` 取该参数的默认值（见 `lib/pet/live2d/mouse_follow.dart`）。
///
/// 清单格式（`pet.json` 顶层）只剩两项：
/// ```json
/// "mouseParams": {
///   "left": "ParamMouseLeftDown",
///   "right": "ParamMouseRightDown",
///   "smooth": 1.0
/// }
/// ```
class MouseParams {
  const MouseParams({
    this.left,
    this.right,
    this.smooth = 1.0,
  });

  /// 缓动速度倍率：`0` = 无缓动（瞬时跟随）；`> 0` = 用 Bongo/`CubismTargetPoint` 那套
  /// **加速度受限**模型跟随（最大速度 4.0/s、0.15s 加到满速、停止阈值 0.01），`1.0` 与
  /// Bongo 完全一致。
  final double smooth;

  /// 鼠标左键参数 id（按下 1 / 松开 0）。
  final String? left;

  /// 鼠标右键参数 id（按下 1 / 松开 0）。
  final String? right;

  /// 是否需要鼠标按键反馈。
  bool get hasButtons => left != null || right != null;
}
