///默认桌宠缩放
const double defaultPetScale = 1.0;
/// 最终缩放上限（baseScale × scaleMultiplier）
const double maxFinalScale = 3.0;
///最大精灵图尺寸
const int maxSpriteSheetDimension = 4096;
///行为刻，多久进行一次行为
const int behaviorTickMs = 50;
const double petWalkSpeed = 100.0;
const String defaultSkinName = 'default';
const String defaultSkinPath = 'assets/default_skin';
const String skinFileName = 'skin.json';
const String mainOrSetting = 'mainOrSetting';
const String defaultPetId = 'default';
const String moveToTarget = 'moveToTarget';
const String moveToEdge = 'moveToEdge';

// ── 快捷启动 ─────────────────────────────────────────────────────────

/// 快捷启动默认快捷键键名。
const String defaultQuickLaunchKey = 'g';
/// 快捷启动按键修饰键（默认 Alt+G，避免拦截输入法）。
const List<String> defaultQuickLaunchModifiers = ['alt'];
/// 快捷启动扇环按钮半径（逻辑像素）。
const double quickLaunchButtonRadius = 40.0;
/// 扇环排列半径（按钮圆心到 pet 中心的距离）。
const double quickLaunchRingRadius = 90.0;
/// 快捷启动最大按钮数。
const int quickLaunchMaxItems = 8;
/// 长按判定阈值（毫秒）。
const int quickLaunchHoldMs = 1000;

class Trigger {
  static const String click = 'click';
  static const String drag = 'drag';
  static const String limitTimer = 'limitTimer';
  static const String waitTimer = 'waitTimer';
  static const String complete = 'complete';
  static const String arrived = 'arrived';
  static const String eat = 'eat';
  static const String moveUp = 'moveUp';
  static const String moveDown = 'moveDown';
  static const String moveLeft = 'moveLeft';
  static const String moveRight = 'moveRight';
  static const String hotkey = 'hotkey';
}
