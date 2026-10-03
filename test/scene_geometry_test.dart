import 'dart:ui';

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

  test('矩形列表等价比较', () {
    const a = [Rect.fromLTWH(0, 0, 10, 10)];

    expect(GrabRectPublisher.sameRects(a, [const Rect.fromLTWH(0, 0, 10, 10)]),
        isTrue);
    expect(GrabRectPublisher.sameRects(a, const []), isFalse);
    expect(
        GrabRectPublisher.sameRects(a, [const Rect.fromLTWH(0, 0, 10, 11)]),
        isFalse);
    expect(
        GrabRectPublisher.sameRects(a, [
          const Rect.fromLTWH(0, 0, 10, 10),
          const Rect.fromLTWH(5, 5, 10, 10),
        ]),
        isFalse);
  });
}
