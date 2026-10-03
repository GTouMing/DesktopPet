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
