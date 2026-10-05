# 自研 Live2D 渲染器：难题与结论留档

这份文档记录**为什么这么写**，而不是又一份 API 说明。里面每一条结论都是实测换来的，
其中若干条与我们最初的直觉相反；**"死胡同"一节请务必先看**，否则很容易重新走一遍。

相关代码：`plugins/pet_live2d/`（原生运行时 + 通道）、`lib/pet/live2d/`（Dart 适配）、
`lib/pet/live2d_pet_visual.dart`（`PetVisual` 实现）。
对照参考：外部 vendored 插件 `live2d_flutter` 的 `PATCHES.md`（本仓库不包含）。

---

## 0. 一页速查

| 症状 | 真正原因 | 证据 / 位置 | 修法 |
|---|---|---|---|
| 模型**完全不出图**（日志一切正常） | `RenderFrame` 里**漏了 `OMSetRenderTargets`**：只清屏不绑定目标，清屏照样生效、模型被画到别处 | 导出渲染目标 → 全透明；对照旧插件 `RenderFrame` | 绘制前绑定 RTV + DSV |
| 缩放后**被裁切**（不是等比缩小） | Cubism 渲染器把**渲染目标尺寸烘焙进自身状态**，只在创建时确定，没有 setter | `CubismRenderer_D3D11.cpp:587 / 1211 / 1639`（`_modelRenderTargetWidth/Height` 用于离屏/遮罩通道） | 尺寸变化 ⇒ **新建实例**（见 §3） |
| 缩放**闪退** | 析构时释放了**引擎仍持有裸指针**的 `TextureVariant` / 渲染目标 | 旧插件 `PATCHES.md` Patch 4 | **故意泄漏到进程退出**（`texture_.release()` + 目标移交静态列表） |
| 模型被"裁掉一块"（桌面/前沿缺失） | 模型**美术超出其声明画布**（该模型画布是归一化 1×1），按画布适配必然切掉超出部分 | 适配到 80% 时桌面完整可见 | 用**真实顶点包围盒**做 contain（`GetDrawableVertexPositions`） |
| 缩放**一两秒空白** | 重建实例 = 模型重载 | 日志：`destroy` → `create` → `loaded` | **预热 + 就绪后切换**（旧实例一直渲染，见 §3.2） |
| "窗口大小和猫大小不一致"（猫只占盒子 60%） | 适配用的包围盒混进了**隐藏道具的几何** | 实测：60%×63%、偏右下 → 过滤后 90%×96%、居中 | 包围盒**按不透明度过滤**（§2.5） |
| 无限重建/重载 | 创建后未记住"该实例的目标尺寸"，每次 `build` 都以为盒子变了 | 日志里成对出现 `destroy`/`create` | 创建成功后回写 `_boxWidthPx/_boxHeightPx` |
| 按键无反应（`setParameter` 无效） | Cubism 每帧 `LoadParameters()` 会用 `_savedParameters` 覆盖参数 | 旧插件 Patch 5 | 参数覆盖表：每帧 `LoadParameters()` 之后重放 |
| 尺寸适配"累积"导致模型越缩越小/越大 | `CubismModelMatrix::SetWidth/SetHeight` 内部是 `Scale()`，**乘法累加** | `CubismModelMatrix.cpp` | 每次 fit 前 `LoadIdentity()` |

---

## 1. 引擎 / 平台侧的硬约束（不是我们的 bug，但必须遵守）

### 1.1 纹理区域（`visible_*`）**变更后引擎不重读**

Flutter 侧 `Texture` 的可见区域来自 `FlutterDesktopGpuSurfaceDescriptor`。实测：**保持不变时正常，
一旦改动尺寸，引擎仍按旧值合成**（"显隐一次才刷新"就是这个现象）。

⇒ 结论：**不要依赖"改描述符来改画面"**。我们最终让区域**恒定等于纹理尺寸**，
画面缩放交给 Flutter 布局（纹理放进更大/更小的盒子，引擎自己缩放）。

### 1.2 引擎持有 `TextureVariant` 的**裸指针**

重新注册纹理（`UnregisterTexture` + `RegisterTexture`）而**复用同一个 `TextureVariant`** 对象，
或者反过来**销毁该对象**，都会让引擎拿到悬垂指针 ⇒ **崩溃**（旧插件 Patch 4 记录过一次
`0xC0000005`，我们这次又踩了一次，症状是"切换缩放直接闪退"）。

