import 'package:desktop_pet/core/hit_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rect 形状相等且 isRect', () {
    expect(const HitShape.rect(), const HitShape.rect());
    expect(const HitShape.rect().hashCode, const HitShape.rect().hashCode);
    expect(const HitShape.rect().isRect, isTrue);
  });

  test('grid 形状按内容比较', () {
    const a = HitShape.grid(cols: 2, rows: 2, bits: [0x1, 0x2]);

    expect(a, const HitShape.grid(cols: 2, rows: 2, bits: [0x1, 0x2]));
    expect(a == const HitShape.grid(cols: 2, rows: 2, bits: [0x1, 0x3]), isFalse);
    expect(a == const HitShape.grid(cols: 2, rows: 1, bits: [0x1]), isFalse);
    expect(a == const HitShape.rect(), isFalse);
    expect(a.isRect, isFalse);
  });

  test('grid 的 hashCode 按位图内容一致', () {
    expect(
      const HitShape.grid(cols: 1, rows: 2, bits: [1, 2]).hashCode,
      const HitShape.grid(cols: 1, rows: 2, bits: [1, 2]).hashCode,
    );
  });
}
