import 'dart:async';
import 'dart:ui';

import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/core/overlay_controller.dart';
import 'package:desktop_pet/input/input.dart';
import 'package:desktop_pet/shortcut/quick_launch_target.dart';
import 'package:desktop_pet/shortcut/ring_panel.dart';
import 'package:desktop_pet/shortcut/shortcut_launcher.dart';
import 'package:desktop_pet/shortcut/system_cursor.dart';
import 'package:desktop_pet/storage/models/app_shortcut.dart';
import 'package:desktop_pet/storage/storage_service.dart';
import 'package:flutter/foundation.dart';

/// 诊断日志(Debug 构建可见)。
void _hk(String message) {
  if (kDebugMode) debugPrint('[hk] $message');
}

enum _Phase { idle, holding, presented }

/// 快捷启动编排器（悬浮窗引擎单例）。
///
/// 只负责"何时展开、展开在哪、松开时启动哪个"这条编排线：
/// - 全局输入只在此注册一份（热键 + 默认中键）；
/// - 触发后：选目标桌宠（[findTargetPet]）→ 置 [ringPresented]
///   （环形菜单画在悬浮窗内，由 [RingOverlay] 承载）；松开时按光标命中扇区
///   （[hitRingSector]）并启动；down 后 3s 未 up 自动收起。
///
/// 拆出去的部分：[system_cursor]（FFI 读光标 → 场景坐标）、
/// [quick_launch_target]（目标选择，纯几何）、[shortcut_launcher]（工人 isolate，
/// 真正去检查与拉起进程）。
///
/// 手势：按下进入 holding，长按满 [quickLaunchHoldMs] 后在目标桌宠处展开环形菜单；
/// 此时松开，命中扇区则启动对应应用，随后收起。未满长按阈值即松开视为取消。
class QuickLaunchInputHost {
  QuickLaunchInputHost._();

  static QuickLaunchInputHost? _instance;

  static QuickLaunchInputHost get instance =>
      _instance ??= QuickLaunchInputHost._();

  /// 当前已注册到 [InputService] 的按键绑定。
  final List<KeyIdentifier> _registered = [];

  /// 已挂载的快捷键签名(`key|mod1,mod2`)。
  ///
  /// 任何设置写入都会触发重挂（见 [StorageService.addSettingsListener]），而结果
  /// 只由快捷键设置决定；用它过滤掉与快捷键无关的写入（透明度/缩放/显隐/坐标等），
  /// 免得每次都去注销再重挂全局钩子。
  String? _armedSignature;

  bool _started = false;

  /// 设置变更订阅（[stop] 时取消）。
  StreamSubscription<void>? _settingsSub;

  _Phase _phase = _Phase.idle;
  Timer? _holdTimer;
  Timer? _guardTimer;
  List<AppShortcut> _items = const [];

