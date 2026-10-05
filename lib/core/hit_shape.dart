import 'package:flutter/foundation.dart';

/// 命中形状的种类。
///
/// [rect] = 包围矩形整块都算命中（v1 唯一产生的种类）；
/// [grid] = 包围矩形内再按 [HitShape.cols]×[HitShape.rows] 位图逐格判定。
enum HitShapeKind { rect, grid }

/// 桌宠命中形状：在 [PetHit.rect] 之内、哪一部分算"抓到"桌宠。
///
/// 这是**预留**的可扩展 payload（见 `single-engine-overlay.md` §13.2）：全局鼠标
/// 钩子的回调有超时，命中形状必须由 Dart 预计算并下发、原生**同步**判定，不能做
/// 原生→Dart→原生 往返。v1 只产生 [HitShapeKind.rect]（整矩形）；[grid] 的字段先
/// 随 payload 一起下发，原生判定留待接 Live2D 时补（当前按包围盒处理）。
///
/// 本类型刻意保持"叶子"：只依赖 `foundation`，与 `core/overlay_controller.dart` 同层。
@immutable
class HitShape {
  /// 整矩形命中（v1，沿用现状）。
  const HitShape.rect()
      : kind = HitShapeKind.rect,
        cols = 0,
        rows = 0,
        bits = const [];

  /// [cols]×[rows] 位图命中：第 `r` 行左起第 `c` 格命中，当且仅当
  /// `bits[r] & (1 << c) != 0`。格子相对 [PetHit.rect] 等分。
  const HitShape.grid({
    required this.cols,
    required this.rows,
    required this.bits,
  }) : kind = HitShapeKind.grid;

  final HitShapeKind kind;

  /// 网格列数（[HitShapeKind.rect] 时为 0）。
  final int cols;

  /// 网格行数（[HitShapeKind.rect] 时为 0）。
  final int rows;

  /// 逐行位图，长度为 [rows]；每行一个整数，最低位是第 0 列（rect 时为空）。
  final List<int> bits;

  /// 是否整矩形命中。
  bool get isRect => kind == HitShapeKind.rect;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HitShape || other.kind != kind) return false;
    if (kind == HitShapeKind.rect) return true;
    if (other.cols != cols || other.rows != rows) return false;
    if (other.bits.length != bits.length) return false;
    for (var i = 0; i < bits.length; i++) {
      if (other.bits[i] != bits[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(kind, cols, rows, Object.hashAll(bits));
}
