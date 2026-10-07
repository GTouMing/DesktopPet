import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'icon_plate.dart';

/// 横幅类型：错误 / 信息。
enum InfoType { error, info }

/// 顶部信息/错误横幅。
///
/// 信息类自动消失；**错误类不会**。一个带着错误、又在 5 秒后自己消失的横幅，等于
/// 按下定时器丢掉用户的排错线索，所以错误只由用户关闭。
///
/// 关闭走一颗真正的按钮：之前只有 `GestureDetector(onTap:)`，键盘与读屏用户既看不到
/// 提示、也关不掉它。
///
/// 刻意不铺全屏遮罩：那是 5 秒内拦掉整个界面的输入，横幅只该占自己那一块。
class InfoOverlay {
  InfoOverlay._();

  /// 信息类横幅自动消失前停留的时长。
  static const Duration _dwell = Duration(seconds: 5);

  /// 在屏幕顶部弹出横幅。
  static void show(
    BuildContext context, {
    required String title,
    String message = '',
    InfoType type = InfoType.info,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Banner(
        title: title,
        message: message,
        type: type,
        dwell: type == InfoType.info ? _dwell : null,
        onDismiss: entry.remove,
      ),
    );
    overlay.insert(entry);
  }
}

class _Banner extends StatefulWidget {
  const _Banner({
    required this.title,
    required this.message,
    required this.type,
    required this.dwell,
    required this.onDismiss,
  });

  final String title;
  final String message;
  final InfoType type;

  /// null = 不自动消失（错误横幅）。
  final Duration? dwell;
  final VoidCallback onDismiss;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Motion.slow,
    reverseDuration: Motion.fast,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.1),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _ctrl,
    curve: Motion.enter,
    reverseCurve: Motion.exit,
  ));
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0, 0.7, curve: Curves.easeOut),
  );

  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    final dwell = widget.dwell;
    if (dwell != null) _timer = Timer(dwell, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    // 用户关闭系统动效时直接移除，不做滑出。
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onDismiss();
      return;
    }
    _ctrl.reverse().whenComplete(widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (Color accent, PlateTone tone, IconData icon) = switch (widget.type) {
      InfoType.error => (
          scheme.error,
          PlateTone.danger,
          Icons.warning_amber_rounded
        ),
      InfoType.info => (
          scheme.primary,
          PlateTone.accent,
          Icons.info_rounded
        ),
    };

    return Positioned(
      top: MediaQuery.of(context).padding.top + Insets.sm,
      left: Insets.lg,
      right: Insets.lg,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Semantics(
                liveRegion: true,
                container: true,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(Radii.panel),
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Insets.md + 2, Insets.md, Insets.sm, Insets.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconPlate(
                              icon: icon,
                              tone: tone,
                              size: 34,
                              iconSize: 18,
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  if (widget.message.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.message,
                                      style: theme.textTheme.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: Insets.xs),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              tooltip: AppLocalizations.of(context).dismiss,
                              onPressed: _dismiss,
                              style: IconButton.styleFrom(
                                foregroundColor: scheme.onSurfaceVariant,
                                hoverColor:
                                    scheme.onSurface.withValues(alpha: 0.06),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 只有会自己消失的横幅才画剩余时间。
                      if (widget.dwell != null)
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 1, end: 0),
                          duration: widget.dwell!,
                          curve: Curves.linear,
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 3,
                              backgroundColor: Colors.transparent,
                              color: accent.withValues(alpha: 0.45),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
