import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'input_source.dart';
import 'key_event.dart';
import 'key_input.dart';
import 'key_registry.dart';
import 'platform/windows_input_source.dart';
import 'pointer_event.dart';

/// 按键检测服务(宿主引擎单例)。
///
/// ## 角色：进程级服务（"状态归属"三条规则里的第 3 条）
///
/// 必须在 `runApp` 之前就能挂全局输入，所以它是单例而不是 Riverpod Provider；但
/// **只从装配点驱动**（`AppHost.start()`），业务侧不要自己去 `instance.start/stop`。
/// 另两条规则见 `storage/storage_service.dart`（持久化真源）与
/// `core/overlay_controller.dart`（场景瞬时状态）。
///
/// 集中管理唯一的 [KeyRegistry](按键 map 映射)与平台 [InputSource]。
/// 业务系统通过 [register] / [unregister] 注册按键, 用 [KeyHandler] 回调收事件。
class InputService implements KeyInput {
  InputService._();

  static final InputService instance = InputService._();

  /// 按键注册表(map 映射 + 事件广播)。
  final KeyRegistry registry = KeyRegistry();

  /// 桌宠指针事件出口(由宿主设置为 PetPointerRouter)。
  void Function(InputPointerEvent event)? onPointer;

  /// 鼠标反馈：光标位置出口（**物理屏幕像素**，由宿主换算为场景坐标）。
  void Function(Offset physical)? onCursor;

  /// 鼠标按键事件广播（多只桌宠可各自订阅）。
  final StreamController<({MouseButton button, bool down})> _mouseButtons =
      StreamController<({MouseButton button, bool down})>.broadcast();

  Stream<({MouseButton button, bool down})> get mouseButtons =>
      _mouseButtons.stream;

  /// 鼠标反馈上报的引用计数：任一订阅者需要就开着。
  int _mouseTracking = 0;

  late final InputSource _source =
      Platform.isWindows ? WindowsInputSource() : NoopInputSource();

  bool _started = false;
  bool _dirty = false;
  Future<void>? _pending;

  /// 初始化并设置监听器(幂等)。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _source.onEvent = registry.dispatch;
    _source.onPointer = (event) => onPointer?.call(event);
    _source.onCursor = (physical) => onCursor?.call(physical);
    _source.onMouseButton =
        (button, down) => _mouseButtons.add((button: button, down: down));
    await _rearm();
  }

  /// 声明桌宠的可抓取区域([regions] 为**物理屏幕像素**)。
  ///
  /// 悬浮窗整窗穿透、收不到鼠标消息,桌宠的点击/拖拽全靠全局钩子;钩子用这份
  /// 区域判断"左键按下算不算抓到了桌宠"。每条区域的 [WatchRegion.shape] 是预留的
  /// 可扩展命中 payload(v1 恒为整矩形)。
  Future<void> setWatchRegions(List<WatchRegion> regions) =>
      _source.setWatchRegions(regions);

  /// 申请/释放鼠标反馈上报（引用计数：任一桌宠需要就开着）。见 [InputSource.setMouseTracking]。
  Future<void> setMouseTracking(bool on) {
    _mouseTracking += on ? 1 : -1;
    if (_mouseTracking < 0) _mouseTracking = 0;
    return _source.setMouseTracking(_mouseTracking > 0);
  }

  /// 注册一个按键(注册后自动初始化/重挂输入源)。
  @override
  Future<void> register(KeyIdentifier id,
      {KeyCallback? onDown, KeyCallback? onUp}) {
    registry.register(id, onDown: onDown, onUp: onUp);
    return _schedule();
  }

  /// 注销一个按键。
  @override
  Future<void> unregister(KeyIdentifier id) {
    registry.unregister(id);
    return _schedule();
  }

  /// 等待当前批次的注册生效(同一批次内的多次注册/注销合并为一次挂载)。
  @override
  Future<void> flush() => _schedule();

  /// 卸载全局输入(宿主退出时)。
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _source.disarm();
  }

  Future<void> _schedule() {
    if (!_started) return Future<void>.value();
    _dirty = true;
    return _pending ??= _drain();
  }

  /// 让出一次事件循环, 合并本批次所有变更后只 arm 一次。
  Future<void> _drain() async {
    await Future<void>.delayed(Duration.zero);
    while (_dirty) {
      _dirty = false;
      await _rearm();
    }
    _pending = null;
  }

  Future<void> _rearm() async {
    if (!_source.supported) return;
    await _source.arm(registry.bindings.keys.toList());
  }
}
