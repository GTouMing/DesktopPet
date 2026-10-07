import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'model_parameter.dart';

/// Dart side of the in-repo Live2D renderer (`plugins/pet_live2d`).
///
/// Three deliberate differences from `live2d_flutter`, each fixing a defect we
/// hit in practice:
///
///  * a pet is addressed by a **persistent `petId`**, and its native model
///    outlives widget rebuilds / hiding / resizing - so a scale change never
///    reloads the model (no flash, no lost motion state);
///  * every command is queued natively **in order**, so the initial motion can be
///    pushed immediately; there is no "wait for load" handshake;
///  * the render target follows the pet's box, and the Flutter texture is
///    **re-registered** when that size changes. The engine only picks up a
///    freshly registered texture (not a changed descriptor), so Dart is told the
///    new id through `textureChanged`.
class Live2DChannel {
  const Live2DChannel._();

  static const MethodChannel methodChannel =
      MethodChannel('desktop_pet/live2d');

  static final Map<String, Live2DSession> _sessions = {};

  static List<ModelParameter> _parseParameters(Object? raw) {
    if (raw is! List) return const [];
    final out = <ModelParameter>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final id = item['id'];
      if (id is! String || id.isEmpty) continue;
      out.add(ModelParameter(
        id: id,
        minimum: (item['min'] as num?)?.toDouble() ?? 0,
        maximum: (item['max'] as num?)?.toDouble() ?? 0,
        defaultValue: (item['default'] as num?)?.toDouble() ?? 0,
      ));
    }
    return out;
  }

  /// Diagnostic snapshot of the native runtime (device / Cubism init state).
  static Future<Map<Object?, Object?>?> getStatus() async {
    try {
      return await methodChannel
          .invokeMethod<Map<Object?, Object?>>('getStatus');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 模型就绪状态 + 参数元数据（Dart 侧轮询）。
  ///
  /// 原生那条 `modelReady` 推送**到不了子窗口引擎**——`desktop_multi_window` 的
  /// 窗口过程不把消息转给引擎的 `TopLevelWindowProcDelegate`，于是推送永远被丢。
  /// 改成由这里轮询：平台侧返回渲染线程存好的参数快照（见 `pet_live2d_plugin.cpp`）。
  static Future<({bool ready, List<ModelParameter> parameters})?> getModelInfo(
      String petId) async {
    try {
      final reply = await methodChannel.invokeMethod<Map<Object?, Object?>>(
          'getModelInfo', {'petId': petId});
      if (reply == null) return null;
      return (
        ready: reply['ready'] == true,
        parameters: _parseParameters(reply['parameters']),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Creates (or replaces) the renderer for [petId], sized for the pet's current
  /// display box (physical pixels).
  ///
  /// [fitScale] multiplies the automatic fit, and [fitOffsetX] / [fitOffsetY]
  /// shift the model from the box centre. Both come from the pack manifest
  /// (`scale` / `translate`) and mirror the reference implementation
  /// (dsh-pet-live2d: `scale.set(fit * manifest.scale)`,
  /// `position.set(w/2 + manifest.x, h/2 + manifest.y)`).
  ///
  /// The offsets are in **view units**: `1` = half the box's short side, `+x`
  /// right and `+y` **down** (screen orientation, like CSS). The caller
  /// normalises from the manifest's logical pixels.
  ///
  /// [breathScale] is the pack manifest's idle-breath amplitude: `1` (default)
  /// uses the engine's standard Cubism breath, `0` disables it. See
  /// `Live2DPetPack.breathScale`.
  ///
  /// Returns `null` when the runtime is unavailable (non-Windows, plugin missing
  /// or initialisation failure).
  static Future<Live2DSession?> create({
    required String petId,
    required String modelDir,
    required String modelFileName,
    required int widthPx,
    required int heightPx,
    double fitScale = 1,
    double fitOffsetX = 0,
    double fitOffsetY = 0,
    double breathScale = 1,
  }) async {
    try {
      final reply =
          await methodChannel.invokeMethod<Map<Object?, Object?>>('create', {
        'petId': petId,
        'modelDir': modelDir,
        'modelFileName': modelFileName,
        'widthPx': widthPx,
        'heightPx': heightPx,
        'fitScale': fitScale,
        'fitOffsetX': fitOffsetX,
        'fitOffsetY': fitOffsetY,
        'breathScale': breathScale,
      });
      final textureId = reply?['textureId'];
      if (textureId is! int) return null;
      final session = Live2DSession._(petId, textureId);
      _sessions[petId] = session;
      return session;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static void _forget(Live2DSession session) {
    if (identical(_sessions[session.petId], session)) {
      _sessions.remove(session.petId);
    }
  }
}

/// Handle for one pet's native renderer.
///
/// Every command is fire-and-forget: the native side queues them in order, and
/// commands for an already-disposed pet are dropped there.
class Live2DSession {
  Live2DSession._(this.petId, this.textureId);

  final String petId;

  /// The Flutter texture to display. Fixed for the session's whole life: a box
  /// change is served by a new session (see the visual), because a native
  /// renderer cannot be resized in place.
  final int textureId;

  /// 模型参数元数据（`modelReady` 时由原生回传）；就绪前为空表。
  List<ModelParameter> parameters = const [];

  bool _disposed = false;

  /// Plays a motion group. [loop] is what makes an idle motion keep playing; the
  /// old plugin had no way to control this and hard-coded its own restart.
  void setMotion({
    required String group,
    int index = 0,
    int priority = 2,
    bool loop = false,
  }) {
    _invoke('setMotion', {
      'group': group,
      'index': index,
      'priority': priority,
      'loop': loop,
    });
  }

  void setExpression(int index) => _invoke('setExpression', {'index': index});

  void setParameter(String parameterId, double value) =>
      _invoke('setParameter', {'parameterId': parameterId, 'value': value});

  /// Restores a parameter to the **model's own default**, not `0`. A slot group
  /// uses this to undo the options it is not using - `0` is not the neutral value
  /// in general (e.g. this pack's base hands sit at `ParamCheek5x = 1`, so writing
  /// 0 there removes the hands entirely).
  void resetParameter(String parameterId) =>
      _invoke('resetParameter', {'parameterId': parameterId});

  void clearParameters() => _invoke('clearParameters', const {});

  void setDragging(double x, double y) =>
      _invoke('setDragging', {'x': x, 'y': y});

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    Live2DChannel._forget(this);
    _invoke('dispose', const {}, reportErrors: false);
  }

  void _invoke(
    String method,
    Map<String, Object?> arguments, {
    bool reportErrors = true,
  }) {
    if (_disposed && method != 'dispose') return;
    unawaited(
      Live2DChannel.methodChannel
          .invokeMethod<void>(method, {'petId': petId, ...arguments})
          .catchError((Object error) {
        if (reportErrors) {
          debugPrint('[live2d] $petId: $method failed: $error');
        }
      }),
    );
  }
}
