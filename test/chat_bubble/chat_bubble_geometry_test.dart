import 'dart:ui';

import 'package:desktop_pet/chat_bubble/chat_bubble_geometry.dart';
import 'package:desktop_pet/petpack/chat_bubble_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// 400×400 的容器，桌宠 40×40、气泡 100×50，默认 gap=8 / margin=8。
const _bounds = Rect.fromLTWH(0, 0, 400, 400);
const _bubble = Size(100, 50);

Offset place(Rect petRect, BubblePlacement placement) => resolveBubbleOffset(
      petRect: petRect,
      bubbleSize: _bubble,
      bounds: _bounds,
      placement: placement,
    );

void main() {
  test('auto：上方放得下 → 放上方、水平以桌宠居中', () {
    // 桌宠中心 x=200，上方空间 200-8-50=142。
    final offset = place(const Rect.fromLTWH(180, 200, 40, 40),
        BubblePlacement.auto);
    expect(offset, const Offset(150, 142));
  });

  test('auto：上方放不下 → 翻到下方', () {
    // 上方 = 10-8-50 < 0，下方 = 50+8 = 58。
    final offset =
        place(const Rect.fromLTWH(180, 10, 40, 40), BubblePlacement.auto);
    expect(offset, const Offset(150, 58));
  });

  test('auto：水平贴左边 → 夹取到 margin 内', () {
    // 居中会得到 -30，夹到 8。
    final offset =
        place(const Rect.fromLTWH(0, 200, 40, 40), BubblePlacement.auto);
    expect(offset.dx, 8);
  });

  test('显式 top：上方空间不足时仍夹取到容器内', () {
    final offset =
        place(const Rect.fromLTWH(180, 10, 40, 40), BubblePlacement.top);
    expect(offset, const Offset(150, 8));
  });

  test('显式 bottom：放在桌宠下方、水平居中', () {
    final offset =
        place(const Rect.fromLTWH(180, 200, 40, 40), BubblePlacement.bottom);
    expect(offset, const Offset(150, 248));
  });

  test('显式 left / right：竖直以桌宠居中并夹取', () {
    final pet = const Rect.fromLTWH(100, 100, 40, 40);
    expect(place(pet, BubblePlacement.left), const Offset(8, 95));
    expect(place(pet, BubblePlacement.right), const Offset(148, 95));
  });

  test('容器比气泡还小 → 退化到 margin，不抛异常', () {
    final offset = resolveBubbleOffset(
      petRect: const Rect.fromLTWH(0, 0, 10, 10),
      bubbleSize: _bubble,
      bounds: const Rect.fromLTWH(0, 0, 50, 50),
      placement: BubblePlacement.auto,
    );
    expect(offset, const Offset(8, 8));
  });
}
