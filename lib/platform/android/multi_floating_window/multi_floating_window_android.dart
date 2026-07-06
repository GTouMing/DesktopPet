import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'multi_floating_window_android_platform_interface.dart';

import 'constants.dart';

/// Overlay flag types
enum OverlayFlag {
  /// Click through - The floating window never receives touch events, suitable for creating click-through floating windows
  clickThrough,

  /// Default flag - The floating window doesn't get keyboard input focus, user can't send key events or other button events
  defaultFlag,

  /// Focus pointer - Allows pointer events outside the floating window to be sent to the windows behind, suitable for input boxes that need to display a keyboard
  focusPointer,
}

/// Window size constants
class WindowSize {
  /// Full cover
  static const int fullCover = -1;

  /// Match parent
  static const int matchParent = -1;

  /// Wrap content
  static const int wrapContent = -2;
}

/// Overlay position
class OverlayPosition {
  final int x;
  final int y;

  OverlayPosition(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

/// Multi Floating Window Android - Supports multiple floating windows using Map to store views
class MultiFloatingWindowAndroid {
  /// Get platform version
  Future<String?> getPlatformVersion() {
    return MultiFloatingWindowAndroidPlatform.instance.getPlatformVersion();
  }

  /// Check if floating window permission is granted
  static Future<bool> isPermissionGranted() {
    return MultiFloatingWindowAndroidPlatform.instance.isPermissionGranted();
  }

  /// Request floating window permission
  static Future<bool> requestPermission() {
    return MultiFloatingWindowAndroidPlatform.instance.requestPermission();
  }

  /// Show floating window with specific overlayId
  static Future<bool> showOverlay({
    required String overlayId,
    int height = WindowSize.fullCover,
    int width = WindowSize.matchParent,
    OverlayFlag flag = OverlayFlag.defaultFlag,
    OverlayPosition? startPosition,
  }) {
    return MultiFloatingWindowAndroidPlatform.instance.showOverlay(
      overlayId: overlayId,
      height: height,
      width: width,
      flag: flag.toString().split('.').last,
      startPosition: startPosition?.toJson(),
    );
  }

  /// Close specific floating window by overlayId
  static Future<bool> closeOverlay(String overlayId) {
    return MultiFloatingWindowAndroidPlatform.instance.closeOverlay(overlayId);
  }

  /// Close all floating windows
  static Future<bool> closeAllOverlays() {
    return MultiFloatingWindowAndroidPlatform.instance.closeAllOverlays();
  }

  /// Check if any floating window is showing
  static Future<bool> isShowing() {
    return MultiFloatingWindowAndroidPlatform.instance.isShowing();
  }

  /// Check if specific overlay is showing
  static Future<bool> isOverlayShowing(String overlayId) {
    return MultiFloatingWindowAndroidPlatform.instance.isOverlayShowing(overlayId);
  }

  /// Get all active overlay ids
  static Future<List<String>> getOverlayIds() {
    return MultiFloatingWindowAndroidPlatform.instance.getOverlayIds();
  }

  /// Update floating window flag for specific overlay
  static Future<bool> updateFlag(String overlayId, OverlayFlag flag) {
    return MultiFloatingWindowAndroidPlatform.instance.updateFlag(
      overlayId,
      flag.toString().split('.').last,
    );
  }

  /// Resize specific floating window
  static Future<bool> resizeOverlay(String overlayId, int width, int height) {
    return MultiFloatingWindowAndroidPlatform.instance.resizeOverlay(
      overlayId,
      width,
      height,
    );
  }

  /// Move specific floating window position
  static Future<bool> moveOverlay(String overlayId, OverlayPosition position) {
    return MultiFloatingWindowAndroidPlatform.instance.moveOverlay(
      overlayId,
      position.toJson(),
    );
  }

  static Future<void> startDragging(String overlayId) async {
    await MultiFloatingWindowAndroidPlatform.instance.startDragging(overlayId);
  }

  /// Get current specific floating window position
  static Future<OverlayPosition> getOverlayPosition(String overlayId) async {
    final Map<String, dynamic> position =
        await MultiFloatingWindowAndroidPlatform.instance.getOverlayPosition(overlayId);
    return OverlayPosition(
      position['x'] as int? ?? 0,
      position['y'] as int? ?? 0,
    );
  }

  /// Get real screen size (returns logical pixels)
  static Future<Size> getScreenSize() async {
    final Map<String, dynamic> size =
        await MultiFloatingWindowAndroidPlatform.instance.getScreenSize();
    final physicalWidth = (size['width'] as int? ?? 1080).toDouble();
    final physicalHeight = (size['height'] as int? ?? 1920).toDouble();
    
    double pixelRatio = 1.0;
    try {
      //pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    } catch (e) {
      // Fallback to 1.0 if unable to get pixel ratio
    }
    
    return Size(physicalWidth / pixelRatio, physicalHeight / pixelRatio);
  }

  /// Share data between floating window and main app
  static Future<bool> shareData(dynamic data) {
    return MultiFloatingWindowAndroidPlatform.instance.shareData(data);
  }

  /// Open main app from floating window
  static Future<bool> openMainApp([Map<String, dynamic>? params]) {
    return MultiFloatingWindowAndroidPlatform.instance.openMainApp(params);
  }

  /// Close floating window from within the floating window
  static Future<void> closeOverlayFromOverlay(String overlayId) async {
    // Use specific channel to communicate with native service
    const MethodChannel channel = MethodChannel(
      Constants.overlayControlChannel,
    );
    try {
      await channel.invokeMethod(Constants.closeOverlayFromOverlay, {
        Constants.overlayId: overlayId,
      });
    } on PlatformException catch (e) {
      throw PlatformException(
        code: 'UNAVAILABLE',
        message: 'Failed to close from floating window: ${e.message}',
      );
    }
  }

  /// Check if main app is running in foreground
  static Future<bool> isMainAppRunning() {
    return MultiFloatingWindowAndroidPlatform.instance.isMainAppRunning();
  }

  /// 通知所有悬浮窗刷新设置（主窗口写入 MMKV 后调用）。
  static Future<void> notifySettingsUpdated() async {
    try {
      await MultiFloatingWindowAndroidPlatform.instance
          .sendSettingsUpdated();
    } catch (_) {}
  }
}
