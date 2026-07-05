import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

// ── SetWinEventHook ───────────────────────────────────────────────────────

typedef _SetWinEventHookNative = IntPtr Function(
  Uint32 eventMin,
  Uint32 eventMax,
  IntPtr hmodWinEventProc,
  Pointer<NativeFunction<_WinEventProcNative>> lpfnWinEventProc,
  Uint32 idProcess,
  Uint32 idThread,
  Uint32 dwFlags,
);

final _setWinEventHook = _user32.lookupFunction<
  _SetWinEventHookNative,
  int Function(
    int, int, int,
    Pointer<NativeFunction<_WinEventProcNative>>,
    int, int, int,
  )
>('SetWinEventHook');

// ── UnhookWinEvent ────────────────────────────────────────────────────────

typedef _UnhookWinEventNative = Int32 Function(IntPtr);
final _unhookWinEvent = _user32.lookupFunction<_UnhookWinEventNative, int Function(int)>('UnhookWinEvent');

// ── GetWindowTextW ────────────────────────────────────────────────────────

typedef _GetWindowTextNative = Int32 Function(IntPtr, Pointer<Uint16>, Int32);
final _getWindowText = _user32.lookupFunction<_GetWindowTextNative, int Function(int, Pointer<Uint16>, int)>('GetWindowTextW');

// ── WinEvent callback signature ───────────────────────────────────────────

typedef _WinEventProcNative = Void Function(IntPtr, Uint32, IntPtr, Int32, Int32, Uint32, Uint32);

const int _eventSystemForeground = 0x0003;
const int _wineventOutOfContext = 0x0000;

/// 通过 Windows [SetWinEventHook] 监听前台窗口切换，无需轮询。
///
/// 全局单例，通过广播流派发窗口标题变更。
class ForegroundWindowWatcher {
  ForegroundWindowWatcher._();

  static final StreamController<String> _controller = StreamController<String>.broadcast();
  static NativeCallable<_WinEventProcNative>? _callable;
  static int _hookHandle = 0;

  /// 前台窗口标题变更广播流。
  static Stream<String> get onTitleChanged => _controller.stream;

  /// 确保 hook 已注册（幂等，可重复调用）。
  static void ensureStarted() {
    if (_hookHandle != 0) return;

    _callable = NativeCallable<_WinEventProcNative>.listener(_onWinEvent);
    _hookHandle = _setWinEventHook(
      _eventSystemForeground,
      _eventSystemForeground,
      0, // hmodWinEventProc = NULL（回调在当前进程）
      _callable!.nativeFunction,
      0, // idProcess = 所有进程
      0, // idThread = 所有线程
      _wineventOutOfContext,
    );

    if (_hookHandle == 0) {
      _callable!.close();
      _callable = null;
    }
  }

  /// 释放 hook。应用退出时调用。
  static void dispose() {
    if (_hookHandle != 0) {
      _unhookWinEvent(_hookHandle);
      _hookHandle = 0;
    }
    _callable?.close();
    _callable = null;
    _controller.close();
  }

  static void _onWinEvent(
    int hook, int event, int hwnd,
    int idObject, int idChild,
    int dwEventThread, int dwmsEventTime,
  ) {
    if (hwnd == 0 || _controller.hasListener == false) return;

    final buffer = calloc<Uint16>(256);
    final len = _getWindowText(hwnd, buffer, 256);
    if (len > 0) {
      _controller.add(String.fromCharCodes(buffer.asTypedList(len)));
    }
    calloc.free(buffer);
  }
}
