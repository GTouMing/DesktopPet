import 'package:desktop_pet/core/constants.dart';
import 'package:flutter/material.dart';

/// 生成一个新的桌宠 id。
///
/// 新建桌宠（列表页 / 编辑页 / 导入宠物包）都走这里，避免同一段拼串散落多处。
String newPetId() => 'pet_${DateTime.now().millisecondsSinceEpoch}';

/// 单个桌宠的配置信息。
///
/// 缩放/透明度是乘数，与 [SettingsModel] 的基础值乘算得到最终值：
/// ```dart
/// finalScale  = SettingsModel.baseScale * scaleMultiplier
/// finalOpacity = SettingsModel.baseOpacity * opacityMultiplier
/// ```
///
/// [width]/[height] 是未经缩放的基帧尺寸（从宠物包加载后自动写入），
/// 显示窗口时由控制器读取并结合全局缩放合成最终窗口尺寸：
/// ```dart
/// finalWindowWidth  = width  × baseScale × scaleMultiplier
/// finalWindowHeight = height × baseScale × scaleMultiplier
/// ```
class PetConfig {
  final String id;
  String name;

  /// 桌宠级缩放乘数（0.1 - 3.0）。
  double scaleMultiplier;

  /// 桌宠级透明度乘数（0.1 - 1.0）。
  double opacityMultiplier;

  /// 宠物包路径。
  /// - 如果 [SettingsModel.packDir] 非 null，此为相对路径；
  /// - 否则为绝对路径或 ZIP 文件路径。
  String packPath;

  bool isLocked;
  bool isVisible;
  double positionX;
  double positionY;
  int order;

  /// 未经缩放的基帧宽度（来自宠物包），窗口控制器用于合成窗口尺寸。
  double width;

  /// 未经缩放的基帧高度（来自宠物包），窗口控制器用于合成窗口尺寸。
  double height;

  /// Live2D 可调参数的选择：组 id → 选项下标（见 `L2dParamGroup`）。
  ///
  /// 与缩放/位置同处 MMKV；未出现过的组按清单的 `default` 处理。
  Map<String, int> paramChoices;

  /// 鼠标跟随强度：乘在宠物包 `mouseParams` 的 `x` / `y` 映射之上（`0` 关闭跟随）。
  ///
  /// 只作用于"跟随"轴（`x`/`y`/`xy`），不影响鼠标按键映射；范围 `[0, maxMouseFollow]`。
  double mouseFollowX;
  double mouseFollowY;

  /// 逐参数的光标跟随轴：参数 id → `'x' | 'y' | 'xy'`（见 `mouse_follow.dart`）。
  ///
  /// 空 = 用引擎的**自动标准集**（`ParamAngleX/Y/Z`、`ParamBodyAngleX`、`ParamEyeBallX/Y`）；
  /// 非空 = 完全按此表，未列出的参数不跟随。
  Map<String, String> mouseBindings;

  PetConfig({
    required this.id,
    required this.name,
    this.scaleMultiplier = 1.0,
    this.opacityMultiplier = 1.0,
    this.packPath = defaultPackPath,
    this.isLocked = false,
    this.isVisible = true,
    this.positionX = 0,
    this.positionY = 0,
    this.order = 0,
    this.width = defaultPetSize,
    this.height = defaultPetSize,
    this.paramChoices = const {},
    this.mouseFollowX = 1.0,
    this.mouseFollowY = 1.0,
    this.mouseBindings = const {},
  });

  double get snappedScaleMultiplier =>
      (scaleMultiplier * 10).round() / 10.0;
  double get snappedOpacityMultiplier =>
      (opacityMultiplier * 10).round() / 10.0;
  double get snappedMouseFollowX => (mouseFollowX * 10).round() / 10.0;
  double get snappedMouseFollowY => (mouseFollowY * 10).round() / 10.0;

  Offset get position => Offset(positionX, positionY);

  PetConfig copyWith({
    String? id,
    String? name,
    double? scaleMultiplier,
    double? opacityMultiplier,
    String? packPath,
    bool? isLocked,
    bool? isVisible,
    double? positionX,
    double? positionY,
    int? order,
    double? width,
    double? height,
    Map<String, int>? paramChoices,
    double? mouseFollowX,
    double? mouseFollowY,
    Map<String, String>? mouseBindings,
  }) {
    return PetConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      scaleMultiplier: scaleMultiplier ?? this.scaleMultiplier,
      opacityMultiplier: opacityMultiplier ?? this.opacityMultiplier,
      packPath: packPath ?? this.packPath,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      order: order ?? this.order,
      width: width ?? this.width,
      height: height ?? this.height,
      paramChoices: paramChoices ?? this.paramChoices,
      mouseFollowX: mouseFollowX ?? this.mouseFollowX,
      mouseFollowY: mouseFollowY ?? this.mouseFollowY,
      mouseBindings: mouseBindings ?? this.mouseBindings,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'scaleMultiplier': scaleMultiplier,
    'opacityMultiplier': opacityMultiplier,
    'packPath': packPath,
    'isLocked': isLocked,
    'isVisible': isVisible,
    'x': positionX,
    'y': positionY,
    'order': order,
    'width': width,
    'height': height,
    'paramChoices': paramChoices,
    'mouseFollowX': mouseFollowX,
    'mouseFollowY': mouseFollowY,
    'mouseBindings': mouseBindings,
  };

  factory PetConfig.fromJson(Map<String, dynamic> json) => PetConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    scaleMultiplier: (json['scaleMultiplier'] as num?)?.toDouble() ?? 1.0,
    opacityMultiplier: (json['opacityMultiplier'] as num?)?.toDouble() ?? 1.0,
    packPath: json['packPath'] as String? ?? defaultPackPath,
    isLocked: json['isLocked'] as bool? ?? false,
    isVisible: json['isVisible'] as bool? ?? true,
    positionX: (json['x'] as num?)?.toDouble() ?? 0,
    positionY: (json['y'] as num?)?.toDouble() ?? 0,
    order: json['order'] as int? ?? 0,
    width: (json['width'] as num?)?.toDouble() ?? defaultPetSize,
    height: (json['height'] as num?)?.toDouble() ?? defaultPetSize,
    paramChoices: _parseChoices(json['paramChoices']),
    mouseFollowX: _clampFollow((json['mouseFollowX'] as num?)?.toDouble()),
    mouseFollowY: _clampFollow((json['mouseFollowY'] as num?)?.toDouble()),
    mouseBindings: _parseBindings(json['mouseBindings']),
  );

  /// 跟随轴表：值只接受 `x` / `y` / `xy`，其余丢弃（防脏数据）。
  static Map<String, String> _parseBindings(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    for (final entry in raw.entries) {
      final axis = entry.value;
      if (axis is! String) continue;
      if (axis != 'x' && axis != 'y' && axis != 'xy') continue;
      out[entry.key.toString()] = axis;
    }
    return out;
  }

  /// 跟随强度收敛到 `[0, maxMouseFollow]`；缺失/非法回 1.0。
  static double _clampFollow(double? value) {
    if (value == null || value.isNaN) return 1.0;
    return value.clamp(0.0, maxMouseFollow).toDouble();
  }

  static Map<String, int> _parseChoices(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is num) out[entry.key.toString()] = value.toInt();
    }
    return out;
  }
}
