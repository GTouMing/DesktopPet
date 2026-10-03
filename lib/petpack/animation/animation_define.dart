/// Configuration for a single animation in a pet pack.
class AnimationDef {
  final String folder;
  final int fps;
  final int frameCount;
  final String framePrefix;
  final int frameStart;

  const AnimationDef({
    required this.folder,
    required this.fps,
    this.frameCount = 1,
    this.framePrefix = '',
    this.frameStart = 0,
  });

  factory AnimationDef.fromJson(Map<String, dynamic> json) {
    return AnimationDef(
      folder: json['folder'] as String? ?? '',
      fps: (json['fps'] as num?)?.toInt() ?? 8,
      frameCount: json['frameCount'] as int? ?? 1,
      framePrefix: json['framePrefix'] as String? ?? '',
      frameStart: json['frameStart'] as int? ?? 0,
    );
  }
}