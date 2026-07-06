import 'dart:ffi' hide Size;
import 'dart:io';


import 'package:desktop_pet/core/pet_window_channel.dart';
import 'package:ffi/ffi.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/platform/windows/tray_manager.dart';
import 'package:desktop_pet/storage/storage_service.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../window_interface.dart';
import 'foreground_window_watcher.dart';

final _user32 = DynamicLibrary.open('user32.dll');

// ─── user32 helpers ──────────────────────────────────────────────────────

typedef GetSystemMetricsNative = Int32 Function(Int32);
final _getSystemMetrics = _user32.lookupFunction<GetSystemMetricsNative, int Function(int)>('GetSystemMetrics');

const smCxScreen = 0;
const smCyScreen = 1;

// ─── SetWindowPos + SWP flags (方案二：避免 WM_CANCELMODE) ─────────────

typedef SetWindowPosNative = Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32);
final _setWindowPos = _user32.lookupFunction<SetWindowPosNative, int Function(int, int, int, int, int, int, int)>('SetWindowPos');

typedef FindWindowWNative = IntPtr Function(Pointer<Utf16>, Pointer<Utf16>);
final _findWindowW = _user32.lookupFunction<FindWindowWNative, int Function(Pointer<Utf16>, Pointer<Utf16>)>('FindWindowW');

const int swpNoSize = 0x0001;
const int swpNoZOrder = 0x0004;
const int swpNoActivate = 0x0010;
/// 跳过 WM_WINDOWPOSCHANGING（潜在 WM_CANCLEMODE 触发源）。
const int swpNoSendChanging = 0x0400;

// ─── Foreground window detection ──────────────────────────────────────────

typedef GetForegroundWindowNative = IntPtr Function();
final _getForegroundWindow = _user32.lookupFunction<GetForegroundWindowNative, int Function()>('GetForegroundWindow');

typedef GetWindowTextNative = Int32 Function(IntPtr, Pointer<Uint16>, Int32);
final _getWindowText = _user32.lookupFunction<GetWindowTextNative, int Function(int, Pointer<Uint16>, int)>('GetWindowTextW');

// ─────────────────────────────────────────────────────────────────────────

/// Windows implementation using window_manager for the frameless pet window.
class WindowControllerWindows implements WindowController {
  final String _windowId;

  WindowControllerWindows({String windowId = 'default'}) : _windowId = windowId;

  @override
  String get id => _windowId;

  @override
  double get devicePixelRatio => 1.0;

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();

    if(_windowId == mainOrSetting) {
      //设置界面
      await windowManager.setMaximizable(true);
      await windowManager.setMinimizable(true);
      await windowManager.setResizable(true);
      await windowManager.setSize(const Size(800, 600));
      await windowManager.show();
      await windowManager.focus();
      return;
    }
    else if (_windowId == 'default') {
      //默认引擎
      //创建并初始化系统托盘功能
      TrayManager.create();
      //锁定/解锁所有桌宠：写入 MMKV 后推送消息到各子窗口
      TrayManager.onUnlock = () {
        final pets = StorageService.readPets();
        for (final pet in pets) {
          StorageService.updatePet(pet.id, (_) => pet.copyWith(isLocked: false));
        }
        PetWindowChannel.notifyLockUpdated();
        setIgnoreMouseEvents(false);
      };
      TrayManager.onLock = () {
        final pets = StorageService.readPets();
        for (final pet in pets) {
          StorageService.updatePet(pet.id, (_) => pet.copyWith(isLocked: true));
        }
        PetWindowChannel.notifyLockUpdated();
        setIgnoreMouseEvents(true);
      };
      TrayManager.onSettings = () async {
        final all = await dmw.WindowController.getAll();
        for (final w in all) {
          if (w.arguments == mainOrSetting) {
            await w.show();
            return;
          }
        }
        dmw.WindowController.create(dmw.WindowConfiguration(arguments: mainOrSetting));
      };

      //创建其他桌宠窗口
      final appData = StorageService.appData;
      for (final pet in appData.pets) {
        //默认引擎无需再创建
        if (pet.id == "default") continue;
        dmw.WindowController.create(dmw.WindowConfiguration(arguments: pet.id));
      }
    }