⇒ 结论：
- **一个实例只注册一次，终身不变**；
- 实例销毁时，`TextureVariant` 与**所有渲染目标**都**故意泄漏到进程退出**（每个几百 KB）；
- 纹理注销（`UnregisterTexture`）**只能在平台线程**调用（引擎可能阻塞）。

### 1.3 尺寸变化时引擎**会**重读描述符

与 1.1 不矛盾：**渲染目标的尺寸**（`width/height`）变更后引擎每帧会重新读取，旧插件就是靠这个
"换目标不换注册"实现无闪烁缩放的（其 Patch 4 原文：*"resizing replaces the render target,
and the engine may still hold the previous descriptor"*，所以旧目标要保留 60 帧）。

---

## 2. Cubism / D3D11 侧的坑

1. **渲染目标尺寸烘焙在 renderer 创建时**（§0 表第 2 行）。这是"必须新建实例"的根因，
   也是本项目缩放方案的最终形态的由来。`SetDrawableClippingMaskBufferSize` 只能改遮罩缓冲，
   改不了离屏目标尺寸；事后重建 renderer 也不够（实测同样碎）。
2. **裁剪遮罩缓冲尺寸必须等于渲染目标尺寸**。按"可见区"去设会把整只模型裁掉。
3. **`CubismModelMatrix::SetWidth/SetHeight` 是乘法**（`LoadIdentity()` 后才幂等）。
4. **画布尺寸不可信**：`GetCanvasWidth/Height()` 对该模型返回归一化 `1×1`，实际美术远超画布。
   ⇒ 用顶点包围盒。
5. **隐藏部件仍有几何，必须按不透明度过滤**。该包把暂时不显示的道具"藏起来"，
   但它们的几何仍在 ⇒ 不过滤时当前姿态只占目标 **60%×63%** 且偏右下（实测），
   看上去就是"窗口和猫大小不一致"。
   **只按 `GetDrawableOpacity(i) <= 0.01` 过滤**即可得到 **90%×96%、四周对称**。
   - 我们一度**额外**用了 `GetDrawableDynamicFlagIsVisible`，并据**截图判读**得出
     "把桌面切掉了"的结论——**那是错的**：加不加该标志，包围盒完全相同，真正起作用
     的是不透明度过滤。教训见 §5。
6. **Windows `min`/`max` 宏**会与 `std::min/std::max` 冲突（框架引入 `windows.h`）：
   写成 `(std::min)(...)`。

---

## 3. 缩放方案的最终形态

### 3.1 不变量

- **渲染目标像素尺寸 ≡ 组件像素尺寸（1:1）**。这是旧插件隐含的规则（Dart 侧把
  `logical × devicePixelRatio` 交给原生，`Resize` 按该尺寸重建目标）。我们曾为了"少重建"
  加了 ×1.25 余量 + 64 对齐，结果纹理永远比盒子大 ⇒ 处处依赖引擎缩放 ⇒ 出现裁切观感。
- **模型适配用顶点包围盒 + 4% 边距**，并 `LoadIdentity()` 后 `Scale`+`Translate` 居中。
- **一个实例一个 key**，模型归运行时所有，`petId` 持久。

### 3.2 尺寸变化 ⇒ 预热 + 无缝切换

因为 §2.1，尺寸变化只能换实例（= 模型重载）。为了**不出现空白**：

1. 旧实例**继续渲染**（此时引擎把旧纹理缩放进新盒子 —— 用户看到的"瞬间正确缩放"就是它）；
2. 后台按新尺寸**建新实例**（独立 key，不动在屏那个）；
3. 新实例加载完成推送 `modelReady`；
4. Dart 侧收到后**切换纹理、补播当前状态、释放旧实例**。

防抖 250ms ⇒ 拖动缩放滑杆只在停稳后预热一次；切换时机由"真正能画"决定，因此**不会空白**。
每个实例用独立 key（`pet_…#序号`），所以预热不会拆掉在屏的那个。

### 3.3 分档帧率（不停帧）

