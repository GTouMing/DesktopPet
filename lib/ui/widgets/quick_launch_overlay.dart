import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;

import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/core/providers.dart';
import 'package:desktop_pet/pet/pet_notifier.dart';
import 'package:desktop_pet/storage/models/app_shortcut.dart';
import 'package:desktop_pet/storage/storage_service.dart';
import 'package:desktop_pet/ui/widgets/sector_button.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:win32/win32.dart';
import 'package:win32hooks/const.win.dart';
import 'package:win32hooks/win32hooks.dart';


/// 快捷启动扇环按钮覆盖层。
///
/// 位于 [PetOverlay] 与 [PetWidget] 之间：
/// - 隐藏时直接透传 child（PetWidget）
/// - 长按全局快捷键后显示扇环半透明按钮（最多 8 个）
/// - 松开快捷键时检测鼠标所在按钮，启动对应应用
class QuickLaunchOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const QuickLaunchOverlay({required this.child, super.key});

  @override
  ConsumerState<QuickLaunchOverlay> createState() => _QuickLaunchOverlayState();
}

class _QuickLaunchOverlayState extends ConsumerState<QuickLaunchOverlay>
    with WinHookEventListener {
  PetNotifier get _notifier => ref.read(petStateProvider.notifier);

  // ── 状态 ─────────────────────────────────────────────────────────────

  bool _visible = false;
  Timer? _holdTimer;

  List<AppShortcut> _shortcuts = [];
  ///桌宠大小
  Size _petSize = Size.zero;


  // ── 扇环布局缓存（避免每帧重复计算） ───────────────────────────────────

  /// 当前悬停的扇区索引（-1 = 不在扇环上），由 Stack 级 [MouseRegion] 计算更新。
  int _index = -1;
  /// 内半径
  double _layoutRingRadius = quickLaunchRingRadius;

  // ── 生命周期 ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    initialState();
  }

  Future<void> initialState() async {
    if (!mounted) return;
    // For onMouseInfoReceived and onWinEventInfoReceived
    winHooks.addListener(this);

    /// Cleans cpp memory for mouse buttons and dart event variables
    /// It's for when you reloads/hotreload your app and change buttons in meantime.
    winHooks.cleanHooks();

    ///  [MouseEvent.control] is for blocking the propagation of the button
    ///  [MouseEvent.watch] is for just receiving callback when the button is pressed.
    winHooks.addMouseHook(button: MouseButtons.Middle, mouseEvent: MouseEvent.watch, reinstallHooks: false);

    /// Initiate cpp call.
    winHooks.installWinHook();
    setState(() {});

    ref.listen(petStateProvider, (prev, next) {
     if (next.finalPetSize != Size.zero) {
       setState(() {});
     }
    });
  }
  @override
  void onMouseInfoReceived(MouseStruct mouse) {
    if (mouse.button != MouseButtons.Middle) return;
    if (mouse.down) {
      _onHotkeyDown();
    }
    if (mouse.up) {
      _onHotkeyUp();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  // ── 快捷键注册 ───────────────────────────────────────────────────────

  void _reloadShortcuts() {
    final all = StorageService.readShortcuts();
    all.sort((a, b) => a.order.compareTo(b.order));
    _shortcuts = all.take(quickLaunchMaxItems).toList();
  }
  // ── 热键事件 ─────────────────────────────────────────────────────────

  void _onHotkeyDown() {
    _holdTimer?.cancel();
    _holdTimer = Timer(Duration(milliseconds: quickLaunchHoldMs), () {
      _show();
    });
  }

  void _onHotkeyUp() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pollHover();
    _launchIfHit();
    _hide();
  }

  // ── 显示/隐藏 ────────────────────────────────────────────────────────

  /// 展开窗口。
  void _show() {
    _reloadShortcuts();
    if (_shortcuts.isEmpty) return;

    _notifier.cantMove(true);
    _petSize = _notifier.finalPetSize;
    _layoutRingRadius = sqrt(_petSize.width * _petSize.width + _petSize.height * _petSize.height) / 2;
    _index = -1;

    setState(() {
      _visible = true;
    });
  }

  void _hide() {

    _notifier.cantMove(false);
    setState(() {
      _visible = false;
    });
  }

  // ── win32 轮询鼠标坐标 → 扇区命中检测 ───────────────────────────────

  /// [GetCursorPos] 获取屏幕坐标 → 减去窗口位置得 local 坐标 →
  /// 遍历 8 个扇区 [SectorClipper.buildSectorPath] 做精确命中测试。
  void _pollHover() {
    if (!_visible) return;
    if (_shortcuts.isEmpty) return;

    final cursorPos = _getCursorScreenPos();
    final Offset pos = cursorPos;
    final double extra = _layoutRingRadius + quickLaunchButtonRadius;
    final Size size = Size(2 * extra, 2 * extra);

    for (int i = 0; i < 8; i++) {
      if (SectorClipper.buildSectorPath(
        size: size,
        startAngle: math.pi / 4 * i + math.pi / 72,
        sweepAngle: 2 * math.pi / 9,
        innerRadius: _layoutRingRadius,
        outerRadius: extra,
      ).contains(pos)) {
        _index = i < _shortcuts.length ? i : -1;
        return;
      }
    }
    _index = -1;
  }

  /// 通过 win32 [GetCursorPos] 获取鼠标屏幕坐标。
  Offset _getCursorScreenPos() {
    final point = calloc<POINT>();
    try {
      GetCursorPos(point);
      return Offset(point.ref.x.toDouble(), point.ref.y.toDouble());
    } finally {
      calloc.free(point);
    }
  }

  // ── 命中检测 & 启动 ─────────────────────────────────────────────────────

  void _launchIfHit() {
    if (_index < 0 || _index >= _shortcuts.length) return;
    final shortcut = _shortcuts[_index];
    try {
      Process.start(shortcut.executablePath, [],
          mode: ProcessStartMode.normal);
    } catch (e) {
      debugPrint('QuickLaunch: failed to start ${shortcut.name}: $e');
    }
  }

  // ── 构建 ─────────────────────────────────────────────────────────────

  /// 始终返回统一的 SizedBox→Stack 结构，确保 [widget.child]（PetWidget）
  /// 永远位于 [Stack] 的 children[0] 位，Flutter Element 得以保留，
  /// 避免 PetWidget 在可见性切换时被销毁重建（导致动画丢失）。
  @override
  Widget build(BuildContext context) {
    final showOverlay = _visible;
    final extra = _layoutRingRadius + quickLaunchButtonRadius;

    // 非可见时使用桌宠实际尺寸，避免 SizedBox 缩到零
    final petW = _petSize.width > 0 ? _petSize.width : _notifier.finalPetSize.width;
    final petH = _petSize.height > 0 ? _petSize.height : _notifier.finalPetSize.height;

    return SizedBox(
      width: showOverlay ? 2 * extra : petW,
      height: showOverlay ? 2 * extra : petH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ★ PetWidget 始终位于 Stack children[0]，Element 不丢失
          widget.child,
          // ★ 扇环按钮仅可见时显示
          if (showOverlay) ..._buildButtons(extra),
        ],
      ),
    );
  }

  List<Widget> _buildButtons(double extra) {
    final n = _shortcuts.length;
    if (n == 0) return [];

    return List.generate(8, (index) {
      // 计算每个扇环的起始角度（从12点钟方向开始）
      final startAngle = math.pi / 4 * index + math.pi / 72;
      final sweepAngle = 2 * math.pi / 9;

      return Positioned(
        left: 0,
        top: 0,
        child: SectorButton(
          index: index,
          indexSetter: (i) => _index = i,
          startAngle: startAngle,
          sweepAngle: sweepAngle,
          innerRadius: _layoutRingRadius,
          outerRadius: extra,
          child: Text('${index + 1}', selectionColor: Colors.red,),
        ),
      );
    });
  }
}
