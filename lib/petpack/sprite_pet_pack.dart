import 'dart:io';

import 'package:flutter/services.dart';

import '../core/enums.dart';
import 'animation/animation_define.dart';
import 'pet_pack.dart';

/// 精灵图宠物包：`animations` 定义 + 每帧 PNG。
class SpritePetPack extends PetPack {
  const SpritePetPack({
    required super.name,
    required super.version,
    required super.baseSize,
    required super.basePath,
    required super.source,
    required this.anims,
    super.states,
    super.initialState,
  }) : super(type: PetPackType.sprite);

  /// 动画名 → 动画定义。
  final Map<String, AnimationDef> anims;

  /// 某动画的帧文件路径（仅文件系统包；asset 包的帧由 asset 键在
  /// `SpriteSheetGenerator` 里现场生成）。
  List<String> getFramePaths(String animationName) {
    final def = anims[animationName];
    if (def == null) return [];
    if (source != PetPackSource.filesystem) return [];

    final dir = Directory('$basePath/${def.folder}');
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files.map((f) => f.path).toList();
  }

  factory SpritePetPack.fromJson(
    Map<String, dynamic> json,
    String basePath,
    PetPackSource source,
  ) {
    final animsJson = json['animations'] as Map<String, dynamic>;
    final anims = <String, AnimationDef>{
      for (final entry in animsJson.entries)
        entry.key: AnimationDef.fromJson(entry.value as Map<String, dynamic>),
    };

    return SpritePetPack(
      name: json['name'] as String,
      version: json['version'] as int,
      baseSize: Size(
        (json['frameWidth'] as num).toDouble(),
        (json['frameHeight'] as num).toDouble(),
      ),
      basePath: basePath,
      source: source,
      anims: anims,
      states: parsePetPackStates(json),
      initialState: json['initialState'] as String? ?? 'idle',
    );
  }
}
