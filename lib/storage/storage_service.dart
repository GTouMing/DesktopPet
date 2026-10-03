import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mmkv/mmkv.dart';

import '../core/constants.dart';
import '../l10n/l10n.dart';
import 'models/pet_config.dart';
import 'models/settings_model.dart';
import 'models/pet_pack_entry.dart';
import 'models/app_shortcut.dart';

/// 应用设置数据：(全局设置, 桌宠列表)。
typedef AppData = ({SettingsModel global, List<PetConfig> pets});

/// MMKV 键值存储服务。
///
/// ## 角色：持久化数据的唯一真源 + 唯一变更信号
///
/// 这是"状态归属"三条规则里的第 1 条（另两条见 `core/overlay_controller.dart` 与
/// `lib/input/input_service.dart`）：
///
/// - 所有读写直接操作 MMKV（MULTI_PROCESS_MODE 确保多进程一致性）；
/// - **所有写 API 写完后都 `notifySettingsChanged()`**（见 [changes]），调用方因此
///   **不需要也不应该**自己 `ref.invalidate` —— UI 只读 `appDataProvider`，它跟着
///   信号自动重算；
/// - 跨引擎（Windows 设置窗口 / Android 主窗口）的写入也走同一个信号：写入方那侧
///   广播变了，另一侧收到"存储已改"后只做一件事——[notifySettingsChanged]，把本地
///   信号补上（后续刷新和同引擎内完全一样）。
class StorageService {
  static MMKV? _mmkv;

  static const _keySettings = 'settings';
  static const _keyPacks = 'skins';
  static const _keyShortcuts = 'shortcuts';
  static const _mmkvId = 'desktop_pet_data';

  /// 每只桌宠一个键:`pet:<id>`。
  ///
  /// 旧版把所有桌宠塞在单一键 `pets` 下,任何写都是"整表读-改-写";宿主与各
  /// 桌宠引擎并发写时会互相覆盖,导致桌宠凭空消失(只剩一只)。改为每只一个键后,
  /// 单只更新不会碰到别的桌宠。
  static const _keyPetPrefix = 'pet:';

  /// 旧版的整表键,仅用于一次性迁移。
  static const _keyLegacyPets = 'pets';

  // ── 初始化 ─────────────────────────────────────────────────────────────

  /// 初始化持久化存储（所有窗口都需要）。
  static Future<void> initStorage() async {
    await StorageService.init();

    // 旧数据(单键整表) → 每只桌宠一个键。
    _migrateLegacyPets();

    // 首次启动：设置全局皮肤目录并创建一个默认桌宠
    if (StorageService.readPets().isEmpty) {
      StorageService.writeSettings(
        SettingsModel(
          packDir: defaultPackPath,
        ),
      );
      StorageService.writePets([
        PetConfig(
          id: defaultPetId,
          name: l10nFor(localeSystem).defaultPetName,
          width: defaultPetSize,
          height: defaultPetSize,
        ),
      ]);
    }
  }

  static Future<void> init() async {
    if (_mmkv != null) return;
    await MMKV.initialize();
    _mmkv = MMKV(_mmkvId, mode: MMKVMode.MULTI_PROCESS_MODE);
  }

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

  // ── 变更信号 ───────────────────────────────────────────────────────────

  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  /// 持久化数据的变更广播。
  ///
  /// **所有写 API 写完后都会 emit 一次**，订阅方据此刷新：`appDataProvider` 自失效、
  /// 跨引擎推送、宿主重挂快捷键、托盘语言刷新。
  ///
  /// 因此调用方**不需要**再自己 invalidate 任何 Provider，也不需要记得"改完要通知
  /// 谁"——这是刻意做成"写即广播"的。
  ///
  /// 例外：皮肤列表（[addPack] / [removePackByPath]）不广播——它不在 [AppData] 里，
  /// 由导入与皮肤选择器按需直接读。
  static Stream<void> get changes => _changes.stream;

