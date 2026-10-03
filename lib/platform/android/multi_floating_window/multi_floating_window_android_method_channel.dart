import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'constants.dart';
import 'multi_floating_window_android_platform_interface.dart';

/// An implementation of [MultiFloatingWindowAndroidPlatform] that uses method channels.
class MethodChannelMultiFloatingWindowAndroid
    extends MultiFloatingWindowAndroidPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(Constants.channelName);

  /// 是否已授予悬浮窗权限
  @override
  Future<bool> hasPermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      Constants.hasPermission,
    );
    return result ?? false;
  }

  /// Request floating window permission
  @override
  Future<bool> requestPermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      Constants.requestPermission,
    );
    return result ?? false;
  }

  /// Show floating window
  @override
  Future<bool> showOverlay({
    required String overlayId,
    int? height,
    int? width,
    String? flag,
    Map<String, dynamic>? startPosition,
  }) async {
    final Map<String, dynamic> arguments = {
      Constants.overlayId: overlayId,
      Constants.height: height,
      Constants.width: width,
      Constants.flag: flag,
      Constants.startPosition: startPosition,
    };
    final result = await methodChannel.invokeMethod<bool>(
      Constants.showOverlay,
      arguments,
    );
    return result ?? false;
  }

  /// Close floating window
  @override
  Future<bool> closeOverlay(String overlayId) async {
    final Map<String, dynamic> arguments = {
      Constants.overlayId: overlayId,
    };
    final result = await methodChannel.invokeMethod<bool>(
      Constants.closeOverlay,
      arguments,
    );
    return result ?? false;
  }

  /// Check if specific overlay is showing
  @override
  Future<bool> isOverlayShowing(String overlayId) async {
    final Map<String, dynamic> arguments = {
      Constants.overlayId: overlayId,
    };
    final result = await methodChannel.invokeMethod<bool>(
      Constants.isOverlayShowing,
      arguments,
    );
    return result ?? false;
  }

  /// Get real screen size (物理像素)
  @override
  Future<Map<String, dynamic>> getScreenSize() async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      Constants.getScreenSize,
    );
    return result ??
        {
          'width': Constants.fallbackScreenWidth,
          'height': Constants.fallbackScreenHeight,
        };
  }

  /// Update floating window flag
  @override
  Future<bool> updateFlag(String overlayId, String flag) async {
    final Map<String, dynamic> arguments = {
      Constants.overlayId: overlayId,
      Constants.flag: flag,
    };
    final result = await methodChannel.invokeMethod<bool>(
      Constants.updateFlag,
      arguments,
    );
    return result ?? false;
  }

  /// Resize floating window
  @override
  Future<bool> resizeOverlay(String overlayId, int width, int height) async {
    final Map<String, dynamic> arguments = {
      Constants.overlayId: overlayId,
      Constants.width: width,
      Constants.height: height,
    };
    final result = await methodChannel.invokeMethod<bool>(
      Constants.resizeOverlay,
      arguments,
    );
    return result ?? false;
  }

  /// Move floating window position
  @override
  Future<bool> moveOverlay(
      String overlayId, Map<String, dynamic> position) async {
    final Map<String, dynamic> arguments = {
      Constants.overlayId: overlayId,
      ...position,
    };
    final result = await methodChannel.invokeMethod<bool>(
      Constants.moveOverlay,
      arguments,
    );
    return result ?? false;
  }

  @override
  Future<void> startDragging(String overlayId) async {
    final Map<String, dynamic> arguments = {
      Constants.overlayId: overlayId,
    };
    await methodChannel.invokeMethod<void>(
      Constants.startDragging,
      arguments,
    );
  }

  /// Get current floating window position
  @override
  Future<Map<String, dynamic>> getOverlayPosition(String overlayId) async {
    final Map<String, dynamic> arguments = {
      Constants.overlayId: overlayId,
    };
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      Constants.getOverlayPosition,
      arguments,
    );
    return result ?? {Constants.x: 0, Constants.y: 0};
  }

  /// 通知所有悬浮窗刷新设置
  @override
  Future<void> sendSettingsUpdated() async {
    await methodChannel.invokeMethod<void>(
      Constants.sendSettingsUpdated,
    );
  }
}
