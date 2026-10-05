import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
  static bool _handlerInstalled = false;

  /// The native side pushes this whenever the render target was re-registered.
  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'modelReady') {
        final petId = call.arguments;
        if (petId is String) _sessions[petId]?.handleModelReady();
      }
      return null;
    });
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

  /// Creates (or replaces) the renderer for [petId], sized for the pet's current
  /// display box (physical pixels).
  ///
  /// Returns `null` when the runtime is unavailable (non-Windows, plugin missing
  /// or initialisation failure).
  static Future<Live2DSession?> create({
    required String petId,
    required String modelDir,
    required String modelFileName,
    required int widthPx,
    required int heightPx,
  }) async {
    _ensureHandler();
    try {
      final reply =
          await methodChannel.invokeMethod<Map<Object?, Object?>>('create', {
        'petId': petId,
        'modelDir': modelDir,
        'modelFileName': modelFileName,
        'widthPx': widthPx,
        'heightPx': heightPx,
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

  void clearParameters() => _invoke('clearParameters', const {});

  void setMotionSpeed(double speed) =>
      _invoke('setMotionSpeed', {'speed': speed});

  void setDragging(double x, double y) =>
      _invoke('setDragging', {'x': x, 'y': y});

  /// Called by the caller once the native model finished loading. A warmed-up
  /// instance is swapped in here, which is what makes a resize blank-free.
  VoidCallback? onReady;

  /// Native → Dart, from the channel's `modelReady` handler.
  void handleModelReady() {
    if (_disposed) return;
    onReady?.call();
  }

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
