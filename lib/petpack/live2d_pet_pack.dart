import 'package:flutter/services.dart';

import '../core/enums.dart';
import 'live2d/l2d_param_group.dart';
import 'pet_pack.dart';

/// Live2D Cubism 宠物包：一个目录 + 其中的 `.model3.json`。
///
/// 与精灵图包的区别只在“资源怎么描述”：状态机（`states` / `initialState`）由
/// [PetPack] 提供，Live2D 渲染器把 `StateDef.animation` 当作**动作组名**使用。
///
/// 模型目录用**绝对路径**：导入的宠物包解压在
/// `<app_documents>/imported_pet_packs/<petId>/`（或自定义 `packDir`），Live2D 插件在
/// 所有原生平台都接受绝对路径（Windows 亦然，实测通过）。
class Live2DPetPack extends PetPack {
  const Live2DPetPack({
    required super.name,
    required super.version,
    required super.baseSize,
    required super.basePath,
    required super.source,
    required this.modelDir,
    required this.modelFileName,
    super.states,
    super.initialState,
    super.hotkeys,
    super.keyParams,
    super.mouseParams,
    super.bubbles,
    this.paramGroups = const [],
    this.scale = 1,
    this.translateX = 0,
    this.translateY = 0,
    this.breathScale = 1,
  }) : super(type: PetPackType.live2d);

  /// 模型所在目录（[PetPack.basePath] 同值，语义化命名）。
  final String modelDir;

  /// `.model3.json` 文件名（插件要求目录与文件名分开传）。
  final String modelFileName;

  /// 可调参数组（清单顶层 `params`，见 [L2dParamGroup]）。空 = 该包没有可调项。
  final List<L2dParamGroup> paramGroups;

  /// 自动适配之上**再乘**的缩放（清单 `scale`，默认 1）。
  ///
  /// 与参考实现（dsh-pet-live2d 的 `live2d.scale`，文档写"在自适应缩放上乘算"）同义：
  /// 适配 = contain(内容框) × scale。作者一次把构图定死，比我们从顶点包围盒猜稳。
  final double scale;

  /// 模型中心相对盒子中心的偏移，单位是**盒子逻辑像素**（清单 `translate.x/y`，默认 0）。
  /// `+x` 向右、`+y` **向下**，与 CSS / pixi 的屏幕坐标一致。
  final double translateX;
  final double translateY;

  /// 待机呼吸幅度（清单 `breath`，默认 1）。`1` = 引擎的 Cubism 标准值，`0` = 不呼吸。
  ///
  /// 引擎永远只喂**标准**那套呼吸（模型作者靠物理的 `PhysicsSetting` 输出 `Scale`
  /// 调摆动幅度），所以包这边**只能调低**，不能放大——摆多少是模型的事，不是引擎的。
  /// 缺失/非法 = 1。
  final double breathScale;

  factory Live2DPetPack.fromJson(
    Map<String, dynamic> json,
    String basePath,
    PetPackSource source,
  ) {
    final declared = (json['model'] as String?)?.trim();
    final modelFileName = (declared != null && declared.isNotEmpty)
        ? declared
        : (PetPackDetector.findModel3FileName(basePath) ?? '');

    return Live2DPetPack(
      name: json['name'] as String,
      version: json['version'] as int,
      baseSize: Size(
        (json['frameWidth'] as num).toDouble(),
        (json['frameHeight'] as num).toDouble(),
      ),
      basePath: basePath,
      source: source,
      modelDir: basePath,
      modelFileName: modelFileName,
      states: parsePetPackStates(json),
      initialState: json['initialState'] as String? ?? 'idle',
      hotkeys: parsePetPackHotkeys(json),
      keyParams: parsePetPackKeyParams(json),
      mouseParams: parsePetPackMouseParams(json),
      bubbles: parsePetPackBubbles(json),
      paramGroups: L2dParamGroup.parse(json['params']),
      scale: _fitScale(json['scale']),
      translateX: _translateAxis(json['translate'], 'x'),
      translateY: _translateAxis(json['translate'], 'y'),
      breathScale: _breathScale(json['breath']),
    );
  }
}

/// 清单 `scale`：只有 `> 0 && <= 10` 才算数（与参考实现同一口径），否则回默认 1。
double _fitScale(Object? raw) {
  final value = raw is num ? raw.toDouble() : null;
  if (value == null || value <= 0 || value > 10) return 1;
  return value;
}

/// 清单 `translate.<axis>`（盒子逻辑像素）。缺失或非数字 = 0。
double _translateAxis(Object? raw, String axis) {
  if (raw is! Map) return 0;
  final value = raw[axis];
  return value is num ? value.toDouble() : 0;
}

/// 清单 `breath`：待机呼吸幅度，钳到 `[0, 1]`（只允许在标准值基础上调低）。缺失 = 1。
double _breathScale(Object? raw) {
  final value = raw is num ? raw.toDouble() : null;
  if (value == null) return 1;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}
