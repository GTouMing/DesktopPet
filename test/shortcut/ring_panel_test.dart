import 'dart:math' as math;

import 'package:desktop_pet/shortcut/ring_panel.dart';
import 'package:desktop_pet/storage/models/app_shortcut.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppShortcut _item(int i) => AppShortcut(
      name: 'app$i',
      executablePath: 'C:/app$i.exe',
      order: i,
    );

List<AppShortcut> _items(int n) => List.generate(n, _item);

Offset _polar(Offset center, double degrees, double radius) {
  final rad = degrees * math.pi / 180;
  return center + Offset(radius * math.cos(rad), radius * math.sin(rad));
}

/// 采样扇区边界(两侧直边 + 内外弧),断言全部落在 [scene] 内。
///
/// 与实现里的包围盒判据是**两条独立路径**,避免"用实现验证实现"。
void _expectSectorInside(
  Rect scene,
  Offset center,
  double solidRadius,
  double totalRadius,
  ({double start, double sweep}) angles,
) {
  final safe = scene.inflate(1e-6);
  for (var k = 0; k <= 32; k++) {
    final a = angles.start + angles.sweep * k / 32;
    for (final r in [solidRadius, totalRadius]) {
      final p = center + Offset(r * math.cos(a), r * math.sin(a));
      expect(
        safe.contains(p),
        isTrue,
        reason: '越界点 $p(角度 ${(a * 180 / math.pi).toStringAsFixed(1)}°, 半径 $r)',
      );
    }
  }
}