  /// 订阅一次数据变更；拿着返回的订阅在销毁时 `cancel()`。
  ///
  /// **优先用它，而不是直接 `changes.listen`**：订阅方的异常会被隔离在这里——
  /// 广播流里某个订阅者抛异常会变成未捕获的 zone 错误，并且会牵连同一次广播里的
  /// 其它订阅者；这里逐个包住，坏的那一个不影响别人。
  static StreamSubscription<void> addSettingsListener(
      void Function() listener) {
    return changes.listen((_) {
      try {
        listener();
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('[storage] change listener failed: $e\n$s');
        }
      }
    });
  }

  /// 广播一次变更（写 API 内部调用；直接改 MMKV 的路径也可手动调用）。
  static void notifySettingsChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  static void writeSettings(SettingsModel settings) {
    _mmkv?.encodeString(_keySettings, jsonEncode(settings.toJson()));
    notifySettingsChanged();
  }

  /// 读取、用 [transform] 修改并写回全局设置。
  ///
  /// **所有设置写入都应经过这里**：调用方拿到的是新对象，不会改到 provider 里那份
  /// 被缓存的实例；写完统一广播变更。
  static void updateSettings(SettingsModel Function(SettingsModel) transform) {
    writeSettings(transform(readSettings()));
  }

  // ── 桌宠配置 ───────────────────────────────────────────────────────────

  /// 一次性把旧的整表键 `pets` 拆成每只桌宠一个键 `pet:<id>`。
  static void _migrateLegacyPets() {
    final mmkv = _mmkv;
    if (mmkv == null || !mmkv.containsKey(_keyLegacyPets)) return;
    final raw = mmkv.decodeString(_keyLegacyPets);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final value in decoded.values) {
            if (value is! Map) continue;
            final pet = PetConfig.fromJson(Map<String, dynamic>.from(value));
            mmkv.encodeString(
                '$_keyPetPrefix${pet.id}', jsonEncode(pet.toJson()));
          }
        }
      } catch (_) {}
    }
    mmkv.removeValue(_keyLegacyPets);
  }

  /// 返回全部桌宠(每只一个键, 互不覆盖)。
  static List<PetConfig> readPets() {
    final mmkv = _mmkv;
    if (mmkv == null) return [];
    final pets = <PetConfig>[];
    for (final key in mmkv.allKeys) {
      if (!key.startsWith(_keyPetPrefix)) continue;
      final pet = _decode<PetConfig>(mmkv.decodeString(key), PetConfig.fromJson);
      if (pet != null) pets.add(pet);
    }
    pets.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
    return pets;
  }

  /// 按 ID 查询单个桌宠。
  static PetConfig? readPet(String id) =>
      _decode<PetConfig>(_mmkv?.decodeString('$_keyPetPrefix$id'),
          PetConfig.fromJson);

  /// 批量写入(逐只写各自键, **不会**删除未列出的桌宠)。
  static void writePets(List<PetConfig> pets) {
    for (final pet in pets) {
      _writePetRaw(pet);
    }
    notifySettingsChanged();
  }

  /// 新增或覆盖单个桌宠(只写它自己的键)。
  static void writePet(PetConfig pet) {
    _writePetRaw(pet);
    notifySettingsChanged();
  }

  static void _writePetRaw(PetConfig pet) {
    _mmkv?.encodeString('$_keyPetPrefix${pet.id}', jsonEncode(pet.toJson()));
  }

  /// 读取、用 [transform] 修改并写回单个桌宠。
  static void updatePet(String id, PetConfig Function(PetConfig) transform) {
    final pet = readPet(id);
    if (pet == null) return;
    writePet(transform(pet));
  }

  /// 新增桌宠（写入 MMKV）。
  static void addPet(PetConfig pet) => writePet(pet);

  /// 删除桌宠。
  static void removePet(String id) {
    _mmkv?.removeValue('$_keyPetPrefix$id');
    notifySettingsChanged();
  }

  // ── 皮肤条目 ───────────────────────────────────────────────────────────

  static List<PetPackEntry> readPacks() {
    final raw = _mmkv?.decodeString(_keyPacks);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return [];
      return decoded.values
          .whereType<Map<String, dynamic>>()
          .map((e) => PetPackEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 以 folderPath 为键存储（覆盖同名路径）。
  static void addPack(PetPackEntry entry) {
    final existing = readPacks();
    final map = {for (final s in existing) s.folderPath: s.toJson()};
    map[entry.folderPath] = entry.toJson();
    _mmkv?.encodeString(_keyPacks, jsonEncode(map));
  }

  static void removePackByPath(String folderPath) {
    final existing = readPacks();
    existing.removeWhere((s) => s.folderPath == folderPath);
    final map = {for (final s in existing) s.folderPath: s.toJson()};
    _mmkv?.encodeString(_keyPacks, jsonEncode(map));
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

  /// 写入快捷启动列表（顺序即 [AppShortcut.order]）。
  static void writeShortcuts(List<AppShortcut> shortcuts) {
    _mmkv?.encodeString(_keyShortcuts, jsonEncode(shortcuts.map((s) => s.toJson()).toList()));
    notifySettingsChanged();
  }

  /// 按可执行文件路径移除快捷启动项，并重新编号 [AppShortcut.order]。
  ///
  /// 用于启动时发现目标程序已不存在（路径失效）的清理。
  static void removeShortcutByPath(String executablePath) {
    final shortcuts = readShortcuts()
      ..removeWhere((s) => s.executablePath == executablePath);
    writeShortcuts(AppShortcut.reindexed(shortcuts));
  }

  // ── 便捷访问 ───────────────────────────────────────────────────────────

  /// 一次性读取设置和桌宠列表（每次读 MMKV）。
  static AppData get appData => (global: readSettings(), pets: readPets());
}

/// [StorageService] 数据的只读视图。
///
/// 由 [StorageService.changes] 驱动：任何写入都会让本 Provider 重算，所以调用方
/// **不需要**再手动 `ref.invalidate(appDataProvider)`——这也是它保持普通 `Provider`
/// 的原因（所有 `ref.watch(appDataProvider)` 的调用点零改动）。
///
/// 注：皮肤列表不在 [AppData] 里，由导入/选择器按需直接读，因此它的写入不广播。
final appDataProvider = Provider<AppData>((ref) {
  // 走 addSettingsListener 而不是直接 listen：它会把订阅方的异常隔离掉。
  final sub = StorageService.addSettingsListener(() => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return StorageService.appData;
});
