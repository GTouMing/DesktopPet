import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pet/pet_notifier.dart';
import '../pet/pet_state.dart';
import '../platform/window_interface.dart';
import '../skin/audio/audio_service.dart';
import '../skin/import/skin_repository.dart';

// ── 已有 Provider ───────────────────────────────────────────────────────────

final skinRepositoryProvider = Provider<SkinRepository>((ref) => SkinRepository());

// ── 窗口级依赖注入（必须由子窗口 ProviderScope 覆写） ─────────────────────

/// 子窗口 ID，由启动参数传入。
final petIdProvider = Provider<String>((ref) => '');

/// 窗口控制器抽象，创建后注入。
final windowControllerProvider = Provider<WindowController>((ref) {
  throw StateError('windowControllerProvider 必须在子窗口 ProviderScope 中覆写');
});

// ── PetNotifier ─────────────────────────────────────────────────────────────

/// 桌宠状态管理器，由 Riverpod 管理生命周期。
///
/// 依赖 [windowControllerProvider] 和 [petIdProvider]，
/// 子窗口创建 [ProviderScope] 时须覆写这两个 provider。
final petStateProvider = StateNotifierProvider<PetNotifier, PetState>((ref) {
  final controller = ref.watch(windowControllerProvider);
  final petId = ref.watch(petIdProvider);
  return PetNotifier(petId, controller);
});

// ── AudioService ────────────────────────────────────────────────────────────

/// 音频服务，autoDispose 自动释放播放器资源。
final audioServiceProvider = Provider.autoDispose<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});