import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/core/pet_window_channel.dart';
import 'package:desktop_pet/core/providers.dart';
import 'package:desktop_pet/pet/pet_initializer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'ui/android/pet_overlay.dart';
import 'ui/windows/pet_overlay.dart';
import 'platform/platform_factory.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 提前判断平台 ──────────────────────────────────────────────────────
  if (!Platform.isWindows && !Platform.isAndroid) throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');

  // ── 解析启动参数（提前，以便按需加载） ──────────────────────────────
  String arg = await parseArgs(args);

  // ── 初始化持久化存储（所有窗口都需要） ──────────────────────────────
  await PetInitializer.initStorage();

  // 新建控制器
  final controller = createWindowController(windowId: arg);
  await controller.init();

  // ── 统一分派 ──────────────────────────────────────────────────────────
  switch (arg) {
    case mainOrSetting: {
      //主引擎或设置窗口注册设置变更通知通道
      PetWindowChannel.register();
      runApp(ProviderScope(child: PetApp()));
    }
    default: {
      runApp(ProviderScope(
        overrides: [
          windowControllerProvider.overrideWithValue(controller),
          petIdProvider.overrideWithValue(arg),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Platform.isAndroid
              ? const AndroidPetOverlay()
              : const WindowsPetOverlay(),
        ),
      ));
    }
  }
}

Future<String> parseArgs(List<String> args) async {
  if (Platform.isAndroid) {
    return args.isEmpty ? mainOrSetting : args[0];
  }
  else {
    final dmwArg = (await dmw.WindowController.fromCurrentEngine()).arguments;
    return dmwArg.isEmpty ? 'default' : dmwArg;
  }
}
