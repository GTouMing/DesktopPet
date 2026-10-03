<h1>桌宠&nbsp;|&nbsp;<a href="README_EN.md">Desktop Pet</a></h1>

用 Flutter 打造的一款桌面宠物应用，支持 **Windows** 与 **Android** 双平台。

在 Windows 上，它由一个铺满桌面的透明悬浮窗统一承载全部桌宠、环形快捷盘与托盘，设置界面按需在独立子窗口打开；在 Android 上，每只桌宠是一个独立的系统悬浮窗，可悬浮于任何应用之上。每一只桌宠都由一份 **JSON 皮肤定义**驱动——动画、行为、交互触发器全部可配置，你还可以导入自己的 `.zip` 皮肤包。

![platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android-blue)

## 功能特性

- **多桌宠并行**：可同时创建多只桌宠，各自独立拥有位置、缩放与行为，且互不干扰。Windows 下它们同处一个悬浮窗场景，Android 下各自一个系统悬浮窗。
- **任意位置漫游**：桌宠并非固定在某个角落，它会自己随机走动、散步，还会响应你的点击、拖拽与抚摸。
- **智能行为状态机**：由 `skin.json` 声明状态与迁移规则（点击、拖拽、定时、方向、到达、播完、全局热键等触发器），配合可编程的变换表达式（缩放/旋转/位移/透明度，支持 `sin/cos/lerp/clamp`），实现活灵活现的动画。
- **桌面不被打扰**：悬浮窗无边框、透明、常驻整窗**点击穿透**（系统在命中测试阶段直接跳过它），所以桌宠永远不会挡住桌面上的其它操作。单只桌宠可锁定 / 解锁：锁定的桌宠既不响应鼠标，也不参与命中。
- **全局热键**：皮肤 JSON 里为某个状态声明的 `hotkey` 规则会注册成系统级快捷键（如 `Ctrl+Alt+S` 入睡、`Ctrl+Alt+K` 走向屏幕边缘）。按键"在哪个状态下生效"完全由皮肤数据决定：按下时按「当前状态 + 组合键」查表跳转。
- **音效**：在状态里声明 `audio` / `audioVolume`，进入该状态即自动播放（`assets/...` 走内置资源，绝对路径走本地文件）。内置皮肤暂未附带音频资源，填入即生效。
- **快捷启动（Windows）**：长按鼠标中键呼出扇环快捷盘（最多 8 个应用），松手即启动目标应用。
- **系统托盘（Windows）**：锁定 / 解锁全部桌宠、打开设置、退出。
- **皮肤系统**：
  - 内置默认皮肤（发呆 / 走路 / 睡觉 / 开心 / 进食 / 拖拽等动画）。
  - 支持从 **ZIP 皮肤包** 一键导入，自动解压、校验并注册。
  - 支持指定**自定义皮肤目录**，自动扫描其中的皮肤包，并支持一键迁移已导入的皮肤。
- **设置中心**：全局缩放 / 透明度 / 播放速度（与单只桌宠的乘数叠加生效），即时生效并同步到所有桌宠。
- **数据持久化**：基于 MMKV 多进程存储，配置修改实时写回并广播给所有桌宠窗口。

## 平台支持

| 平台    | 形态                                   | 说明                                                                   |
|---------|----------------------------------------|------------------------------------------------------------------------|
| Windows | 全屏透明悬浮窗 + 设置子窗口 + 系统托盘 | 单引擎：所有桌宠与环形快捷盘都画在同一个悬浮窗里，设置按需在子窗口打开 |
| Android | 系统悬浮窗（每只桌宠一个）             | 需要「显示在其他应用上层」权限；支持多个悬浮窗                         |

> 其他平台（Linux / macOS / iOS）启动时会抛出 `UnsupportedError`，目前不在支持范围内。

## 快速开始

### 环境要求

- Flutter SDK `^3.12.2`（Dart `^3.12.2`）
- Windows：Windows 10 / 11（需要桌面窗口支持）
- Android：Android 7.0+（API 24+，悬浮窗依赖系统授权）

### 运行

