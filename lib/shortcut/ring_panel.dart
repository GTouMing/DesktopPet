import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/storage/models/app_shortcut.dart';
import 'package:flutter/material.dart';

/// 环形菜单的纯粉色主色。
const Color _ringPink = Color(0xFFFF69B4);

/// 整圈张角(2π):可用弧缺省即整圈。
const double ringFullSpan = 2 * math.pi;

/// 环形菜单面板的数据与几何(单点真相,纯函数可单测)。
///
/// 几何(均以**场景坐标**表示,见 `ui/host/scene_geometry.dart`):
/// - 环心 [centerInWindow] = 目标桌宠中心;
/// - [totalRadius] 总半径(粉色带外缘);
/// - [solidRadius] 外接圆半径(纯粉带内缘),再向内按二次函数渐隐至透明;
/// - [startAngle]/[spanAngle] = 本次实际使用的**可用弧**:贴边时只占朝向屏内的
///   那一段(见 [ringFittingArc]),整圈可用时即 `(0, 2π)`。
class RingPayload {
  /// 环心(场景坐标)。
  final Offset centerInWindow;

  /// 总半径:粉色带外缘。
  final double totalRadius;

  /// 外接圆半径:纯粉带内缘;由此向内二次渐隐至透明。
  final double solidRadius;

  /// 可用弧的起始角(弧度)。整圈可用时为 0。
  final double startAngle;

  /// 可用弧的张角(弧度)。整圈可用时为 [ringFullSpan]。
  final double spanAngle;

  /// 展示的快捷项(最多 [quickLaunchMaxItems] 个)。
  final List<AppShortcut> items;

  const RingPayload({
    this.centerInWindow = Offset.zero,
    this.totalRadius = quickLaunchMinRadius,
    required this.solidRadius,
    this.startAngle = 0,
    this.spanAngle = ringFullSpan,
    required this.items,
  });
}

/// 当前呈现中的环形菜单（null = 未呈现）。
///
/// 由 [QuickLaunchInputHost] 写入、[RingOverlay] 读取——两者都在 shortcut 层，
/// 所以这份状态跟着环形菜单走，而不是留在场景共享状态里（那会让 core 反向依赖
/// shortcut）。
final ValueNotifier<RingPayload?> ringPresented =
    ValueNotifier<RingPayload?>(null);

/// 桌宠窗口的外接圆半径(纯粉带内缘)。
double ringSolidRadius(Size petSize) {
  final squared =
      petSize.width * petSize.width + petSize.height * petSize.height;
  return math.sqrt(squared) / 2;
}

/// 总半径基准: 桌宠外接圆半径 + 桌宠边长 / 2,不低于 [quickLaunchMinRadius]。
double ringTotalRadius(Size petSize) {
  final side = math.max(petSize.width, petSize.height);
  final wanted = ringSolidRadius(petSize) + side / 2;
  return math.max(wanted, quickLaunchMinRadius);
}

/// 环形菜单几何(单点真相): 面板恒为正方形,且边长不超过屏幕较短边。
///
/// [panel] 是环的外接正方形(悬浮窗内容坐标),既用于向原生声明"这块要接收
/// 鼠标"(否则在扇区上松手会点到底下的程序),也用于判定环是否完整落屏。
/// 半径超出屏幕时两个半径等比缩小,保证"边长 = 2 × [totalRadius]"这一前提成立。
({Rect panel, double totalRadius, double solidRadius}) ringGeometry({
  required Offset center,
  required Size petSize,
  required Size screen,
}) {
  final maxSide = math.min(screen.width, screen.height);
  var total = ringTotalRadius(petSize);
  var solid = ringSolidRadius(petSize);
  if (total * 2 > maxSide) {
    final scale = maxSide / (total * 2);
    total *= scale;
    solid *= scale;
  }
  return (
    panel: Rect.fromCenter(center: center, width: total * 2, height: total * 2),
    totalRadius: total,
    solidRadius: solid,
  );
}

