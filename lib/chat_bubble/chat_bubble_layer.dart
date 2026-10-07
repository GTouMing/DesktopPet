import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/enums.dart';
import '../pet/chat_bubble_payload.dart';
import '../pet/pet_providers.dart';
import '../petpack/chat_bubble_content.dart';
import '../ui/theme/app_theme.dart';
import 'chat_bubble_geometry.dart';

/// 一只桌宠的聊天气泡层。
///
/// 与 `RingOverlay` 同一套路：永远是 [Positioned.fill] 这一个 widget 类型，只在内部
/// 换内容——`Positioned` 是 ParentDataWidget，反复挂载/卸载会走祖先链查找，在这个会
/// 增删成员的 Stack 里会抛 "Looking up a deactivated widget's ancestor is unsafe"。
///
/// 纯展示：整层 [IgnorePointer]，不接收指针事件（Windows 悬浮窗整窗穿透本就收不到，
/// Android 上让点击穿过气泡落到桌宠）。
class ChatBubbleLayer extends ConsumerStatefulWidget {
  const ChatBubbleLayer({
    super.key,
    required this.petId,
    required this.petRect,
  });

  final String petId;

  /// 桌宠在**本层坐标系**里的矩形。
  ///
  /// 本层铺满所在 Stack（Windows = 场景面积；Android = 悬浮窗）：Windows 传
  /// `PetState.position & finalPetSize`；Android 传
  /// `Rect.fromLTWH(0, chatBubbleAndroidHeadroom, w, h)`（桌宠画在窗口底部）。
  final Rect petRect;

  @override
  ConsumerState<ChatBubbleLayer> createState() => _ChatBubbleLayerState();
}

class _ChatBubbleLayerState extends ConsumerState<ChatBubbleLayer>
    with SingleTickerProviderStateMixin {
  // 在 initState 里创建（而不是 `late final` 惰性初始化）：气泡从未显示时 [_anim]
  // 不会有任何读取，若到 dispose 才惰性创建，就会在卸载阶段做祖先查找并抛
  // "Looking up a deactivated widget's ancestor is unsafe"。
  late final AnimationController _anim;
  late final Animation<double> _fade;

  /// 正在显示的气泡（收起动画播完才清空，与 `RingOverlay` 同款）。
  ChatBubblePayload? _shown;

  /// 用户关闭了系统动效时直接切换，不做淡入淡出。
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: Motion.slow,
      reverseDuration: Motion.fast,
    );
    _fade = CurvedAnimation(
      parent: _anim,
      curve: Motion.enter,
      reverseCurve: Motion.exit,
    );
    // 本层可能晚于气泡建立（宿主重建）：直接就位，不播入场动画。
    _shown = ref.read(petStateProvider(widget.petId)).bubble;
    if (_shown != null) _anim.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onBubbleChanged(ChatBubblePayload? bubble) {
    if (bubble == null) {
      _close();
      return;
    }
    setState(() => _shown = bubble);
    if (_reduceMotion) {
      _anim.value = 1;
      return;
    }
    _anim.duration = Motion.slow;
    _anim.forward(from: 0);
  }

  void _close() {
    if (_shown == null) return;
    if (_reduceMotion) {
      setState(() => _shown = null);
      return;
    }
    _anim.duration = Motion.fast;
    unawaited(_anim.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() => _shown = null);
    }));
  }

  @override
  Widget build(BuildContext context) {
    // 只对"换了一条气泡"（seq 变化）反应：重复显示同一条也要重播入场动画。
    ref.listen(petStateProvider(widget.petId), (prev, next) {
      if (prev?.bubble?.seq == next.bubble?.seq) return;
      _onBubbleChanged(next.bubble);
    });

    final shown = _shown;
    return Positioned.fill(
      child: IgnorePointer(
        child: shown == null
            ? const SizedBox.shrink()
            : _AnchoredBubble(
                key: ValueKey(shown.seq),
                content: shown.content,
                petRect: widget.petRect,
                image: _imageProvider(shown.content.image),
                animation: _fade,
              ),
      ),
    );
  }

  /// 内容里的图片相对路径 → 可渲染的 [ImageProvider]。
  ///
  /// 口径与精灵图帧一致：asset 包拼成 asset 键，文件系统包拼成绝对路径。
  /// 气泡只在宠物包就绪后才会存在，故 `pack` 必然可读。
  ImageProvider? _imageProvider(String? image) {
    if (image == null || image.isEmpty) return null;
    final pack = ref.read(petStateProvider(widget.petId).notifier).pack;
    final path = '${pack.basePath}/$image';
    return pack.source == PetPackSource.asset
        ? AssetImage(path)
        : FileImage(File(path));
  }
}

/// 按 [petRect] 摆位、并套上淡入淡出的气泡卡片。
class _AnchoredBubble extends StatelessWidget {
  const _AnchoredBubble({
    super.key,
    required this.content,
    required this.petRect,
    required this.image,
    required this.animation,
  });

  final ChatBubbleContent content;
  final Rect petRect;
  final ImageProvider? image;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomSingleChildLayout(
          delegate: BubbleAnchorDelegate(
            petRect: petRect,
            placement: content.placement,
            maxWidth: content.maxWidth ?? chatBubbleMaxWidth,
          ),
          child: FadeTransition(
            opacity: animation,
            child: _BubbleCard(text: content.text, image: image),
          ),
        );
      },
    );
  }
}

/// 气泡本体：文本 / 图片，视觉与 `InfoOverlay` 的横幅同一套「暖房」语言。
class _BubbleCard extends StatelessWidget {
  const _BubbleCard({required this.text, this.image});

  final String? text;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasText = text != null && text!.isNotEmpty;
    final hasImage = image != null;

    return Semantics(
      liveRegion: true,
      container: true,
      label: hasText ? text : null,
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
        child: Padding(
          padding: const EdgeInsets.all(Insets.sm + 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.control),
                  child: Image(
                    image: image!,
                    fit: BoxFit.contain,
                    // 图片缺失/损坏只隐藏图片本身，气泡其余内容照常显示。
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              if (hasImage && hasText) const SizedBox(height: Insets.sm),
              if (hasText) Text(text!, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