```bash
flutter pub get
flutter run -d windows   # Windows 桌面
flutter run -d <device>  # Android 真机 / 模拟器
```

首次启动会在应用文档目录建立默认数据，并自动创建一只名为「默认桌宠」的宠物。

### 构建发布

```bash
# Windows
flutter build windows

# Android
flutter build apk
```

## 目录结构

```
lib/
├── main.dart                     # main()：平台分派、单实例锁、各窗口角色的装配
├── app.dart                      # MaterialApp 入口（主界面 / 桌宠悬浮窗共用）
├── core/                         # 叶子层：常量、枚举、设备像素比、场景共享状态、跨引擎消息
├── input/                        # 全局输入抽象：InputService / KeyRegistry / 平台输入源
├── pet/                          # 桌宠运行时：状态机、行为引擎、动画、热键、指针路由
│   ├── pet_notifier.dart         #   状态管理器（Riverpod StateNotifier）
│   ├── pet_state.dart            #   桌宠运行状态快照
│   ├── pet_providers.dart        #   petId / petState Provider
│   ├── pet_metrics.dart          #   渲染值派生（全局 × 单宠，纯函数）
│   ├── pet_window_binding.dart   #   仅 Android 的系统悬浮窗同步
│   ├── behavior_engine.dart      #   目标生成与移动插值、方向/到达事件
│   ├── pet_pointer_router.dart   #   全局钩子指针事件 → 逐宠命中与拖拽
│   ├── hotkey_engine.dart        #   皮肤 hotkey 规则 → 全局输入层
│   ├── pet_animation.dart        #   单组动画的加载与播放控制（循环/重复）
│   ├── pet_widget.dart           #   渲染组件（精灵图 + 变换 + 透明度）
│   └── pet_context.dart          #   提供给行为引擎的上下文接口
├── skin/                         # 皮肤系统
│   ├── skin_package.dart         #   皮肤包模型（animations / states / skin.json）
│   ├── expression.dart           #   轻量表达式求值器（sin/cos/lerp/clamp…）
│   ├── audio/                    #   状态音效服务（进入状态即播放；内置皮肤暂未附带音频）
│   ├── sheet/                    #   帧 PNG → 精灵图集（运行时拼合）+ 渲染器
│   ├── import/                   #   ZIP 导入、校验、仓库、目录迁移
│   └── state/  animation/        #   状态定义 / 动画定义的 JSON 模型
├── platform/                     # 平台抽象与实现
│   ├── window_interface.dart     #   WindowController 抽象接口（仅 Android 有实现）
│   ├── windows/                  #   Windows：宿主装配、悬浮窗/设置窗口通道、托盘
│   └── android/                  #   Android：多悬浮窗（内置插件）、设置变更广播
├── shortcut/                     # 快捷启动：环形面板几何与绘制、宿主手势状态机、图标提取
├── storage/                      # MMKV 持久化 + 数据模型（设置 / 桌宠 / 皮肤 / 快捷启动）
└── ui/
    ├── common/                   #   主界面、桌宠编辑、皮肤选择、语言、对话框
    │   └── settings/             #   设置页拆成各分区（外观 / 皮肤 / 快捷启动 / 语言 / 关于）
    ├── host/                     #   两个窗口的根组件及其支撑件
    │   ├── overlay_scene.dart    #     悬浮窗场景（全部桌宠 + 环形菜单）
    │   ├── settings_window_root.dart #  设置窗口根组件
    │   ├── scene_geometry.dart   #     场景几何（= 桌面几何）与物理/逻辑换算
    │   ├── grab_rects.dart       #     把桌宠矩形声明给全局钩子
    │   └── settings_window_channel.dart # 监听设置窗口的"存储已改"
    ├── android/                  #   单只桌宠悬浮窗的内容
    └── widgets/                  #   通用组件（窗口框、桌宠列表/卡片、信息浮层）
```

## 皮肤包（Skin）

皮肤是一份包含 `skin.json` 与动画序列帧的目录，`frameWidth/frameHeight` 定义单帧画布。

