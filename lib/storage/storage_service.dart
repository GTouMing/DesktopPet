import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mmkv/mmkv.dart';

import '../core/constants.dart';
import 'models/pet_config.dart';
import 'models/settings_model.dart';
import 'models/skin_entry.dart';
import 'models/app_shortcut.dart';

/// 应用设置数据：(全局设置, 桌宠列表)。
typedef AppData = ({SettingsModel global, List<PetConfig> pets});

/// MMKV 键值存储服务。
///
/// 所有读写直接操作 MMKV（MULTI_PROCESS_MODE 确保多进程一致性）。
class StorageService {
  static MMKV? _mmkv;

  static const _keySettings = 'settings';
  static const _keyPetConfig = 'pets';
  static const _keySkins = 'skins';
  static const _keyShortcuts = 'shortcuts';
  static const _mmkvId = 'desktop_pet_data';

  // ── 初始化 ─────────────────────────────────────────────────────────────

  /// 初始化持久化存储（所有窗口都需要）。
  static Future<void> initStorage() async {
    await StorageService.init();

    // 首次启动：设置全局皮肤目录并创建一个默认桌宠
    if (StorageService.readPets().isEmpty) {
      StorageService.writeSettings(
        SettingsModel(
          skinDir: defaultSkinPath,
        ),
      );
      StorageService.writePets([
        PetConfig(
          id: defaultPetId,
          name: '默认桌宠',
          width: 200,
          height: 200,
        ),
      ]);
    }
  }

  static Future<void> init() async {
    if (_mmkv != null) return;
    await MMKV.initialize();
    _mmkv = MMKV(_mmkvId, mode: MMKVMode.MULTI_PROCESS_MODE);
  }

  static bool isReady() => _mmkv != null;

  // ── 辅助 ───────────────────────────────────────────────────────────────

  static T? _decode<T>(String? raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {}
    return null;
  }

  // ── 全局设置 ───────────────────────────────────────────────────────────

  static SettingsModel readSettings() {
    return _decode<SettingsModel>(_mmkv?.decodeString(_keySettings), SettingsModel.fromJson) ??
        SettingsModel();
  }

  /// 设置写入后的回调（主窗口设置此回调，用于跨窗口推送通知）。
  static void Function()? onSettingsChanged;

  static void _notifySettingsChanged() {
    onSettingsChanged?.call();
  }

  static void writeSettings(SettingsModel settings) {
    _mmkv?.encodeString(_keySettings, jsonEncode(settings.toJson()));
    _notifySettingsChanged();
  }

  // ── 桌宠配置 ───────────────────────────────────────────────────────────

  /// 返回全部桌宠列表（每次读 MMKV）。
  static List<PetConfig> readPets() {
    final raw = _mmkv?.decodeString(_keyPetConfig);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return [];
      return decoded.values
          .whereType<Map<String, dynamic>>()
          .map((e) => PetConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 按 ID 查询单个桌宠。
  static PetConfig? readPet(String id) {
    return readPets().cast<PetConfig?>().where((p) => p?.id == id).firstOrNull;
  }

  /// 全量替换桌宠列表。
  static void writePets(List<PetConfig> pets) {
    final map = {for (final p in pets) p.id: p.toJson()};
    _mmkv?.encodeString(_keyPetConfig, jsonEncode(map));
    _notifySettingsChanged();
  }

  /// 新增或覆盖单个桌宠。
  static void writePet(PetConfig pet) {
    final pets = readPets();
    final index = pets.indexWhere((p) => p.id == pet.id);
    if (index >= 0) {
      pets[index] = pet;
    } else {
      pets.add(pet);
    }
    writePets(pets);
  }

  /// 读取、用 [transform] 修改并写回单个桌宠。
  ///
  /// 等价于 readPet(id) → pet.copyWith(...) → writePet(pet)。
  static void updatePet(String id, PetConfig Function(PetConfig) transform) {
    final pet = readPet(id);
    if (pet == null) return;
    writePet(transform(pet));
  }

  /// 新增桌宠（写入 MMKV）。
  static void addPet(PetConfig pet) {
    final pets = readPets();
    pets.add(pet);
    writePets(pets);
  }

  /// 删除桌宠。
  static void removePet(String id) {
    final pets = readPets();
    pets.removeWhere((p) => p.id == id);
    writePets(pets);
  }

  // ── 皮肤条目 ───────────────────────────────────────────────────────────

  static List<SkinEntry> readSkins() {
    final raw = _mmkv?.decodeString(_keySkins);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return [];
      return decoded.values
          .whereType<Map<String, dynamic>>()
          .map((e) => SkinEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 以 folderPath 为键存储（覆盖同名路径）。
  static void addSkin(SkinEntry entry) {
    final existing = readSkins();
    final map = {for (final s in existing) s.folderPath: s.toJson()};
    map[entry.folderPath] = entry.toJson();
    _mmkv?.encodeString(_keySkins, jsonEncode(map));
  }

  static void removeSkinByPath(String folderPath) {
    final existing = readSkins();
    existing.removeWhere((s) => s.folderPath == folderPath);
    final map = {for (final s in existing) s.folderPath: s.toJson()};
    _mmkv?.encodeString(_keySkins, jsonEncode(map));
  }

  // ── 快捷启动 ───────────────────────────────────────────────────────────

  static List<AppShortcut> readShortcuts() {
    final raw = _mmkv?.decodeString(_keyShortcuts);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => AppShortcut.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void writeShortcuts(List<AppShortcut> shortcuts) {
    _mmkv?.encodeString(_keyShortcuts, jsonEncode(shortcuts.map((s) => s.toJson()).toList()));
  }

  // ── 便捷访问 ───────────────────────────────────────────────────────────

  /// 一次性读取设置和桌宠列表（每次读 MMKV）。
  static AppData get appData => (global: readSettings(), pets: readPets());
}

/// 监听 [StorageService] 数据变化的 Riverpod 提供者。
///
/// 当数据写回 MMKV 后，调用 [Ref.invalidate] 触发重建，
/// 提供者会从 MMKV 重新读取最新数据。
final appDataProvider = Provider<AppData>((ref) => StorageService.appData);