import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/core/pet_window_channel.dart';
import 'package:desktop_pet/core/providers.dart';
import 'package:desktop_pet/platform/android/multi_floating_window/multi_floating_window_android.dart';
import 'package:desktop_pet/platform/windows/tray_manager.dart';
import 'package:desktop_pet/storage/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_alone/flutter_alone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 提前判断平台 ──────────────────────────────────────────────────────
  ensureSupport();

  // ── 解析启动参数（提前，以便按需加载） ──────────────────────────────
  String arg = await parseArgs(args);

  // ── 初始化持久化存储（所有窗口都需要） ──────────────────────────────
  await StorageService.initStorage();

  // ── 统一分派 ──────────────────────────────────────────────────────────
  switch (arg) {
    case mainOrSetting:
      if (!await tryLockSingleInstance()) return;
      if (Platform.isWindows) {
        await windowManager.ensureInitialized();

        await windowManager.setAsFrameless();
        await windowManager.setSize(const Size(800, 600));

        TrayManager.create();
      }
      else {
        await MultiFloatingWindowAndroid.requestPermission();
      }
      PetWindowChannel.register();
      runApp(ProviderScope(child: MainApp()));
      break;
    default:
      runApp(ProviderScope(
        overrides: [
          petIdProvider.overrideWithValue(arg),
        ],
        child: PetApp(),
      ));
    }
}

Future<String> parseArgs(List<String> args) async {
  if (Platform.isAndroid) {
    // Android: 无参数时为主窗口，否则为桌宠 overlay ID
    return args.isEmpty ? mainOrSetting : args[0];
  }
  // Windows: 主引擎不由 dmw 启动，fromCurrentEngine 会抛异常
  // dmw 子进程通过 fromCurrentEngine().arguments 获取 pet.id
  try {
    final dmwArg = (await dmw.WindowController.fromCurrentEngine()).arguments;
    if (dmwArg.isNotEmpty) return dmwArg;
  } catch (_) {}
  return mainOrSetting;
}

/// 尝试获取单实例锁。
///
/// - 返回 `true` — 本进程是唯一实例，可以继续运行。
/// - 返回 `false` — 已有其他实例在运行，本进程应退出。
///
/// 仅在 Windows 主窗口执行，dmw 子窗口不参与。
Future<bool> tryLockSingleInstance() async {
  if (!Platform.isWindows) return true;
  final config = FlutterAloneConfig.forWindows(
    windowsConfig: const DefaultWindowsMutexConfig(
      packageId: 'com.desktop_pet.app',
      appName: 'Desktop Pet',
    ),
    messageConfig: const EnMessageConfig(),
  );
  return FlutterAlone.instance.checkAndRun(config: config);
}

void ensureSupport() {
  if (!Platform.isAndroid && !Platform.isWindows) {
    throw UnsupportedError(
      'Unsupported platform: ${Platform.operatingSystem}',
    );
  }
}