- **内置皮肤**位于 `assets/default_skin/`。
- **导入的皮肤**默认解压到 `<应用文档目录>/imported_skins/<petId>/`；若设置了自定义皮肤目录，则解压到 `<皮肤目录>/<petId>/`。
- **自定义目录**：可在设置中选择一个文件夹作为皮肤目录，应用会扫描其中所有包含 `skin.json` 的子目录。

### 皮肤 JSON 结构

| 字段                         | 说明                                                                                                       |
|------------------------------|------------------------------------------------------------------------------------------------------------|
| `name` / `version`           | 皮肤名与版本号                                                                                             |
| `frameWidth` / `frameHeight` | 单帧画布宽高（逻辑像素）                                                                                   |
| `initialState`               | 初始状态名（默认 `idle`）                                                                                  |
| `animations`                 | 动画定义：`{ folder, fps, frameCount, framePrefix?, frameStart? }`，每帧为 `folder/0.png`、`folder/1.png`… |
| `states`                     | 状态定义：引用动画 + 行为 + 变换表达式 + 迁移规则                                                          |

状态定义示例：

```json
{
  "idle": {
    "animation": "idle",
    "transitions": {
      "walk":  { "limitTimer": { "minMs": 15000, "maxMs": 15000 } },
      "sleep": { "waitTimer": { "afterMs": 120000 },
                 "hotkey":   { "key": "s", "modifiers": ["ctrl", "alt"] } },
      "happy": { "click": {} },
      "drag":  { "drag": {} }
    }
  },
  "walk": {
    "animation": "walk",
    "behavior": "moveToTarget",
    "scaleY": "1 - 0.05*(1 - cos(2*PI*t))",
    "transitions": {
      "idle":  { "arrived": {} },
      "happy": { "click": {} }
    }
  }
}
```

#### 触发器（trigger）

| 触发器                                     | 触发时机                                      |
|--------------------------------------------|-----------------------------------------------|
| `click`                                    | 单击桌宠                                      |
| `drag`                                     | 开始拖拽                                      |
| `arrived`                                  | 移动到达目标点                                |
| `moveUp / moveDown / moveLeft / moveRight` | 移动方向事件                                  |
| `limitTimer`                               | 随机定时（`minMs`~`maxMs`），用于定期更换行为 |
| `waitTimer`                                | 固定延时（`afterMs`）后触发                   |
| `hotkey`                                   | 全局快捷键（`key` + `modifiers`）             |
| `complete`                                 | 单次（非循环）动画播放完毕                    |

#### 行为（behavior）

| 行为           | 说明                                                          |
|----------------|---------------------------------------------------------------|
| `moveToTarget` | 移动到目标点（可用 `targetPos` 指定固定坐标，缺省为随机坐标） |
| `moveToEdge`   | 移动到屏幕边缘                                                |
| （无）         | 原地待机                                                      |

#### 变换表达式

每个状态都可用表达式描述随时间 `t`（0→1，每循环重置）变化的变换：

- `scaleX` / `scaleY`：缩放，可做弹跳等效果
- `rotation`：旋转（弧度）
- `offsetX` / `offsetY`：位移
- `opacity`：不透明度
- `mirrorH`：水平镜像（向左移动时自动翻转）

表达式支持 `+ - * / ^ ( )`、数字、常量 `PI`、变量 `t`，以及函数 `sin cos abs clamp lerp`。

## 交互与使用

**桌面上的宠物**
- 单击 → 触发交互（如从发呆变为开心）。
- 拖拽 → 拖起宠物到任意位置松手，它会被限制在屏幕内。
- 锁定 / 点击穿透 → 通过托盘锁定 / 解锁，锁定时宠物不再响应鼠标（可作纯装饰悬浮物）。

**管理桌宠**
- 主窗口列出所有桌宠，可：
  - 新建桌宠（命名、选择皮肤、调节缩放/透明度/速度）
  - 编辑 / 删除已有桌宠
- 全局设置可调节所有桌宠的基础缩放、透明度与动画速度（单宠乘数叠加生效）。

**快捷启动（Windows）**
- 长按 **鼠标中键**（约 1 秒）呼出环绕宠物的扇环快捷盘。
- 按住中键将鼠标移向目标按钮，松手即可启动对应应用。
- 在「设置 → 快捷启动应用」中添加 / 编辑 / 排序 / 删除应用项，最多 8 个。

