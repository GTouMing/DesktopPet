import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/android/multi_floating_window/multi_floating_window_android.dart';
import '../../platform/android/notification_permission_service.dart';
import '../../platform/platform_factory.dart';
import '../../platform/window_interface.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import '../widgets/pet_list_tile.dart';
import 'pet_edit_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  bool _hasOverlayPermission = false;
  bool _hasNotificationPermission = true;

  /// 每个桌宠对应一个 WindowController，避免重复创建 / 用 ID 查表。
  final Map<String, WindowController> _petControllers = {};

  WindowController _getOrCreateController(String petId) {
    return _petControllers.putIfAbsent(
      petId,
      () => createWindowController(windowId: petId),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appData = ref.watch(appDataProvider);
    final petList = appData.pets;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Desktop Pet'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          tooltip: '全局设置',
          onPressed: _openSettings,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '添加桌宠',
            onPressed: _hasOverlayPermission ? _createNewPet : null,
          ),
        ],
      ),
      body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_hasOverlayPermission) ...[
                  _buildPermissionGuideCard(theme),
                  const SizedBox(height: 24),
                ],
                if (!_hasNotificationPermission) ...[
                  _buildNotificationPermissionCard(theme),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Icon(Icons.pets, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '我的桌宠 (${petList.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (petList.isEmpty)
                  _buildEmptyState(theme)
                else
                  ...petList.map((pet) => PetListTile(
                        pet: pet,
                        onTap: () => _navigateToEditPage(pet),
                        onToggleLocked: () async {
                          final updated = pet.copyWith(isLocked: !pet.isLocked);
                          final ctrl = _getOrCreateController(pet.id);
                          await ctrl.setIgnoreMouseEvents(updated.isLocked);
                          StorageService.writePet(updated);
                          ref.invalidate(appDataProvider);
                        },
                        onToggleVisible: () async {
                          final ctrl = _getOrCreateController(pet.id);
                          if (pet.isVisible) {
                            await ctrl.close();
                          } else {
                            await ctrl.setSize(Size(
                              200 * pet.scaleMultiplier,
                              200 * pet.scaleMultiplier,
                            ));
                            await ctrl.show();
                          }
                          final updated = pet.copyWith(isVisible: !pet.isVisible);
                          StorageService.writePet(updated);
                          ref.invalidate(appDataProvider);
                        },
                        onDelete: () => _showDeleteConfirmation(pet),
                      )),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildPermissionGuideCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('需要悬浮窗权限',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('⚠️ 需要悬浮窗权限才能让桌宠显示在其他应用上层',
                style: TextStyle(fontSize: 14, color: Colors.orange)),
            const SizedBox(height: 4),
            Text('悬浮窗权限用于在桌面上显示宠物，不会收集任何个人信息',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('前往设置开启悬浮窗权限'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationPermissionCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('需要通知权限',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('🔔 通知权限用于保持桌面宠物在后台运行',
                style: TextStyle(fontSize: 14, color: Colors.blue)),
            const SizedBox(height: 4),
            Text('通知权限通过前台服务保持应用活跃，防止桌宠被系统清理',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _requestNotificationPermission,
                icon: const Icon(Icons.notification_add, size: 18),
                label: const Text('开启通知权限'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.pets, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('还没有添加桌宠', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 8),
            Text('点击右上角 + 按钮添加', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Future<void> _checkPermission() async {
    try {
      if (Platform.isAndroid) {
        final hasOverlay = await MultiFloatingWindowAndroid.isPermissionGranted();
        final hasNotification = await NotificationPermissionService.checkNotificationPermission();
        if (mounted) {
          setState(() {
            _hasOverlayPermission = hasOverlay;
            _hasNotificationPermission = hasNotification;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      await MultiFloatingWindowAndroid.requestPermission();
      await Future.delayed(const Duration(milliseconds: 500));
      _checkPermission();
    }
  }

  Future<void> _requestNotificationPermission() async {
    await NotificationPermissionService.requestNotificationPermission();
    await Future.delayed(const Duration(milliseconds: 500));
    _checkPermission();
  }

  Future<void> _createNewPet() async {
    final newPet = PetConfig(id: '', name: '',);

    final result = await Navigator.push<PetConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => PetEditScreen(pet: newPet, isNewPet: true),
      ),
    );

    if (!mounted || result == null) return;

    final petToAdd = result.id.isEmpty
        ? result.copyWith(id: 'pet_${DateTime.now().millisecondsSinceEpoch}')
        : result;
    StorageService.addPet(petToAdd);
    ref.invalidate(appDataProvider);

    // 创建新桌宠的窗口/悬浮窗
    _createPetWindow(petToAdd);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('桌宠添加成功'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _navigateToEditPage(PetConfig pet) async {
    final updatedPet = await Navigator.push<PetConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => PetEditScreen(pet: pet, isNewPet: false),
      ),
    );
    if (updatedPet != null && mounted) {
      StorageService.writePet(updatedPet);
      ref.invalidate(appDataProvider);
    }
  }

  /// 为指定桌宠创建子窗口（Windows）或悬浮窗（Android）。
  void _createPetWindow(PetConfig pet) {
    if (Platform.isWindows) {
      dmw.WindowController.create(dmw.WindowConfiguration(arguments: pet.id));
    } else if (Platform.isAndroid) {
      final settings = StorageService.readSettings();
      final scale = settings.baseScale * pet.scaleMultiplier;
      final w = (pet.width * scale).round().clamp(1, 9999);
      final h = (pet.height * scale).round().clamp(1, 9999);
      MultiFloatingWindowAndroid.showOverlay(
        overlayId: pet.id,
        width: w,
        height: h,
        startPosition: OverlayPosition(pet.positionX.toInt(), pet.positionY.toInt()),
      );
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showDeleteConfirmation(PetConfig pet) {
    final petList = ref.read(appDataProvider).pets;

    if (petList.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('至少需要保留一个桌宠'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除桌宠'),
        content: Text('确定要删除「${pet.name}」吗？\n\n缩放: ${(pet.snappedScaleMultiplier * 100).round()}%\n透明度: ${(pet.snappedOpacityMultiplier * 100).round()}%'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              StorageService.removePet(pet.id);
              ref.invalidate(appDataProvider);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
