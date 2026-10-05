import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../sprite_pet_pack.dart';

/// 图集磁盘缓存的格式版本。
///
/// 内置宠物包(asset 源)的字节随构建固定,只能靠改这个常量手动失效:
/// **修改 `assets/` 下的宠物包资源后必须 +1**,否则旧缓存会被继续命中。
const int _sheetCacheVersion = 1;

/// 诊断日志(Debug 构建可见)。
void _log(String message) {
  if (kDebugMode) debugPrint('[sheet] $message');
}

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
///
/// 生成的图集按 (宠物包, 动画) 缓存到磁盘(见 [generateFromPack]):同一个宠物包
/// 在多个引擎里各加载一遍时,只有第一次需要逐帧解码 + 拼接。
class SpriteSheetGenerator {

  /// 从 asset bundle 键（以 "assets/" 开头的路径）加载帧。
  static Future<SpriteSheetData> generateFromAssets({
    required List<String> assetPaths,
    required ui.Size frameSize,
  }) async {
    final frames = <ui.Image>[];
    for (final path in assetPaths) {
      ui.Codec? codec;
      try {
        final data = await rootBundle.load(path);
        codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        frames.add(frame.image);
      } catch (_) {
        // 跳过缺失/损坏的帧。旧实现在此 dispose 已加载的帧却继续拼接,
        // 使 _stitch 使用已释放的图片(debug 断言 / release 原生崩溃)。
        continue;
      } finally {
        codec?.dispose();
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
      try {
        final frame = await codec.getNextFrame();
        frames.add(frame.image);
      } finally {
        codec.dispose();
      }
    }
    return _stitch(frames, frameSize);
  }

  /// 从 [PetPack] 取得指定动画的精灵图集。
  ///
  /// 优先命中磁盘缓存:命中时只解一张图集 PNG,不再逐帧解码 + 画布拼接。
  /// 未命中则现场生成并落盘。缓存全程 best-effort——任何失败都回退到现场
  /// 生成,绝不影响渲染。
  static Future<SpriteSheetData> generateFromPack(
    SpritePetPack pack,
    String animName,
  ) async {
    final key = await _cacheKey(pack, animName);

    if (key != null) {
      final cached = await _readCache(key);
      if (cached != null) {
        _log('hit $key (${pack.basePath}/$animName)');
        return cached;
      }
    }

    final watch = Stopwatch()..start();
    final sheet = await _build(pack, animName);
    _log('build ${pack.basePath}/$animName '
        '${watch.elapsedMilliseconds}ms${key == null ? '' : ' -> $key'}');
    if (key != null) await _writeCache(key, sheet);
    return sheet;
  }

  /// 现场生成:逐帧解码 + 拼接图集。
  static Future<SpriteSheetData> _build(
    SpritePetPack pack,
    String animName,
  ) async {
    final animDef = pack.anims[animName]!;
    if (pack.source == PetPackSource.asset) {
      final assetPaths = List.generate(
        animDef.frameCount,
        (i) => '${pack.basePath}/${animDef.folder}/$i.png',
      );
      return generateFromAssets(
        assetPaths: assetPaths,
        frameSize: pack.baseSize,
      );
    }
    return generateFromFiles(
      framePaths: pack.getFramePaths(animName),
      frameSize: pack.baseSize,
    );
  }

  // ── 磁盘缓存 ──────────────────────────────────────────────────────────
  //
  // 同一个宠物包会被多个引擎各加载一遍(每只桌宠一个引擎),逐帧解码 + 画布
  // 拼接本来要做 N 次。这里按 (宠物包, 动画) 落一张图集 PNG + 一份元数据,
  // 命中时只解一张图。

  /// 写临时文件的序号:保证同一引擎内并发写也不重名。
  static int _tmpSeq = 0;

  /// 缓存 key:宠物包来源 + 帧标识的稳定摘要(FNV-1a 64,不引入额外依赖)。
  ///
  /// filesystem 宠物包把每帧的文件名/大小/mtime 混入,资源一改就换 key;
  /// asset 宠物包靠 [_sheetCacheVersion] 手动失效。无法确定时返回 null(不缓存)。
  static Future<String?> _cacheKey(SpritePetPack pack, String animName) async {
    try {
      final animDef = pack.anims[animName];
      if (animDef == null) return null;

      final parts = <String>[
        'v$_sheetCacheVersion',
        pack.source.name,
        pack.basePath,
        animName,
        animDef.folder,
        '${pack.baseSize.width}x${pack.baseSize.height}',
        '${animDef.frameCount}',
      ];
      if (pack.source == PetPackSource.filesystem) {
        for (final path in pack.getFramePaths(animName)) {
          final stat = await File(path).stat();
          parts.add(
              '$path:${stat.size}:${stat.modified.millisecondsSinceEpoch}');
        }
      }

      var hash = 0xcbf29ce484222325;
      for (final part in parts) {
        for (final unit in part.codeUnits) {
          hash = (hash ^ unit) * 0x100000001b3;
        }
        hash = (hash ^ 0x1f) * 0x100000001b3;
      }
      final high = (hash >> 32) & 0xFFFFFFFF;
      final low = hash & 0xFFFFFFFF;
      return '${high.toRadixString(16).padLeft(8, '0')}'
          '${low.toRadixString(16).padLeft(8, '0')}';
    } catch (_) {
      return null;
    }
  }

  /// 读缓存;缺失/损坏/版本不符一律返回 null,由调用方回退到现场生成。
  static Future<SpriteSheetData?> _readCache(String key) async {
    try {
      final png = await _cacheFile(key, '.png');
      final meta = await _cacheFile(key, '.json');
      if (!await png.exists() || !await meta.exists()) return null;

      final json =
          jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      if (json['v'] != _sheetCacheVersion) return null;

      final codec = await ui.instantiateImageCodec(await png.readAsBytes());
      final frame = await codec.getNextFrame();
      codec.dispose();

      return SpriteSheetData(
        image: frame.image,
        frameCount: json['frameCount'] as int,
        grid: GridCoordinate(c: json['cols'] as int, r: json['rows'] as int),
        frameSize: ui.Size(
          (json['frameWidth'] as num).toDouble(),
          (json['frameHeight'] as num).toDouble(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 写缓存(best-effort)。
  ///
  /// 顺序是**先元数据、后 PNG**:读缓存要求两者齐备,于是半成品只会是"有元数据
  /// 没 PNG"——下次写入就会补上;反过来(有 PNG 没元数据)则永远读不中。
  ///
  /// 多引擎会并发写同一个 key,所以:
  /// - 临时文件名带 pid + 序号,互不覆盖;
  /// - rename 目标已存在时**保留已有文件、丢弃自己的临时文件**:key 相同 ⇒
  ///   输入相同 ⇒ 内容相同,谁赢都等价;绝不删别人的成品——万一删掉后自己
  ///   又失败了,就留下一个补不回来的窟窿。
  static Future<void> _writeCache(String key, SpriteSheetData sheet) async {
    File? tmp;
    try {
      final meta = await _cacheFile(key, '.json');
      await meta.writeAsString(
        jsonEncode({
          'v': _sheetCacheVersion,
          'frameCount': sheet.frameCount,
          'cols': sheet.grid.c,
          'rows': sheet.grid.r,
          'frameWidth': sheet.frameSize.width,
          'frameHeight': sheet.frameSize.height,
        }),
        flush: true,
      );

      final bytes = await sheet.image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;

      final png = await _cacheFile(key, '.png');
      tmp = File('${png.path}.$pid.${_tmpSeq++}.tmp');
      await tmp.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      await tmp.rename(png.path);
      tmp = null;
    } catch (_) {
      // 目标已存在(另一引擎已写好)等:保留已有文件,清掉自己的临时文件。
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  /// 缓存文件句柄(目录不存在则创建)。
  static Future<File> _cacheFile(String key, String suffix) async {
    final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/sheet_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$key$suffix');
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
