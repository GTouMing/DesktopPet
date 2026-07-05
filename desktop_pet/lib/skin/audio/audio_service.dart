import 'package:audioplayers/audioplayers.dart';

/// Plays audio files synced with pet animations.
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  String? _currentAnim;
  bool muted = false;

  /// Play an audio file for the given animation, if configured.
  /// [audioPath] is a file path or asset key.
  Future<void> playForAnimation(String animName, String? audioPath, {
    double volume = 1.0,
    bool loop = false,
  }) async {
    if (muted || audioPath == null || audioPath.isEmpty) return;

    // Don't restart the same audio
    if (_currentAnim == animName && _player.state == PlayerState.playing) return;

    _currentAnim = animName;
    try {
      await _player.stop();
      if (audioPath.startsWith('assets/')) {
        await _player.play(AssetSource(audioPath));
      } else {
        await _player.play(DeviceFileSource(audioPath));
      }
      await _player.setVolume(volume);
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    } catch (_) {}
  }

  Future<void> stop() async {
    _currentAnim = null;
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
