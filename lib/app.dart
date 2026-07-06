import 'dart:io';

import 'package:flutter/material.dart';

import 'ui/android/main_screen.dart';
import 'ui/android/settings_screen.dart';
import 'ui/windows/settings_screen.dart';

class PetApp extends StatelessWidget {
  const PetApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid && !Platform.isWindows) {
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}',
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        useMaterial3: true,
      ),
      home: Platform.isAndroid
          ? const MainScreen()
          : const WindowsSettingsScreen(),
    );
  }
}