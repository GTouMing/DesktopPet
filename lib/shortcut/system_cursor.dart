import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:ffi/ffi.dart';

import '../core/device.dart';

typedef _GetCursorPosNative = Int32 Function(Pointer<_Point>);

final class _Point extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

/// `user32!GetCursorPos`。
///
/// 顶层 final 是惰性求值的：非 Windows 平台永远不会碰它，因此不会去打开
/// `user32.dll`（这个文件在 Android 构建里也会被 import）。
final _getCursorPos = DynamicLibrary.open('user32.dll')
    .lookupFunction<_GetCursorPosNative, int Function(Pointer<_Point>)>(
        'GetCursorPos');

/// 光标位置（**物理屏幕像素**）；取不到返回 null。
Offset? getSystemCursorPosition() {
  final point = calloc<_Point>();
  try {
    if (_getCursorPos(point) == 0) return null;
    return Offset(point.ref.x.toDouble(), point.ref.y.toDouble());
  } finally {
    calloc.free(point);
  }
}

/// 光标在宿主悬浮窗内容坐标（**逻辑像素**）中的位置；取不到返回 null。
///
/// 宿主窗口铺满虚拟桌面，其内容原点即虚拟桌面左上角，所以物理坐标直接除以 DPR
/// 就是场景坐标，不需要任何原点偏移。
Offset? getCursorInScene() {
  final physical = getSystemCursorPosition();
  if (physical == null) return null;
  final dpr = currentDevicePixelRatio;
  return Offset(physical.dx / dpr, physical.dy / dpr);
}
