<h1>桌宠&nbsp;|&nbsp;<a href="README_EN.md">Desktop Pet</a></h1>

用 Flutter 打造的一款桌面宠物应用，支持 **Windows** 与 **Android** 双平台。

在 Windows 上，它由一个铺满桌面的透明悬浮窗统一承载全部桌宠、环形快捷盘与托盘，设置界面按需在独立子窗口打开；在 Android 上，每只桌宠是一个独立的系统悬浮窗，可悬浮于任何应用之上。每一只桌宠都由一份 **宠物包（Pet Pack）** 驱动——一份 JSON 清单（`pet.json`）声明动画/状态/交互触发器，资源可以是**精灵图逐帧**（sprite）或 **Live2D Cubism 模型**（live2d），你还可以导入自己的 `.zip` 宠物包。

![platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android-blue)

## 功能特性

- **多桌宠并行**：可同时创建多只桌宠，各自独立拥有位置、缩放与行为，且互不干扰。Windows 下它们同处一个悬浮窗场景，Android 下各自一个系统悬浮窗。
- **任意位置漫游**：桌宠并非固定在某个角落，它会自己随机走动、散步，还会响应你的点击、拖拽与抚摸。
- **智能行为状态机**：由宠物包清单声明状态与迁移规则（点击、拖拽、定时、方向、到达、播完、全局热键等触发器），配合可编程的变换表达式（缩放/旋转/位移/透明度，支持 `sin/cos/lerp/clamp`），实现活灵活现的动画。
- **两种渲染后端**：精灵图逐帧包与 **Live2D Cubism 模型包**并存，可在同一份状态机下混装。
- **桌面不被打扰**：悬浮窗无边框、透明、常驻整窗**点击穿透**（系统在命中测试阶段直接跳过它），所以桌宠永远不会挡住桌面上的其它操作。单只桌宠可锁定 / 解锁：锁定的桌宠既不响应鼠标，也不参与命中。
- **全局热键**：宠物包 JSON 里为某个状态声明的 `hotkey` 规则会注册成系统级快捷键（如 `Ctrl+Alt+S` 入睡、`Ctrl+Alt+K` 走向屏幕边缘）。按键"在哪个状态下生效"完全由宠物包数据决定：按下时按「当前状态 + 组合键」查表跳转。
- **音效**：在状态里声明 `audio` / `audioVolume`，进入该状态即自动播放（`assets/...` 走内置资源，绝对路径走本地文件）。内置宠物包暂未附带音频资源，填入即生效。
- **快捷启动（Windows）**：长按鼠标中键呼出扇环快捷盘（最多 8 个应用），松手即启动目标应用。
- **系统托盘（Windows）**：锁定 / 解锁全部桌宠、打开设置、退出。
- **宠物包系统**：
  - 内置默认宠物包（精灵图：发呆 / 走路 / 睡觉 / 开心 / 进食 / 拖拽等动画）。
  - 支持从 **ZIP 宠物包** 一键导入：自动解压、按类型校验并注册；导入时自动判别**精灵图 / Live2D**。
  - 支持指定**自定义宠物包目录**，自动扫描其中的宠物包，并支持一键迁移已导入的宠物包。
- **设置中心**：全局缩放 / 透明度（与单只桌宠的乘数叠加生效），即时生效并同步到所有桌宠。
- **数据持久化**：基于 MMKV 多进程存储，配置修改实时写回并广播给所有桌宠窗口。

## 平台支持

| 平台    | 形态                                   | 说明                                                                   |
|---------|----------------------------------------|------------------------------------------------------------------------|
| Windows | 全屏透明悬浮窗 + 设置子窗口 + 系统托盘 | 单引擎：所有桌宠与环形快捷盘都画在同一个悬浮窗里，设置按需在子窗口打开 |
| Android | 系统悬浮窗（每只桌宠一个）             | 需要「显示在其他应用上层」权限；支持多个悬浮窗                         |

> 其他平台（Linux / macOS / iOS）启动时会抛出 `UnsupportedError`，目前不在支持范围内。

### Live2D 支持

