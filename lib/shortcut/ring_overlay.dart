import 'dart:async';
import 'dart:ui' as ui;

import 'package:desktop_pet/core/constants.dart';
import 'package:desktop_pet/shortcut/app_icon.dart';
import 'package:desktop_pet/shortcut/ring_panel.dart';
import 'package:desktop_pet/storage/models/app_shortcut.dart';
import 'package:flutter/material.dart';

/// 悬浮窗内的环形菜单。
///
/// 由 [ringPresented] 驱动：置值即展开，置 null 即收起（先播完收缩动画）。
/// 拆分职责与改造前一致，只是不再有独立窗口：
/// - 本组件只负责"显示面"（展开/收起动画、图标加载、绘制）；
/// - 命中与启动仍由宿主 [QuickLaunchInputHost] 按屏幕坐标完成，本组件整体
///   [IgnorePointer]。
///
/// 改造前这些动画与"窗口 show/setBounds/setOpacity"纠缠在一起（还有隐藏态下引擎
/// 不调度帧导致的首次呈现僵局）；现在它只是一个普通 Widget，那套时序问题随之消失。
class RingOverlay extends StatefulWidget {
  const RingOverlay({super.key});

  @override
  State<RingOverlay> createState() => _RingOverlayState();
}

class _RingOverlayState extends State<RingOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _enterDuration =
      Duration(milliseconds: quickLaunchLineMs + quickLaunchSweepMs);
  static const Duration _collapseDuration =
      Duration(milliseconds: quickLaunchCollapseMs);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _enterDuration,
  );

  RingPayload? _payload;

  /// 已加载的程序图标(路径 → 图像)。
  Map<String, ui.Image> _icons = const {};

  /// 收起阶段: 只收缩半径,不再回收扇形展开进度。
  bool _collapsing = false;

  @override
  void initState() {
    super.initState();
    ringPresented.addListener(_onRingChanged);
  }

  @override
  void dispose() {
    ringPresented.removeListener(_onRingChanged);
    _anim.dispose();
    super.dispose();
  }

  void _onRingChanged() {
    final next = ringPresented.value;

    if (next != null) {
      setState(() {
        _payload = next;
        _collapsing = false;
      });
      unawaited(_loadIcons(next.items));
      // 展开: 先径向线生长,再顺时针扫开扇形。
      _anim.duration = _enterDuration;
      _anim.forward(from: 0);
      return;
    }

    if (_payload == null) return;
    // 收起: 逐帧减小总半径令扇形向内收缩,动画结束后清空内容。
    _collapsing = true;
    _anim.duration = _collapseDuration;
    unawaited(_anim.reverse(from: _anim.value).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _payload = null;
        _collapsing = false;
      });
    }));
  }

  /// 异步加载各 item 的程序图标(已缓存的立即命中,不阻塞呈现)。
  Future<void> _loadIcons(List<AppShortcut> items) async {
    for (final item in items) {
      if (_icons.containsKey(item.executablePath)) continue;
      final image = await AppIconLoader.load(item.executablePath);
      if (image == null || !mounted) continue;
      setState(() => _icons = {..._icons, item.executablePath: image});
    }
  }

  /// 把 [AnimationController] 的值拆成"线生长 / 顺时针扫开 / 半径收缩"。
  ///
  /// 扫开阶段引导线的角度跟随扇形前沿(reveal 前沿)一起旋转,扫过**可用弧**
  /// (`_payload` 的 `startAngle → startAngle + spanAngle`;整圈可用时就是一圈)。
  ({double line, double lineAngle, double reveal, double radius, double lineOpacity})
      _phase(double t) {
    if (_collapsing) {
      return (line: 0, lineAngle: 0, reveal: 1, radius: t, lineOpacity: 0);
    }
    final start = _payload?.startAngle ?? 0;
    final span = _payload?.spanAngle ?? ringFullSpan;
    final lineFraction =
        quickLaunchLineMs / (quickLaunchLineMs + quickLaunchSweepMs);
    if (t < lineFraction) {
      // 先由圆心沿可用弧起点径向生长。
      return (
        line: (t / lineFraction).clamp(0.0, 1.0).toDouble(),
        lineAngle: start,
        reveal: 0,
        radius: 1,
        lineOpacity: 1,
      );
    }
    final reveal =
        ((t - lineFraction) / (1 - lineFraction)).clamp(0.0, 1.0).toDouble();
    return (
      line: 1,
      // 线的前端角 = 扇形扫开前沿,沿可用弧顺时针扫过。
      lineAngle: start + reveal * span,
      reveal: reveal,
      radius: 1,
      // 扫开期间保持可见,仅在最后一小段渐隐。
      lineOpacity: ((1 - reveal) / 0.2).clamp(0.0, 1.0).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;

    // 始终返回 Positioned.fill（同一个 widget 类型），只在内部换内容。
    //
    // 不能在没有 payload 时改返回 SizedBox.shrink()：Positioned 是
    // ParentDataWidget，挂载/卸载时会走祖先链查找，而环形菜单每次展开/收起都会
    // 触发这个切换，等于在 Stack 子树上反复挂载 ParentDataWidget —— 这正是
    // "Looking up a deactivated widget's ancestor is unsafe" 那类断言的来源。
    return Positioned.fill(
      child: payload == null
          ? const SizedBox.shrink()
          : AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final phase = _phase(_anim.value);
                return RingMenu(
                  payload: payload,
                  radiusFactor: phase.radius,
                  revealProgress: phase.reveal,
                  lineProgress: phase.line,
                  lineAngle: phase.lineAngle,
                  lineOpacity: phase.lineOpacity,
                  icons: _icons,
                );
              },
            ),
    );
  }
}