/// 每项两侧各截断的间隔(弧度)。
///
/// 弧紧到单项跨度容不下间隔时不留间隔(否则 sweep 会变成负数)。
double _insetFor(double step) {
  final gap = quickLaunchSectorGapDeg * math.pi / 180;
  return step > 2 * gap ? gap / 2 : 0.0;
}

/// 第 [index]/[count] 个扇区的角度。
///
/// 默认铺满整圈;贴边时 [startAngle]/[spanAngle] 给出可用的那段弧,各项在弧内
/// 平分。边界处各截断 [quickLaunchSectorGapDeg] / 2(合计 5°) 区分触发区。
({double start, double sweep}) ringSectorAngles({
  required int index,
  required int count,
  double startAngle = 0,
  double spanAngle = ringFullSpan,
}) {
  assert(count > 0, 'count must be positive');
  final step = spanAngle / count;
  final inset = _insetFor(step);
  return (start: startAngle + index * step + inset, sweep: step - 2 * inset);
}

/// 贴边时的**可用弧**:半径不变时环能完整落屏的那段连续角度区间。
///
/// 判据(充要):环形扇区 `[a,b] × [solidRadius, totalRadius]` 的包围盒 ⊆ [scene]
/// ——矩形包含一个集合,等价于包含它的包围盒。
///
/// 以 [scanDeg] 为步长逐格判定,取**最长连续可行段**;按圆周处理(允许跨 0°):
/// 否则贴左边界时可行段会被 0° 切成两半、只能取到一半弧。
///
/// 返回:
/// - 整圈都可行 → `(0, 2π)`,与不贴边时的行为逐值一致;
/// - 可行弧窄于 `count × [minItemDeg]` → `null`,由调用方退回"整圈 + 等比缩小"。
({double start, double span})? ringFittingArc({
  required Offset center,
  required Rect scene,
  required double solidRadius,
  required double totalRadius,
  required int count,
  double minItemDeg = quickLaunchMinItemDeg,
  double scanDeg = quickLaunchArcScanDeg,
}) {
  if (count <= 0 || scene.isEmpty || totalRadius <= 0) return null;

  final step = scanDeg * math.pi / 180;
  if (step <= 0) return null;
  final cells = (2 * math.pi / step).round();
  if (cells <= 0) return null;

  const eps = 1e-6;
  final ok = List<bool>.filled(cells, false);
  for (var i = 0; i < cells; i++) {
    final a = i * step;
    // _arcBounds 以原点为心,必须平移到环心才是扇区在场景里的包围盒。
    final box = _arcBounds(totalRadius, a, a + step)
        .expandToInclude(_arcBounds(solidRadius, a, a + step))
        .shift(center);
    ok[i] = box.left >= scene.left - eps &&
        box.top >= scene.top - eps &&
        box.right <= scene.right + eps &&
        box.bottom <= scene.bottom + eps;
  }

  // 整圈都可行。
  var anchor = -1;
  for (var i = 0; i < cells; i++) {
    if (!ok[i]) {
      anchor = i;
      break;
    }
  }
  if (anchor < 0) return (start: 0.0, span: ringFullSpan);

  // 从不可行格的下一个开始绕行一圈,记录最长连续可行段。
  var bestStart = -1;
  var bestLen = 0;
  var runStart = -1;
  var runLen = 0;
  for (var k = 1; k <= cells; k++) {
    final i = (anchor + k) % cells;
    if (ok[i]) {
      if (runLen == 0) runStart = i;
      runLen++;
      if (runLen > bestLen) {
        bestLen = runLen;
        bestStart = runStart;
      }
    } else {
      runLen = 0;
    }
  }
  if (bestLen == 0) return null;

  final span = bestLen * step;
  if (span < count * minItemDeg * math.pi / 180) return null;
  return (start: bestStart * step, span: span);
}

