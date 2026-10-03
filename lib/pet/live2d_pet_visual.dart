import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:live2d_flutter/live2d_flutter.dart';

import '../petpack/live2d_pet_pack.dart';
import '../petpack/state/state_define.dart';
import 'pet_visual.dart';

/// Live2D 渲染实现。
///
/// 插件在 Windows 上走 D3D11 GPU-surface 纹理、在 Android 上走 PlatformView，两者
/// 都以**普通 widget** 进入 Flutter 场景，所以这里与精灵图实现完全同构：宿主只
/// 负责在「就绪 / 状态变化 / 销毁」三个时点驱动。
///
/// 尺寸语义与 [PetVisual] 约定一致：只接受 `finalPetSize`（逻辑像素）并由
/// `Live2DView` 自己缩放，不自建坐标系。
class Live2DPetVisual implements PetVisual {
  Live2DPetVisual({required this._pack, this.motionPriority = 3});

  final Live2DPetPack _pack;

  /// 动作优先级：`0` none / `1` idle / `2` normal / `3` force。
  final int motionPriority;

  Live2DViewController? _controller;

  /// 最近一次请求的动作组名（写回 `PetState.currentAnim`）。
  String? _current;

  /// 最近一次请求的状态名。加载完成前到达的状态变化不能丢，加载后补播。
  String? _pendingState;

  bool _loaded = false;
  bool _disposed = false;

  @override
  String? get animationName => _current;

  @override
  Future<void> prepare(String currentState) async {
    if (_disposed || _controller != null) return;
    final controller = Live2DViewController();
    _controller = controller;
    _pendingState = currentState;
    // 视图挂载后 whenAttached 才会完成（build() 返回 Live2DView）。
    unawaited(_loadThenPlay(controller));
  }

  @override
  void playState(String stateName, StateDef? stateDef) {
    if (_disposed) return;
    _pendingState = stateName;
    if (!_loaded) return; // 加载完成时会补播 _pendingState。
    _play(stateDef, stateName);
  }

  @override
  Widget build(BuildContext context, Size size, StateDef? stateDef) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Live2DView(controller: controller),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    final controller = _controller;
    _controller = null;
    if (controller == null) return;

    // 本组件的 dispose 可能先于 Live2DView 的 dispose 执行，而后者会调
    // controller._detach()（会写 controller.value）。推迟到本帧结束后再释放，
    // 保证视图先卸载。vendored 副本里也给 _detach() 加了 _isDisposed 守卫，双保险。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        controller.dispose();
      } catch (_) {
        // 已释放 / 视图已拆除：忽略。
      }
    });
  }

  // ── 内部 ─────────────────────────────────────────────────────────────

  Future<void> _loadThenPlay(Live2DViewController controller) async {
    try {
      await controller.whenAttached;
      if (_disposed) return;

      var ok = await controller.loadModel(
        modelDir: _pack.modelDir,
        modelFileName: _pack.modelFileName,
      );
      if (_disposed) return;

      if (!ok) {
        // Android 实测：视图刚 attach 后**第一次** loadModel 必然返回 false
        // （GL/Surface 尚未就绪），紧接着重试一次即可成功；Windows 首载即成功。
        // 插件在这条路径上没有任何日志（Android 的 PrintLogLn 是空实现），
        // 只能靠重试兜住——否则桌宠表现为“永久透明”。
        _report('loadModel failed once, retrying');
        ok = await controller.loadModel(
          modelDir: _pack.modelDir,
          modelFileName: _pack.modelFileName,
        );
        if (_disposed) return;
      }

      if (!ok) {
        _report('loadModel returned false for ${_pack.modelFileName}');
        return;
      }
      _loaded = true;

      final state = _pendingState ?? _pack.initialState;
      _play(_pack.states[state], state);
    } catch (e) {
      _report('prepare failed: $e');
    }
  }

  void _play(StateDef? stateDef, String stateName) {
    final group = stateDef?.animation ?? stateName;
    if (group.isEmpty) return;

    _current = group;
    final controller = _controller;
    if (controller == null) return;

    unawaited(
      controller.startMotion(group: group, priority: motionPriority).catchError(
            (Object e) => _report('startMotion("$group") failed: $e'),
          ),
    );
  }

  void _report(String message) {
    if (kDebugMode) debugPrint('[live2d] ${_pack.name}: $message');
  }
}
