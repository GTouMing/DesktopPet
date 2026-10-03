import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/enums.dart';
import 'live2d_pet_pack.dart';
import 'sprite_pet_pack.dart';
import 'state/state_define.dart';

/// 一个宠物包：渲染元数据 + 状态机 + （按类型）各自的资源描述。
///
/// 两种类型：
/// - [SpritePetPack]：精灵图逐帧包（`animations` + 帧图片）；
/// - [Live2DPetPack]：Live2D Cubism 模型包（`.model3.json` + moc3/贴图/动作）。
///
/// 状态机（[states] / [findTransition] / [findBestTimer] / [hasBehavior]）与渲染器
/// **无关**，两种类型共用：`StateDef.animation` 对精灵图是“动画名”，对 Live2D 是
/// “动作组名”。
abstract class PetPack {
  const PetPack({
    required this.name,
    required this.version,
    required this.type,
    required this.baseSize,
    required this.basePath,
    this.states = const {},
    this.initialState = 'idle',
    required this.source,
  });

  final String name;
  final int version;
  final PetPackType type;

  /// 渲染基准尺寸（**逻辑像素**）：精灵图包 = 单帧尺寸，Live2D 包 = 逻辑画布尺寸。
  ///
  /// 进 `PetState.basePetSize`；最终显示尺寸是 `finalPetSize`，渲染实现内部缩放到它。
  final Size baseSize;

  final String basePath;
  final Map<String, StateDef> states;
  final String initialState;
  final PetPackSource source;

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
        if (TransitionRule.compositeKey(rule.key!, rule.modifiers) !=
            hotkeyComposite) {
          continue;
        }
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
      final rule =
          entry.value[Trigger.limitTimer] ?? entry.value[Trigger.waitTimer];
      if (rule == null) continue;
      final delay = rule.delay;
      if (bestDelay == null || delay < bestDelay) {
        bestDelay = delay;
        bestTarget = entry.key;
      }
    }
    return (bestDelay, bestTarget);
  }

  // ── 清单 ────────────────────────────────────────────────────────────

  /// 清单文件名：新名 `pet.json` 优先，兼容旧名 `skin.json`。
  static const List<String> manifestNames = ['pet.json', 'skin.json'];

  /// 读取清单 JSON（asset 走 rootBundle，文件系统走 File）；都没有则 null。
  static Future<Map<String, dynamic>?> readManifest(
    String basePath,
    PetPackSource source,
  ) async {
    for (final name in manifestNames) {
      try {
        final String? content;
        if (source == PetPackSource.asset) {
          content = await rootBundle.loadString('$basePath/$name', cache: false);
        } else {
          final file = File('$basePath/$name');
          content = await file.exists() ? await file.readAsString() : null;
        }
        if (content == null) continue;
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // 该名字不存在或解析失败：试下一个；都不行返回 null。
      }
    }
    return null;
  }

  /// 载入宠物包：读清单 → 判别类型 → 交给对应实现解析。
  ///
  /// 清单缺失返回 null（调用方按“加载失败”处理）；清单存在但字段不合法则抛异常。
  static Future<PetPack?> load(String path) async {
    final source = path.startsWith('assets/')
        ? PetPackSource.asset
        : PetPackSource.filesystem;
    final json = await readManifest(path, source);
    if (json == null) return null;

    return switch (PetPackDetector.detect(json, path, source)) {
      PetPackType.sprite => SpritePetPack.fromJson(json, path, source),
      PetPackType.live2d => Live2DPetPack.fromJson(json, path, source),
    };
  }
}

/// 解析清单里的 `states`（两种类型共用）。
Map<String, StateDef> parsePetPackStates(Map<String, dynamic> json) {
  final states = <String, StateDef>{};
  final raw = json['states'];
  if (raw is Map<String, dynamic>) {
    for (final entry in raw.entries) {
      states[entry.key] =
          StateDef.fromJson(entry.key, entry.value as Map<String, dynamic>);
    }
  }
  return states;
}

/// 判别宠物包类型。
///
/// 优先看清单里的 `type`；否则**文件系统**目录里存在 `*.model3.json` 即视为
/// Live2D；两者都没有则按精灵图处理。
class PetPackDetector {
  PetPackDetector._();

  static PetPackType detect(
    Map<String, dynamic> json,
    String basePath,
    PetPackSource source,
  ) {
    final declared = json['type'];
    if (declared is String) {
      switch (declared.toLowerCase()) {
        case 'live2d':
          return PetPackType.live2d;
        case 'sprite':
          return PetPackType.sprite;
      }
    }
    if (source == PetPackSource.filesystem && findModel3FileName(basePath) != null) {
      return PetPackType.live2d;
    }
    return PetPackType.sprite;
  }

  /// 返回目录里第一个 `*.model3.json` 的文件名（无则 null）。
  static String? findModel3FileName(String dir) {
    try {
      final d = Directory(dir);
      if (!d.existsSync()) return null;
      for (final entity in d.listSync()) {
        if (entity is File &&
            entity.path.toLowerCase().endsWith('.model3.json')) {
          return entity.uri.pathSegments.last;
        }
      }
    } catch (_) {}
    return null;
  }
}