void main() {
  group('ringTotalRadius', () {
    test('一般尺寸: 外接圆半径 + 边长/2', () {
      final r = ringTotalRadius(const Size(200, 200));
      expect(r, closeTo(math.sqrt(200 * 200 + 200 * 200) / 2 + 100, 1e-6));
    });

    test('小桌宠: 不低于下限 150', () {
      expect(ringTotalRadius(const Size(100, 100)), closeTo(150, 1e-6));
    });
  });

  test('ringSolidRadius: 外接圆半径', () {
    expect(ringSolidRadius(const Size(200, 200)),
        closeTo(math.sqrt(200 * 200 + 200 * 200) / 2, 1e-6));
  });

  group('ringGeometry', () {
    test('一般尺寸: 面板为正方形, 边长 = 2*总半径, 以桌宠中心为心', () {
      final g = ringGeometry(
        center: const Offset(500, 400),
        petSize: const Size(200, 200),
        screen: const Size(1920, 1080),
      );
      expect(g.panel.center, const Offset(500, 400));
      expect(g.panel.width, closeTo(g.panel.height, 1e-9));
      expect(g.panel.width, closeTo(g.totalRadius * 2, 1e-9));
      expect(g.solidRadius, closeTo(ringSolidRadius(const Size(200, 200)), 1e-9));
    });

    test('超大桌宠: 面板边长收敛到屏幕较短边, 两半径等比缩小且 solid < total', () {
      final g = ringGeometry(
        center: const Offset(500, 400),
        petSize: const Size(1080, 1080),
        screen: const Size(1920, 1080),
      );
      // 超过屏幕较短边会被系统夹成非正方形, 必须自行收敛。
      expect(g.panel.width, closeTo(1080, 1e-9));
      expect(g.panel.height, closeTo(1080, 1e-9));
      expect(g.panel.width, closeTo(g.totalRadius * 2, 1e-9));
      expect(g.totalRadius, closeTo(540, 1e-9));
      expect(g.solidRadius, lessThan(g.totalRadius));
    });

    test('小桌宠: 面板边长不低于下限半径对应值', () {
      final g = ringGeometry(
        center: const Offset(500, 400),
        petSize: const Size(20, 20),
        screen: const Size(1920, 1080),
      );
      expect(g.totalRadius, closeTo(150, 1e-6));
      expect(g.panel.width, closeTo(300, 1e-6));
      expect(g.panel.width, closeTo(g.panel.height, 1e-9));
    });
  });

  group('ringSectorAngles', () {
    test('8 项: 45° 步进,边界各截断 2.5°,合计留 5° 间隔', () {
      final a = ringSectorAngles(index: 0, count: 8);
      expect(a.start, closeTo(2.5 * math.pi / 180, 1e-9));
      expect(a.sweep, closeTo(40 * math.pi / 180, 1e-9));
      final b = ringSectorAngles(index: 3, count: 8);
      expect(b.start, closeTo(137.5 * math.pi / 180, 1e-9));
    });

    test('1 项: 整圈减去 5° 间隔', () {
      final a = ringSectorAngles(index: 0, count: 1);
      expect(a.start, closeTo(2.5 * math.pi / 180, 1e-9));
      expect(a.sweep, closeTo(355 * math.pi / 180, 1e-9));
    });
  });

  group('hitRingSector', () {
    RingPayload payload(int count) => RingPayload(
          centerInWindow: const Offset(300, 300),
          totalRadius: 200,
          solidRadius: 100,
          items: _items(count),
        );

    test('4 项: 各扇区中心命中', () {
      final p = payload(4);
      for (var i = 0; i < 4; i++) {
        final deg = (i * 90 + 45).toDouble();
        expect(hitRingSector(contentPoint: _polar(p.centerInWindow, deg, 150), payload: p), i);
      }
    });

    test('间隔区(边界 5° 内)不命中', () {
      final p = payload(4);
      // 边界 90°: 起始偏移 2.5° 后落在扇区 0 的尾部间隔内。
      expect(hitRingSector(contentPoint: _polar(p.centerInWindow, 90, 150), payload: p), isNull);
      // 首边界前的间隔。
      expect(hitRingSector(contentPoint: _polar(p.centerInWindow, 1, 150), payload: p), isNull);
    });

    test('纯粉带之外不命中(内圈渐隐区 / 超过总半径)', () {
      final p = payload(4);
      expect(hitRingSector(contentPoint: _polar(p.centerInWindow, 45, 50), payload: p), isNull);
      expect(hitRingSector(contentPoint: _polar(p.centerInWindow, 45, 250), payload: p), isNull);
    });

    test('n=3: 相邻扇区之间的间隔不命中', () {
      final p = payload(3);
      // 边界 120°: 偏移后落在扇区 0 尾部间隔内。
      expect(hitRingSector(contentPoint: _polar(p.centerInWindow, 120, 150), payload: p), isNull);
      // 刚越过间隔进入扇区 1。
      expect(hitRingSector(contentPoint: _polar(p.centerInWindow, 130, 150), payload: p), 1);
    });

    test('空 items: 不命中', () {
      final p = payload(0);
      expect(hitRingSector(contentPoint: p.centerInWindow + const Offset(150, 0), payload: p), isNull);
    });
  });

  group('ringFittingArc', () {
    const scene = Rect.fromLTWH(0, 0, 1920, 1080);
    const petSize = Size(200, 200);
    final solid = ringSolidRadius(petSize);
    final total = ringTotalRadius(petSize);

    /// 逐项断言 8 个扇区都完整落屏。
    void expectAllSectorsInside(Offset center, ({double start, double span}) arc) {
      for (var i = 0; i < 8; i++) {
        _expectSectorInside(
          scene,
          center,
          solid,
          total,
          ringSectorAngles(
            index: i,
            count: 8,
            startAngle: arc.start,
            spanAngle: arc.span,
          ),
        );
      }
    }

    test('居中: 整圈可用 → (0, 2π)', () {
      final arc = ringFittingArc(
        center: const Offset(960, 540),
        scene: scene,
        solidRadius: solid,
        totalRadius: total,
        count: 8,
      );
      expect(arc, isNotNull);
      expect(arc!.start, 0);
      expect(arc.span, closeTo(ringFullSpan, 1e-9));
    });

    test('贴左边界: 弧避开屏幕外方向, 且每个扇区都落屏', () {
      const center = Offset(60, 540);
      final arc = ringFittingArc(
        center: center,
        scene: scene,
        solidRadius: solid,
        totalRadius: total,
        count: 8,
      );
      expect(arc, isNotNull);
      expect(arc!.span, lessThan(ringFullSpan));

      // 正左方(180°)在屏幕外,不能落在可用弧内。
      final startDeg = arc.start * 180 / math.pi;
      final spanDeg = arc.span * 180 / math.pi;
      expect((180 - startDeg) % 360, greaterThan(spanDeg));

      expectAllSectorsInside(center, arc);
    });

    test('贴左上角: 弧约占一圈的四分之一, 且每个扇区都落屏', () {
      const center = Offset(60, 60);
      final arc = ringFittingArc(
        center: center,
        scene: scene,
        solidRadius: solid,
        totalRadius: total,
        count: 8,
      );
      expect(arc, isNotNull);
      final spanDeg = arc!.span * 180 / math.pi;
      expect(spanDeg, greaterThan(80));
      expect(spanDeg, lessThan(180));

      expectAllSectorsInside(center, arc);
    });

    test('可用弧窄到点不中 → null(退回整圈);项数少时仍可用', () {
      // 环带几乎顶到四边:只有四条对角线附近各约 46° 可用 —— 8 项各需 8°,
      // 46 < 64,判定为"点不中"而退回整圈;只要 1 项(8°)就足够。
      const tight = Rect.fromLTWH(0, 0, 400, 400);
      const center = Offset(200, 200);
      expect(
        ringFittingArc(
          center: center,
          scene: tight,
          solidRadius: 190,
          totalRadius: 215,
          count: 8,
        ),
        isNull,
      );
      expect(
        ringFittingArc(
          center: center,
          scene: tight,
          solidRadius: 190,
          totalRadius: 215,
          count: 1,
        ),
        isNotNull,
      );
    });

    test('退化参数: 空场景 / 非正项数 → null', () {
      expect(
        ringFittingArc(
          center: Offset.zero,
          scene: Rect.zero,
          solidRadius: 100,
          totalRadius: 200,
          count: 4,
        ),
        isNull,
      );
      expect(
        ringFittingArc(
          center: const Offset(960, 540),
          scene: scene,
          solidRadius: solid,
          totalRadius: total,
          count: 0,
        ),
        isNull,
      );
    });
  });

  group('ringSectorAngles 可用弧', () {
    test('在 90° 弧内平分: 8 项 = 11.25° 一步, 首项偏移 2.5°', () {
      final a = ringSectorAngles(
        index: 0,
        count: 8,
        startAngle: 0,
        spanAngle: 90 * math.pi / 180,
      );
      expect(a.start, closeTo(2.5 * math.pi / 180, 1e-9));
      expect(a.sweep, closeTo(6.25 * math.pi / 180, 1e-9));

      final b = ringSectorAngles(
        index: 7,
        count: 8,
        startAngle: 0,
        spanAngle: 90 * math.pi / 180,
      );
      expect(b.start, closeTo(81.25 * math.pi / 180, 1e-9));
    });

    test('弧紧到容不下间隔: 不留间隔, 且 sweep 不为负', () {
      final a = ringSectorAngles(
        index: 0,
        count: 8,
        startAngle: 0,
        spanAngle: 20 * math.pi / 180,
      );
      expect(a.sweep, closeTo(2.5 * math.pi / 180, 1e-9));
    });
  });

  group('hitRingSector 可用弧', () {
    // 90° / 2 项 → 步长 45°、间隔 5°:扇区0=[2.5°,42.5°],扇区1=[47.5°,87.5°]。
    RingPayload arcPayload() => RingPayload(
          centerInWindow: const Offset(300, 300),
          totalRadius: 200,
          solidRadius: 100,
          startAngle: 0,
          spanAngle: 90 * math.pi / 180,
          items: _items(2),
        );

    test('弧内: 各扇区中心命中', () {
      final p = arcPayload();
      expect(
        hitRingSector(contentPoint: _polar(p.centerInWindow, 20, 150), payload: p),
        0,
      );
      expect(
        hitRingSector(contentPoint: _polar(p.centerInWindow, 65, 150), payload: p),
        1,
      );
    });

    test('弧外(超过 span)不命中', () {
      final p = arcPayload();
      expect(
        hitRingSector(contentPoint: _polar(p.centerInWindow, 100, 150), payload: p),
        isNull,
      );
      expect(
        hitRingSector(contentPoint: _polar(p.centerInWindow, 300, 150), payload: p),
        isNull,
      );
    });

    test('弧内间隔区 / 起始间隔不命中', () {
      final p = arcPayload();
      expect(
        hitRingSector(contentPoint: _polar(p.centerInWindow, 45, 150), payload: p),
        isNull,
      );
      expect(
        hitRingSector(contentPoint: _polar(p.centerInWindow, 1, 150), payload: p),
        isNull,
      );
    });
  });

  group('RingMenu 渲染', () {
    testWidgets('构建 CustomPaint 且铺满父级可用区域', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: RingMenu(
                payload: RingPayload(
                  centerInWindow: const Offset(200, 200),
                  totalRadius: 150,
                  solidRadius: 90,
                  items: _items(1),
                ),
              ),
            ),
          ),
        ),
      ));

      final paintFinder = find.byType(CustomPaint);
      expect(paintFinder, findsWidgets);
      final painter = tester.widgetList<CustomPaint>(paintFinder).firstWhere(
            (c) => c.painter is RingMenuPainter,
          );
      final ringPainter = painter.painter! as RingMenuPainter;
      expect(ringPainter.payload.totalRadius, 150);
      expect(ringPainter.payload.items.length, 1);

      // 环心由 payload 给出（悬浮窗内容坐标），组件本身铺满父级——它不再是
      // 一个"边长 = 2 × 总半径"的独立面板窗口。
      final ringPaint = find.byElementPredicate((element) {
        final widget = element.widget;
        return widget is CustomPaint && widget.painter is RingMenuPainter;
      });
      expect(tester.getSize(ringPaint), const Size(400, 400));
    });
  });
}
