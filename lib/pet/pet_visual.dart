import 'package:flutter/widgets.dart';

import '../petpack/hotkey_action.dart';
import '../petpack/state/state_define.dart';

/// 桌宠「怎么画」的边界（对应方案 §13.1 的渲染边界约束）。
///
/// [PetWidget] 只负责把 `PetState` 画出来；具体像素由本接口的实现产出。今天只有
/// 精灵图实现（`SpritePetVisual`），将来 Live2D 作为**第二个实现**接入——行为、
/// 位置、状态机（`BehaviorEngine` / `PetNotifier` / `PetState` / `finalPetSize`）
/// 与渲染器零耦合，换渲染器不必改动它们。
///
/// 实现方自持加载与播放生命周期；宿主（[PetWidget]）只在三个时点驱动它：
/// 宠物包就绪、状态变化、组件销毁。
abstract class PetVisual {
  /// 宠物包就绪后调用一次：加载 [currentState] 所需资源，并后台预加载其余。
  Future<void> prepare(String currentState);

  /// 当前状态变为 [stateName] 时调用。可重复、可乱序到达，实现需自判幂等。
  void playState(String stateName, StateDef? stateDef);

  /// 播放一次「瞬时动作」（宠物包顶层 `hotkeys` 触发，见 [HotkeyAction]）：直接播
  /// 这个动作/表情，**不改变状态机**。
  ///
  /// 默认忽略——只有支持它的渲染器（Live2D）才覆写；实现需自判幂等与就绪状态。
  void playAction(HotkeyAction action) {}

  /// "打字反应"：把模型参数 [parameterId] 设为 [value]（按住 1 / 松开 0），由包顶层
  /// `keyParams` 驱动。默认忽略——只有 Live2D 实现。
  void setParameter(String parameterId, double value) {}

  /// 最终播放速度（`PetState.finalSpeed`，全局 × 本宠）。默认忽略——只有 Live2D
  /// 实现会把它接到动作播放速度上；精灵图的播放速度由每帧时长决定，不在此列。
  void setSpeed(double speed) {}

  /// 产出一帧画面。[size] 是 `PetState.finalPetSize`（**逻辑像素**）：实现内部
  /// 自行缩放到该尺寸，**不得**自建坐标系或反向回写坐标（见方案 §13.3）。
  Widget build(BuildContext context, Size size, StateDef? stateDef);

  /// 当前正在播放的动画/动作名，写回 `PetState.currentAnim`。
  String? get animationName;


  /// 释放资源（控制器、图集、原生对象……）。
  void dispose();
}