      //桌宠窗口初始化
      final petSize = _computePetWindowSize(_windowId);
      final options = WindowOptions(
        title: _windowId,
        size: petSize,
        alwaysOnTop: true,
        skipTaskbar: true,
        titleBarStyle: TitleBarStyle.hidden,
        backgroundColor: const Color(0x00000000),
      );

      await windowManager.setAlwaysOnTop(true);
      await windowManager.setMaximizable(false);
      await windowManager.setMinimizable(false);
      await windowManager.setResizable(false);
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setAsFrameless();
        await windowManager.setHasShadow(false);
        await windowManager.show();
        await windowManager.focus();
      });
  }

  @override
  Future<void> show() async {
    await windowManager.show();
  }

  @override
  Future<void> hide() async {
    await windowManager.hide();
  }

  @override
  Future<void> close() async {
    await windowManager.destroy();
    exit(0);
  }

  @override
  void dispose() {}

  // ─── Window operations ─────────────────────────────────────────────────

  @override
  Future<void> setIgnoreMouseEvents(bool ignore) async {
    await windowManager.setIgnoreMouseEvents(ignore);
  }

  @override
  Future<Offset> getPosition() async {
    return await windowManager.getPosition();
  }

  @override
  Future<void> setPosition(Offset pos) async {
    await windowManager.setPosition(pos);
  }

  /// 通过 FFI 调用 [SetWindowPos] 移动窗口，附加 SWP_NOSENDCHANGING 标志。
  ///
  /// 避免触发 [WM_CANCELMODE]，防止托盘弹出菜单在 `_onTick` 同步位置时被关闭。
  /// 同步（非 async）调用，不涉及 MethodChannel 往返。
  @override
  void setPositionSync(Offset pos) {
    final hwnd = _getHwnd();
    _setWindowPos(
      hwnd, 0,
      pos.dx.round(), pos.dy.round(),
      0, 0,
      swpNoSize | swpNoZOrder | swpNoActivate | swpNoSendChanging,
    );
  }

  static int? _cachedHwnd;
  int _getHwnd() {
    if (_cachedHwnd case final hwnd?) return hwnd;
    final title = _windowId.toNativeUtf16();
    _cachedHwnd = _findWindowW(nullptr, title);
    calloc.free(title);
    return _cachedHwnd!;
  }

  @override
  Future<void> moveRelative(Offset delta) async {
    final pos = await windowManager.getPosition();
    await setPosition(Offset(pos.dx + delta.dx, pos.dy + delta.dy));
  }

  @override
  Future<void> setSize(Size size) async {
    await windowManager.setSize(size);
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
  }

  @override
  Future<Size> getScreenSize() async {
    try {
      final screenWidth = _getSystemMetrics(smCxScreen);
      final screenHeight = _getSystemMetrics(smCyScreen);
      if (screenWidth > 0 && screenHeight > 0) {
        return Size(screenWidth.toDouble(), screenHeight.toDouble());
      }
    } catch (_) {}
    return const Size(1920, 1080);
  }

  @override
  Future<void> startDragging() async {
    await windowManager.startDragging();
  }

  @override
  String? getForegroundWindowTitle() {
    final hwnd = _getForegroundWindow();
    if (hwnd == 0) return null;
    final buffer = calloc<Uint16>(256);
    final len = _getWindowText(hwnd, buffer, 256);
    if (len <= 0) {
      calloc.free(buffer);
      return null;
    }
    final title = String.fromCharCodes(buffer.asTypedList(len));
    calloc.free(buffer);
    return title;
  }

  @override
  Stream<String> get onForegroundWindowTitle {
    ForegroundWindowWatcher.ensureStarted();
    return ForegroundWindowWatcher.onTitleChanged;
  }

  /// 从 PetConfig × SettingsModel 合成桌宠窗口初始尺寸。
  Size _computePetWindowSize(String petId) {
    final settings = StorageService.readSettings();
    final pet = StorageService.readPet(petId);
    if (pet == null) return const Size(200, 200);
    final scale = settings.baseScale * pet.scaleMultiplier;
    return Size(
      (pet.width * scale).clamp(1.0, double.infinity),
      (pet.height * scale).clamp(1.0, double.infinity),
    );
  }
}
