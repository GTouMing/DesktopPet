import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/enums.dart';
import 'chat_bubble_content.dart';
import 'hotkey_action.dart';
import 'live2d_pet_pack.dart';
import 'mouse_params.dart';
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
    this.hotkeys = const [],
    this.keyParams = const {},
    this.mouseParams,
    this.bubbles = const {},
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

  /// 包级快捷键 → 动作（不经状态机，见 [HotkeyAction]）。
  final List<HotkeyAction> hotkeys;

  /// "打字反应"：键名 → 模型**参数 id**（如 `{"q": "Q1"}`）。
  ///
  /// 按住键 → 参数置 1、松开 → 置 0（见 `PetVisual.setParameter`）。仅 Live2D 实现；
  /// 精灵图包不用。空表示该包不启用。
  final Map<String, String> keyParams;

  /// 鼠标反馈参数（光标跟随 + 鼠标按键）；null = 不启用。仅 Live2D 实现。
  final MouseParams? mouseParams;

  /// 聊天气泡**命名池**（清单顶层 `bubbles`）：key → 内容。
  ///
  /// 由 [StateDef.bubble] 按 key 引用（进入状态即显示），也可由
  /// `PetNotifier.showBubble(key: ...)` 按 key 显示。空 = 该包没有可显示的气泡。
  final Map<String, ChatBubbleContent> bubbles;

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

  /// 当前状态下**下一个** `time` 迁移：距触发还有多久，以及目标状态。
  ///
  /// [TransitionRule.at] 是当天时刻（`HH:MM:SS`，可多个），每个每天触发一次：已过的
  /// 时刻顺延到明天；正好到点则为 `Duration.zero`。所有时刻里取最近的一个。
  (Duration? bestDelay, String? bestTarget) findNextTimeAt(
    String currentState,
    DateTime now,
  ) {
    final def = states[currentState];
    if (def == null) return (null, null);
    final nowSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    Duration? bestDelay;
    String? bestTarget;
    for (final entry in def.transitions.entries) {
      final times = entry.value[Trigger.time]?.atSeconds ?? const <int>[];
      for (final seconds in times) {
        var delta = seconds - nowSeconds;
        if (delta < 0) delta += 86400;
        final delay = Duration(seconds: delta);
        if (bestDelay == null || delay < bestDelay) {
          bestDelay = delay;
          bestTarget = entry.key;
        }
      }
    }
    return (bestDelay, bestTarget);
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

  /// 清单文件名（`pet.json`）。
  static const List<String> manifestNames = ['pet.json'];

  /// 可调参数槽位的独立文件名（`params.json`，仅 Live2D）。
  ///
  /// 参数组声明（原先清单顶层的 `params`）单独成文件：内容就是那个对象
  /// （`{ "<槽位>": { label?, type?, default?, params? | offParams? | options? } }`）。
  /// 缺失 = 该包没有可调项。见 [L2dParamGroup]。
  static const String paramsFileName = 'params.json';

  /// 读取清单 JSON（依次尝试 [manifestNames]）；都不行则 null。
  static Future<Map<String, dynamic>?> readManifest(
    String basePath,
    PetPackSource source,
  ) async {
    for (final name in manifestNames) {
      final json = await _readJsonFile(basePath, source, name);
      if (json != null) return json;
    }
    return null;
  }

  /// 读取包根下的一个 JSON 文件（asset 走 rootBundle，文件系统走 File）。
  ///
  /// 不存在 / 解析失败 / 顶层不是对象，一律返回 null。
  static Future<Map<String, dynamic>?> _readJsonFile(
    String basePath,
    PetPackSource source,
    String fileName,
  ) async {
    try {
      final String? content;
      if (source == PetPackSource.asset) {
        content =
            await rootBundle.loadString('$basePath/$fileName', cache: false);
      } else {
        final file = File('$basePath/$fileName');
        content = await file.exists() ? await file.readAsString() : null;
      }
      if (content == null) return null;
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// 载入宠物包：读清单 → 判别类型 →（Live2D）合并 [paramsFileName] → 交给对应实现解析。
  ///
  /// 清单缺失返回 null（调用方按“加载失败”处理）；清单存在但字段不合法则抛异常。
  static Future<PetPack?> load(String path) async {
    final source = path.startsWith('assets/')
        ? PetPackSource.asset
        : PetPackSource.filesystem;
    final json = await readManifest(path, source);
    if (json == null) return null;

    final type = PetPackDetector.detect(json, path, source);
    if (type == PetPackType.live2d) {
      // 可调参数槽位只在包根的 `params.json` 里；清单里若残留内联 `params` 一律忽略
      // （拆分后清单不再是它的真源），合成一份再交给解析。
      json.remove('params');
      final params = await _readJsonFile(path, source, paramsFileName);
      if (params != null) json['params'] = params;
    }

    return switch (type) {
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

/// 解析清单顶层的 `hotkeys`（包级快捷键 → 动作，见 [HotkeyAction]）。
///
/// 跳过没有 `key` 的无效项。
List<HotkeyAction> parsePetPackHotkeys(Map<String, dynamic> json) {
  final raw = json['hotkeys'];
  if (raw is! Map) return const [];
  final actions = <HotkeyAction>[];
  for (final value in raw.values) {
    if (value is! Map) continue;
    final action = HotkeyAction.fromJson(Map<String, dynamic>.from(value));
    if (action.key.isEmpty) continue;
    actions.add(action);
  }
  return actions;
}

/// 解析清单顶层的 `keyParams`（键名 → 模型参数 id，见 [PetPack.keyParams]）。
///
/// 键名统一小写；跳过空值项。
Map<String, String> parsePetPackKeyParams(Map<String, dynamic> json) {
  final raw = json['keyParams'];
  if (raw is! Map) return const {};
  final params = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString().toLowerCase();
    final value = entry.value;
    if (key.isEmpty || value is! String || value.isEmpty) continue;
    params[key] = value;
  }
  return params;
}

/// 解析清单顶层的 `mouseParams`（见 [MouseParams]）。空表返回 null。
///
/// 光标跟随的参数与幅度**读自模型**，不在清单里；这里只取鼠标按键与缓动。
MouseParams? parsePetPackMouseParams(Map<String, dynamic> json) {
  final raw = json['mouseParams'];
  if (raw is! Map || raw.isEmpty) return null;

  String? str(Object? v) => (v is String && v.isNotEmpty) ? v : null;
  return MouseParams(
    left: str(raw['left']),
    right: str(raw['right']),
    smooth: (raw['smooth'] as num?)?.toDouble() ?? 1.0,
  );
}

/// 解析清单顶层的 `bubbles`（聊天气泡命名池，见 [ChatBubbleContent]）。
///
/// 跳过非对象项与没有任何可显示内容的空项。
Map<String, ChatBubbleContent> parsePetPackBubbles(Map<String, dynamic> json) {
  final raw = json['bubbles'];
  if (raw is! Map) return const {};
  final bubbles = <String, ChatBubbleContent>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! Map) continue;
    final content = ChatBubbleContent.fromJson(Map<String, dynamic>.from(value));
    if (content.isEmpty) continue;
    bubbles[entry.key.toString()] = content;
  }
  return bubbles;
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
