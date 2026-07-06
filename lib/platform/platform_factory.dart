import 'dart:io';

import 'window_interface.dart';
import 'android/window_android.dart';
import 'windows/window_windows.dart';

/// Creates the appropriate [WindowController] for the current platform.
WindowController createWindowController({String? windowId}) {
  if (Platform.isAndroid) {
    return WindowControllerAndroid(overlayId: windowId ?? 'default');
  } else if (Platform.isWindows) {
    return WindowControllerWindows(windowId: windowId ?? 'default');
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}