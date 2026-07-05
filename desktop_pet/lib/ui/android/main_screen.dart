import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/android/multi_floating_window/multi_floating_window_android.dart';
import '../../platform/platform_factory.dart';
import '../../platform/window_interface.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import '../widgets/pet_list_tile.dart';
import '../screens/pet_edit_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    _requestOverlayPermission();
  }

  Future<void> _requestOverlayPermission() async {
    final controller = createWindowController(windowId: 'main');
    await controller.init();

    // 创建所有桌宠的悬浮窗
    final pets = StorageService.readPets();
    for (final pet in pets) {
      if (!mounted) return;
      _createPetWindow(pet, controller);
    }
  }

  void _createPetWindow(PetConfig pet, WindowController controller) {
    final settings = StorageService.readSettings();
    final scale = settings.baseScale * pet.scaleMultiplier;
    final w = (pet.width * scale).round().clamp(1, 9999);
    final h = (pet.height * scale).round().clamp(1, 9999);
    MultiFloatingWindowAndroid.showOverlay(
      overlayId: pet.id,
      width: w,
      height: h,
      startPosition: OverlayPosition(
        pet.positionX.toInt(),
        pet.positionY.toInt(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(appDataProvider).pets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('桌面宠物'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(),
          ),
        ],
      ),
      body: pets.isEmpty
          ? const Center(child: Text('还没有桌宠，点击下方按钮添加'))
          : ListView.builder(
              itemCount: pets.length,
              itemBuilder: (context, index) {
                final pet = pets[index];
                return PetListTile(
                  pet: pet,
                  onTap: () => _navigateToEditPage(pet),
                  onToggleLocked: () => _togglePetLocked(pet),
                  onToggleVisible: () => _togglePetVisible(pet),
                  onDelete: () => _showDeleteConfirmation(pet),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewPet,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AndroidSettingsScreen()),
    );
  }

  void _togglePetLocked(PetConfig pet) {
    final updated = pet.copyWith(isLocked: !pet.isLocked);
    StorageService.writePet(updated);
    ref.invalidate(appDataProvider);
  }

  void _togglePetVisible(PetConfig pet) {
    final updated = pet.copyWith(isVisible: !pet.isVisible);
    StorageService.writePet(updated);
    ref.invalidate(appDataProvider);
  }

  Future<void> _createNewPet() async {
    final newPet = PetConfig(
      id: '',
      name: '',
      scaleMultiplier: 1.0,
      opacityMultiplier: 1.0,
      isLocked: true,
      isVisible: true,
    );

    final result = await Navigator.push<PetConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => PetEditScreen(pet: newPet, isNewPet: true),
      ),
    );

    if (!mounted || result == null) return;

    StorageService.addPet(result);
    ref.invalidate(appDataProvider);

    final controller = createWindowController(windowId: result.id);
    _createPetWindow(result, controller);
  }

  void _navigateToEditPage(PetConfig pet) async {
    final updatedPet = await Navigator.push<PetConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => PetEditScreen(pet: pet, isNewPet: false),
      ),
    );

    if (!mounted || updatedPet == null) return;

    StorageService.writePet(updatedPet);
    ref.invalidate(appDataProvider);
  }

  void _showDeleteConfirmation(PetConfig pet) {
    if (ref.read(appDataProvider).pets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('至少需要保留一个桌宠'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除桌宠'),
        content: Text(
            '确定要删除「${pet.name}」吗？\n\n缩放: ${(pet.snappedScaleMultiplier * 100).round()}%\n透明度: ${(pet.snappedOpacityMultiplier * 100).round()}%\n速度: ${pet.snappedSpeedMultiplier.toStringAsFixed(1)}x'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (!mounted || confirmed != true) return;
      StorageService.removePet(pet.id);
      ref.invalidate(appDataProvider);
    });
  }
}
