import 'dart:ui';

import 'constants.dart';
import 'pet_floating_window_platform_interface.dart';

/// 悬浮窗触摸标志(与原生 `Constants.kt` 的字符串值一致)。
enum OverlayFlag {
  /// 完全穿透:不接收任何触摸/焦点事件(对应"锁定")。
  clickThrough,

  /// 默认:接收触摸但不抢焦点,且不阻塞系统手势。
  defaultFlag,
}

/// 窗口尺寸哨兵值,与原生 `Constants.MATCH_PARENT/WRAP_CONTENT` 一致。
class WindowSize {
  /// 撑满父窗口。
  static const int matchParent = -1;

  /// 包裹内容。
  static const int wrapContent = -2;
}

/// 悬浮窗位置(物理像素)。
class OverlayPosition {
  final int x;
  final int y;

  OverlayPosition(this.x, this.y);

  Map<String, dynamic> toJson() => {Constants.x: x, Constants.y: y};
}

/// 多悬浮窗(Android):每只桌宠一个系统悬浮窗。
class PetFloatingWindow {
  /// 主通道名。悬浮窗引擎侧注册 MethodChannel 处理器时使用。
  static const String channelName = Constants.channelName;

  /// 原生 → 悬浮窗:设置已更新的方法名。
  static const String settingsUpdatedEvent = Constants.settingsUpdatedEvent;

  /// 原生取屏幕尺寸失败时的兜底值(物理像素)。
  static const int fallbackScreenWidth = Constants.fallbackScreenWidth;
  static const int fallbackScreenHeight = Constants.fallbackScreenHeight;

  /// 是否已授予悬浮窗权限（"显示在其他应用上层"）。
  static Future<bool> hasPermission() {
    return PetFloatingWindowPlatform.instance.hasPermission();
  }

  /// 请求悬浮窗权限：拉起系统设置页并**立刻返回**（用户是否授予无从得知，
  /// 回到前台后由调用方重新检查）。
  static Future<bool> requestPermission() {
    return PetFloatingWindowPlatform.instance.requestPermission();
  }

  /// 创建/显示指定 id 的悬浮窗。
  ///
  /// [width]/[height] 与 [startPosition] 均为**物理像素**。
  static Future<bool> showOverlay({
    required String overlayId,
    int height = WindowSize.matchParent,
    int width = WindowSize.matchParent,
    OverlayFlag flag = OverlayFlag.defaultFlag,
    OverlayPosition? startPosition,
  }) {
    return PetFloatingWindowPlatform.instance.showOverlay(
      overlayId: overlayId,
      height: height,
      width: width,
      flag: flag.name,
      startPosition: startPosition?.toJson(),
    );
  }

  /// 关闭指定悬浮窗。
  static Future<bool> closeOverlay(String overlayId) {
    return PetFloatingWindowPlatform.instance.closeOverlay(overlayId);
  }

  /// 指定悬浮窗是否已显示。
  static Future<bool> isOverlayShowing(String overlayId) {
    return PetFloatingWindowPlatform.instance.isOverlayShowing(overlayId);
  }

  /// 更新触摸标志。
  static Future<bool> updateFlag(String overlayId, OverlayFlag flag) {
    return PetFloatingWindowPlatform.instance.updateFlag(overlayId, flag.name);
  }

  /// 调整悬浮窗尺寸(物理像素)。
  static Future<bool> resizeOverlay(String overlayId, int width, int height) {
    return PetFloatingWindowPlatform.instance
        .resizeOverlay(overlayId, width, height);
  }

  /// 移动悬浮窗(物理像素)。
  static Future<bool> moveOverlay(String overlayId, OverlayPosition position) {
    return PetFloatingWindowPlatform.instance
        .moveOverlay(overlayId, position.toJson());
  }

  /// 交给系统拖拽整个悬浮窗,返回的 Future 完成时表示拖拽结束。
  static Future<void> startDragging(String overlayId) async {
    await PetFloatingWindowPlatform.instance.startDragging(overlayId);
  }

  /// 当前悬浮窗位置(物理像素)。
  static Future<OverlayPosition> getOverlayPosition(String overlayId) async {
    final Map<String, dynamic> position =
        await PetFloatingWindowPlatform.instance.getOverlayPosition(overlayId);
    return OverlayPosition(
      position[Constants.x] as int? ?? 0,
      position[Constants.y] as int? ?? 0,
    );
  }

  /// 真实屏幕尺寸(物理像素;逻辑换算由 WindowControllerAndroid 处理)。
  static Future<Size> getScreenSize() async {
    final Map<String, dynamic> size =
        await PetFloatingWindowPlatform.instance.getScreenSize();
    return Size(
      (size['width'] as int? ?? Constants.fallbackScreenWidth).toDouble(),
      (size['height'] as int? ?? Constants.fallbackScreenHeight).toDouble(),
    );
  }

  /// 通知所有悬浮窗刷新设置(主窗口写入 MMKV 后调用)。
  static Future<void> notifySettingsUpdated() async {
    try {
      await PetFloatingWindowPlatform.instance.sendSettingsUpdated();
    } catch (_) {}
  }
}
