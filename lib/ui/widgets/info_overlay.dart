import 'package:flutter/material.dart';

/// 横幅类型：错误（淡红）/ 信息（蓝色）。
enum InfoType { error, info }

/// 灵动岛风格信息/错误横幅。
///
/// 从 screen 顶部向下弹出，5秒自动消失，轻触关闭。
/// 文本由调用方提供，本组件不解析。
///
/// ## 使用
/// ```dart
/// InfoOverlay.show(context, title: '保存失败', message: '磁盘空间不足', type: InfoType.error);
/// InfoOverlay.show(context, title: '导入成功', message: '已导入 3 个皮肤');
/// ```
class InfoOverlay {
  InfoOverlay._();

  /// 在 Screen 顶部弹出横幅。
  static void show(
    BuildContext context, {
    required String title,
    String message = '',
    InfoType type = InfoType.info,
  }) {
    _showPill(context, title: title, message: message, type: type);
  }

  // ── 内部实现 ─────────────────────────────────────────────────────────

  static void _showPill(
    BuildContext context, {
    required String title,
    required String message,
    required InfoType type,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _EntryBanner(
        title: title,
        message: message,
        type: type,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

// ── 弹出式横幅（用于 Overlay） ─────────────────────────────────────────

class _EntryBanner extends StatefulWidget {
  final String title;
  final String message;
  final InfoType type;
  final VoidCallback onDismiss;
  const _EntryBanner({
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_EntryBanner> createState() => _EntryBannerState();
}

class _EntryBannerState extends State<_EntryBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(onTap: _dismiss, child: const SizedBox.expand()),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: GestureDetector(
                onTap: _dismiss,
                child: _Pill(
                  title: widget.title,
                  message: widget.message,
                  type: widget.type,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 胶囊 ───────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String title;
  final String message;
  final InfoType type;

  const _Pill({
    required this.title,
    required this.message,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color shadow) = switch (type) {
      InfoType.error => (const Color(0xFFCC3333), const Color(0x66FF4444)),
      InfoType.info  => (const Color(0xFF3388CC), const Color(0x664488FF)),
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(
            type == InfoType.error
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
