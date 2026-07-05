import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/enums.dart';
import 'state/state_define.dart';
import 'animation/animation_define.dart';


/// A complete pet skin with animation definitions, states, and metadata.
class SkinPackage {
  final String name;
  final int version;
  final Size frameSize;
  final String basePath;
  final Map<String, AnimationDef> anims;
  final Map<String, StateDef> states;
  final String initialState;
  final SkinSource source;

  const SkinPackage({
    required this.name,
    required this.version,
    required this.frameSize,
    required this.basePath,
    required this.anims,
    this.states = const {},
    this.initialState = 'idle',
    required this.source,
  });

  StateMachine createStateMachine() => StateMachine(def: states[initialState]!, allDefs: states);

  factory SkinPackage.fromJson(Map<String, dynamic> json, String basePath, SkinSource source) {
    final anims = <String, AnimationDef>{};
    final animsJson = json['animations'] as Map<String, dynamic>;
    for (final entry in animsJson.entries) {
      anims[entry.key] = AnimationDef.fromJson(entry.value as Map<String, dynamic>);
    }
    // Parse states
    final states = <String, StateDef>{};
    final statesJson = json['states'] as Map<String, dynamic>?;
    if (statesJson != null) {
      for (final entry in statesJson.entries) {
        states[entry.key] = StateDef.fromJson(entry.key, entry.value as Map<String, dynamic>);
      }
    }
    return SkinPackage(
      name: json['name'] as String,
      version: json['version'] as int,
      frameSize: Size(
        (json['frameWidth'] as num).toDouble(),
        (json['frameHeight'] as num).toDouble(),
      ),
      basePath: basePath,
      anims: anims,
      states: states,
      initialState: json['initialState'] as String? ?? 'idle',
      source: source,
    );
  }

  static Future<SkinPackage> fromAsset(String assetPath) async {
    final content = await rootBundle.loadString('$assetPath/skin.json');
    final json = jsonDecode(content) as Map<String, dynamic>;
    return SkinPackage.fromJson(json, assetPath, SkinSource.asset);
  }

  static Future<SkinPackage> fromPath(String path) async {
    final file = File('$path/skin.json');
    if (!await file.exists()) {
      throw Exception('skin.json not found at $path');
    }
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return SkinPackage.fromJson(json, path, SkinSource.filesystem);
  }

  /// 从给定的路径（asset 或文件系统）加载皮肤包。
  ///
  /// - 以 `assets/` 开头 → 通过 AssetBundle 加载
  /// - 其他 → 从文件系统加载
  /// 加载失败时返回 null。
  static Future<SkinPackage?> load(String path) async {
    try {
      if (path.startsWith('assets/')) {
        return await SkinPackage.fromAsset(path);
      } else {
        return await SkinPackage.fromPath(path);
      }
    } catch (_) {
      return null;
    }
  }

  static SkinPackage fromJsonString(String jsonString, String basePath) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return SkinPackage.fromJson(json, basePath, SkinSource.asset);
  }

  /// Returns all frame paths for an animation, sorted naturally.
  /// 返回动画的所有帧路径，自然排序。
  List<String> getFramePaths(String animationName) {
    final def = anims[animationName];
    if (def == null) return [];

    if (source == SkinSource.filesystem) {
      final dir = Directory('$basePath/${def.folder}');
      if (!dir.existsSync()) return [];
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      return files.map((f) => f.path).toList();
    } else {
      // Asset source: discover frames by scanning consecutive indices
      return [];
    }
  }

}
