import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_alone/flutter_alone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../platform/pet_manager.dart';
import '../../storage/storage_service.dart';
import '../../storage/models/pet_config.dart';
import '../widgets/pet_list.dart';
import '../widgets/info_overlay.dart';
import 'pet_edit_screen.dart';
import 'pet_launcher.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late final PetManager _petManager = PetManager();

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      Future.delayed(Duration.zero, () => windowManager.hide());
    }
    Future.microtask(() => _petManager.loadAllExisting().catchError((_) {}));
  }

  @override
  void dispose() {
    _petManager.dispose();
    if (Platform.isWindows) {
      FlutterAlone.instance.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appData = ref.watch(appDataProvider);
    final petList = appData.pets;

    return Scaffold(
      appBar: AppBar(
        title: Text('Desktop Pet'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: _openSettings,
          ),
          Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '添加桌宠',
            onPressed: _createNewPet,
          ),
        ],
      ),
      body: PetList(pets: petList, onTap: _navigateToEditPage),
    );
  }

  Future<void> _createNewPet() async {
    final ok = await createNewPet(context, onCreated: () {
      ref.invalidate(appDataProvider);
      final pets = StorageService.readPets();
      if (pets.isEmpty) return;
      _petManager.open(pets.last);
    });
    if (ok && mounted) {
      InfoOverlay.show(context, title: '桌宠添加成功');
    }
  }

  void _navigateToEditPage(PetConfig pet) async {
    final updatedPet = await Navigator.push<PetConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => PetEditScreen(pet: pet, isNewPet: false),
      ),
    );
    if (updatedPet != null && mounted) {
      StorageService.writePet(updatedPet);
      ref.invalidate(appDataProvider);
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}
