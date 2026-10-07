import 'dart:math';

import 'package:flutter/cupertino.dart';

import '../../core/constants.dart';
import '../expression.dart';

/// 解析 `{ "<槽位id>": "<选项label>" }`（bool 槽位可写 `true`/`false`，映射为 `on`/`off`）。
///
/// 包级 `hotkeys[].sets` 与状态的 [StateDef.params] 共用这一套写法。
Map<String, String> parseParamSet(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  for (final entry in raw.entries) {
    final id = entry.key.toString();
    if (id.isEmpty) continue;
    final value = entry.value;
    if (value is String && value.isNotEmpty) {
      out[id] = value;
    } else if (value is bool) {
      out[id] = value ? 'on' : 'off';
    }
  }
  return out;
}

/// 解析 `time` 规则的时刻：单个 `"09:00:00"` 或数组 `["09:00:00", "14:00:00"]`。
///
/// 空串与非字符串项忽略；范围校验在 [TransitionRule.atSeconds] 做。
List<String> _parseTimes(Object? raw) {
  if (raw is String) return raw.isEmpty ? const [] : [raw];
  if (raw is List) {
    return [
      for (final e in raw)
        if (e is String && e.isNotEmpty) e,
    ];
  }
  return const [];
}

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

  /// 时间触发器（[Trigger.time]）：当天时刻 `HH:MM:SS`（`00:00:00`–`23:59:59`）。
  ///
  /// 可给一个时刻，也可给数组（每个时刻每天各触发一次）。
  final List<String> at;

  /// 长按触发器（[Trigger.hold]）：在桌宠上按住多少毫秒后触发。
  final int? holdMs;

  const TransitionRule({
    required this.trigger,
    this.alignment,
    this.afterMs,
    this.minMs,
    this.maxMs,
    this.key,
    this.modifiers = const [],
    this.at = const [],
    this.holdMs,
  });

  /// [at] 里合法的时刻，解析成"当天第几秒"；越界/非法项忽略（列表为空 = 规则无效）。
  List<int> get atSeconds {
    final out = <int>[];
    for (final value in at) {
      final parts = value.split(':');
      if (parts.length != 3) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final s = int.tryParse(parts[2]);
      if (h == null || m == null || s == null) continue;
      if (h < 0 || h > 23 || m < 0 || m > 59 || s < 0 || s > 59) continue;
      out.add(h * 3600 + m * 60 + s);
    }
    return out;
  }

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

  /// 状态携带的**参数集**（仅 Live2D；精灵图实现忽略）：槽位组 id → 选项 label。
  ///
  /// 对应精灵图状态的 [animation]——精灵图是"进这个状态播这个动画"，Live2D 是
  /// "进这个状态把这几个槽位切到这些选项"。写法与包级 `hotkeys[].sets` 一致：组 id
  /// 取清单顶层 `params` 声明的槽位，bool 槽位用 `on` / `off`。
  ///
  /// 它是一层**运行时**覆盖（压在用户在编辑页选的槽位之上），离开状态即恢复，
  /// 不写回该桌宠的设置。
  final Map<String, String> params;

  /// 进入该状态时显示的聊天气泡 key（指向包顶层 `bubbles` 命名池的条目）。
  ///
  /// 两种渲染器通用。null / 空 = 该状态不显示气泡。参照的条目不存在时同样不显示。
  final String? bubble;

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
    this.params = const {},
    this.bubble,
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
          final t = trigEntry.key.toString();
          final raw = trigEntry.value;
          // 允许两种写法：对象（`{ "at": "09:00:00" }` / `{ "holdMs": 500 }`）或标量
          // （`"09:00:00"` / `500`）——标量只对 time / hold 有意义。
          final v = raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{
                  if (t == Trigger.time && (raw is String || raw is List))
                    'at': raw,
                  if (t == Trigger.hold && raw is num) 'holdMs': raw,
                };
          inner[t] = TransitionRule(
            trigger: t,
            alignment: v['alignment'] as String?,
            afterMs: (v['afterMs'] as num?)?.toInt(),
            minMs: (v['minMs'] as num?)?.toInt(),
            maxMs: (v['maxMs'] as num?)?.toInt(),
            key: v['key'] as String?,
            modifiers: (v['modifiers'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
            at: _parseTimes(v['at']),
            holdMs: (v['holdMs'] as num?)?.toInt(),
          );
        }
        transitions[targetEntry.key] = inner;
      }
    }

    return StateDef(
      name: name,
      animation: json['animation'] as String? ?? '',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      motionIndex: (json['motionIndex'] as num?)?.toInt(),
      motionPriority: (json['motionPriority'] as num?)?.toInt(),
      targetPos: _parseTargetPos(json['targetPos']),
      params: parseParamSet(json['params']),
      bubble: _optionalText(json['bubble']),
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

  /// 取可选文本字段：非字符串或去空白后为空返回 null。
  static String? _optionalText(dynamic v) {
    if (v is! String) return null;
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : trimmed;
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
