import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// 可执行文件图标加载器（Windows）。
///
/// 通过 `SHGetFileInfoW(SHGFI_ICON | SHGFI_LARGEICON)` 取到 HICON，
/// 再用 GDI `GetDIBits` 读出 32bpp BGRA,转换为 RGBA 后交给
/// [ui.decodeImageFromPixels]。结果按路径缓存,同一程序只解析一次。
class AppIconLoader {
  AppIconLoader._();

  static final Map<String, ui.Image> _cache = {};
  static final Map<String, Future<ui.Image?>> _pending = {};

  /// 加载并缓存 [executablePath] 的图标(失败返回 null)。
  static Future<ui.Image?> load(String executablePath) {
    final cachedImage = _cache[executablePath];
    if (cachedImage != null) return Future.value(cachedImage);

    return _pending.putIfAbsent(executablePath, () async {
      try {
        final image = await _extract(executablePath);
        if (image != null) _cache[executablePath] = image;
        return image;
      } finally {
        _pending.remove(executablePath);
      }
    });
  }

  static Future<ui.Image?> _extract(String executablePath) async {
    final pathPtr = executablePath.toNativeUtf16();
    final fileInfo = calloc<SHFILEINFO>();
    try {
      final result = SHGetFileInfo(
        pathPtr,
        0,
        fileInfo,
        sizeOf<SHFILEINFO>(),
        SHGFI_ICON | SHGFI_LARGEICON,
      );
      if (result == 0 || fileInfo.ref.hIcon == 0) return null;

      try {
        return await _iconToImage(fileInfo.ref.hIcon);
      } finally {
        DestroyIcon(fileInfo.ref.hIcon);
      }
    } finally {
      calloc.free(fileInfo);
      calloc.free(pathPtr);
    }
  }

  static Future<ui.Image?> _iconToImage(int hIcon) async {
    final iconInfo = calloc<ICONINFO>();
    if (GetIconInfo(hIcon, iconInfo) == 0) {
      calloc.free(iconInfo);
      return null;
    }

    final colorBitmap = iconInfo.ref.hbmColor;
    final maskBitmap = iconInfo.ref.hbmMask;
    try {
      final bitmap = calloc<BITMAP>();
      try {
        if (GetObject(colorBitmap, sizeOf<BITMAP>(), bitmap) == 0) return null;
        final width = bitmap.ref.bmWidth;
        final height = bitmap.ref.bmHeight;
        if (width <= 0 || height <= 0) return null;

        final rgba = _readPixels(colorBitmap, maskBitmap, width, height);
        if (rgba == null) return null;
        return _decode(rgba, width, height);
      } finally {
        calloc.free(bitmap);
      }
    } finally {
      if (colorBitmap != 0) DeleteObject(colorBitmap);
      if (maskBitmap != 0) DeleteObject(maskBitmap);
      calloc.free(iconInfo);
    }
  }

  /// 读出图标像素为自上而下的 RGBA(直通 alpha)。
  static Uint8List? _readPixels(
      int colorBitmap, int maskBitmap, int width, int height) {
    final hdc = CreateCompatibleDC(NULL);
    if (hdc == 0) return null;

    final info = calloc<BITMAPINFO>();
    final buffer = calloc<Uint8>(width * height * 4);
    try {
      info.ref.bmiHeader
        ..biSize = sizeOf<BITMAPINFOHEADER>()
        ..biWidth = width
        ..biHeight = height
        ..biPlanes = 1
        ..biBitCount = 32
        ..biCompression = BI_RGB;

      final lines = GetDIBits(hdc, colorBitmap, 0, height, buffer, info,
          DIB_RGB_COLORS);
      if (lines == 0) return null;

      final rgba = Uint8List(width * height * 4);
      var hasAlpha = false;
      for (var y = 0; y < height; y++) {
        // DIB 为自下而上,翻转成自上而下。
        final sourceRow = (height - 1 - y) * width * 4;
        final targetRow = y * width * 4;
        for (var x = 0; x < width; x++) {
          final s = sourceRow + x * 4;
          final d = targetRow + x * 4;
          final b = buffer[s];
          final g = buffer[s + 1];
          final r = buffer[s + 2];
          final a = buffer[s + 3];
          rgba[d] = r;
          rgba[d + 1] = g;
          rgba[d + 2] = b;
          rgba[d + 3] = a;
          if (a != 0) hasAlpha = true;
        }
      }

      // 无 alpha 通道的老式图标:用 AND mask 生成透明度。
      if (!hasAlpha && maskBitmap != 0) {
        _applyMask(hdc, maskBitmap, width, height, rgba);
      }
      _premultiplyIfStraight(rgba, width, height);
      return rgba;
    } finally {
      calloc.free(buffer);
      calloc.free(info);
      DeleteDC(hdc);
    }
  }

  /// mask 位为 1 表示透明。
  static void _applyMask(
      int hdc, int maskBitmap, int width, int height, Uint8List rgba) {
    final info = calloc<BITMAPINFO>();
    final rowBytes = ((width + 31) ~/ 32) * 4;
    final buffer = calloc<Uint8>(rowBytes * height);
    try {
      info.ref.bmiHeader
        ..biSize = sizeOf<BITMAPINFOHEADER>()
        ..biWidth = width
        ..biHeight = height
        ..biPlanes = 1
        ..biBitCount = 1
        ..biCompression = BI_RGB;

      final lines = GetDIBits(hdc, maskBitmap, 0, height, buffer, info,
          DIB_RGB_COLORS);
      if (lines == 0) return;

      for (var y = 0; y < height; y++) {
        final sourceRow = (height - 1 - y) * rowBytes;
        for (var x = 0; x < width; x++) {
          final bit = (buffer[sourceRow + x ~/ 8] >> (7 - (x % 8))) & 1;
          rgba[(y * width + x) * 4 + 3] = bit == 1 ? 0 : 255;
        }
      }
    } finally {
      calloc.free(buffer);
      calloc.free(info);
    }
  }

  /// [ui.PixelFormat.rgba8888] 需要预乘 alpha;若像素为直通则就地预乘。
  static void _premultiplyIfStraight(Uint8List rgba, int width, int height) {
    var straight = false;
    for (var i = 0; i < width * height; i++) {
      final a = rgba[i * 4 + 3];
      if (a == 0 || a == 255) continue;
      if (rgba[i * 4] > a || rgba[i * 4 + 1] > a || rgba[i * 4 + 2] > a) {
        straight = true;
        break;
      }
    }
    if (!straight) return;

    for (var i = 0; i < width * height; i++) {
      final a = rgba[i * 4 + 3];
      rgba[i * 4] = rgba[i * 4] * a ~/ 255;
      rgba[i * 4 + 1] = rgba[i * 4 + 1] * a ~/ 255;
      rgba[i * 4 + 2] = rgba[i * 4 + 2] * a ~/ 255;
    }
  }

  static Future<ui.Image> _decode(Uint8List rgba, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
