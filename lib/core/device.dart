import 'dart:ui';

/// 当前引擎所在视图的设备像素比。
///
/// 多引擎下（Windows 的设置子窗口、Android 每只桌宠一个悬浮窗）每个引擎有独立的
/// `PlatformDispatcher`，视图 DPR 也可能不同，所以只能从当前视图现取，不能缓存成
/// 全局常量。取不到时退化为 1.0（视图像素即逻辑像素）。
double get currentDevicePixelRatio {
  try {
    return PlatformDispatcher.instance.views.first.devicePixelRatio;
  } catch (_) {
    return 1.0;
  }
}