- **平台**：Windows 已实现（自研渲染器走 D3D11 GPU-surface 纹理进入 Flutter 场景）；Android 为后续阶段。
- **模型要求**：一个目录 + 其中的 `.model3.json`；**`.model3.json` 必须在包根目录**，它引用的 `.moc3`（支持版本 3.0–5.3）/ 贴图 / 动作按相对路径同目录即可。
- **状态机共用**：`StateDef.animation` 对 Live2D 被当作**动作组名**（`startMotion`），状态/迁移/表达式与精灵图完全一致。
- **命中**：v1 沿用**整矩形**（包围盒）；逐像素命中的可扩展 payload 已预留（见「技术要点」）。
- **许可**：模型与 Cubism 运行时归 Live2D Inc. 所有，见「开源许可」。

## 快速开始

### 环境要求

- Flutter SDK `^3.12.2`（Dart `^3.12.2`）
- Windows：Windows 10 / 11（需要桌面窗口支持；Live2D 需要支持 D3D11 的显卡）
- Android：Android 7.0+（**API 24+**，悬浮窗依赖系统授权）

### 运行

```bash
flutter pub get
flutter run -d windows   # Windows 桌面
flutter run -d <device>  # Android 真机 / 模拟器
```

首次启动会在应用文档目录建立默认数据，并自动创建一只名为「默认桌宠」的宠物。

> ⚠️ 克隆后需先跑一次脚本获取 Live2D SDK（不入库），见下面「构建说明」。

### 构建说明

- **Live2D SDK（必读）**：Cubism 运行时由 `plugins/pet_live2d/` 自研渲染器使用，**SDK 本身不入库**，克隆后跑一次：
  `powershell -ExecutionPolicy Bypass -File tool/fetch_live2d_sdk.ps1`
  它按 `third_party/live2d.sdk.json` 固化的版本 + sha256 拉取并解出所需子集到 `third_party/live2d/`（已 gitignore）。
  官方 SDK zip 位于许可确认页之后、无法稳定直链，脚本支持 `-SdkZip <path>` 指向人工下载的官方包。
  CMake 在缺少该子集时会以可读信息报错并提示跑哪个脚本。
- **打包分发**：`powershell -ExecutionPolicy Bypass -File tool/package_windows.ps1`
  会构建 Release → 前置校验（缺 `app.so` / `pet_live2d_plugin.dll` / `FrameworkShaders`、`generated_plugins.cmake`
  里列出的插件 DLL 少了一个、或 Release 目录里混进 Debug 版引擎，都会直接报错退出——分别对应"启动即退出 /
  无 Live2D / `Not running in AOT mode`"）→ 清掉已移除插件的陈旧 DLL、运行时产物（`*.log`、`l2d_dump_*.bmp`）
  与空目录 → 补进 app-local VC 运行时和 `LICENSE`/`NOTICES`/Live2D 许可 → 产出
  `dist/DesktopPet-<版本>-windows-x64.zip`（打印 sha256）；本机装了 Inno Setup 还会顺带出 `setup.exe`。
  加 `-SkipBuild` 可复用现有构建，加 `-Clean` 先 `flutter clean` 再构建（**出正式分发包建议用 `-Clean`**：
  Flutter 不会清理已移除插件留下的 DLL/资源目录，长期存在的 build 目录会把陈旧文件带进包里；脚本会尽量剔除，
  但干净构建是唯一彻底的解法）。
- **分发包的运行库与许可**：exe 与各插件都以 `/MD` 链接，目标机若没有 **VC++ 2015–2022 x64 Redistributable**
  会缺 `VCRUNTIME140.dll`/`MSVCP140.dll` 而启动失败（Cubism Core 只提供 MD/MDd 静态库，改 `/MT` 规避不了）。
  打包脚本会把 VC 运行时 DLL **app-local 一并打进包**（找不到时打印警告）；包内同时附带 `LICENSE`、`NOTICES`
  与 Live2D 的 `Live2D-Cubism-Core-LICENSE.md`——Cubism Core 是**静态链进 `pet_live2d_plugin.dll`** 的，
  发布编译产物需随附其许可文本并遵守 Live2D 的条款。
- **不再有 `live2d_flutter`**：旧的第三方插件（含其 `dependency_overrides` 的仓库外 vendored 副本）已彻底移除；
  我们为它打过的补丁与它架构上的坑，沉淀为 `doc/live2d-renderer-notes.md` 与 `plugins/pet_live2d/`。
