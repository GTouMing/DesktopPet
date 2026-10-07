import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat_bubble/chat_bubble_layer.dart';
import '../../core/device.dart';
import '../../core/hit_shape.dart';
import '../../core/overlay_controller.dart';
import '../../input/input.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../platform/windows/overlay_window.dart';
import '../../pet/pet_pointer_router.dart';
import '../../pet/pet_providers.dart';
import '../../pet/pet_view.dart';
import '../../shortcut/ring_overlay.dart';
import '../../storage/storage_service.dart';
import '../theme/app_theme.dart';
import 'grab_rects.dart';
import 'scene_geometry.dart';
import 'settings_window_channel.dart';

/// 悬浮窗的唯一根组件。
///
/// 这一个引擎/一个窗口同时承载：全部桌宠 + 环形菜单。窗口本身由原生铺满整个
/// 虚拟桌面，且**常驻整窗穿透**（见 windows/runner/overlay_window.cpp）——桌面
/// 因此永远可用，UI 卡死也挡不住任何点击。
///
/// 代价是这个窗口收不到鼠标消息（`WS_EX_TRANSPARENT` 让系统在命中测试时直接跳过
/// 它），所以桌宠的点击/拖拽不能靠 Flutter 的手势系统，而由进程级全局钩子驱动：
/// 本组件把各桌宠的矩形声明给钩子（"光标在这里按下才算抓到桌宠"），钩子转发来的
/// 事件交给 [PetPointerRouter] 做逐宠命中与拖拽。
///
/// 两件事拆在隔壁：[SceneGeometry]（场景几何 + 物理/逻辑换算）、
/// [GrabRectPublisher]（把矩形声明给钩子）；跨引擎的"存储已改"监听见
/// [listenToSettingsWindow]。
///
/// 另一个必须知道的前提：窗口客户区是**正方形**（边长 = 桌面宽，底部一条对齐
/// 屏幕）。引擎的渲染表面边长取的是窗口宽度，非正方形客户区会被整体纵向压成
/// "高/宽"并贴底，所以场景内容必须画在客户区底部那一条里（见 [build]）。
class OverlayScene extends ConsumerStatefulWidget {
  const OverlayScene({super.key});

  @override
  ConsumerState<OverlayScene> createState() => _OverlaySceneState();
}

