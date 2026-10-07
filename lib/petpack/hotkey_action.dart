import 'state/state_define.dart';

/// 宠物包声明的「包级快捷键 → 动作」。
///
/// 与 `Trigger.hotkey` **不同**：后者是状态机里的一次状态迁移（会切走当前状态），
/// 本类则是"按下这个键，直接播放这个动作/表情"，**不改变状态机**——适合 Live2D 这类
/// 一个模型带一堆动作（配件/表情开关），想挨个按键点播的场景。
///
/// 清单格式（`pet.json` 顶层 `hotkeys`，map 的 key 仅作标识）：
/// ```json
/// "hotkeys": {
///   "selfie": { "key": "5", "modifiers": ["alt"],
///               "animation": "Selfie", "durationMs": 3300,
///               "requires": { "rhand": ["掏出手机"] },   // 前提：右手得先掏出手机
///               "sets":     { "selfie": "自拍" } },       // 播放时改动的参数
///   "cry":    { "key": "2", "modifiers": ["ctrl", "alt"], "expression": 3 }
/// }
/// ```
///
/// [animation] 对 Live2D 是**动作组名**（`startMotion` 的 `group`）、对精灵图是动画名；
/// 纯表情动作可留空。[expression] 仅 Live2D 使用（`setExpression`）。
class HotkeyAction {
  const HotkeyAction({
    required this.key,
    this.modifiers = const [],
    this.animation = '',
    this.motionIndex = 0,
    this.motionPriority = 3,
    this.expression,
    this.durationMs = 0,
    this.requires = const {},
    this.sets = const {},
  });

  /// 物理键名（如 `q` / `1` / `f5`）。
  final String key;

  /// 修饰键名（小写，可空），与 `TransitionRule` 同一套写法。
  final List<String> modifiers;

  /// 动作组名（Live2D）/ 动画名（精灵图）。
  final String animation;

  /// 组内索引（Live2D `startMotion` 的 `index`）。
  final int motionIndex;

  /// 动作优先级（Live2D：`0` none / `1` idle / `2` normal / `3` force）。
  final int motionPriority;

  /// 表情索引（Live2D `setExpression`）；`null` = 不切表情。
  final int? expression;

  /// 该动作（动作组）的时长（毫秒），取模型里 motion 的 `Meta.Duration`。
  ///
  /// 用于**串行化/互斥**：一次动作播放期间，后续动作排队；到点后才播下一个。
  /// `0` = 不串行（立即抢占）。
  final int durationMs;

  /// **参数前提**：组 id → 允许的选项 label 列表。
  ///
  /// 当前该组选项（按 label）不在列表里时，动作**不执行**（门禁）。bool 组用
  /// `on` / `off` 两个 label。空 = 无前提。
  final Map<String, List<String>> requires;

  /// 动作**播放时改动的参数**：组 id → 选项 label（会写回该桌宠的 `paramChoices`）。
  final Map<String, String> sets;

  /// 与热键匹配共用的复合键标识。
  ///
  /// **必须**用 `TransitionRule.compositeKey`（与 `HotkeyEngine` / `findTransition`
  /// 完全一致），否则原生触发时两侧对不上。
  String get composite => TransitionRule.compositeKey(key, modifiers);

  /// 是否带动作（纯表情动作可以只给 [expression]）。
  bool get hasMotion => animation.isNotEmpty;

  factory HotkeyAction.fromJson(Map<String, dynamic> json) => HotkeyAction(
        key: json['key'] as String? ?? '',
        modifiers: (json['modifiers'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        animation: json['animation'] as String? ?? '',
        motionIndex: (json['motionIndex'] as num?)?.toInt() ?? 0,
        motionPriority: (json['motionPriority'] as num?)?.toInt() ?? 3,
        expression: (json['expression'] as num?)?.toInt(),
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        requires: _parseRequires(json['requires']),
        sets: parseParamSet(json['sets']),
      );

  /// `requires`：`{ "<组>": "<label>" | ["<label>", ...] | true/false }`。
  static Map<String, List<String>> _parseRequires(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, List<String>>{};
    for (final entry in raw.entries) {
      final id = entry.key.toString();
      if (id.isEmpty) continue;
      final value = entry.value;
      final labels = <String>[
        if (value is String && value.isNotEmpty) value,
        if (value is bool) value ? 'on' : 'off',
        if (value is List)
          for (final item in value)
            if (item is String && item.isNotEmpty) item,
      ];
      if (labels.isNotEmpty) out[id] = labels;
    }
    return out;
  }
}
