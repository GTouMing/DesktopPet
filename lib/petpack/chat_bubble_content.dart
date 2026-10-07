/// 气泡相对桌宠的摆放位置。
///
/// [auto] 优先放上方，上方空间不足时自动翻到下方；其余为显式方向。
enum BubblePlacement { auto, top, bottom, left, right }

/// 一条聊天气泡的内容（文本 / 图片，可同时存在）。
///
/// 两个来源共用本类：
/// - 宠物包 `pet.json` 顶层 `bubbles` 命名池里的一条（见 [parsePetPackBubbles]）；
/// - `PetNotifier.showBubble` 的内联参数——以命名池条目为底、逐项 [copyWith] 覆盖。
///
/// [image] 是**相对宠物包根目录**的路径（如 `bubble/wave.png`），与精灵图帧同一套
/// 口径：asset 包拼成 asset 键，文件系统包拼成绝对路径。
class ChatBubbleContent {
  const ChatBubbleContent({
    this.text,
    this.image,
    this.durationMs,
    this.placement = BubblePlacement.auto,
    this.maxWidth,
  });

  /// 文本内容；null / 空串表示不显示文字。
  final String? text;

  /// 图片路径（相对宠物包根目录）；null / 空串表示不显示图片。
  final String? image;

  /// 显示时长（毫秒）：`null` = 用默认（`chatBubbleDefaultDurationMs`），
  /// `0` = 粘滞（驻留到被替换 / 隐藏 / 状态切换），`>0` = 到点自动消失。
  final int? durationMs;

  /// 相对桌宠的摆放位置。
  final BubblePlacement placement;

  /// 宽度上限（逻辑像素）；null = 用默认（`chatBubbleMaxWidth`）。
  final double? maxWidth;

  /// 是否没有任何可显示内容（文本与图片都为空）。
  bool get isEmpty =>
      (text == null || text!.isEmpty) && (image == null || image!.isEmpty);

  /// 从清单字段构造。非法/缺失字段一律回默认值（与其它 `parsePetPack*` 同一口径）。
  factory ChatBubbleContent.fromJson(Map<String, dynamic> json) {
    return ChatBubbleContent(
      text: _nonEmpty(json['text']),
      image: _nonEmpty(json['image']),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      placement: _placement(json['placement']),
      maxWidth: (json['maxWidth'] as num?)?.toDouble(),
    );
  }

  /// 用非空参数逐项覆盖（null = 保留原值）。API 内联参数即走这里。
  ChatBubbleContent copyWith({
    String? text,
    String? image,
    int? durationMs,
    BubblePlacement? placement,
    double? maxWidth,
  }) {
    return ChatBubbleContent(
      text: text ?? this.text,
      image: image ?? this.image,
      durationMs: durationMs ?? this.durationMs,
      placement: placement ?? this.placement,
      maxWidth: maxWidth ?? this.maxWidth,
    );
  }

  static String? _nonEmpty(Object? value) =>
      (value is String && value.isNotEmpty) ? value : null;

  static BubblePlacement _placement(Object? value) {
    if (value is! String) return BubblePlacement.auto;
    for (final placement in BubblePlacement.values) {
      if (placement.name == value) return placement;
    }
    return BubblePlacement.auto;
  }
}
