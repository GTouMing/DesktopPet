import 'dart:ui';

/// 桌宠上下文接口。
///
/// [BehaviorEngine] 通过此接口访问 [PetNotifier] 的属性和方法，
/// 避免两端直接互相引用造成循环依赖。
abstract class PetContext {
  void onEvent(String trigger);
  Size get screenSize;
  Size get finalPetSize;
}
