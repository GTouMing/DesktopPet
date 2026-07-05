const double defaultPetScale = 1.0;
const double maxFinalScale = 3.0; // 最终缩放上限（baseScale × scaleMultiplier）
const int maxSpriteSheetDimension = 4096;
const int behaviorTickMs = 50;
const double petWalkSpeed = 100.0; // pixels per second
const int activityPollIntervalMs = 2000;
const int gameDetectIntervalMs = 5000;
const int idleThresholdMs = 30000;
const int lightThresholdMs = 2000;
const String defaultSkinName = 'default';
const String defaultSkinPath = 'assets/default_skin';
const String skinFileName = 'skin.json';
const String mainOrSetting = 'mainOrSetting';
const String defaultPetId = 'default';
class Trigger {
  static const String click = 'click';
  static const String drag = 'drag';
  static const String timer = 'timer';
  static const String window = 'window';
  static const String complete = 'complete';
  static const String arrived = 'arrived';
  static const String eat = 'eat';
  static const String moveUp = 'moveUp';
  static const String moveDown = 'moveDown';
  static const String moveLeft = 'moveLeft';
  static const String moveRight = 'moveRight';
}
