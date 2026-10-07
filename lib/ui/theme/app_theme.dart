import 'package:flutter/material.dart';

/// 设计令牌：间距。
///
/// 与明暗无关的纯常量，不做成 ThemeExtension。
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 36;
}

/// 设计令牌：圆角。
///
/// 只保留三档——控件、面板、胶囊。多于三档就会开始出现"随手取一个"的圆角。
abstract final class Radii {
  static const double control = 12;
  static const double panel = 18;
  static const double pill = 999;
}

/// 设计令牌：动效。
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 130);
  static const Duration slow = Duration(milliseconds: 260);

  /// 入场：快速减速，不用回弹（回弹读起来像玩具）。
  static const Curve enter = Curves.easeOutExpo;

  /// 出场：比入场快，走加速曲线。
  static const Curve exit = Curves.easeInCubic;
}

/// ColorScheme 之外还需要语义色：正向状态色、焦点环。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.positive,
    required this.positiveContainer,
    required this.onPositiveContainer,
    required this.focusRing,
  });

  /// 「显示中」「健康」等正向状态的强调色（小面积用）。
  final Color positive;
  final Color positiveContainer;
  final Color onPositiveContainer;

  /// 焦点环颜色。
  ///
  /// 用墨色而不是品牌色，因为环必须落在**任何**底色上都看得见：白面板、暖沙页面、
  /// 蜜色主填充、橄榄副填充。实测对白面板 14.53:1、暖沙 13.44:1、蜜色主填充 3.13:1，
  /// 对橄榄副填充与各类 container 均在 11:1 以上。品牌色做主填充时自己就是底色，
  /// 拿它当环会直接消失。
  final Color focusRing;

  /// 焦点环的墨色本身，供 ThemeData.focusColor / overlay 复用。
  static const Color focusRingInk = Color(0xFF2B2620);

  static const AppColors light = AppColors(
    positive: Color(0xFF4E6B3F),
    positiveContainer: Color(0xFFDCE8CE),
    onPositiveContainer: Color(0xFF17240F),
    focusRing: focusRingInk,
  );

  @override
  AppColors copyWith({
    Color? positive,
    Color? positiveContainer,
    Color? onPositiveContainer,
    Color? focusRing,
  }) {
    return AppColors(
      positive: positive ?? this.positive,
      positiveContainer: positiveContainer ?? this.positiveContainer,
      onPositiveContainer: onPositiveContainer ?? this.onPositiveContainer,
      focusRing: focusRing ?? this.focusRing,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      positive: Color.lerp(positive, other.positive, t)!,
      positiveContainer:
          Color.lerp(positiveContainer, other.positiveContainer, t)!,
      onPositiveContainer:
          Color.lerp(onPositiveContainer, other.onPositiveContainer, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// 全局主题。
///
/// 方向是"暖房"：暖沙色纸面、蜜色单一强调色、软材质面板（描边而非投影）、
/// 圆角图标。刻意避开 M3 默认的粉紫与 `colorSchemeSeed` 直接生成的通用观感。
abstract final class AppTheme {
  /// 已构建好的主题（缓存）。
  ///
  /// 三个 MaterialApp 根都在 `build()` 里取主题，`OverlayScene` 还会随存储/桌宠变化
  /// 频繁重建。每次重建都重造一棵 ThemeData（scheme + 11 个文字样式 + 20 多个组件
  /// 主题）纯属白做，所以这里只构建一次。
  static final ThemeData _light = _buildLight();

  /// 焦点 / 悬停 / 按下的叠色，一律用墨色。
  ///
  /// 刻意不用"控件自己的前景色"：`filledButtonTheme` 同时作用于 `FilledButton` 与
  /// `FilledButton.tonal`，两者底色一亮一暗，任何单一前景色都会在其中一种上失效。
  /// 墨色对蜜色主填充、橄榄副填充、透明底都成立。焦点档 0.32 明显高于悬停 0.08 与
  /// 按下 0.16，所以键盘焦点不会被误读成鼠标经过。
  static final WidgetStateProperty<Color?> _focusOverlay =
      WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return AppColors.focusRingInk.withValues(alpha: 0.32);
    }
    if (states.contains(WidgetState.pressed)) {
      return AppColors.focusRingInk.withValues(alpha: 0.16);
    }
    if (states.contains(WidgetState.hovered)) {
      return AppColors.focusRingInk.withValues(alpha: 0.08);
    }
    return null;
  });

  /// 悬浮窗场景用的透明版本。
  static final ThemeData _overlay = _light.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
  );

  /// 焦点环。
  ///
  /// 环色取"与该控件自身填充对比"的那一支：浅底/透明底用墨色 [AppColors.focusRingInk]，
  /// 深底（蜜色主填充、危险色填充）用它自己的前景色。没有一种颜色能同时压过蜜色与
  /// 橄榄色（两者亮度差太大，需要亮度既 ≥0.52 又 ≤0.23，无解），而
  /// `filledButtonTheme` 又同时管着 `FilledButton` 与 `FilledButton.tonal` 两种底色，
  /// 所以深底那支只能在调用点单独给（见 pet_list 的空状态按钮）。
  ///
  /// [base] 是未聚焦时的描边（带描边的控件必须回填，否则返回 null 会抹掉它原本的边）。
  static WidgetStateProperty<BorderSide?> focusRing(
    Color ring, {
    BorderSide? base,
  }) {
    return WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.focused)
            ? BorderSide(color: ring, width: 2)
            : base);
  }

  /// Windows 设置窗口与 Android 主界面共用的一套主题。
  ///
  /// 强调色相固定在蜜色（约 0xFF96550A）：暖、有陪伴感，且不是"科技蓝紫"。
  static ThemeData light() => _light;

  /// 悬浮窗（桌宠场景）用的主题：其余一致，只是背景透明。
  static ThemeData overlay() => _overlay;

  static ThemeData _buildLight() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      // ── 表面：暖沙纸面 ────────────────────────────────────────────
      surface: Color(0xFFF7F2E9),
      onSurface: Color(0xFF2B2620),
      onSurfaceVariant: Color(0xFF6B6154),
      surfaceDim: Color(0xFFE7E0D2),
      surfaceBright: Color(0xFFFFFCF6),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFFFBF4),
      surfaceContainer: Color(0xFFF3ECE0),
      surfaceContainerHigh: Color(0xFFEDE5D7),
      surfaceContainerHighest: Color(0xFFE7DECE),
      outline: Color(0xFF8C8172),
      outlineVariant: Color(0xFFE0D6C5),
      // ── 强调色：蜜色 ──────────────────────────────────────────────
      // 比原来的 #A8610F 再深一档：白字对它从 4.54:1 提到 5.53:1，它作文字落在
      // 面板上从 4.65:1 提到 5.65:1。原来两个方向都只压着 AA 线 0.05 左右，
      // 任何一次微调都会悄悄掉到线下。
      primary: Color(0xFF96550A),
      onPrimary: Color(0xFFFFF8EE),
      primaryContainer: Color(0xFFF7E2C1),
      onPrimaryContainer: Color(0xFF3A2408),
      // ── 次强调：橄榄灰绿，只做低饱和衬色 ──────────────────────────
      secondary: Color(0xFF5F6B4E),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFDDE7CB),
      onSecondaryContainer: Color(0xFF1B2410),
      tertiary: Color(0xFF8A5340),
      onTertiary: Color(0xFFFFF8F5),
      tertiaryContainer: Color(0xFFF3DCCF),
      onTertiaryContainer: Color(0xFF37211A),
      // ── 危险色：陶土红 ────────────────────────────────────────────
      error: Color(0xFFB2331F),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF9DAD2),
      onErrorContainer: Color(0xFF41100A),
      // ── 反色：用于浮层（横幅/提示）────────────────────────────────
      inverseSurface: Color(0xFF332E27),
      onInverseSurface: Color(0xFFF7F2E9),
      inversePrimary: Color(0xFFF0B457),
      shadow: Color(0xFF2B2620),
      scrim: Color(0xFF2B2620),
      surfaceTint: Color(0x00000000),
    );

    final text = _textTheme(scheme);
    const onSurfaceTint = Colors.transparent;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      // ListTile / 卡片 / chip / 自定义 InkWell 的焦点反馈都走 InkWell 的默认色；
      // M3 默认只有 12%，在暖色底上基本看不出来，这里统一抬到看得见的一档。
      focusColor: AppColors.focusRingInk.withValues(alpha: 0.24),
      visualDensity: VisualDensity.standard,
      textTheme: text,
      primaryTextTheme: text,
      extensions: const <ThemeExtension<dynamic>>[AppColors.light],

      // ── 顶栏：左对齐、无阴影、无色调 ──────────────────────────────
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: onSurfaceTint,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleSpacing: Insets.lg,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      ),

      // ── 面板：描边而非投影 ────────────────────────────────────────
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: onSurfaceTint,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.panel),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleMedium?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        minVerticalPadding: Insets.md,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),

      // ── 控件 ─────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.xl, vertical: Insets.md + 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ).copyWith(
          overlayColor: _focusOverlay,
          // 蜜色填充用白环（5.53:1）。叠色在深底上只有 1.44:1，肉眼分辨不出来。
          side: focusRing(scheme.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.xl, vertical: Insets.md + 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ).copyWith(
          overlayColor: _focusOverlay,
          // 带描边的控件必须回填未聚焦时的描边，否则 null 会把它原本的边一起抹掉。
          side: focusRing(
            AppColors.focusRingInk,
            base: BorderSide(color: scheme.outline),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ).copyWith(
          overlayColor: _focusOverlay,
          side: focusRing(AppColors.focusRingInk),
        ),
      ),
      // 刻意**不**设 foregroundColor。
      //
      // 主题样式的优先级高于各变体自己的默认值：一旦在这里写死 onSurfaceVariant，
      // `IconButton.filled` / `.tonal` 就会拿到一个与自身深色填充几乎同亮的图标
      // （蜜色填充上实测 1.04:1，等于看不见）。M3 给普通图标按钮的默认前景本来就是
      // onSurfaceVariant，所以不写反而与原来一致，且变体各自拿到正确的前景色。
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ).copyWith(
          overlayColor: _focusOverlay,
          // 主题级墨色环：所有图标按钮（设置/删除/编辑/关闭/浏览…）一次覆盖。
          side: focusRing(AppColors.focusRingInk),
        ),
      ),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        // 比面板更亮一档：暖色面板上的输入框仍然一眼可辨。
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Insets.lg, vertical: Insets.md + 2),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        prefixIconColor: scheme.onSurfaceVariant,
        border: _inputBorder(scheme, scheme.outlineVariant, 1),
        enabledBorder: _inputBorder(scheme, scheme.outlineVariant, 1),
        focusedBorder: _inputBorder(scheme, scheme.primary, 1.6),
        errorBorder: _inputBorder(scheme, scheme.error, 1),
        focusedErrorBorder: _inputBorder(scheme, scheme.error, 1.6),
      ),

      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        // 这里只能是纯色（SliderThemeData 没有状态解析）；真正的焦点态在
        // SliderField 通过 `Slider.overlayColor` 单独给（那个才是按状态解析的）。
        overlayColor: AppColors.focusRingInk.withValues(alpha: 0.14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        trackShape: const RoundedRectSliderTrackShape(),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorColor: scheme.inverseSurface,
        valueIndicatorTextStyle: text.labelMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        // 不指定颜色：让 M3 按未选中/选中/禁用自行解析，避免选中态文字对比度不足。
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
        shape: const StadiumBorder(),
        // 选中态永远带勾选标记，不靠颜色单独表意。
        showCheckmark: true,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline;
        }),
      ),

      // ── 浮层 ─────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: onSurfaceTint,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
            horizontal: Insets.xl, vertical: Insets.xl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.panel + 2),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: onSurfaceTint,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.panel + 2),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: onSurfaceTint,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(Radii.control - 4),
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.md, vertical: Insets.sm),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double>(8),
        radius: const Radius.circular(Radii.pill),
        thumbColor: WidgetStatePropertyAll<Color>(
          scheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(
    ColorScheme scheme,
    Color color,
    double width,
  ) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.control),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// 字号/字重对比拉开的三级层次，颜色跟随 scheme。
  static TextTheme _textTheme(ColorScheme scheme) {
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: 13.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 13.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontSize: 14.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontSize: 12.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: muted,
      ),
    );
  }
}
