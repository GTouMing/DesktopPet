import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/storage_service.dart';
import '../../storage/models/app_shortcut.dart';

/// Radial shortcut menu that appears around the pet.
class RadialMenu extends ConsumerStatefulWidget {
  const RadialMenu({super.key});

  @override
  ConsumerState<RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends ConsumerState<RadialMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<AppShortcut> shortcuts;
    try {
      if (StorageService.isReady()) {
        shortcuts = StorageService.readShortcuts();
      } else {
        shortcuts = [];
      }
    } catch (_) {
      shortcuts = [];
    }
    if (shortcuts.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: dismiss,
      child: Stack(
        children: [
          // Center dot
          Center(
            child: ScaleTransition(
              scale: _scale,
              child: GestureDetector(
                onTap: dismiss,
                child: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
            ),
          ),
          // Radial items
          for (int i = 0; i < shortcuts.length; i++)
            _RadialItem(
              index: i,
              total: shortcuts.length,
              shortcut: shortcuts[i],
              scale: _scale,
              onTap: () {
                _launchApp(shortcuts[i]);
                dismiss();
              },
            ),
        ],
      ),
    );
  }

  void _launchApp(AppShortcut s) {
    if (Platform.isWindows) {
      Process.run(s.executablePath, []);
    }
  }
}

class _RadialItem extends StatelessWidget {
  final int index, total;
  final AppShortcut shortcut;
  final Animation<double> scale;
  final VoidCallback onTap;

  const _RadialItem({
    required this.index, required this.total, required this.shortcut,
    required this.scale, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final angle = (index / total) * 2 * pi - pi / 2;
    final radius = 100.0;
    final dx = cos(angle) * radius;
    final dy = sin(angle) * radius;

    return AnimatedBuilder(
      animation: scale,
      builder: (_, child) => Transform.translate(
        offset: Offset(dx * scale.value, dy * scale.value),
        child: child,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Center(
            child: Text(shortcut.name.isNotEmpty ? shortcut.name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
      ),
    );
  }
}
