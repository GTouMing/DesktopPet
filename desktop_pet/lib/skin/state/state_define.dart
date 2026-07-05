import 'package:flutter/cupertino.dart';

import '../expression.dart';
import '../../core/constants.dart';

/// A transition rule: when [trigger] fires, go to [target] state.
class TransitionRule {
  final String trigger;
  final String target;
  final int? afterMs;
  final int? minMs;
  final int? maxMs;
  final String? match; // for "window": comma-separated window title patterns

  const TransitionRule({
    required this.trigger,
    required this.target,
    this.afterMs,
    this.minMs,
    this.maxMs,
    this.match,
  });

  factory TransitionRule.fromJson(Map<String, dynamic> json) => TransitionRule(
    trigger: json['trigger'] as String,
    target: json['target'] as String,
    match: json['match'] as String?,
    afterMs: json['afterMs'] as int?,
    minMs: json['minMs'] as int?,
    maxMs: json['maxMs'] as int?,
  );
}

/// Timer configuration registered on a [StateDef] during JSON parsing.
///
/// Extracted from [TransitionRule]s whose [trigger] is `"timer"`, so the
/// state machine can pre-scan and schedule them without re-parsing every time.
class StateTimer {
  final String target;
  final int? afterMs;
  final int? minMs;
  final int? maxMs;

  const StateTimer({
    required this.target,
    this.afterMs,
    this.minMs,
    this.maxMs,
  });
}

/// A state definition from JSON: animation, repeatCount, behavior, transitions.
class StateDef {
  final String name;
  final String animation;

  /// 重复次数。
  ///
  /// 取值：
  /// - `-1`  — 无限循环（对应 JSON 中的 `"infinite"`）
  /// - `0`   — 播放一次（不重复）
  /// - `N>0` — 播放一次后再重复 N 次，共播放 N+1 次
  final int repeatCount;
  final String? behavior;    // "moveToTarget" | null
  final String? audio;       // audio file path
  final double audioVolume;
  final bool mirrorH;     // flip horizontally when moving left
  final String scaleX;       // cyclic expression of t (0→1 repeating)
  final String scaleY;
  final String rotation;
  final String offsetX;
  final String offsetY;
  final String opacity;
  final List<TransitionRule> transitions;
  final List<StateTimer> timers;

  const StateDef({
    required this.name,
    required this.animation,
    this.repeatCount = 0,
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
    this.transitions = const [],
    this.timers = const [],
  });

  /// 是否为无限循环。
  bool get isInfinite => repeatCount < 0;

  factory StateDef.fromJson(String name, Map<String, dynamic> json) {
    // 解析 repeatCount：接受 "infinite"、数字，以及旧的 bool loop
    int repeatCount = 0;
    final raw = json['repeatCount'];
    if (raw is String && raw == 'infinite') {
      repeatCount = -1;
    } else if (raw is num) {
      repeatCount = raw.toInt().clamp(0, 999999);
    }

    final transList = (json['transitions'] as List<dynamic>?)
        ?.map((t) => TransitionRule.fromJson(t as Map<String, dynamic>))
        .toList() ?? [];

    // 提取 timer 触发器注册为 StateTimer，供状态机预调度
    final timers = transList
        .where((t) => t.trigger == Trigger.timer)
        .map((t) => StateTimer(
            target: t.target,
            afterMs: t.afterMs,
            minMs: t.minMs,
            maxMs: t.maxMs,
        ))
        .toList();

    return StateDef(
      name: name,
      animation: json['animation'] as String,
      repeatCount: repeatCount,
      behavior: json['behavior'] as String?,
      mirrorH: json['mirrorH'] as bool? ?? false,
      scaleX: json['scaleX'] as String? ?? '1.0',
      scaleY: json['scaleY'] as String? ?? '1.0',
      rotation: json['rotation'] as String? ?? '0.0',
      offsetX: json['offsetX'] as String? ?? '0.0',
      offsetY: json['offsetY'] as String? ?? '0.0',
      opacity: json['opacity'] as String? ?? '1.0',
      audio: json['audio'] as String?,
      audioVolume: (json['audioVolume'] as num?)?.toDouble() ?? 1.0,
      transitions: transList,
      timers: timers,
    );
  }

  /// 计算基于时间的透明度值。
  double computeOpacity(double t) => _doubleExp(opacity, t).clamp(0.0, 1.0);

  /// 计算基于时间的变换矩阵，用于 [Transform] 组件。
  Matrix4 computeTransformMatrix(Size size, double t) {
    final sx = mirrorH ? -_doubleExp(scaleX, t) : _doubleExp(scaleX, t);
    return Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..rotateZ(_doubleExp(rotation, t))
      ..scaleByDouble(sx, _doubleExp(scaleY, t), 1, 1)
      ..translateByDouble(_doubleExp(offsetX, t), _doubleExp(offsetY, t), 0, 1)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
  }

  double _doubleExp(String exp, double t) {
    return evalExpr(exp, t: t);
  }
}

/// 状态机，持有当前状态定义并提供事件驱动的状态跳转能力。
///
/// Timer 调度由 [PetNotifier] 负责，本类仅关注状态定义查找与跳转。
class StateMachine {
  StateDef def;
  final Map<String, StateDef> _allDefs;

  StateMachine({required this.def, required Map<String, StateDef> allDefs})
      : _allDefs = allDefs;

  /// 当前状态是否需要移动行为。
  bool get shouldMove => def.behavior == 'moveToTarget';

  /// 当前状态注册的 timer 触发器列表，由 [PetNotifier] 消费。
  List<StateTimer> get timers => def.timers;

  /// 按 [trigger] 查找匹配的跳转目标状态名。找不到返回 null。
  String? onEvent(String trigger) {
    for (final t in def.transitions) {
      if (t.trigger == trigger) return t.target;
    }
    return null;
  }

  /// 检查当前活动窗口标题是否匹配任一 `window` 触发器的 [match] 规则。
  ///
  /// [match] 为逗号分隔的标题片段（不区分大小写），匹配任一即返回对应 [target]。
  String? matchWindow(String title) {
    if (title.isEmpty) return null;
    final lower = title.toLowerCase();
    for (final t in def.transitions) {
      if (t.trigger == Trigger.window && t.match != null) {
        for (final pattern in t.match!.split(',')) {
          if (lower.contains(pattern.trim().toLowerCase())) {
            return t.target;
          }
        }
      }
    }
    return null;
  }

  /// 跳转到指定状态，更新内部的 [def] 引用。
  void transitionTo(String stateName) {
    final newDef = _allDefs[stateName];
    if (newDef != null) def = newDef;
  }
}