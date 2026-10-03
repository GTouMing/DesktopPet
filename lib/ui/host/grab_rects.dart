import 'dart:ui';

import '../../core/overlay_controller.dart';
import '../../input/input.dart';
import 'scene_geometry.dart';

/// 把桌宠矩形声明给全局输入钩子。
///
/// 窗口本身**不需要任何可交互区域**——它常驻 `WS_EX_TRANSPARENT`，系统在命中测试
/// 阶段就跳过它。桌宠的点击/拖拽由进程级钩子驱动，这份矩形只用来告诉钩子
/// "光标在哪里按下才算抓到桌宠"，免得把桌面上的每次移动都转发过来（也就不产生
/// 任何通道流量）。
///
/// 锁定中的桌宠**不声明**——这正是"锁定"的语义：点它等于点桌面。
///
/// 与上一次相同时不重复下发：拖拽时桌宠矩形每帧都变，但几何没变的重推没有意义。
class GrabRectPublisher {
  GrabRectPublisher(this._geometry);

  final SceneGeometry _geometry;

  List<Rect> _published = const [];

  /// 用 [pets] 的矩形刷新声明（物理屏幕像素）。
  Future<void> publish(List<PetHit> pets) async {
    final rects = <Rect>[
      for (final pet in pets)
        if (!pet.locked) _geometry.toPhysical(pet.rect),
    ];
    if (sameRects(rects, _published)) return;
    _published = rects;
    await InputService.instance.setWatchRects(rects);
  }

  /// 两个矩形列表是否等价（顺序敏感：钩子按声明顺序逐个判断）。
  static bool sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