class _OverlaySceneState extends ConsumerState<OverlayScene>
    with WidgetsBindingObserver {
  /// 场景几何（= 桌面几何）与向钩子的矩形声明。
  final SceneGeometry _geometry = SceneGeometry();
  late final GrabRectPublisher _grabRects = GrabRectPublisher(_geometry);

  /// 最近一次构建得出的桌宠清单（场景坐标，靠后者在上）。
  List<PetHit> _pets = const [];

  late final PetPointerRouter _router = PetPointerRouter(
    resolve: (petId) {
      if (!mounted) return null;
      try {
        return ref.read(petStateProvider(petId).notifier);
      } catch (_) {
        // 该宠物已被删除/隐藏，对应 provider 已释放。
        return null;
      }
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    InputService.instance.onPointer = (event) =>
        _router.handle(event, currentDevicePixelRatio, _geometry.origin);
    InputService.instance.onCursor = _onCursor;
    OverlayWindow.registerHandler();
    OverlayWindow.onGeometryChanged = () {
      // 原生重铺了几何（DPI 变化等）：重取边界并重推抓取矩形。
      unawaited(_refreshScene());
    };
    unawaited(_refreshScene());
    unawaited(_listenToSettingsWindow());
  }

  @override
  void dispose() {
    OverlayWindow.onGeometryChanged = null;
    InputService.instance.onPointer = null;
    InputService.instance.onCursor = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // 显示器拓扑/缩放变化：窗口尺寸可能已由原生重设，重新取一次。
    unawaited(_refreshScene());
  }

  /// 全局光标（物理像素）→ 归一化场景坐标（`[-1, 1]`），供"光标跟随"用。
  void _onCursor(Offset physical) {
    final bounds = OverlayController.sceneBounds.value;
    if (bounds.isEmpty) return;
    final scene = (physical - _geometry.origin) / currentDevicePixelRatio;
    final nx =
        ((scene.dx - bounds.width / 2) / (bounds.width / 2)).clamp(-1.0, 1.0);
    final ny =
        -((scene.dy - bounds.height / 2) / (bounds.height / 2)).clamp(-1.0, 1.0);
    OverlayController.cursorNorm.value = Offset(nx, ny);
  }

  /// 重取场景几何，并重推抓取矩形（几何变了，此前声明的矩形已失效）。
  Future<void> _refreshScene() async {
    if (!await _geometry.refresh()) return;
    if (!mounted) return;
    await _grabRects.publish(_pets);
  }

  /// 监听设置窗口写存储。
  Future<void> _listenToSettingsWindow() => listenToSettingsWindow(() {
        if (!mounted) return;
        // 广播一次变更：appDataProvider 自失效（场景重建：新增/删除/显隐/锁定/顺序），
        // 宿主重挂全局快捷键绑定（快捷键与快捷启动项都配在设置窗口里），
        // 各桌宠按新设置刷新缩放/不透明度。
        StorageService.notifySettingsChanged();
      });

  // ── 构建 ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final locale = data.global.locale;
    // 场景空间 = 桌面空间（见 home: 处的说明）。
    final scene = OverlayController.sceneBounds.value;

    final children = <Widget>[];
    final bubbles = <Widget>[];
    final pets = <PetHit>[];

    for (final pet in data.pets) {
      if (!pet.isVisible) continue;
      final petState = ref.watch(petStateProvider(pet.id));
      // 宠物包未就绪时还没有可渲染的尺寸，先不登记（否则会声明一块空的抓取区）。
      if (petState.finalPetSize.isEmpty) continue;
      final rect = petState.position & petState.finalPetSize;
      pets.add((
        id: pet.id,
        rect: rect,
        locked: pet.isLocked,
        // v1：整矩形命中。Live2D 的逐格命中留待后续填入（预留 payload）。
        shape: const HitShape.rect(),
      ));
      children.add(PetView(key: ValueKey(pet.id), petId: pet.id));
      bubbles.add(ChatBubbleLayer(
        key: ValueKey('bubble-${pet.id}'),
        petId: pet.id,
        petRect: rect,
      ));
    }

    // 气泡画在所有桌宠之上、环形菜单之下。
    children.addAll(bubbles);

    // 环形菜单画在所有桌宠之上（与改造前 ring 窗口始终浮在桌宠窗口之上一致）。
    //
    // 每个子节点都必须有稳定 key：这个列表的成员会随"新增/删除桌宠"而增删，
    // Flutter 靠 runtimeType + key 匹配新旧子节点。没有 key 就按位置错配——删掉一只
    // 桌宠会让另一只的 Element 被顶替复用（连带 PetWidget 的动画串到别的桌宠身上），
    // 环形菜单的元素也会被牵着失活并重建，从而抛出
    // "Looking up a deactivated widget's ancestor is unsafe"。
    children.add(const RingOverlay(key: ValueKey('ringOverlay')));

    _syncPets(pets);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.overlay(),
      locale: settingsLocale(locale),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      // 场景内容必须画在客户区的**底部那一条 (宽 × 高)**里。
      //
      // 窗口客户区是**正方形**（边长 = 桌面宽），位置让它的下半 1080 行正好对齐屏幕
      // —— 之所以这样做，是因为这个平台上引擎的渲染表面总是正方形（高 = 窗口宽），
      // Windows 再把它拉伸进客户区；非正方形客户区会被纵向压成 `高/宽`（逐像素实测
      // 1920×1080→0.5625、1000×800→0.8、800×600→0.75，全部精确等于 高/宽），
      // 且贴底。原来的桌宠窗口是 200×200 正方形，所以从没暴露过。
      //
      // 客户区做成正方形后拉伸变成恒等变换，而 Align 把场景放进底部那一条：
      // 于是场景的坐标空间仍然**等于屏幕空间**，桌宠坐标 / 命中矩形 / 输入换算
      // 都不需要任何偏移。
      home: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: scene.width,
            height: scene.height,
            child: Stack(children: children),
          ),
        ),
      ),
    );
  }

  /// 记录本帧的桌宠清单（供指针命中、环形菜单选目标、以及向钩子声明抓取矩形），
  /// 变化时立刻重推。
  void _syncPets(List<PetHit> pets) {
    if (_sameHits(pets, _pets)) return;
    _pets = pets;
    OverlayController.pets.value = pets;
    // build 期间不能直接触发副作用，放到帧后。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_grabRects.publish(_pets));
    });
  }

  static bool _sameHits(List<PetHit> a, List<PetHit> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].rect != b[i].rect ||
          a[i].locked != b[i].locked ||
          a[i].shape != b[i].shape) {
        return false;
      }
    }
    return true;
  }
}
