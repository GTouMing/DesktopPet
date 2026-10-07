import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/constants.dart';
import '../petpack/chat_bubble_content.dart';

/// 在容器 [bounds] 内、围绕桌宠矩形 [petRect] 求气泡左上角。
///
/// 纯函数（不依赖 widget），便于单测。规则：
/// - [BubblePlacement.auto]：优先放上方，上方放不下时翻到下方；
/// - [BubblePlacement.top] / [bottom]：水平以桌宠中心对齐，放在上/下方；
/// - [BubblePlacement.left] / [right]：竖直以桌宠中心对齐，放在左/右侧；
/// - 最后统一夹取到 [bounds] 内（含 [margin] 留白），保证整块气泡可见。
Offset resolveBubbleOffset({
  required Rect petRect,
  required Size bubbleSize,
  required Rect bounds,
  required BubblePlacement placement,
  double gap = chatBubbleGap,
  double margin = chatBubbleScreenMargin,
}) {
  final offset = switch (placement) {
    BubblePlacement.left => Offset(
        petRect.left - gap - bubbleSize.width,
        petRect.center.dy - bubbleSize.height / 2,
      ),
    BubblePlacement.right => Offset(
        petRect.right + gap,
        petRect.center.dy - bubbleSize.height / 2,
      ),
    BubblePlacement.top => Offset(
        _centeredLeft(petRect, bubbleSize),
        petRect.top - gap - bubbleSize.height,
      ),
    BubblePlacement.bottom => Offset(
        _centeredLeft(petRect, bubbleSize),
        petRect.bottom + gap,
      ),
    BubblePlacement.auto =>
      _autoOffset(petRect, bubbleSize, bounds, gap, margin),
  };
  return _clampInto(offset, bubbleSize, bounds, margin);
}

/// `auto`：上方放得下就放上方，否则翻到下方。
Offset _autoOffset(
  Rect petRect,
  Size bubbleSize,
  Rect bounds,
  double gap,
  double margin,
) {
  final left = _centeredLeft(petRect, bubbleSize);
  final above = petRect.top - gap - bubbleSize.height;
  if (above >= bounds.top + margin) return Offset(left, above);
  return Offset(left, petRect.bottom + gap);
}

double _centeredLeft(Rect petRect, Size bubbleSize) =>
    petRect.center.dx - bubbleSize.width / 2;

/// 夹取到 [bounds] 内（`clamp` 要求下界 ≤ 上界，容器比气泡还小时退化为下界）。
Offset _clampInto(Offset offset, Size bubbleSize, Rect bounds, double margin) {
  final minX = bounds.left + margin;
  final maxX = math.max(minX, bounds.right - margin - bubbleSize.width);
  final minY = bounds.top + margin;
  final maxY = math.max(minY, bounds.bottom - margin - bubbleSize.height);
  return Offset(
    offset.dx.clamp(minX, maxX),
    offset.dy.clamp(minY, maxY),
  );
}

/// 把气泡摆到 [petRect] 周围。
///
/// 坐标由 [resolveBubbleOffset] 决定；宽度上限交给 [getConstraintsForChild]，
/// 高度自适应内容（多行文本 / 图片）。
class BubbleAnchorDelegate extends SingleChildLayoutDelegate {
  const BubbleAnchorDelegate({
    required this.petRect,
    required this.placement,
    this.maxWidth = chatBubbleMaxWidth,
  });

  /// 桌宠矩形（与交给本委托的布局尺寸同一坐标系）。
  final Rect petRect;

  final BubblePlacement placement;

  /// 气泡宽度上限（逻辑像素）。
  final double maxWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = constraints.maxWidth - chatBubbleScreenMargin * 2;
    return BoxConstraints(maxWidth: math.min(maxWidth, math.max(0, available)));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return resolveBubbleOffset(
      petRect: petRect,
      bubbleSize: childSize,
      bounds: Offset.zero & size,
      placement: placement,
    );
  }

  @override
  bool shouldRelayout(BubbleAnchorDelegate oldDelegate) =>
      petRect != oldDelegate.petRect ||
      placement != oldDelegate.placement ||
      maxWidth != oldDelegate.maxWidth;
}
