import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/enums.dart';
import 'state/state_define.dart';
import 'animation/animation_define.dart';


/// A complete pet pack with animation definitions, states, and metadata.
class PetPack {
  final String name;
  final int version;
  final Size frameSize;
  final String basePath;
  final Map<String, AnimationDef> anims;
  final Map<String, StateDef> states;
  final String initialState;
  final PetPackSource source;

  const PetPack({
    required this.name,
    required this.version,
    required this.frameSize,
    required this.basePath,
    required this.anims,
    this.states = const {},
    this.initialState = 'idle',
    required this.source,
  });

  bool hasBehavior(String stateName) => states[stateName]?.behavior != null;

  /// 查找匹配的跳转目标状态名。
  ///
  /// [hotkeyComposite] 形如 `"k+alt+ctrl"`，仅对 `hotkey` 触发器生效，
  /// 用于匹配规则的 `key`+`modifiers`。
  String? findTransition(String stateName, String trigger,
      {String? alignment, String? hotkeyComposite}) {
    final def = states[stateName];
    if (def == null) return null;
    for (final target in def.transitions.entries) {
      final rule = target.value[trigger];
      if (rule == null) continue;
      if (rule.alignment != null && rule.alignment != alignment) continue;
      if (hotkeyComposite != null && rule.key != null) {
        if (TransitionRule.compositeKey(rule.key!, rule.modifiers) != hotkeyComposite) continue;
      }
      if (hotkeyComposite != null && rule.key == null) continue;
      return target.key;
    }
    return null;
  }

  (Duration? bestDelay, String? bestTarget) findBestTimer(String currentState) {
    final def = states[currentState];
    if (def == null) return (null, null);

    Duration? bestDelay;
    String? bestTarget;

    for (final entry in def.transitions.entries) {
      final rule = entry.value[Trigger.limitTimer] ?? entry.value[Trigger.waitTimer];
      if (rule == null) continue;
      final delay = rule.delay;
      if (bestDelay == null || delay < bestDelay) {
        bestDelay = delay;
        bestTarget = entry.key;
      }
    }
    return (bestDelay, bestTarget);
  }

  List<String> getFramePaths(String animationName) {
    final def = anims[animationName];
    if (def == null) return [];

    if (source == PetPackSource.filesystem) {
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
      return [];
    }
  }

  // ── 工厂构造 ────────────────────────────────────────────────────────

  factory PetPack.fromJson(Map<String, dynamic> json, String basePath, PetPackSource source) {
    final anims = <String, AnimationDef>{};
    final animsJson = json['animations'] as Map<String, dynamic>;
    for (final entry in animsJson.entries) {
      anims[entry.key] = AnimationDef.fromJson(entry.value as Map<String, dynamic>);
    }
    final states = <String, StateDef>{};
    final statesJson = json['states'] as Map<String, dynamic>?;
    if (statesJson != null) {
      for (final entry in statesJson.entries) {
        states[entry.key] = StateDef.fromJson(entry.key, entry.value as Map<String, dynamic>);
      }
    }
    return PetPack(
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

  static Future<PetPack> fromAsset(String assetPath) async {
    final content = await rootBundle.loadString('$assetPath/skin.json');
    final json = jsonDecode(content) as Map<String, dynamic>;
    return PetPack.fromJson(json, assetPath, PetPackSource.asset);
  }

  static Future<PetPack> fromPath(String path) async {
    final file = File('$path/skin.json');
    if (!await file.exists()) {
      throw Exception('skin.json not found at $path');
    }
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return PetPack.fromJson(json, path, PetPackSource.filesystem);
  }

  static Future<PetPack?> load(String path) async {
    if (path.startsWith('assets/')) {
      return await PetPack.fromAsset(path);
    } else {
      return await PetPack.fromPath(path);
    }
  }
}
