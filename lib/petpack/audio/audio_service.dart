import 'package:audioplayers/audioplayers.dart';

import '../state/state_define.dart';

/// 桌宠音效服务（每只桌宠一个实例，随 [PetNotifier] 生命周期）。
///
/// 宠物包在状态里声明 `audio` + `audioVolume`：**进入该状态时播放一次**。更复杂的
/// 场景（喂食 / 对话 / 天气等）可以直接调 [play] 播任意路径。
///
/// 约定：
/// - 播放器**惰性创建**：从不发声的桌宠不会占用播放器；在没有音频插件的环境
///   （如单元测试）里也不会被构造。
/// - 所有播放失败都被吞掉：音效是装饰性的，缺文件 / 平台不支持都不应影响桌宠行为。
///
/// 还没有静音开关——等设置里真有这一项时再加（现在加了也没人调用）。
class AudioService {
  AudioPlayer? _player;
  bool _playerUnavailable = false;

  /// 当前音效标识（通常是状态名），没有则为 null。
  String? _cue;
  String? get cue => _cue;

  /// 是否有音效正在播放。
  bool get isPlaying => _player?.state == PlayerState.playing;

  /// 播放一次性音效。
  ///
  /// - [path] 支持 `assets/...`（内置宠物包）或文件系统绝对路径（导入的宠物包）；
  /// - [cue] 标识"当前放的是哪一条"，用于去重与定向停止；不传则每次都是新音效；
  /// - [volume] 与 [audioVolume] 一起决定响度（0~1）；
  /// - [loop] 为 true 时循环直到被 [stop] 或下一条音效打断。
  Future<void> play(
    String path, {
    String? cue,
    double volume = 1.0,
    bool loop = false,
  }) async {
    if (path.isEmpty) return;
    // 同一条音效正在播就不打断：状态机可能在同一状态内被反复触发。
    if (cue != null && cue == _cue && isPlaying) return;

    final player = _ensurePlayer();
    if (player == null) return;

    _cue = cue;
    try {
      await player.stop();
      await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await player.setVolume(volume.clamp(0.0, 1.0).toDouble());
      await player.play(_sourceFor(path));
    } catch (_) {
      // 装饰性功能：失败不影响桌宠行为。
    }
  }

  /// 播放某个状态声明的音效。
  ///
  /// [cue] 传状态名即可（它就是"这条音效属于哪个状态"）。该状态没有配置音效时
  /// 什么都不做，也不打断上一条（一次性音效让它自然播完）。
  Future<void> playForState(StateDef? state, {required String cue}) {
    final path = state?.audio;
    if (path == null || path.isEmpty) return Future<void>.value();
    return play(path, cue: cue, volume: state?.audioVolume ?? 1.0);
  }

  /// 停止当前音效；传 [cue] 时只在当前正是该 cue 时停止。
  Future<void> stop({String? cue}) async {
    if (cue != null && cue != _cue) return;
    _cue = null;
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
  }

  /// 释放播放器资源。
  void dispose() {
    _cue = null;
    _player?.dispose();
    _player = null;
  }

  /// 惰性创建播放器；不可用时记住失败，避免每次播放都重试。
  AudioPlayer? _ensurePlayer() {
    if (_player != null) return _player;
    if (_playerUnavailable) return null;
    try {
      return _player = AudioPlayer();
    } catch (_) {
      _playerUnavailable = true;
      return null;
    }
  }

  /// `assets/` 前缀由 audioplayers 自行补上（`AssetSource` 默认相对 `assets/`），
  /// 直接传全路径会变成 `assets/assets/...`。
  static Source _sourceFor(String path) {
    const prefix = 'assets/';
    return path.startsWith(prefix)
        ? AssetSource(path.substring(prefix.length))
        : DeviceFileSource(path);
  }
}
