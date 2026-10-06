import 'dart:io';

import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/pet/pet_providers.dart';
import 'package:desktop_pet/platform/android/pet_window_channel.dart';
import 'package:desktop_pet/platform/windows/app_host.dart';
import 'package:desktop_pet/storage/storage_service.dart';
import 'package:desktop_pet/ui/host/overlay_scene.dart';
import 'package:desktop_pet/ui/host/settings_window_root.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_alone/flutter_alone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_floating_window/pet_floating_window.dart';

import 'app.dart';

/// 诊断日志(Debug 构建可见)。
void _hk(String message) {
  if (kDebugMode) debugPrint('[hk] $message');
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 提前判断平台 ──────────────────────────────────────────────────────
  ensureSupport();

  // ── 初始化持久化存储（所有窗口都需要） ──────────────────────────────
  await StorageService.initStorage();

  if (Platform.isAndroid) {
    await _runAndroid(args);
    return;
  }
  await _runWindows(args);
}

// ── Windows：一个悬浮窗 + 一个按需创建的设置窗口 ──────────────────────

/// 启动 Windows 端。
///
/// 桌宠与环形菜单都在**同一个**悬浮窗引擎里绘制（见 `ui/host/overlay_scene.dart`），
/// 因此不再有"每个桌宠/环形菜单一个子引擎"的启动编排，也不需要启动时的逐个错开。
/// 唯一的子窗口是设置窗口。
Future<void> _runWindows(List<String> args) async {
  // 子窗口身份判定：dmw 给子引擎的启动参数固定为
  // ['multi_window', <windowId>, <windowArgument>]（见 desktop_multi_window 的
  // flutter_window.cc）。同步读取它即可判断身份——无竞态，且不依赖插件注册时序
  //（改用 fromCurrentEngine() 会在插件就绪前抛异常，把子窗口误判成主窗口，进而
  // 被单实例锁静默丢弃）。
  if (args.length >= 3 &&
      args.first == 'multi_window' &&
      args[2] == settingsWindowRole) {
    _hk('settings window engine');
    runApp(const ProviderScope(child: SettingsWindowRoot()));
    return;
  }

  _hk('overlay engine');
  // 单实例锁只作用于悬浮窗（主窗口）。
  if (!await tryLockSingleInstance()) return;

  await AppHost.start();
  runApp(const ProviderScope(child: OverlayScene()));
}

// ── Android：主 Activity + 每只桌宠一个系统悬浮窗 ─────────────────────

Future<void> _runAndroid(List<String> args) async {
  // 无参数 = 主窗口；否则为桌宠 overlay 的 id。
  final arg = args.isEmpty ? mainOrSetting : args[0];
  _hk('main args=$args arg="$arg"');

  if (arg == mainOrSetting) {
    // 只在**缺权限**时才拉起系统设置页。
    //
    // 原来的写法是无条件请求：每次启动都会把用户甩到"显示在其他应用上层"页面，
    // 即便早已授权。`requestPermission()` 只是 `startActivity` 后立刻返回，用户是否
    // 授予这里无从得知——授权后重新建悬浮窗由 MainScreen 的 resumed 钩子负责。
    if (!await _hasOverlayPermission()) {
      await PetFloatingWindow.requestPermission()
          .catchError((_) => false);
    }
    // 设置变更 → 推送给各桌宠悬浮窗引擎。
    PetWindowChannel.register();
    runApp(const ProviderScope(child: MainApp()));
    return;
  }

  runApp(ProviderScope(
    overrides: [
      petIdProvider.overrideWithValue(arg),
    ],
    child: const PetApp(),
  ));
}

/// 查询悬浮窗权限；查不到时按"已有权限"处理。
///
/// 宁可漏弹一次设置页，也不要每次启动都把用户甩进系统设置。
Future<bool> _hasOverlayPermission() async {
  try {
    return await PetFloatingWindow.hasPermission();
  } catch (e) {
    _hk('hasPermission failed: $e');
    return true;
  }
}

/// 尝试获取单实例锁。
///
/// - 返回 `true` — 本进程是唯一实例，可以继续运行。
/// - 返回 `false` — 已有其他实例在运行，本进程应退出。
///
/// 仅在 Windows 悬浮窗执行，设置窗口不参与。
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