/// 半径 [radius] 的圆弧在角度区间 `[a,b]` 上的包围盒。
///
/// 极值出现在两端点,以及区间内的 0°/90°/180°/270° 轴交点。
Rect _arcBounds(double radius, double a, double b) {
  final ca = math.cos(a);
  final sa = math.sin(a);
  final cb = math.cos(b);
  final sb = math.sin(b);
  var minX = math.min(ca, cb) * radius;
  var maxX = math.max(ca, cb) * radius;
  var minY = math.min(sa, sb) * radius;
  var maxY = math.max(sa, sb) * radius;
  for (var k = 0; k < 4; k++) {
    final axis = k * math.pi / 2;
    if (axis > a && axis < b) {
      minX = math.min(minX, math.cos(axis) * radius);
      maxX = math.max(maxX, math.cos(axis) * radius);
      minY = math.min(minY, math.sin(axis) * radius);
      maxY = math.max(maxY, math.sin(axis) * radius);
    }
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// 命中断言测试: [contentPoint] 为场景坐标(与 [RingPayload.centerInWindow] 同一坐标系)。
///
/// 仅纯粉带(外接圆半径 ~ 总半径)且落在**可用弧内**才算命中;返回命中的槽位
/// `0..items.length-1`,未命中/间隔区/弧外/越界返回 null。
int? hitRingSector({
  required Offset contentPoint,
  required RingPayload payload,
}) {
  final items = payload.items;
  if (items.isEmpty) return null;

  final local = contentPoint - payload.centerInWindow;
  final distance = local.distance;
  if (distance < payload.solidRadius || distance > payload.totalRadius) {
    return null;
  }

  final count = items.length;
  final step = payload.spanAngle / count;
  final inset = _insetFor(step);
  final sweep = step - 2 * inset;

  // 相对可用弧起点的角度(0 ~ 2π);弧外不命中。
  var angle = math.atan2(local.dy, local.dx) - payload.startAngle;
  angle %= 2 * math.pi;
  if (angle > payload.spanAngle) return null;

  // 去掉起始间隔后落在第几个扇区、是否处于截断间隔内。
  final offset = angle - inset;
  if (offset < 0) return null;
  final index = (offset / step).floor();
  if (index >= count) return null;
  return offset - index * step <= sweep ? index : null;
}

/// 扇形路径: 从 [center] 沿 [startAngle] 扫过 [sweepAngle],半径 [radius]。
Path buildRingSectorPath({
  required Offset center,
  required double startAngle,
  required double sweepAngle,
  required double radius,
}) {
  final path = Path()
    ..moveTo(center.dx, center.dy)
    ..lineTo(
      center.dx + radius * math.cos(startAngle),
      center.dy + radius * math.sin(startAngle),
    )
    ..arcTo(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, false)
    ..close();
  return path;
}

/// 环形菜单绘制器。
///
/// - [radiusFactor]: 1 = 展开态;收起时逐帧减小 → 所有扇形向内收缩;
/// - [revealProgress]: 0..1 沿可用弧顺时针扫开的进度(0 = 未展开);
/// - [lineProgress]: 0..1 引导线长度系数;
/// - [lineAngle]: 引导线角度(弧度)——扫开阶段随前沿一起旋转;
/// - [lineOpacity]: 引导线透明度。
class RingMenuPainter extends CustomPainter {
  final RingPayload payload;
  final double radiusFactor;
  final double revealProgress;
  final double lineProgress;
  final double lineAngle;
  final double lineOpacity;

  /// item 可执行文件路径 → 已加载的程序图标。
  final Map<String, ui.Image> icons;

  const RingMenuPainter({
    required this.payload,
    this.radiusFactor = 1,
    this.revealProgress = 1,
    this.lineProgress = 0,
    this.lineAngle = 0,
    this.lineOpacity = 0,
    this.icons = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = payload.items.length;
    if (count == 0 || radiusFactor <= 0) return;

    final center = payload.centerInWindow;
    final total = payload.totalRadius * radiusFactor;
    final solid = payload.solidRadius * radiusFactor;
    if (total <= 0) return;

    final shader = _buildGradient(center, total, solid);
    final paint = Paint()
      ..shader = shader
      ..isAntiAlias = true;

    final start = payload.startAngle;
    final span = payload.spanAngle;
    final revealAngle = start + revealProgress * span;
    for (var i = 0; i < count; i++) {
      final angles = ringSectorAngles(
        index: i,
        count: count,
        startAngle: start,
        spanAngle: span,
      );
      final visible =
          (revealAngle - angles.start).clamp(0.0, angles.sweep).toDouble();
      if (visible <= 0) continue;
      canvas.drawPath(
        buildRingSectorPath(
          center: center,
          startAngle: angles.start,
          sweepAngle: visible,
          radius: total,
        ),
        paint,
      );
      // 该扇区完全展开后在中间渲染对应程序图标。
      if (visible >= angles.sweep - 1e-6) {
        _paintIcon(canvas, i, center, solid, total);
      }
    }

    if (lineOpacity > 0 && lineProgress > 0) {
      final direction = Offset(math.cos(lineAngle), math.sin(lineAngle));
      canvas.drawLine(
        center,
        center + direction * (total * lineProgress),
        Paint()
          ..color = _ringPink.withValues(alpha: lineOpacity.clamp(0.0, 1.0))
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }
  }

  /// 在扇区正中(纯粉带中线)绘制 item 图标;缺图标时回退为序号。
  void _paintIcon(
      Canvas canvas, int index, Offset center, double solid, double total) {
    final band = total - solid;
    if (band <= 0) return;

    final angles = ringSectorAngles(
      index: index,
      count: payload.items.length,
      startAngle: payload.startAngle,
      spanAngle: payload.spanAngle,
    );
    final midAngle = angles.start + angles.sweep / 2;
    final radius = solid + band / 2;
    final position = center +
        Offset(radius * math.cos(midAngle), radius * math.sin(midAngle));

    final size = math.min(48.0, math.max(24.0, band * 0.7));
    final image = icons[payload.items[index].executablePath];
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: position, width: size, height: size),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    _paintIndex(canvas, position, index + 1, size);
  }

  void _paintIndex(Canvas canvas, Offset center, int index, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$index',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  /// 径向渐变: 最外圆边沿为不透明硬边,向内按二次函数渐隐至透明
  /// (到达外接圆半径处完全透明)。
  ui.Shader _buildGradient(Offset center, double total, double solid) {
    const samples = 48;
    final band = total - solid;
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final radius = t * total;
      final double alpha;
      if (band <= 0) {
        alpha = 1;
      } else if (radius <= solid) {
        alpha = 0;
      } else {
        alpha = math.pow((radius - solid) / band, 2).toDouble();
      }
      colors.add(_ringPink.withValues(alpha: alpha.clamp(0.0, 1.0)));
      stops.add(t);
    }
    return ui.Gradient.radial(center, total, colors, stops);
  }

  @override
  bool shouldRepaint(RingMenuPainter old) =>
      old.payload != payload ||
      old.radiusFactor != radiusFactor ||
      old.revealProgress != revealProgress ||
      old.lineProgress != lineProgress ||
      old.lineAngle != lineAngle ||
      old.lineOpacity != lineOpacity ||
      old.icons != icons;
}

/// 环形菜单视觉组件(铺满悬浮窗,环心取 [RingPayload.centerInWindow])。
///
/// 组件不吃鼠标事件(命中由宿主按屏幕坐标自行判定)。
class RingMenu extends StatelessWidget {
  final RingPayload payload;
  final double radiusFactor;
  final double revealProgress;
  final double lineProgress;
  final double lineAngle;
  final double lineOpacity;
  final Map<String, ui.Image> icons;

  const RingMenu({
    super.key,
    required this.payload,
    this.radiusFactor = 1,
    this.revealProgress = 1,
    this.lineProgress = 0,
    this.lineAngle = 0,
    this.lineOpacity = 0,
    this.icons = const {},
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: RingMenuPainter(
          payload: payload,
          radiusFactor: radiusFactor,
          revealProgress: revealProgress,
          lineProgress: lineProgress,
          lineAngle: lineAngle,
          lineOpacity: lineOpacity,
          icons: icons,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
