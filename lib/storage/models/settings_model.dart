/// 全局基础设置（对所有桌宠生效）。
class SettingsModel {
  /// 全局基础缩放倍数。与 [PetConfig.scaleMultiplier] 乘算得到最终缩放。
  double baseScale;

  /// 全局基础不透明度。与 [PetConfig.opacityMultiplier] 乘算得到最终不透明度。
  double baseOpacity;

  /// 全局基础速度。与 [PetConfig.speedMultiplier] 乘算得到最终动画播放速度。
  /// 1.0 = 正常速度，2.0 = 2 倍速，0.5 = 半速。
  double baseSpeed;

  /// 全局皮肤目录（绝对路径）。
  /// 为 null 时使用内置皮肤；非 null 时 [PetConfig.skinPath] 是相对于此的路径。
  String? skinDir;

  SettingsModel({
    this.baseScale = 1.0,
    this.baseOpacity = 1.0,
    this.baseSpeed = 1.0,
    this.skinDir,
  });

  // ── JSON ──────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'baseScale': baseScale,
    'baseOpacity': baseOpacity,
    'baseSpeed': baseSpeed,
    'skinDir': skinDir,
  };

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      baseScale: (json['baseScale'] as num?)?.toDouble() ?? 1.0,
      baseOpacity: (json['baseOpacity'] as num?)?.toDouble() ?? 1.0,
      baseSpeed: (json['baseSpeed'] as num?)?.toDouble() ?? 1.0,
      skinDir: json['skinDir'] as String?,
    );
  }

  SettingsModel copyWith({
    double? baseScale,
    double? baseOpacity,
    double? baseSpeed,
    String? skinDir,
  }) {
    return SettingsModel(
      baseScale: baseScale ?? this.baseScale,
      baseOpacity: baseOpacity ?? this.baseOpacity,
      baseSpeed: baseSpeed ?? this.baseSpeed,
      skinDir: skinDir ?? this.skinDir,
    );
  }
}
