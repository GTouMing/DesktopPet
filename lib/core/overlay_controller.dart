import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'hit_shape.dart';

/// 悬浮窗场景里一只桌宠的落点与可交互性。
///
/// 按绘制顺序排列：靠后者在上（与 `Stack` 子节点顺序一致），因此命中测试取
/// "最后一个包含光标的条目"。
///
/// [shape] 说明 [rect] 之内哪一部分算命中（见 [HitShape]）：v1 恒为整矩形；
/// [grid] 是为 Live2D 预留的可扩展 payload（`single-engine-overlay.md` §13.2）。
typedef PetHit = ({String id, Rect rect, bool locked, HitShape shape});

/// 悬浮窗场景的共享状态。
///
/// ## 角色：场景瞬时状态（"状态归属"三条规则里的第 2 条）
///
/// 进程内共享、**不持久化**，也**不是通用事件总线**：
///
/// - 写入方固定：[OverlayScene]（场景尺寸、桌宠矩形）与 [QuickLaunchInputHost]
///   （[frozenPet]）；其它层一律只读。
/// - 读取方是桌宠运行时（活动范围）、指针路由（逐宠命中）与环形菜单（选目标）。
/// - 持久化数据不在这里（那是 `StorageService` + `appDataProvider` 的地盘），
///   进程级服务也不在这里（`InputService` / 托盘等）。
///
/// 桌宠与环形菜单现在同处一个引擎、同一个 isolate，因此原本必须跨引擎传递的几件
/// 事退化为进程内状态，直接共享即可。
///
/// 本文件刻意保持"叶子"：只依赖 `dart:ui` 与 `foundation`。**环形菜单自身的呈现
/// 状态不在这里**——它属于 shortcut 层（见 `shortcut/ring_panel.dart` 的
/// `ringPresented`），放进 core 会让 core 反向依赖 shortcut。
class OverlayController {
  OverlayController._();

  /// 场景可用区域（逻辑像素，原点 = 虚拟桌面左上角）。
  ///
  /// 桌宠的活动范围与拖拽 clamp 都以此为准，取代了原先每只桌宠各自向
  /// window_manager 查询的屏幕尺寸。
  static final ValueNotifier<Rect> sceneBounds =
      ValueNotifier<Rect>(Rect.zero);

  /// 每只**可见**桌宠的矩形（场景坐标），按绘制顺序（靠后者在上）。
  ///
  /// 两处消费者：
  /// - 环形菜单据此选目标宠物（含已锁定的——锁只影响能否抓取，不影响选目标）；
  /// - 指针路由据此做逐宠命中（跳过锁定的）。
  static final ValueNotifier<List<PetHit>> pets =
      ValueNotifier<List<PetHit>>(const []);

  /// 归一化光标位置（场景坐标，`[-1, 1]`；null = 未知）。
  ///
  /// 由 [OverlayScene] 从全局鼠标接口换算写入；Live2D 桌宠的"光标跟随"据此驱动
  /// `ParamMouseX/Y`（见 `PetPack.mouseParams`）。屏幕中心 = (0, 0)，右/上为正。
  static final ValueNotifier<Offset?> cursorNorm = ValueNotifier<Offset?>(null);

  /// 被冻结移动的桌宠 id（环形菜单展开期间，避免环与宠物错位）；null = 无。
  ///
  /// 取代原先发往桌宠子窗口的 `set_cant_move` 跨引擎消息。
  static final ValueNotifier<String?> frozenPet = ValueNotifier<String?>(null);
}
