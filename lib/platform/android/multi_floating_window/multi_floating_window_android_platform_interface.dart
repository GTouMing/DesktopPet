import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'multi_floating_window_android_method_channel.dart';

abstract class MultiFloatingWindowAndroidPlatform extends PlatformInterface {
  /// Constructs a MultiFloatingWindowAndroidPlatform.
  MultiFloatingWindowAndroidPlatform() : super(token: _token);

  static final Object _token = Object();

  static MultiFloatingWindowAndroidPlatform _instance =
      MethodChannelMultiFloatingWindowAndroid();

  /// The default instance of [MultiFloatingWindowAndroidPlatform] to use.
  ///
  /// Defaults to [MethodChannelMultiFloatingWindowAndroid].
  static MultiFloatingWindowAndroidPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MultiFloatingWindowAndroidPlatform] when
  /// they register themselves.
  static set instance(MultiFloatingWindowAndroidPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 是否已授予悬浮窗权限
  Future<bool> hasPermission() {
    throw UnimplementedError('hasPermission() has not been implemented.');
  }

  /// Request floating window permission
  Future<bool> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  /// Show floating window with overlayId
  Future<bool> showOverlay({
    required String overlayId,
    int? height,
    int? width,
    String? flag,
    Map<String, dynamic>? startPosition,
  }) {
    throw UnimplementedError('showOverlay() has not been implemented.');
  }

  /// Close specific floating window
  Future<bool> closeOverlay(String overlayId) {
    throw UnimplementedError('closeOverlay() has not been implemented.');
  }

  /// Check if specific overlay is showing
  Future<bool> isOverlayShowing(String overlayId) {
    throw UnimplementedError('isOverlayShowing() has not been implemented.');
  }

  /// Update floating window flag
  Future<bool> updateFlag(String overlayId, String flag) {
    throw UnimplementedError('updateFlag() has not been implemented.');
  }

  /// Resize floating window
  Future<bool> resizeOverlay(String overlayId, int width, int height) {
    throw UnimplementedError('resizeOverlay() has not been implemented.');
  }

  Future<void> startDragging(String overlayId) {
    throw UnimplementedError('startDragging() has not been implemented.');
  }

  /// Move floating window position
  Future<bool> moveOverlay(String overlayId, Map<String, dynamic> position) {
    throw UnimplementedError('moveOverlay() has not been implemented.');
  }

  /// Get current floating window position
  Future<Map<String, dynamic>> getOverlayPosition(String overlayId) {
    throw UnimplementedError('getOverlayPosition() has not been implemented.');
  }

  /// Get real screen size
  Future<Map<String, dynamic>> getScreenSize() {
    throw UnimplementedError('getScreenSize() has not been implemented.');
  }

  /// 通知所有悬浮窗刷新设置
  Future<void> sendSettingsUpdated() {
    throw UnimplementedError('sendSettingsUpdated() has not been implemented.');
  }
}
