import 'dart:io';

import 'package:desktop_pet/ui/android/pet_overlay.dart';
import 'package:desktop_pet/ui/windows/pet_overlay.dart';
import 'package:flutter/material.dart';

import 'desktop_pet.dart';
import 'ui/common/main_screen.dart';
import 'ui/widgets/window_frame.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    ensureSupport();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.pink,
        useMaterial3: true,
      ),
      home: const MainScreen(),
      builder: (context, child) {
        return Platform.isWindows
            ? WindowFrame(child: child!)
            : child!;
      },
    );
  }
}

class PetApp extends StatelessWidget {
  const PetApp({super.key});

  @override
  Widget build(BuildContext context) {
    ensureSupport();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Platform.isAndroid
          ? const AndroidPetOverlay()
          : const WindowsPetOverlay(),
    );
  }
}