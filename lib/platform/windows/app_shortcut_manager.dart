import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/storage_service.dart';
import '../../storage/models/app_shortcut.dart';

/// Manages CRUD operations for user-defined application launch shortcuts.
class AppShortcutManager {
  List<AppShortcut> listShortcuts() {
    final shortcuts = StorageService.readShortcuts();
    shortcuts.sort((a, b) => a.order.compareTo(b.order));
    return shortcuts;
  }

  Future<void> addShortcut(AppShortcut shortcut) async {
    final shortcuts = StorageService.readShortcuts();
    shortcuts.add(shortcut);
    StorageService.writeShortcuts(shortcuts);
  }

  Future<void> updateShortcut(int index, AppShortcut shortcut) async {
    final shortcuts = StorageService.readShortcuts();
    if (index >= shortcuts.length) return;
    shortcuts[index] = shortcut;
    StorageService.writeShortcuts(shortcuts);
  }

  Future<void> deleteShortcut(int index) async {
    final shortcuts = StorageService.readShortcuts();
    if (index >= shortcuts.length) return;
    shortcuts.removeAt(index);
    StorageService.writeShortcuts(shortcuts);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final shortcuts = StorageService.readShortcuts();
    if (oldIndex >= shortcuts.length) return;
    final moved = shortcuts.removeAt(oldIndex);
    final updated = AppShortcut(
      name: moved.name,
      executablePath: moved.executablePath,
      order: newIndex,
    );
    if (newIndex > shortcuts.length) newIndex = shortcuts.length;
    shortcuts.insert(newIndex, updated);
    StorageService.writeShortcuts(shortcuts);
  }
}

final appShortcutManagerProvider = Provider<AppShortcutManager>((ref) => AppShortcutManager());