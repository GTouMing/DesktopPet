import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class NotificationPermissionService {
  static const MethodChannel _channel = MethodChannel('github.gtouming.desktop_pet/permissions');
  static final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  /// 检查通知权限
  static Future<bool> checkNotificationPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final bool result = await _channel.invokeMethod('checkNotificationPermission');
      return result;
    } catch (e) {
      _logger.e('[NotificationPermissionService] 检查权限失败: $e');
      return false;
    }
  }

  /// 请求通知权限
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final bool result = await _channel.invokeMethod('requestNotificationPermission');
      return result;
    } catch (e) {
      _logger.e('[NotificationPermissionService] 请求权限失败: $e');
      return false;
    }
  }
}
