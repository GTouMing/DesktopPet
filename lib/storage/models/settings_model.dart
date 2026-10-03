import '../../core/constants.dart';

/// [SettingsModel.copyWith] 用它区分"未传该参数"与"显式传 null"。
const Object _unset = Object();

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
  /// 为 null 时使用内置皮肤；非 null 时 [PetConfig.packPath] 是相对于此的路径。
  String? packDir;

  /// 快捷启动快捷键键名，如 `` ` ``、`'g'`。空字符串表示禁用。
  String quickLaunchKey;

  /// 快捷启动快捷键修饰键，如 `['alt']`、`['ctrl', 'shift']`。
  List<String> quickLaunchModifiers;

  /// 界面语言：`system`(跟随系统) / `zh` / `en`。
  String locale;

  SettingsModel({
    this.baseScale = 1.0,
    this.baseOpacity = 1.0,
    this.baseSpeed = 1.0,
    this.packDir,
    this.quickLaunchKey = defaultQuickLaunchKey,
    this.quickLaunchModifiers = defaultQuickLaunchModifiers,
    this.locale = localeSystem,
  });

  // ── JSON ──────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'baseScale': baseScale,
    'baseOpacity': baseOpacity,
    'baseSpeed': baseSpeed,
    'skinDir': packDir,
    'quickLaunchKey': quickLaunchKey,
    'quickLaunchModifiers': quickLaunchModifiers,
    'locale': locale,
  };

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      baseScale: (json['baseScale'] as num?)?.toDouble() ?? 1.0,
      baseOpacity: (json['baseOpacity'] as num?)?.toDouble() ?? 1.0,
      baseSpeed: (json['baseSpeed'] as num?)?.toDouble() ?? 1.0,
      packDir: json['skinDir'] as String?,
      quickLaunchKey: json['quickLaunchKey'] as String? ?? defaultQuickLaunchKey,
      quickLaunchModifiers: (json['quickLaunchModifiers'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? defaultQuickLaunchModifiers,
      locale: json['locale'] as String? ?? localeSystem,
    );
  }

  /// 复制并覆盖部分字段。
  ///
  /// [packDir] 是唯一的可空字段，"没传"与"显式清空"必须区分：传 `null` 表示恢复
  /// 默认（用内置皮肤），不传则保持原值。
  SettingsModel copyWith({
    double? baseScale,
    double? baseOpacity,
    double? baseSpeed,
    Object? packDir = _unset,
    String? quickLaunchKey,
    List<String>? quickLaunchModifiers,
    String? locale,
  }) {
    return SettingsModel(
      baseScale: baseScale ?? this.baseScale,
      baseOpacity: baseOpacity ?? this.baseOpacity,
      baseSpeed: baseSpeed ?? this.baseSpeed,
      packDir: identical(packDir, _unset) ? this.packDir : packDir as String?,
      quickLaunchKey: quickLaunchKey ?? this.quickLaunchKey,
      quickLaunchModifiers: quickLaunchModifiers ?? this.quickLaunchModifiers,
      locale: locale ?? this.locale,
    );
  }
}