- **Android `minSdk`**：显式 pin 为 `24`，为后续 Android 端 Live2D（Cubism 运行时要求）预留；不取 `flutter.minSdkVersion`。
- **Windows 工具链**：原生代码在 `cxx_std_17 + /W4 /WX + _HAS_EXCEPTIONS=0` 下编译链接通过，共享的 `apply_standard_settings` 无需放宽。
- **debug 构建提示**：渲染器**从不请求** `D3D11_CREATE_DEVICE_DEBUG`——在未安装 D3D11 调试层的机器上该请求会失败并回退到 WARP，而 WARP 的共享纹理无法被引擎的硬件设备绑定（表现为"不渲染"）。这是一条踩过的坑，见 `doc/live2d-renderer-notes.md`。

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
├── core/                        # 叶子层：常量、枚举、DPR、命中形状、场景共享状态、跨引擎通道
├── input/                       # 全局输入抽象：InputService / KeyRegistry / 平台输入源 / 命中区域(shape)
├── pet/                         # 桌宠运行时：状态机、行为引擎、渲染边界、热键、指针路由
│   ├── pet_notifier.dart        #   状态管理器（Riverpod StateNotifier）
│   ├── pet_state.dart           #   桌宠运行状态快照
│   ├── pet_providers.dart       #   petId / petState Provider
│   ├── pet_metrics.dart         #   渲染值派生（全局 × 单宠，纯函数）
│   ├── pet_window_binding.dart  #   仅 Android 的系统悬浮窗同步
│   ├── behavior_engine.dart     #   目标生成与移动插值、方向/到达事件
│   ├── pet_pointer_router.dart  #   全局钩子指针事件 → 逐宠命中与拖拽
│   ├── hotkey_engine.dart       #   宠物包 hotkey 规则 → 全局输入层
│   ├── pet_visual.dart          #   渲染边界抽象（PetVisual）
│   ├── sprite_pet_visual.dart   #   精灵图实现（动画 + 图集 + 变换）
│   ├── live2d_pet_visual.dart   #   Live2D 实现（Texture + 动作组驱动；尺寸变化预热切换）
│   ├── live2d/                  #   Live2D 通道封装（原生运行时 ↔ Dart）
│   ├── pet_widget.dart          #   只做两件事：把 PetState 画出来 + 按类型选 PetVisual
│   └── pet_context.dart         #   提供给行为引擎的上下文接口
├── petpack/                     # 宠物包系统（renderer 无关）
│   ├── pet_pack.dart            #   抽象基类 + 清单读取 + 类型判别（PetPackDetector）
│   ├── sprite_pet_pack.dart     #   精灵图包（animations / 帧图片）
│   ├── live2d_pet_pack.dart     #   Live2D 包（model3.json / 动作组）
│   ├── pet_pack_lister.dart     #   可用宠物包发现（含类型标记）
│   ├── expression.dart          #   轻量表达式求值器（sin/cos/lerp/clamp…）
│   ├── audio/                   #   状态音效服务（进入状态即播放）
│   ├── sheet/                   #   帧 PNG → 精灵图集（运行时拼合）+ 渲染器
│   ├── import/                  #   ZIP 导入、按类型校验、仓库、目录迁移
│   └── state/  animation/       #   状态定义 / 动画定义的 JSON 模型
├── platform/                    # 平台抽象与实现
│   ├── window_interface.dart    #   WindowController 抽象接口（仅 Android 有实现）
│   ├── windows/                 #   Windows：宿主装配、悬浮窗/设置窗口通道、托盘
│   └── android/                 #   Android：多悬浮窗（内置插件）、设置变更广播
├── shortcut/                    # 快捷启动：环形面板几何与绘制、宿主手势状态机、图标提取
├── storage/                     # MMKV 持久化 + 数据模型（设置 / 桌宠 / 宠物包 / 快捷启动）
└── ui/
    ├── common/                  #   主界面、桌宠编辑、宠物包选择、语言、对话框
    │   └── settings/            #   设置页拆成各分区（外观 / 宠物包 / 快捷启动 / 语言 / 关于）
    ├── host/                    #   两个窗口的根组件及其支撑件
    │   ├── overlay_scene.dart   #     悬浮窗场景（全部桌宠 + 环形菜单）
    │   ├── settings_window_root.dart #  设置窗口根组件
    │   ├── scene_geometry.dart  #     场景几何（= 桌面几何）与物理/逻辑换算
    │   ├── grab_rects.dart      #     把桌宠命中区域声明给全局钩子
    │   └── settings_window_channel.dart # 监听设置窗口的"存储已改"
    ├── android/                 #   单只桌宠悬浮窗的内容
    └── widgets/                 #   通用组件（窗口框、桌宠列表/卡片、信息浮层）