  // ── 生命周期 ─────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 先把绑定装进注册表，再启动输入源。
    //
    // 反过来的话 InputService.start() 会先按"空注册表"挂一次（原生
    // configure bindings=0 + start），紧接着 register 又重挂一次，原生那边
    // 白跑一轮钩子配置。
    await _registerBindings();
    // start() 内部会按当前注册表挂载一次，无需再 flush（那会多挂一次）。
    await InputService.instance.start();
    _settingsSub = StorageService.addSettingsListener(_reRegister);
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _reset();
    for (final id in _registered) {
      unawaited(InputService.instance.unregister(id));
    }
    _registered.clear();
    _armedSignature = null;
    await _settingsSub?.cancel();
    _settingsSub = null;
    await InputService.instance.stop();
  }

  /// 设置变更 → 重新注册绑定（改快捷键即时生效）。
  Future<void> _reRegister() => _registerBindings();

  /// 按当前设置注册按键绑定（键盘组合键 + 中键），合并为一次挂载。
  ///
  /// 结果只由快捷键设置决定，而任何设置写入都会触发本方法（见 [_reRegister]）；
  /// 故先比对签名：没变直接返回，不去注销重挂全局钩子。
  Future<void> _registerBindings() async {
    final settings = StorageService.readSettings();
    final keyName = settings.quickLaunchKey;
    final signature = '$keyName|${settings.quickLaunchModifiers.join(',')}';
    if (_armedSignature == signature && _registered.isNotEmpty) return;
    _armedSignature = signature;

    for (final id in _registered) {
      unawaited(InputService.instance.unregister(id));
    }
    _registered.clear();

    _hk('register key="$keyName" mods=${settings.quickLaunchModifiers}');

    if (keyName.isNotEmpty) {
      final id = KeyIdentifier.key(
        keyName,
        modifiers: settings.quickLaunchModifiers,
      );
      _registered.add(id);
      unawaited(InputService.instance.register(
        id,
        onDown: (_) => _onTriggerDown(),
        onUp: (_) => _onTriggerUp(),
      ));
    }

    final mouseId = KeyIdentifier.mouse(MouseButton.middle);
    _registered.add(mouseId);
    unawaited(InputService.instance.register(
      mouseId,
      onDown: (_) => _onTriggerDown(),
      onUp: (_) => _onTriggerUp(),
    ));

    await InputService.instance.flush();
    _hk('bindings=${_registered.map((e) => e.composite).join(",")}');
  }

  // ── 触发 ─────────────────────────────────────────────────────────────

  Future<void> _onTriggerDown() async {
    _hk('down phase=$_phase');
    // 上一轮手势未结束(holding/presented)时忽略重复按下。
    if (_phase != _Phase.idle) return;

    final items = StorageService.readShortcuts()
      ..sort((a, b) => a.order.compareTo(b.order));
    _items = items.take(quickLaunchMaxItems).toList();
    _hk('down items=${_items.length}');
    // 没有快捷启动项时整体不响应。
    if (_items.isEmpty) return;

    _phase = _Phase.holding;
    _holdTimer?.cancel();
    _holdTimer = Timer(Duration(milliseconds: quickLaunchHoldMs), () {
      unawaited(_present());
    });
  }

  Future<void> _onTriggerUp() async {
    _hk('up phase=$_phase');
    _holdTimer?.cancel();
    _holdTimer = null;

    // 长按已展开：松开时按光标命中扇区启动。
    if (_phase == _Phase.presented) {
      await _releaseAndLaunch();
      return;
    }

    // holding(未满长按阈值)/idle：视为点按取消。
    _reset();
  }

  // ── 呈现 ─────────────────────────────────────────────────────────────

  Future<void> _present() async {
    if (_phase != _Phase.holding) return;

    final target = await _pickTargetPet();
    _hk('present rect=${target?.rect}');
    if (target == null) {
      _reset();
      return;
    }

    final scene = OverlayController.sceneBounds.value;
    if (scene.isEmpty) {
      _reset();
      return;
    }

    // 环心 = 目标桌宠中心(场景坐标)。半径上限收敛到屏幕较短边。
    final geometry = ringGeometry(
      center: target.rect.center,
      petSize: target.rect.size,
      screen: scene.size,
    );

    // 贴边/贴角时整圈装不下:半径不变,改用"能完整落屏的那段弧"平分启动区
    // (见 [ringFittingArc]);弧窄到点不中(fitting == null)则退回整圈,
    // 与不贴边时行为一致。
    final fitting = ringFittingArc(
      center: target.rect.center,
      scene: scene,
      solidRadius: geometry.solidRadius,
      totalRadius: geometry.totalRadius,
      count: _items.length,
    );

    // 展开期间冻结目标宠物移动,避免环与宠物错位;收起时恢复。
    OverlayController.frozenPet.value = target.petId;
    ringPresented.value = RingPayload(
      centerInWindow: target.rect.center,
      totalRadius: geometry.totalRadius,
      solidRadius: geometry.solidRadius,
      startAngle: fitting?.start ?? 0,
      spanAngle: fitting?.span ?? ringFullSpan,
      items: _items,
    );
    _hk('present delivered (arc=$fitting)');
    _phase = _Phase.presented;

    // 兜底: down 后长时间未 up → 收起(防卡死)。
    _guardTimer?.cancel();
    _guardTimer = Timer(const Duration(seconds: 3), () {
      _dismiss();
      _reset();
    });
  }

  /// 松开: 光标命中扇区 → 先收起手势，再启动。
  ///
  /// 顺序不能反。启动走 [ShortcutLauncher]，慢或抛异常都不该把中键手势卡在
  /// presented：环不收起、目标桌宠不解冻，下次按中键又因为 `_phase != idle` 被直接
  /// 忽略 —— 表现就是"中键像还按着没释放"。启动是最后一步，且不该影响收尾。
  Future<void> _releaseAndLaunch() async {
    final slot = _hitSlot();
    final target =
        (slot != null && slot < _items.length) ? _items[slot] : null;

    _dismiss();
    _reset();

    if (target != null) {
      ShortcutLauncher.launch(target.executablePath);
    }
  }

  /// 收起环形菜单（[RingOverlay] 会先播完收缩动画）。
  void _dismiss() {
    ringPresented.value = null;
  }

  // ── 命中换算 ─────────────────────────────────────────────────────────

  /// 光标位置直接与当前 [RingPayload] 比较。
  int? _hitSlot() {
    final payload = ringPresented.value;
    final cursor = getCursorInScene();
    if (payload == null || cursor == null) return null;
    return hitRingSector(contentPoint: cursor, payload: payload);
  }

  // ── 目标选择 ─────────────────────────────────────────────────────────

  /// 目标桌宠：长期未就绪时短暂重试，仍无则回退到光标处的默认尺寸（此时无目标
  /// 桌宠，不冻结移动）。
  ///
  /// 应用刚启动、宠物包尚未加载完时桌宠还没有可渲染尺寸，首次触发会找不到目标；
  /// 若直接放弃，表现为"第一次按没反应，过一会儿按才有反应"。
  Future<RingTarget?> _pickTargetPet() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final cursor = getCursorInScene();
      if (cursor != null) {
        final target = findTargetPet(OverlayController.pets.value, cursor);
        if (target != null) return target;
      }
      if (attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }

    // 兜底: 以光标为中心用默认尺寸开环,保证快捷键始终有响应。
    final cursor = getCursorInScene();
    if (cursor == null) return null;
    return (
      petId: null,
      rect: Rect.fromCenter(
        center: cursor,
        width: quickLaunchFallbackPetSize,
        height: quickLaunchFallbackPetSize,
      ),
    );
  }

  void _reset() {
    // 恢复目标宠物移动(无论因命中启动、取消还是 3s 兜底收起)。
    OverlayController.frozenPet.value = null;

    _holdTimer?.cancel();
    _guardTimer?.cancel();
    _holdTimer = null;
    _guardTimer = null;
    _phase = _Phase.idle;
    _items = const [];
  }
}