**系统托盘（Windows）**
- 锁定 / 解锁全部桌宠、显示主界面（设置）、退出应用。

## 技术要点

- **单悬浮窗架构（Windows）**：全部桌宠与环形快捷盘画在同一个铺满桌面的透明悬浮窗里，设置界面按需在 `desktop_multi_window` 子引擎中打开。桌面不被挡住靠的是该窗口常驻 `WS_EX_LAYERED | WS_EX_TRANSPARENT`——系统在命中测试阶段直接跳过它，即使 Flutter 侧卡死也挡不住任何点击。
- **全局输入钩子**：悬浮窗收不到鼠标消息，所以桌宠的点击/拖拽与全局快捷键都走进程级 `WH_MOUSE_LL` / `WH_KEYBOARD_LL` 钩子。Dart 把每只未锁定桌宠的矩形声明给钩子作为"可抓取区"，钩子只在其中转发指针事件，并**吞掉**这一次点击，避免它继续作用到桌面下面的窗口。
- **单实例锁**：Windows 启动时使用互斥量（`flutter_alone`）确保只有一个悬浮窗实例，重复启动会聚焦已有实例。
- **跨进程存储**：MMKV 以 `MULTI_PROCESS_MODE` 打开，所有引擎共享同一份配置；写入后触发回调广播刷新。
- **运行时精灵图集**：把每帧 PNG 拼成一张 GPU 友好的图集（限制单边 ≤ 4096，自动计算最优网格），由 `CustomPaint` 按帧绘制，降低纹理切换开销。图集按（皮肤, 动画）**缓存到磁盘**：同一皮肤在多个桌宠引擎、以及后续每次启动之间，都只需逐帧解码 + 拼接一次。
- **锁定与拖拽**：Windows 的"锁定"= 不把该桌宠的矩形声明给钩子，于是点它等于点桌面；拖拽则完全在 Dart 侧改场景坐标（原始点击已被钩子吞掉）。Android 每只桌宠是一个真正的系统悬浮窗，"锁定"通过 `FLAG_NOT_TOUCHABLE` 整窗穿透，拖拽交给系统移动窗口（`startDragging`）。
- **表达式求值**：自带轻量递归下降解析器，皮肤变换可直接书写数学公式，无需改代码即可做出弹跳、摇摆、呼吸等效果。
- **状态归属**：三类状态各有唯一真源，刻意分开，不要混用——
  1. **持久化数据**（设置 / 桌宠 / 皮肤 / 快捷启动）：真源是 `StorageService`，**写即广播**（`changes` 流）。UI 只读 `appDataProvider`（普通 `Provider`，由该流驱动自动重算），因此**不需要也不应该**到处手动 `ref.invalidate`。跨引擎写入也只传"存储变了"这一件事：Windows 走 dmw 消息、Android 走原生 `settings_updated`，另一侧收到后统一只做 `notifySettingsChanged()`，后续刷新与同引擎内完全一致。
  2. **场景瞬时状态**（场景尺寸、各桌宠矩形、目标桌宠冻结、环形菜单呈现）：进程内共享、不持久化，写入方固定（`OverlayScene` / `QuickLaunchInputHost`），其它层只读。
  3. **进程级服务**（`InputService` / `ShortcutLauncher` / 托盘 / 设置窗口宿主）：必须在 `runApp` 之前或跨窗口角色存在，保持单例，但只从装配点（`main` / `AppHost`）驱动。

## 路线图

- [x] 全局热键接入（皮肤 `hotkey` 规则已接到全局输入层）
- [x] 皮肤音效接通（进入状态即播放该状态的 `audio`，`audioVolume` 控制响度；内置皮肤暂未附带音频资源）
- [ ] 皮肤「投喂 / 对话 / 天气」等更多事件与行为
- [ ] 桌宠间互动（靠近、追逐、结伴）
- [ ] 更多平台支持

## 开源许可

本项目基于 [MIT](LICENSE) 许可开源。
