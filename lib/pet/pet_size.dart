import 'dart:math' as math;
import 'dart:ui';

/// 按精灵图比例把桌宠的渲染尺寸收敛到场景内。
///
/// 窗口与精灵图保持同一宽高比（**不强制 1:1**），只在超过场景时**等比**缩小，
/// 保证精灵图不变形。缩放上限（`maxFinalScale`）之外，这是第二道保险：极端缩放
/// 或小屏幕下也不让桌宠被场景裁掉。
Size fitPetSize({
  required Size spriteSize,
  required Size maxSize,
}) {
  if (spriteSize.width <= 0 || spriteSize.height <= 0) return spriteSize;
  if (maxSize.width <= 0 || maxSize.height <= 0) return spriteSize;

  final scale = math.min(
    maxSize.width / spriteSize.width,
    maxSize.height / spriteSize.height,
  );
  if (scale >= 1.0) return spriteSize;
  return Size(spriteSize.width * scale, spriteSize.height * scale);
}