渲染线程 60Hz 轮询，但**按实例分档**：动作在播 / 1 秒内有输入 ⇒ 满帧；否则每 3 帧更新一次
（约 20fps），**并把 dt 同步放大 3 倍**，让动作、物理、眨眼保持真实时间速度，只是更新密度下降。
**不做完全停帧**——眨眼与物理是"活着"的关键，停帧会变成死图（这一条推翻了方案里
"空闲完全停帧"的原始设想）。

### 3.4 速度

`PetState.finalSpeed`（全局 × 本宠）经 `PetVisual.setSpeed` 接到 `setMotionSpeed`。
此前该值只影响行走速度，对 Live2D 无效。

---

## 4. 死胡同（试过、错、且原因明确，不要重走）

| 尝试 | 为什么不行 |
|---|---|
| 固定大尺寸纹理 + 改 `visible_*` 只渲染可见区 | 引擎不重读变更后的 `visible_*`（§1.1） |
| 恒定区域 + Flutter 侧 `Transform` 放大映射 | 外部纹理配 Transform 的显示不可靠；且引入"区域/对齐"假设 |
| 就地 resize 渲染目标（换目标 + 重设遮罩 + 重新适配） | §2.1：渲染器状态仍指向旧尺寸 ⇒ 只渲染出碎片/裁切 |
| 就地 resize 时**重建 renderer** + 重绑贴图 | 实测同样是碎片 |
| 按"不透明度/可见标志"过滤包围盒以让宠物占满盒子 | 该包有标志与实际绘制不一致的部件 ⇒ 反而更切 |
| 复用一个 `TextureVariant` 只换注册 id | 引擎按对象缓存描述符 ⇒ 缩放后采样错区域（且换掉对象会崩，见 §1.2） |
| 实时下发尺寸给原生（`setBoxSize`） | 会走"就地 resize"这条注定错的路径；尺寸只在创建时使用 |

---

## 5. 诊断方法（以及它们的坑）

- **原生日志写文件**（`l2d_native.log`，可执行文件旁）：应用可以正常启动、托盘可退出，
  不依赖 stdout 重定向（早期用重定向启动导致"孤儿进程关不掉"）。
- **导出渲染目标**：`PET_LIVE2D_DUMP=1` ⇒ 每次重建后写 `l2d_dump_<key>_<WxH>.bmp`。
  这是区分"**我们没画**"和"**引擎没合成**"的唯一可靠手段（本次两条主线都靠它定位）。
  - **坑**：早期版本在目标交换后仍读**旧目标**，导出的是陈旧内容，把结论带偏了很久。
    现在导出前会重新读取当前目标。
- **`PET_LIVE2D_TRACE=1`**：逐事件（`param` / `expression`）日志，默认关闭（每次按键都会触发）。
- **测试探针的坑**：探针若写在"创建完成"路径里，会**每次创建重新武装** ⇒ 自我循环、
  并让 Flutter 盒子与上报尺寸不一致。验证缩放这类问题时，探针必须只武装一次。
- **截图判读（vision）不可靠**：同一张图对"有没有猫""什么颜色"的判读会反复摇摆。
  **不要用它做结论**，要用导出图 / 日志；但"有没有画面"这类问题它基本判对过——
  只是不适合做精细判断。

---

## 6. 构建侧的两个坑（自研插件引入的）

1. **Cubism SDK 不入库**：由 `tool/fetch_live2d_sdk.ps1` 拉取（固定 pub 版本 + sha256 校验）
   到 `third_party/live2d/`（已 gitignore）。官方 SDK zip 在许可确认页后，无法稳定直链，
   脚本支持 `-SdkZip` 人工兜底。
2. **工程配置集是 `Debug;Profile;Release`**：`Live2DCubismCore` 这个 imported target
   **必须给出 `IMPORTED_LOCATION_PROFILE`**，否则 `flutter build windows --profile`
   会因 CMake CMP0111 失败（不只是警告）。
3. 其它：插件被 Flutter 软链到 `.plugin_symlinks/`，CMake 里要用 `REALPATH` 才能找回仓库根；
   `pluginClass` 里若写成 `PetLive2DPluginCApi`，工具按 camel→snake 会生成
   `pet_live_v2_d_plugin_c_api.h` 这种名字 ⇒ 类名写成 `PetLive2dPluginCApi`。
