import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../storage/storage_service.dart';

/// 诊断日志(Debug 构建可见)。
void _hk(String message) {
  if (kDebugMode) debugPrint('[hk] $message');
}

/// 快捷启动的工人 isolate。
///
/// "目标是否还在"与"拉起进程"都是**同步阻塞**调用（`existsSync`、
/// `Process.start` 即 CreateProcess），路径落在断开的网络盘/慢速设备上会更久。
/// 而触发它们的却是全局钩子回调（平台线程 = UI 线程）：一旦超过系统的
/// LowLevelHooksTimeout（默认 300ms），系统会**直接摘掉钩子**——中键、桌宠拖拽、
/// 光标命中面全部失灵，必须重启应用。
///
/// 所以真正干活的部分搬到这里，钩子回调里只剩一次非阻塞的 `SendPort.send`。
/// 也正因如此，[warmUp] **必须在安装全局钩子之前**调用：`Isolate.spawn` 的启动部分
/// 是同步的（debug 构建还要准备内核），第一次可能几百毫秒。
class ShortcutLauncher {
  ShortcutLauncher._();

  /// 工人 isolate 的收件口（null = 尚未预热）。
  static SendPort? _port;

  /// 回执口；持有它以免被回收。
  static final ReceivePort _reports = ReceivePort();

  /// 是否已预热。
  static bool get isReady => _port != null;

  /// 预热工人 isolate（幂等）。
  static Future<void> warmUp() async {
    if (_port != null) return;
    final ready = ReceivePort();
    await Isolate.spawn(_entry, [ready.sendPort, _reports.sendPort]);
    _port = await ready.first as SendPort;
    ready.close();
    _reports.listen(_onReport);
  }

  /// 投递一条启动请求（非阻塞）。未预热时记日志并跳过。
  static void launch(String executablePath) {
    final port = _port;
    if (port == null) {
      _hk('launcher not ready, skipped: $executablePath');
      return;
    }
    port.send(executablePath);
  }

  /// 工人 isolate 入口：收到路径就检查并拉起，回执给主 isolate。
  static void _entry(List<SendPort> ports) {
    final toMain = ports[1];
    final inbox = ReceivePort();
    ports[0].send(inbox.sendPort);
    inbox.listen((message) {
      final path = message as String;
      String status;
      try {
        if (!File(path).existsSync()) {
          status = 'missing';
        } else {
          // 仍用 detached：normal 模式会给子进程建 stdio 管道，而我们不读取，
          // 日志较多的程序（Electron 类，如 Blockbench）写满缓冲后会被卡死。
          Process.start(path, const [], mode: ProcessStartMode.detached);
          status = 'launched';
        }
      } catch (e) {
        status = 'failed: $e';
      }
      toMain.send((status, path));
    });
  }

  /// 回执处理：目标已失效时顺手清掉该快捷方式。
  ///
  /// MMKV 只能在主 isolate 里写，所以这条兜底留在主 isolate。
  static void _onReport(Object? message) {
    final (status, path) = message as (String, String);
    switch (status) {
      case 'launched':
        _hk('launched: $path');
      case 'missing':
        _hk('target missing, remove shortcut: $path');
        StorageService.removeShortcutByPath(path);
      default:
        _hk('launch failed: $path -> $status');
    }
  }
}
