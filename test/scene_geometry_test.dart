import 'dart:ui';

import 'package:desktop_pet/core/hit_shape.dart';
import 'package:desktop_pet/input/input.dart';
import 'package:desktop_pet/ui/host/grab_rects.dart';
import 'package:desktop_pet/ui/host/scene_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('场景矩形 → 物理屏幕矩形(含负原点，多显示器)', () {
    final physical = SceneGeometry.toPhysicalRect(
      const Rect.fromLTWH(10, 20, 100, 50),
      const Offset(-1920, -100),
      2.0,
    );

    expect(physical, const Rect.fromLTRB(-1900, -60, -1700, 40));
  });

  test('命中区域列表等价比较(含形状)', () {
    const rect = Rect.fromLTWH(0, 0, 10, 10);
    final a = <WatchRegion>[(rect: rect, shape: const HitShape.rect())];

    expect(
      GrabRectPublisher.sameRegions(
          a, [(rect: rect, shape: const HitShape.rect())]),
      isTrue,
    );
    expect(GrabRectPublisher.sameRegions(a, const []), isFalse);
    expect(
      GrabRectPublisher.sameRegions(a, [
        (rect: const Rect.fromLTWH(0, 0, 10, 11), shape: const HitShape.rect()),
      ]),
      isFalse,
    );
    expect(
      GrabRectPublisher.sameRegions(a, [
        (rect: rect, shape: const HitShape.rect()),
        (rect: const Rect.fromLTWH(5, 5, 10, 10), shape: const HitShape.rect()),
      ]),
      isFalse,
    );
    // 同一矩形、不同形状 → 不等价（形状参与比较）。
    expect(
      GrabRectPublisher.sameRegions(a, [
        (rect: rect, shape: const HitShape.grid(cols: 1, rows: 1, bits: [1])),
      ]),
      isFalse,
    );
  });
}
