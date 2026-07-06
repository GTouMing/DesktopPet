import 'package:flutter/animation.dart';

import '../platform/window_interface.dart';
import '../skin/sheet/sprite_sheet_generator.dart';
import '../skin/skin_package.dart';
import 'behavior_engine.dart';
import 'pet_hotkey_bindings.dart';

/// 桌宠运行时资源集合。
///
/// 统一持有皮肤包、行为引擎、快捷键、精灵图、动画控制器及窗口控制器，
/// 由 [PetNotifier] 持有，[PetWidget] 通过 Notifier 访问。
class PetResources {
  SkinPackage? skin;
  final BehaviorEngine engine = BehaviorEngine();
  final PetHotkeyBindings hotkey = PetHotkeyBindings();
  final WindowController windowController;
  final Map<String, SpriteSheetData> sheets = {};
  final Map<String, AnimationController> controllers = {};

  PetResources({required this.windowController});
}