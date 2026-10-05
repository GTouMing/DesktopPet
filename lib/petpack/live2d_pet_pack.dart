import 'package:flutter/services.dart';

import '../core/enums.dart';
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
  }) : super(type: PetPackType.live2d);

  /// 模型所在目录（[PetPack.basePath] 同值，语义化命名）。
  final String modelDir;

  /// `.model3.json` 文件名（插件要求目录与文件名分开传）。
  final String modelFileName;

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
    );
  }
}
