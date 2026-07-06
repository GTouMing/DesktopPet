import 'package:flutter/material.dart';

import 'sprite_sheet_generator.dart';

/// 纯帧渲染器，仅负责从精灵图集绘制指定帧，不做任何变换。
class SpriteRenderer extends CustomPainter {
  final SpriteSheetData sheet;
  final int currentFrame;

  SpriteRenderer({
    required this.sheet,
    required this.currentFrame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sheet.frameCount == 0) return;

    final frameIndex = currentFrame % sheet.frameCount;
    final src = sheet.getFrameRect(frameIndex);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(
      sheet.image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(SpriteRenderer oldDelegate) {
    return oldDelegate.currentFrame != currentFrame ||
        oldDelegate.sheet != sheet;
  }
}