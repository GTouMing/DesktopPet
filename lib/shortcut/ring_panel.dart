import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/storage/models/app_shortcut.dart';
import 'package:flutter/material.dart';

/// 环形菜单的纯粉色主色。
const Color _ringPink = Color(0xFFFF69B4);

/// 环形菜单面板的数据与几何(单点真相,纯函数可单测)。
///
/// 几何(均以**悬浮窗内容坐标**表示):
/// - 环心 [centerInWindow] = 目标桌宠中心;
/// - [totalRadius] 总半径(粉色带外缘);
/// - [solidRadius] 外接圆半径(纯粉带内缘),再向内按二次函数渐隐至透明。
class RingPayload {
  /// 环心(窗口内容坐标)。
  final Offset centerInWindow;

  /// 总半径:粉色带外缘。
  final double totalRadius;

  /// 外接圆半径:纯粉带内缘;由此向内二次渐隐至透明。
  final double solidRadius;

  /// 展示的快捷项(最多 8 个)。
  final List<AppShortcut> items;

  const RingPayload({
    this.centerInWindow = Offset.zero,
    this.totalRadius = quickLaunchMinRadius,
    required this.solidRadius,
    required this.items,
  });

  /// 8 槽固定角布局的最大槽数。
  static const int maxSlots = 8;
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

/// 第 [index]/[count] 个扇区的角度:边界处各截断
/// [quickLaunchSectorGapDeg] / 2,合计留出 5° 间隔区分触发区。
({double start, double sweep}) ringSectorAngles({
  required int index,
  required int count,
}) {
  assert(count > 0, 'count must be positive');
  final step = 2 * math.pi / count;
  final gap = quickLaunchSectorGapDeg * math.pi / 180;
  return (start: index * step + gap / 2, sweep: step - gap);
}

/// 命中断言测试: [contentPoint] 为悬浮窗内容坐标(光标 − 悬浮窗原点)。
///
/// 仅纯粉带(外接圆半径 ~ 总半径)参与命中;返回命中的槽位 `0..items.length-1`,
/// 未命中/间隔区/越界返回 null。
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
  final step = 2 * math.pi / count;
  final gap = quickLaunchSectorGapDeg * math.pi / 180;
  final sweep = step - gap;

  var angle = math.atan2(local.dy, local.dx);
  if (angle < 0) angle += 2 * math.pi;

  // 去掉起始偏移后落在第几个扇区、是否处于截断间隔内。
  final offset = angle - gap / 2;
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
/// - [revealProgress]: 0..1 顺时针扫开的进度(0 = 未展开);
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

    final revealAngle = revealProgress * 2 * math.pi;
    for (var i = 0; i < count; i++) {
      final angles = ringSectorAngles(index: i, count: count);
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

    final angles = ringSectorAngles(index: index, count: payload.items.length);
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
