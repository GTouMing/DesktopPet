import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:win32hooks/win32hooks.dart';

import '../pet/pet_notifier.dart';
import '../pet/pet_state.dart';
import '../skin/audio/audio_service.dart';

// ── 窗口级依赖注入（必须由子窗口 ProviderScope 覆写） ─────────────────────

/// 子窗口 ID，由启动参数传入。
final petIdProvider = Provider<String>((ref) => '');

// ── PetNotifier ─────────────────────────────────────────────────────────────

/// 桌宠状态管理器，由 Riverpod 管理生命周期。
final petStateProvider = StateNotifierProvider<PetNotifier, PetState>((ref) => PetNotifier(ref));

// ── AudioService ────────────────────────────────────────────────────────────

/// 音频服务，autoDispose 自动释放播放器资源。
final audioServiceProvider = Provider.autoDispose<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

final winHooks = WinHooks();