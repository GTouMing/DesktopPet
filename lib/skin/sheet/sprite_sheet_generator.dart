import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../skin_package.dart';

/// 描述精灵图集的网格布局（列数 × 行数）。
class GridCoordinate {
  final int c;
  final int r;
  const GridCoordinate({required this.c, required this.r});
}

/// 描述生成的精灵图集及其帧布局元数据。
class SpriteSheetData {
  final ui.Image image;
  final int frameCount;
  final GridCoordinate grid;
  final ui.Size frameSize;

  const SpriteSheetData({
    required this.image,
    required this.frameCount,
    required this.grid,
    required this.frameSize,
  });

  /// 返回第 [index] 帧的源矩形。
  ui.Rect getFrameRect(int index) {
    final col = index % grid.c;
    final row = index ~/ grid.c;
    return ui.Rect.fromLTWH(
      col * frameSize.width,
      row * frameSize.height,
      frameSize.width,
      frameSize.height,
    );
  }

  void dispose() {
    image.dispose();
  }
}

/// 将单帧 PNG 图片拼接为 GPU 友好的精灵图集。
class SpriteSheetGenerator {

  /// 从 asset bundle 键（以 "assets/" 开头的路径）加载帧。
  static Future<SpriteSheetData> generateFromAssets({
    required List<String> assetPaths,
    required ui.Size frameSize,
  }) async {
    final frames = <ui.Image>[];
    for (final path in assetPaths) {
      try {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        frames.add(frame.image);
      } catch (_) {
        for (var a in frames) {
          a.dispose();
        }
      }
    }
    return _stitch(frames, frameSize);
  }


  /// 从文件系统路径加载帧。
  static Future<SpriteSheetData> generateFromFiles({
    required List<String> framePaths,
    required ui.Size frameSize,
  }) async {
    final frames = <ui.Image>[];
    for (final path in framePaths) {
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frames.add(frame.image);
    }
    return _stitch(frames, frameSize);
  }

  /// 从 [SkinPackage] 生成指定动画的精灵图集。
  static Future<SpriteSheetData> generateFromSkin(
    SkinPackage skin,
    String animName,
  ) async {
    final animDef = skin.anims[animName]!;
    if (skin.source == SkinSource.asset) {
      final assetPaths = List.generate(
        animDef.frameCount,
        (i) => '${skin.basePath}/${animDef.folder}/$i.png',
      );
      return generateFromAssets(
        assetPaths: assetPaths,
        frameSize: skin.frameSize,
      );
    } else {
      return generateFromFiles(
        framePaths: skin.getFramePaths(animName),
        frameSize: skin.frameSize,
      );
    }
  }

  static Future<SpriteSheetData> _stitch(List<ui.Image> frames, ui.Size frameSize) async {
    final n = frames.length;
    final cellW = frameSize.width.toInt();
    final cellH = frameSize.height.toInt();

    if (n == 0) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, frameSize.width, frameSize.height),
        ui.Paint()..color = const ui.Color(0x22CCCCCC),
      );
      final picture = recorder.endRecording();
      final img = await picture.toImage(cellW, cellH);
      picture.dispose();
      return SpriteSheetData(
        image: img,
        frameCount: 1,
        grid: const GridCoordinate(c: 1, r: 1),
        frameSize: frameSize,
      );
    }

    final grid = _calculateGrid(n, cellW, cellH);
    final sheetW = grid.c * cellW;
    final sheetH = grid.r * cellH;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    for (int i = 0; i < n; i++) {
      final col = i % grid.c;
      final row = i ~/ grid.c;
      final dst = ui.Rect.fromLTWH(
        col * cellW.toDouble(), row * cellH.toDouble(),
        cellW.toDouble(), cellH.toDouble(),
      );
      canvas.drawImageRect(
        frames[i],
        ui.Rect.fromLTWH(0, 0, frames[i].width.toDouble(), frames[i].height.toDouble()),
        dst,
        ui.Paint(),
      );
    }

    final picture = recorder.endRecording();
    final sheetImage = await picture.toImage(sheetW, sheetH);
    picture.dispose();

    for (final frame in frames) {
      frame.dispose();
    }

    return SpriteSheetData(
      image: sheetImage,
      frameCount: n,
      grid: grid,
      frameSize: frameSize,
    );
  }

  static GridCoordinate _calculateGrid(int frameCount, int cellW, int cellH) {
    int bestCols = frameCount;
    int bestRows = 1;
    int minWaste = (frameCount * cellW) % maxSpriteSheetDimension;

    for (int rows = 1; rows <= frameCount; rows++) {
      final cols = (frameCount + rows - 1) ~/ rows;
      final totalW = cols * cellW;
      final totalH = rows * cellH;
      
      if (totalW <= maxSpriteSheetDimension && totalH <= maxSpriteSheetDimension) {
        final waste = (cols * rows) - frameCount;
        if (waste < minWaste || (waste == minWaste && cols > bestCols)) {
          minWaste = waste;
          bestCols = cols;
          bestRows = rows;
        }
      }
    }
    
    return GridCoordinate(c: bestCols, r: bestRows);
  }
}