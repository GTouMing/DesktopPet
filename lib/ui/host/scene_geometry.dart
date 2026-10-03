import 'dart:ui';

import '../../core/device.dart';
import '../../core/overlay_controller.dart';
import '../../platform/windows/overlay_window.dart';

/// 悬浮窗场景的几何：**场景空间 = 桌面空间**。
///
/// 场景原点在屏幕上的位置（物理像素）就是虚拟桌面左上角（多显示器下它常在主屏
/// 左/上方，即负数）。之所以能这样简单对应，是因为窗口客户区被做成正方形、场景
/// 内容只画在底部那一条——见 `overlay_scene.dart` 的说明。
class SceneGeometry {
  /// 场景原点（**物理像素**）。
  ///
  /// 未取到之前是 (0,0)：那时还没有任何抓取矩形，不会有指针事件换算。
  Offset origin = Offset.zero;

  /// 重新向原生取虚拟桌面矩形并刷新 [OverlayController.sceneBounds]。
  ///
  /// 原生不可用时返回 false（保持上一次的值），调用方据此决定要不要重推抓取矩形。
  Future<bool> refresh() async {
    final physical = await OverlayWindow.getVirtualScreenRect();
    if (physical == null) return false;

    final dpr = currentDevicePixelRatio;
    origin = physical.topLeft;
    OverlayController.sceneBounds.value =
        Rect.fromLTWH(0, 0, physical.width / dpr, physical.height / dpr);
    return true;
  }

  /// 场景矩形 → 物理屏幕矩形（声明给全局钩子用）。
  Rect toPhysical(Rect sceneRect) =>
      toPhysicalRect(sceneRect, origin, currentDevicePixelRatio);

  /// 纯换算，便于单测。
  static Rect toPhysicalRect(Rect sceneRect, Offset origin, double dpr) =>
      Rect.fromLTRB(
        sceneRect.left * dpr + origin.dx,
        sceneRect.top * dpr + origin.dy,
        sceneRect.right * dpr + origin.dx,
        sceneRect.bottom * dpr + origin.dy,
      );
}