```

## 宠物包（Pet Pack）

一个宠物包是一个目录，包含一份清单 **`pet.json`** 与资源。

- **内置宠物包**位于 `assets/default_pet_pack/`。
- **导入的宠物包**默认解压到 `<应用文档目录>/imported_pet_packs/<petId>/`；若设置了自定义宠物包目录，则解压到 `<宠物包目录>/<petId>/`。
- **自定义目录**：可在设置中选择一个文件夹作为宠物包目录，应用会扫描其中所有包含清单（`pet.json`）的子目录。
- **类型判别**：清单里的 `type` 优先（`"sprite"` / `"live2d"`）；缺省时按内容探测——目录内存在 `*.model3.json` 即视为 Live2D，否则按精灵图处理。

### 清单字段（`pet.json`）

| 字段                         | 说明                                                                                                          |
|------------------------------|---------------------------------------------------------------------------------------------------------------|
| `name` / `version`           | 名称与版本号                                                                                                  |
| `type`                       | `"sprite"`（精灵图，默认）或 `"live2d"`；缺省按内容探测                                                       |
| `frameWidth` / `frameHeight` | 渲染基准尺寸（逻辑像素）：精灵图 = 单帧画布；Live2D = 逻辑画布                                                |
| `initialState`               | 初始状态名（默认 `idle`）                                                                                     |
| `animations`                 | （精灵图）动画定义：`{ folder, fps, frameCount, framePrefix?, frameStart? }`，每帧为 `folder/0.png`、`folder/1.png`… |
| `model`                      | （Live2D）`.model3.json` 文件名；缺省时自动取包根目录下第一个 `*.model3.json`                                 |
| `scale`                      | （Live2D）自动适配之上**再乘**的缩放（默认 `1`，需 `> 0` 且 `<= 10`）：作者用它一次把构图定死，比让适配器猜稳 |
| `translate`                  | （Live2D）模型中心相对盒子中心的偏移 `{ "x": 0, "y": 0 }`，单位**逻辑像素**，`+x` 向右、`+y` 向下 |
| `breath`                     | （Live2D）待机呼吸幅度（默认 `1`）：引擎固定喂 Cubism 标准呼吸，这里只能**调低**（`0` = 不呼吸）。摆动量本应由模型物理决定，作者用这个开关适配自己的模型 |
| `states`                     | 状态定义：引用动画/动作组 + 行为 + 变换表达式 + 迁移规则                                                     |
| `hotkeys`                    | 包级快捷键 → 动作（**不经状态机**，见下节）：`{ "<id>": { key, modifiers?, animation?, motionIndex?, motionPriority?, expression?, durationMs? } }` |
| `keyParams`                  | "打字反应"（仅 Live2D）：`{ "<键名>": "<模型参数 id>" }`，按住键把参数置 1、松开置 0 |
| `mouseParams`                | 鼠标反馈（仅 Live2D）：`{ x?, y?, xy?, left?, right?, smooth? }`，每个轴是一组 `{param, scale}` 映射，可一次驱动多个参数 |
| `params`                     | 可调槽位组（仅 Live2D）：`{ "<槽位>": { label?, type?, default?, params? \| options? } }`，在编辑宠物时可调；见「可调参数」 |

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

### 包级快捷键（`hotkeys`）

顶层 `hotkeys` 把按键**直接**映射到动作/表情，**不经过状态机**——它与状态里的 `hotkey`
迁移不同，后者会切换当前状态；前者只是"按下这个键，播这个动作/表情"。适合 Live2D 这类
一个模型带一堆动作、想挨个按键点播的场景（显示/隐藏配件、切换表情…）。

```json
"hotkeys": {
  "ear": { "key": "1", "modifiers": ["ctrl", "alt"],
           "animation": "CAT_motion_lock", "motionIndex": 1, "motionPriority": 3 },
  "cry": { "key": "2", "modifiers": ["ctrl", "alt"], "expression": 3 }
}
```

- `key`（必填）+ `modifiers?`：物理键名与修饰键，写法与状态里的 `hotkey` 规则一致。
- `animation?`：动作组名（Live2D）/ 动画名（精灵图）；纯表情动作可省略。
- `motionIndex?` / `motionPriority?`：组内索引与优先级（`0` none / `1` idle / `2` normal /
  `3` force，默认 `3`）。
- `expression?`：仅 Live2D，切换表情索引。
- `durationMs?`：该动作的时长（毫秒，取 motion 的 `Meta.Duration`）。给了就**串行化**：
  一次动作播放期间，后续动作**排队**（后来的覆盖先前的），播完才播下一个——Bongo 就是
  "当前动画播完才允许下一个"。`0`/缺省 = 立即抢占。
- `requires?`：**参数前提**——`{ "<槽位id>": "<label>" | ["<label>", ...] }`。当前每个列出槽位的
  选项（按 label 比较）都命中才允许播放；bool 槽位用 `on` / `off` 两个 label。缺省 = 无前提。
- `sets?`：**改动参数**——`{ "<槽位id>": "<label>" }`。动作播放时把这些槽位切到指定选项
  （写回该桌宠保存的选择）。

命中优先级：**状态迁移优先**——当前状态声明了该组合键的 `hotkey` 迁移时走状态机，否则
触发包级动作。全局快捷键仅 Windows 可用；按键**不吞事件**（其它应用照常收到）。

> 包级动作目前只由 Live2D 渲染器实现，精灵图渲染器忽略。

### 可调参数（`params`，槽位）

顶层 `params` 声明**互斥的槽位组**（仅 Live2D）。每组是编辑宠物时的一个控件：**组内**只能选一个
选项、**组间**可同时生效；选项直接写模型参数：

```json
"params": {
  "glasses": {
    "label": "眼镜", "default": "无",
    "options": [
      { "label": "无" },
      { "label": "圆眼镜", "params": { "ParamCheek70": 1 } }
    ]
  },
  "whale": { "label": "头顶鲸", "type": "bool", "default": false, "params": { "jingyu": 1 } }
}
```

- `type: "bool"` → 一个开关，开启时写入该组的 `params`。
- 否则是 `options` 下拉；`default` 写选项 label（或下标）。
- 切选项会把上一个选项的参数复位，槽位之间不打架——它取代了 Cubism 排他式表情管理器
  （配件与情绪表情本该能叠加）。
- 选择按桌宠保存；包级动作可用 `requires` / `sets` 读取并改动槽位。

### 打字反应（`keyParams`）

顶层 `keyParams` 把**物理键**映射到 Live2D 模型的**参数 id**：按住键把该参数置 `1`、
松开置 `0`（"你按哪个键，猫的手就按哪个键"）。空对象表示不启用；精灵图包不用。

```json
"keyParams": {
  "space": "Space", "enter": "Enter1", "alt": "Alt", "ctrl": "Ctrl", "shift": "Shift",
  "q": "Q1", "w": "W1", "e": "E1", "r": "R1", "t": "T1",
  "a": "A1", "s": "S1", "d": "D1", "f": "F1", "g": "G1",
  "z": "Z1", "x": "X1", "c": "C1", "v": "V1", "b": "B1",
  "1": "F0", "2": "F2", "3": "F3", "4": "F4", "5": "F5"
}
```

键名用小写（`space`/`enter`/`alt`/…，字母/数字即其本身）。全局快捷键仅 Windows 可用；按键
**不吞事件**，前台程序照常收到。

### 鼠标反馈（`mouseParams`）

顶层 `mouseParams` 把**光标**映射到 Live2D 模型参数（仅 Live2D）。每个轴可以一次驱动**多个**参数：

```json
"mouseParams": {
  "x": [
    { "param": "ParamAngleX",   "scale": 30 },
    { "param": "ParamEyeBallX", "scale": 1 },
    { "param": "ParamMouseX",   "scale": 30, "raw": true }
  ],
  "y": [
    { "param": "ParamAngleY",   "scale": 30 },
    { "param": "ParamEyeBallY", "scale": 1 },
    { "param": "ParamMouseY",   "scale": 30, "raw": true }
  ],
  "xy": [
    { "param": "ParamAngleZ", "scale": -30 }
  ],
  "left": "ParamMouseLeftDown",
  "right": "ParamMouseRightDown",
  "smooth": 1.0
}
```

- `x`：光标左右（屏幕中心 = 0，右为正）；`y`：光标上下（上为正）；`xy`：`x*y`
  （用于头部倾斜这类乘积曲线）。
- 每项写法：`{ "param": "<参数 id>", "scale": <系数>, "raw"? }`；也可以只写参数名字符串（`scale` 取 1）。
- `scale` 要匹配模型里该参数的取值范围（例如 `ParamAngleX` ≈ ±30、`ParamEyeBallX` ≈ ±1）。
- `raw: true`：该项**不缓动**，直接用原始光标值。Bongo 里平滑只作用在 look-at（角度/眼珠），
  手/鼠标图形是直接跟光标的——给后者标 `raw: true`。
- `left` / `right`：鼠标左/右键按下 → `1`、松开 → `0`。
- `smooth`：缓动速度倍率（默认 `0` = 瞬时跟随）。`> 0` 时用 Bongo/`CubismTargetPoint`
  那套**加速度受限**模型跟随——最大速度 `4.0/s`、`0.15s` 加到满速、接近目标时刹车、停止阈值
  `0.01`（都在归一化 `±1` 范围内）；`1.0` 与 Bongo **完全一致**，`> 1` 更快、`< 1` 更慢。
- 全空 = 不启用（此时也不开启全局光标上报，零开销）。

> 光标上报只在有包声明 `mouseParams` 时开启；某轴方向/幅度不对时调对应 `scale`（取负即可反向）。

### Live2D 宠物包

- 目录里放置 `.model3.json` 及其引用的 `.moc3` / 贴图 / 动作；**`.model3.json` 必须在包根目录**（放到子目录会被拒绝），这样包目录即模型目录，模型内部的相对引用才能对上。
- 状态机与精灵图共用：`state.animation` 被当作**动作组名**（`startMotion`）。
- 已知取舍（v1）：只做「状态 → 动作组」，**没有**表情/参数映射；命中为**整矩形**；隐藏该桌宠即卸载模型（重新显示会重载）。

## 交互与使用

**桌面上的宠物**
- 单击 → 触发交互（如从发呆变为开心）。
- 拖拽 → 拖起宠物到任意位置松手，它会被限制在屏幕内。
- 锁定 / 点击穿透 → 通过托盘锁定 / 解锁，锁定时宠物不再响应鼠标（可作纯装饰悬浮物）。

**管理桌宠**
- 主窗口列出所有桌宠，可：
  - 新建桌宠（命名、选择宠物包、调节缩放/透明度）
  - 编辑 / 删除已有桌宠
- 全局设置可调节所有桌宠的基础缩放与透明度（单宠乘数叠加生效）。

**快捷启动（Windows）**
- 长按 **鼠标中键**（约 1 秒）呼出环绕宠物的扇环快捷盘。
- 按住中键将鼠标移向目标按钮，松手即可启动对应应用。
- 在「设置 → 快捷启动应用」中添加 / 编辑 / 排序 / 删除应用项，最多 8 个。

**系统托盘（Windows）**
- 锁定 / 解锁全部桌宠、显示主界面（设置）、退出应用。

## 技术要点

- **单悬浮窗架构（Windows）**：全部桌宠与环形快捷盘画在同一个铺满桌面的透明悬浮窗里，设置界面按需在 `desktop_multi_window` 子引擎中打开。桌面不被挡住靠的是该窗口常驻 `WS_EX_LAYERED | WS_EX_TRANSPARENT`——系统在命中测试阶段直接跳过它，即使 Flutter 侧卡死也挡不住任何点击。
- **全局输入钩子**：悬浮窗收不到鼠标消息，所以桌宠的点击/拖拽与全局快捷键都走进程级 `WH_MOUSE_LL` / `WH_KEYBOARD_LL` 钩子。Dart 把每只未锁定桌宠的**命中区域**声明给钩子作为"可抓取区"，钩子只在其中转发指针事件，并**吞掉**这一次点击，避免它继续作用到桌面下面的窗口。命中区域带一个可扩展的 `shape` 字段（`rect` / `grid`）：v1 恒为整矩形，**逐像素命中（网格）为预留**——原生在钩子回调内**同步**判定，不做 原生→Dart→原生 往返。
- **渲染边界 `PetVisual`**：`PetWidget` 只做两件事——把 `PetState` 画出来，并按宠物包类型选择视觉实现。精灵图走 `SpritePetVisual`（动画 + 图集 + `CustomPaint`），Live2D 走 `Live2DPetVisual`（原生运行时 + `Texture` + 动作组）。行为引擎 / `PetNotifier` / `PetState` 与渲染器**零耦合**。
- **单实例锁**：Windows 启动时使用互斥量（`flutter_alone`）确保只有一个悬浮窗实例，重复启动会聚焦已有实例。
- **跨进程存储**：MMKV 以 `MULTI_PROCESS_MODE` 打开，所有引擎共享同一份配置；写入后触发回调广播刷新。
- **运行时精灵图集**：把每帧 PNG 拼成一张 GPU 友好的图集（限制单边 ≤ 4096，自动计算最优网格），由 `CustomPaint` 按帧绘制，降低纹理切换开销。图集按（宠物包, 动画）**缓存到磁盘**：同一宠物包在多个桌宠引擎、以及后续每次启动之间，都只需逐帧解码 + 拼接一次。
- **锁定与拖拽**：Windows 的"锁定"= 不把该桌宠的命中区域声明给钩子，于是点它等于点桌面；拖拽则完全在 Dart 侧改场景坐标（原始点击已被钩子吞掉）。Android 每只桌宠是一个真正的系统悬浮窗，"锁定"通过 `FLAG_NOT_TOUCHABLE` 整窗穿透，拖拽交给系统移动窗口（`startDragging`）。
- **表达式求值**：自带轻量递归下降解析器，宠物包变换可直接书写数学公式，无需改代码即可做出弹跳、摇摆、呼吸等效果。
- **状态归属**：三类状态各有唯一真源，刻意分开，不要混用——
  1. **持久化数据**（设置 / 桌宠 / 宠物包 / 快捷启动）：真源是 `StorageService`，**写即广播**（`changes` 流）。UI 只读 `appDataProvider`（普通 `Provider`，由该流驱动自动重算），因此**不需要也不应该**到处手动 `ref.invalidate`。跨引擎写入也只传"存储变了"这一件事：Windows 走 dmw 消息、Android 走原生 `settings_updated`，另一侧收到后统一只做 `notifySettingsChanged()`，后续刷新与同引擎内完全一致。
  2. **场景瞬时状态**（场景尺寸、各桌宠矩形/命中形状、目标桌宠冻结、环形菜单呈现）：进程内共享、不持久化，写入方固定（`OverlayScene` / `QuickLaunchInputHost`），其它层只读。
  3. **进程级服务**（`InputService` / `ShortcutLauncher` / 托盘 / 设置窗口宿主）：必须在 `runApp` 之前或跨窗口角色存在，保持单例，但只从装配点（`main` / `AppHost`）驱动。

## 路线图

- [x] 全局热键接入（宠物包 `hotkey` 规则已接到全局输入层）
- [x] 宠物包音效接通（进入状态即播放该状态的 `audio`，`audioVolume` 控制响度；内置宠物包暂未附带音频资源）
- [x] Live2D Cubism 宠物包接入（Windows + Android）
- [ ] Live2D 命中逐像素（网格 shape）与表情/参数映射
- [ ] 宠物包「投喂 / 对话 / 天气」等更多事件与行为
- [ ] 桌宠间互动（靠近、追逐、结伴）
- [ ] 更多平台支持

## 开源许可

本项目基于 [MIT](LICENSE) 许可开源。

第三人称组件与许可（详见 [NOTICES](NOTICES)）：

- **Live2D Cubism Core / Native SDK**：归 Live2D Inc. 所有，受其 Free Material / Proprietary / Distribution License 约束。仓库本身**不含** SDK 源码/二进制（由 `tool/fetch_live2d_sdk.ps1` 拉取，见 [NOTICES](NOTICES)），但 `plugins/pet_live2d/` 把 Cubism Core **静态链接**进 `pet_live2d_plugin.dll`——因此**编译产物内嵌该 Core 二进制**，分发编译产物同样受上述许可约束，需随附其许可文本。`.moc3` 支持版本 3.0–5.3。使用 Live2D 功能时请遵守 Live2D Inc. 的许可条款。
