import 'dart:math';

/// 最终缩放上限（baseScale × scaleMultiplier）
const double maxFinalScale = 3.0;

/// 未收敛的最终缩放（全局 baseScale × 本宠 scaleMultiplier）。
double rawFinalScale(double baseScale, double scaleMultiplier) =>
    baseScale * scaleMultiplier;

/// 收敛到 [maxFinalScale] 后的最终缩放。
///
/// 全工程唯一的"最终缩放"算法：窗口尺寸、渲染尺寸、编辑页校验都走它。
double finalScaleOf(double baseScale, double scaleMultiplier) =>
    min(rawFinalScale(baseScale, scaleMultiplier), maxFinalScale);
///最大精灵图尺寸
const int maxSpriteSheetDimension = 4096;
///行为刻，多久进行一次行为
const int behaviorTickMs = 50;
const double petWalkSpeed = 100.0;
/// 桌宠基帧/窗口的默认尺寸（逻辑像素）。
const double defaultPetSize = 200.0;
const String defaultPackPath = 'assets/default_pet_pack';
const String mainOrSetting = 'mainOrSetting';
/// 设置窗口（唯一的 dmw 子窗口）的启动参数。
///
/// 桌宠与环形菜单都由宿主悬浮窗自己绘制，所以设置窗口是仅剩的子窗口身份。
const String settingsWindowRole = 'settingsWindow';
const String defaultPetId = 'default';
const String moveToTarget = 'moveToTarget';
const String moveToEdge = 'moveToEdge';

// ── 快捷启动 ─────────────────────────────────────────────────────────

/// 快捷启动默认快捷键键名。
const String defaultQuickLaunchKey = 'g';
/// 快捷启动按键修饰键（默认 Alt+G，避免拦截输入法）。
const List<String> defaultQuickLaunchModifiers = ['alt'];
/// 环形菜单总半径下限（逻辑像素）。
const double quickLaunchMinRadius = 150.0;
/// 触发时找不到桌宠窗口（尚未就绪）时的兜底尺寸（逻辑像素）。
const double quickLaunchFallbackPetSize = 200.0;
/// 相邻扇区之间在边界处截断的夹角（度），用于区分各 item 触发区域。
const double quickLaunchSectorGapDeg = 5.0;
/// 快捷启动最大按钮数。
const int quickLaunchMaxItems = 8;
/// 长按判定阈值（毫秒）。
const int quickLaunchHoldMs = 1000;
/// 展开动画：从圆心沿 0° 径向生长的线时长（毫秒）。
const int quickLaunchLineMs = 140;
/// 展开动画：顺时针扫开扇形的时长（毫秒）。
const int quickLaunchSweepMs = 280;
/// 收起动画：总半径逐帧收缩的时长（毫秒）。
const int quickLaunchCollapseMs = 200;

// ── 语言 ─────────────────────────────────────────────────────────────

/// 跟随系统语言。
const String localeSystem = 'system';
/// 简体中文。
const String localeZh = 'zh';
/// English。
const String localeEn = 'en';

class Trigger {
  static const String click = 'click';
  static const String drag = 'drag';
  static const String limitTimer = 'limitTimer';
  static const String waitTimer = 'waitTimer';
  static const String complete = 'complete';
  static const String arrived = 'arrived';
  static const String moveUp = 'moveUp';
  static const String moveDown = 'moveDown';
  static const String moveLeft = 'moveLeft';
  static const String moveRight = 'moveRight';
  static const String hotkey = 'hotkey';
}
