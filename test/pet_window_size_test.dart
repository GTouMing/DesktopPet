import 'package:desktop_pet/pet/pet_size.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const maxSize = Size(1920, 1080);

  Size fit(Size sprite) => fitPetSize(spriteSize: sprite, maxSize: maxSize);

  test('屏幕内: 原样返回, 不改尺寸', () {
    expect(fit(const Size(200, 200)), const Size(200, 200));
    expect(fit(const Size(300, 100)), const Size(300, 100));
  });

  group('非正方形精灵图保持比例(不强制 1:1)', () {
    test('宽扁精灵: 窗口不被拉成正方形', () {
      final size = fit(const Size(300, 100));
      expect(size.width / size.height, closeTo(3.0, 1e-6));
      expect(size.width, isNot(closeTo(size.height, 1.0)));
    });

    test('竖长精灵: 窗口不被拉成正方形', () {
      final size = fit(const Size(100, 300));
      expect(size.width / size.height, closeTo(1 / 3, 1e-6));
    });
  });

  test('超过屏幕: 等比缩小到屏幕内', () {
    final size = fit(const Size(3000, 3000));
    expect(size.width, lessThanOrEqualTo(1920));
    expect(size.height, lessThanOrEqualTo(1080));
    expect(size.width / size.height, closeTo(1.0, 1e-3));
  });

  test('宽扁精灵超屏: 按宽度收敛, 比例保持', () {
    final size = fit(const Size(4000, 1000));
    expect(size.width, closeTo(1920, 1e-6));
    expect(size.height, closeTo(480, 1e-6));
    expect(size.width / size.height, closeTo(4.0, 1e-6));
  });

  test('退化输入: 精灵图尺寸为 0 时原样返回', () {
    expect(fit(Size.zero), Size.zero);
    expect(fit(const Size(0, 100)), const Size(0, 100));
  });
}
