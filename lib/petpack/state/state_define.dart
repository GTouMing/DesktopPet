import 'dart:math';

import 'package:flutter/cupertino.dart';

import '../expression.dart';

/// A transition rule: when its trigger fires with all conditions met,
/// transition to the target state that owns this rule.
class TransitionRule {
  final String trigger;

  /// 方位：仅在 `moveAroundScreen` 行为时检查。
  final String? alignment;

  final int? afterMs;
  final int? minMs;
  final int? maxMs;
  final String? key; // for "hotkey": physical key name, e.g. "h"
  final List<String> modifiers; // for "hotkey": ["alt"], ["ctrl","shift"]

  const TransitionRule({
    required this.trigger,
    this.alignment,
    this.afterMs,
    this.minMs,
    this.maxMs,
    this.key,
    this.modifiers = const [],
  });

  Duration get delay {
    if (afterMs != null) return Duration(milliseconds: afterMs!);
    if (minMs != null && maxMs != null) {
      final range = maxMs! - minMs!;
      if (range <= 0) return Duration(milliseconds: minMs!);
      return Duration(milliseconds: minMs! + _random.nextInt(range));
    }
    if (minMs != null) return Duration(milliseconds: minMs!);
    return Duration(milliseconds: maxMs ?? 0);
  }

  /// 生成复合键标识：`key+mod1+mod2` 排序后拼接，如 `"h+alt"`。
  static String compositeKey(String key, List<String> modifiers) {
    final parts = [key.toLowerCase(), ...modifiers.map((m) => m.toLowerCase())];
    parts.sort();
    return parts.join('+');
  }

  static final _random = Random();
}

/// A state definition from JSON: animation, repeatCount, behavior, transitions.
class StateDef {
  final String name;
  final String animation;

  /// 播放次数。
  ///
  /// 取值：
  /// - `0`  — 无限循环（默认，JSON 未写明时即为 0）
  /// - `N>0` — 播放 N 次
  final int playCount;

  /// 渲染器相关提示：动作组内的**索引**（Live2D 用；精灵图实现忽略）。
  ///
  /// 一个动作组里通常有多个动作——例如一只“跟着按键做动作”的模型，把各键的
  /// 按下/松开都放在同一组里。没有这个字段就只能播到 index 0。缺省 0。
  final int? motionIndex;

  /// 渲染器相关提示：动作优先级（Live2D：0 none / 1 idle / 2 normal / 3 force）。缺省按渲染器默认。
  final int? motionPriority;

  /// 行为目标坐标。
  ///
  /// - `null`  → 随机坐标
  /// - `Offset(x, y)` 且 x,y ≥ 0 → 固定坐标
  final Offset? targetPos;

  final String? behavior;    // "moveToTarget" | "moveAroundScreen" | null
  final String? audio;       // audio file path
  final double audioVolume;
  final bool mirrorH;     // flip horizontally when moving left
  final String scaleX;       // cyclic expression of t (0→1 repeating)
  final String scaleY;
  final String rotation;
  final String offsetX;
  final String offsetY;
  final String opacity;

  /// 过渡规则，以目标状态名为 key，值为 `触发器名 → 规则` 的内层 Map。
  ///
  /// JSON 格式：
  /// ```json
  /// "transitions": {
  ///   "targetState": {
  ///     "moveRight": { "alignment": "top" },
  ///     "arrived": {}
  ///   }
  /// }
  /// ```
  final Map<String, Map<String, TransitionRule>> transitions;

  const StateDef({
    required this.name,
    required this.animation,
    this.playCount = 0,
    this.motionIndex,
    this.motionPriority,
    this.targetPos,
    this.behavior,
    this.audio,
    this.audioVolume = 1.0,
    this.mirrorH = false,
    this.scaleX = '1.0',
    this.scaleY = '1.0',
    this.rotation = '0.0',
    this.offsetX = '0.0',
    this.offsetY = '0.0',
    this.opacity = '1.0',
    this.transitions = const {},
  });

  factory StateDef.fromJson(String name, Map<String, dynamic> json) {
    final Map<String, Map<String, TransitionRule>> transitions = {};
    final transRaw = json['transitions'];
    if (transRaw is Map) {
      for (final targetEntry in transRaw.entries) {
        final triggerRaw = targetEntry.value;
        if (triggerRaw is! Map) continue;
        final inner = <String, TransitionRule>{};
        for (final trigEntry in triggerRaw.entries) {
          final t = trigEntry.key;
          final v = trigEntry.value as Map<String, dynamic>;
          inner[t] = TransitionRule(
            trigger: t,
            alignment: v['alignment'] as String?,
            afterMs: v['afterMs'] as int?,
            minMs: v['minMs'] as int?,
            maxMs: v['maxMs'] as int?,
            key: v['key'] as String?,
            modifiers: (v['modifiers'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ?? [],
          );
        }
        transitions[targetEntry.key] = inner;
      }
    }

    return StateDef(
      name: name,
      animation: json['animation'] as String,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      motionIndex: (json['motionIndex'] as num?)?.toInt(),
      motionPriority: (json['motionPriority'] as num?)?.toInt(),
      targetPos: _parseTargetPos(json['targetPos']),
      behavior: json['behavior'] as String?,
      mirrorH: json['mirrorH'] as bool? ?? false,
      scaleX: _numOrString(json['scaleX'], '1.0'),
      scaleY: _numOrString(json['scaleY'], '1.0'),
      rotation: _numOrString(json['rotation'], '0.0'),
      offsetX: _numOrString(json['offsetX'], '0.0'),
      offsetY: _numOrString(json['offsetY'], '0.0'),
      opacity: _numOrString(json['opacity'], '1.0'),
      audio: json['audio'] as String?,
      audioVolume: (json['audioVolume'] as num?)?.toDouble() ?? 1.0,
      transitions: transitions,
    );
  }

  double computeOpacity(double t) => _doubleExp(opacity, t).clamp(0.0, 1.0);

  Matrix4 computeTransformMatrix(Size size, double t) {
    final sx = mirrorH ? -_doubleExp(scaleX, t) : _doubleExp(scaleX, t);
    return Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..rotateZ(_doubleExp(rotation, t))
      ..scaleByDouble(sx, _doubleExp(scaleY, t), 1, 1)
      ..translateByDouble(_doubleExp(offsetX, t), _doubleExp(offsetY, t), 0, 1)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
  }

  double _doubleExp(String exp, double t) => evalExpr(exp, t: t);

  /// 从 JSON 取值转为 String：num → toString，String → 原值，否则用默认值。
  static String _numOrString(dynamic v, String def) {
    if (v is num) return v.toString();
    if (v is String) return v;
    return def;
  }

  /// 解析 `targetPos` JSON。
  ///
  /// - `{"x": N, "y": N}` → `Offset(x, y)`
  /// - 其他 → `null`
  static Offset? _parseTargetPos(dynamic value) {
    if (value is Map && value.containsKey('x') && value.containsKey('y')) {
      return Offset(
        (value['x'] as num).toDouble(),
        (value['y'] as num).toDouble(),
      );
    }
    return null;
  }
}
