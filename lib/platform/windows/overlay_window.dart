import 'package:flutter/services.dart';

import 'windows_channels.dart';

/// 单窗口 overlay 的原生控制(见 windows/runner/overlay_window.cpp)。
///
/// 宿主窗口**常驻** `WS_EX_LAYERED | WS_EX_TRANSPARENT`：系统在命中测试阶段直接
/// 跳过它，所以这个铺满桌面的窗口**结构上不可能拦住点击**，Dart 卡死也不会。
///
/// 代价是它收不到鼠标消息——桌宠的点击/拖拽因此走进程级全局钩子
/// (见 `lib/input/platform/windows_input_source.dart` 与
/// `lib/pet/pet_pointer_router.dart`)，窗口本身不需要任何"可交互区域"。
///
/// 窗口客户区是**正方形**（边长 = 桌面宽，底部一条对齐屏幕），原因见
/// `overlay_window.h`：引擎的渲染表面边长取的是窗口宽度，非正方形客户区会被纵向
/// 压成"高/宽"。场景内容由 [OverlayScene] 放进客户区底部那一条，因此场景坐标空间
/// 仍然等于桌面空间。
class OverlayWindow {
  OverlayWindow._();

  static const MethodChannel _channel =
      MethodChannel(OverlayWindowChannel.name);

  /// 原生重铺窗口几何(如 DPI 变化)后的回调：Dart 需要重新推导场景矩形。
  static void Function()? onGeometryChanged;

  /// 注册原生→Dart 的消息处理器(幂等，在场景挂载时调用一次)。
  static void registerHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == OverlayWindowChannel.onGeometryChanged) {
        onGeometryChanged?.call();
      }
      return null;
    });
  }

  /// 虚拟桌面矩形(**物理像素**)，即桌宠可活动范围对应的屏幕区域。
  static Future<Rect?> getVirtualScreenRect() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        OverlayWindowChannel.getVirtualScreenRect,
      );
      if (result == null) return null;
      return Rect.fromLTWH(
        (result[OverlayWindowChannel.left] as num).toDouble(),
        (result[OverlayWindowChannel.top] as num).toDouble(),
        (result[OverlayWindowChannel.width] as num).toDouble(),
        (result[OverlayWindowChannel.height] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
