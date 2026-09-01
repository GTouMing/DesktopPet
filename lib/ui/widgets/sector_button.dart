import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. 自定义 Clipper
class SectorClipper extends CustomClipper<Path> {
  final double startAngle;   // 起始角度 (弧度)
  final double sweepAngle;   // 扫过角度 (弧度)
  final double innerRadius;  // 内半径
  final double outerRadius;  // 外半径

  SectorClipper({
    required this.startAngle,
    required this.sweepAngle,
    required this.innerRadius,
    required this.outerRadius,
  });

  static Path buildSectorPath({
    required Size size,
    required double startAngle,
    required double sweepAngle,
    required double innerRadius,
    required double outerRadius,
  })
  {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    path.moveTo(
      center.dx + outerRadius * math.cos(startAngle),
      center.dy + outerRadius * math.sin(startAngle),
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      sweepAngle,
      false,
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle + sweepAngle,
      -sweepAngle,
      false,
    );
    path.close();
    return path;
  }

  @override
  Path getClip(Size size) {
    return buildSectorPath(
        size: size,
        startAngle: startAngle,
        sweepAngle: sweepAngle,
        innerRadius: innerRadius,
        outerRadius: outerRadius
    );
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}

// 2. 异形按钮 Widget
class SectorButton extends ConsumerStatefulWidget {
  final Widget child;
  final double startAngle;
  final double sweepAngle;
  final double innerRadius;
  final double outerRadius;
  final int index;
  final void Function(int)? indexSetter;

  const SectorButton({
    super.key,
    required this.child,
    required this.index,
    required this.startAngle,
    required this.sweepAngle,
    required this.innerRadius,
    required this.outerRadius,
    required this.indexSetter
  });

  @override
  ConsumerState<SectorButton> createState() => _SectorButtonState();
}

class _SectorButtonState extends ConsumerState<SectorButton> {

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.outerRadius * 2,
      height: widget.outerRadius * 2,
      child: ClipPath(
        clipper: SectorClipper(
          startAngle: widget.startAngle,
          sweepAngle: widget.sweepAngle,
          innerRadius: widget.innerRadius,
          outerRadius: widget.outerRadius,
        ),
        child: Container(
          color: Colors.blue,
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}