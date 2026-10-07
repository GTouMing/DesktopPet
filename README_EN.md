<h1><a href="README_CN.md">桌宠</a>&nbsp;|&nbsp;Desktop Pet</h1>

A desktop pet application built with Flutter, supporting both **Windows** and **Android**.

On Windows a single full-desktop transparent overlay window hosts every pet, the radial quick-launch dial and the tray icon, while the settings form opens in a separate child window on demand; on Android each pet is its own system overlay window floating above any app. Every pet is driven by a **Pet Pack** — a JSON manifest (`pet.json`) declaring animations/states/interaction triggers, with assets that are either **sprite frames** (sprite) or a **Live2D Cubism model** (live2d). You can also import your own `.zip` pet packs.

![platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android-blue)

## Features

- **Multiple pets at once**: Create several pets, each with its own position, scale and behavior — fully independent of one another. On Windows they share one overlay scene; on Android each gets its own system overlay window.
- **Wander anywhere**: Pets are not pinned to one corner. They move around on their own, and respond to your clicks, drags and pokes.
- **Behavior state machine**: the pet pack manifest declares states and transition rules (click, drag, timers, direction, arrival, animation complete, global hotkeys, etc.), combined with programmable transform expressions (scale / rotation / offset / opacity with `sin/cos/lerp/clamp`) for lively animation.
- **Two render backends**: sprite frame packs and **Live2D Cubism model packs** coexist under one state machine.
- **The desktop stays usable**: the overlay is frameless, transparent and permanently **click-through** (the system skips it during hit-testing), so pets can never block anything else on your desktop. Each pet can be locked/unlocked; a locked pet neither reacts to the mouse nor takes part in hit-testing.
- **Global hotkeys**: A state's `hotkey` rule in the pet pack JSON becomes a system-wide shortcut (e.g. `Ctrl+Alt+S` to sleep, `Ctrl+Alt+K` to walk to the screen edge). *Which* state a key applies in is decided entirely by the pack data: on press the app looks up “current state + combo”.
- **Sound effects**: declare `audio` / `audioVolume` on a state and it plays on entry (`assets/...` for bundled resources, an absolute path for local files). The built-in pet pack ships no audio assets yet — fill one in and it plays.
- **Quick Launch (Windows)**: Hold the middle mouse button to summon a radial quick-launch dial (up to 8 apps); release over an item to launch it.
- **System tray (Windows)**: Lock / unlock all pets, open settings, and quit.
- **Pet pack system**:
  - Built-in default pet pack (sprite: idle / walk / sleep / happy / eat / drag animations).
  - One-click import from **ZIP pet packs** — automatically extracted, validated per type and registered; **sprite / Live2D** is detected on import.
  - Configurable **custom pet pack directory**, auto-scanned for packs, with one-click migration of already-imported packs.
- **Settings hub**: Global scale / opacity (multiplied with each pet's own multipliers), applied live across all pets.
- **Persistence**: MMKV multi-process storage — config changes are written back and broadcast to every pet in real time.

## Platform Support

| Platform | Form                                                                   | Notes                                                                                                                   |
|----------|------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| Windows  | Full-desktop transparent overlay + settings child window + system tray | Single engine: every pet and the radial dial are drawn in one overlay window; settings open in a child window on demand |
| Android  | System overlay window (one per pet)                                    | Requires the "display over other apps" permission; multiple overlays supported                                          |

> Other platforms (Linux / macOS / iOS) throw an `UnsupportedError` at startup and are not currently supported.

### Live2D Support

- **Platforms**: Windows is implemented (the in-repo renderer arrives as a D3D11 GPU-surface texture inside the Flutter scene); Android is a later stage.
- **Model layout**: one directory plus its `.model3.json`. The **`.model3.json` must live at the pack root**; the `.moc3` (versions 3.0–5.3), textures and motions it references resolve relatively next to it.
- **Shared state machine**: `StateDef.animation` is treated as a **motion group name** (`startMotion`) for Live2D; states, transitions and expressions are identical to sprites.
- **Hit-testing**: v1 uses the whole **bounding rectangle**; the extensible payload for per-pixel hit-testing is reserved (see “Technical Highlights”).
- **License**: the model and the Cubism runtime belong to Live2D Inc. — see “License”.

## Getting Started

### Prerequisites

- Flutter SDK `^3.12.2` (Dart `^3.12.2`)
- Windows: Windows 10 / 11 (needs D3D11 for Live2D)
- Android: Android 7.0+ (**API 24+**; overlays need system authorization)

### Run

```bash
flutter pub get
flutter run -d windows   # Windows desktop
flutter run -d <device>  # Android device / emulator
```

On first launch the app seeds default data in the app documents directory and creates a pet named "默认桌宠" (Default Pet).

> ⚠️ After cloning, fetch the Live2D SDK once (it is not committed) — see “Build Notes” below.

### Build Notes

- **Live2D SDK (required)**: the Cubism runtime is used by the in-repo renderer in `plugins/pet_live2d/`; the **SDK itself is not committed**. After cloning, run once:
  `powershell -ExecutionPolicy Bypass -File tool/fetch_live2d_sdk.ps1`
  It fetches a pinned version (plus sha256 verification) declared in `third_party/live2d.sdk.json` and extracts the needed subset into `third_party/live2d/` (gitignored). Live2D's official SDK zip sits behind a license-acceptance page and cannot be fetched by a stable direct link, so the script also accepts `-SdkZip <path>` for a manually downloaded copy. CMake fails with a readable message pointing at the script when the subset is missing.
- **Packaging**: `powershell -ExecutionPolicy Bypass -File tool/package_windows.ps1`
  builds the release, runs a pre-flight check (a missing `app.so` / `pet_live2d_plugin.dll` / `FrameworkShaders`, a
  plugin DLL listed in `generated_plugins.cmake` that was not produced, or a DEBUG engine DLL inside the Release
  directory, all abort with a clear message - they show up as "exits immediately" / "no Live2D" /
  "Not running in AOT mode"), drops stale plugin DLLs, runtime artefacts (`*.log`, `l2d_dump_*.bmp`) and empty
  directories, adds the app-local VC runtime and the license/notice files, and writes
  `dist/DesktopPet-<version>-windows-x64.zip` (sha256 printed). With Inno Setup installed it also
  produces a `setup.exe`. Pass `-SkipBuild` to reuse the existing build, or `-Clean` to `flutter clean` first
  (**use `-Clean` for a real distributable**: Flutter never prunes DLLs or asset directories left behind by
  removed plugins, so a long-lived build directory leaks stale files into the package; the script drops what
  it can, but a clean build is the only complete fix).
- **Packaged runtime & licenses**: the exe and every plugin DLL are linked `/MD`, so a target machine without the
  **VC++ 2015-2022 x64 Redistributable** fails to start (`VCRUNTIME140.dll` / `MSVCP140.dll` missing); the Cubism
  Core only ships as MD/MDd, so a `/MT` rebuild is not an option. The packaging script bundles the VC runtime DLLs
  **app-local** (it warns if it cannot find them) and ships `LICENSE`, `NOTICES` and Live2D's
  `Live2D-Cubism-Core-LICENSE.md` - the Cubism Core is **statically linked** into `pet_live2d_plugin.dll`, so a
  distributed build must carry its license text.
- **No more `live2d_flutter`**: the old third-party plugin (and its out-of-repo vendored copy behind `dependency_overrides`) is gone. The patches we wrote for it and the architectural traps it had are recorded in `doc/live2d-renderer-notes.md` and `plugins/pet_live2d/`.
- **Android `minSdk`**: explicitly pinned to `24`, reserved for the future Android Live2D path (a Cubism runtime requirement) rather than `flutter.minSdkVersion`.
- **Windows toolchain**: the native code compiles and links under `cxx_std_17 + /W4 /WX + _HAS_EXCEPTIONS=0`; the shared `apply_standard_settings` needs no relaxation.
- **Debug-build caveat**: the renderer **never** requests `D3D11_CREATE_DEVICE_DEBUG` — on a machine without the D3D11 debug layer that request fails and falls back to WARP, whose shared textures the engine's hardware device cannot bind (it shows up as "nothing renders"). One of the traps recorded in `doc/live2d-renderer-notes.md`.

```bash
# Windows
flutter build windows

# Android
flutter build apk
```

## Project Structure

```
lib/
├── main.dart                     # main(): platform dispatch, single-instance lock, window-role wiring
├── app.dart                      # MaterialApp entry (shared by the main UI & the pet overlay)
├── core/                        # Leaf layer: constants, enums, DPR, hit shape, shared scene state, cross-engine channel
├── input/                       # Global input: InputService / KeyRegistry / platform input source / watch regions (shape)
├── pet/                         # Pet runtime: state machine, behavior, render boundary, hotkeys, pointer routing
│   ├── pet_notifier.dart        #   State manager (Riverpod StateNotifier)
│   ├── pet_state.dart           #   Runtime state snapshot of a pet
│   ├── pet_providers.dart       #   petId / petState providers
│   ├── pet_metrics.dart         #   Derived render values (global × per-pet, pure functions)
│   ├── pet_window_binding.dart  #   Android-only system overlay sync
│   ├── behavior_engine.dart     #   Target generation & interpolation, direction/arrival events
│   ├── pet_pointer_router.dart  #   Hook pointer events → per-pet hit-testing and dragging
│   ├── hotkey_engine.dart       #   Pet pack `hotkey` rules → global input layer
│   ├── pet_visual.dart          #   Render boundary abstraction (PetVisual)
│   ├── sprite_pet_visual.dart   #   Sprite implementation (animation + atlas + transform)
│   ├── live2d_pet_visual.dart   #   Live2D implementation (Texture + motion groups; warm-up swap on resize)
│   ├── live2d/                  #   Live2D channel wrapper (native runtime ↔ Dart)
│   ├── pet_widget.dart          #   Does two things: draws PetState + picks a PetVisual by type
│   └── pet_context.dart         #   Context interface consumed by the behavior engine
├── petpack/                     # Pet pack system (renderer-agnostic)
│   ├── pet_pack.dart            #   Abstract base + manifest reading + type detection (PetPackDetector)
│   ├── sprite_pet_pack.dart     #   Sprite pack (animations / frame images)
│   ├── live2d_pet_pack.dart     #   Live2D pack (model3.json / motion groups)
│   ├── pet_pack_lister.dart     #   Available-pack discovery (with type badge)
│   ├── expression.dart          #   Lightweight expression evaluator (sin/cos/lerp/clamp…)
│   ├── audio/                   #   Per-state sound service (plays on state entry)
│   ├── sheet/                   #   Frame PNG → sprite atlas (runtime stitching) + renderer
│   ├── import/                  #   ZIP import, per-type validation, repository, directory migration
│   └── state/  animation/       #   JSON models for states / animations
├── platform/                    # Platform abstraction & implementations
│   ├── window_interface.dart    #   WindowController abstract interface (Android only)
│   ├── windows/                 #   Windows: host wiring, overlay/settings channels, tray
│   └── android/                 #   Android: multi overlay (vendored plugin), settings-change broadcast
├── shortcut/                    # Quick launch: ring geometry & painting, host gesture machine, icon extraction
├── storage/                     # MMKV persistence + data models (settings / pets / pet packs / shortcuts)
└── ui/
    ├── common/                  #   Main list, pet editor, pet pack picker, language, dialogs
    │   └── settings/            #   Settings page split into sections (appearance / pet packs / shortcuts / language / about)
    ├── host/                    #   Roots of the two windows and their support pieces
    │   ├── overlay_scene.dart   #     The pet overlay scene (every pet + the radial dial)
    │   ├── settings_window_root.dart #  Settings window root
    │   ├── scene_geometry.dart  #     Scene geometry (= desktop geometry) and DPR conversion
    │   ├── grab_rects.dart      #     Publishes pet hit regions to the global hook
    │   └── settings_window_channel.dart # Listens for "storage changed" from the settings window
    ├── android/                 #   Content of one pet's system overlay
    └── widgets/                 #   Shared widgets (window frame, pet list/card, info overlay)
```

## Pet Packs

A pet pack is a directory containing a manifest — **`pet.json`** — plus assets.

- The **built-in pet pack** lives in `assets/default_pet_pack/`.
- **Imported packs** are extracted to `<app documents>/imported_pet_packs/<petId>/` by default, or to `<packDir>/<petId>/` when a custom pet pack directory is configured.
- **Custom directory**: pick any folder in Settings to use as the pet pack directory; every subdirectory containing a manifest (`pet.json`) is discovered automatically.
- **Type detection**: the manifest's `type` wins (`"sprite"` / `"live2d"`); otherwise it is detected from content — a `*.model3.json` in the directory means Live2D, anything else is a sprite pack.

### Manifest Reference (`pet.json`)

| Field                        | Description                                                                                                                 |
|------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `name` / `version`           | Pack name and version                                                                                                       |
| `type`                       | `"sprite"` (default) or `"live2d"`; detected from content when omitted                                                      |
| `frameWidth` / `frameHeight` | Render base size (logical pixels): sprite = single frame; live2d = logical canvas                                           |
| `initialState`               | Initial state name (defaults to `idle`)                                                                                     |
| `animations`                 | (sprite) Animation definitions: `{ folder, fps, frameCount, framePrefix?, frameStart? }`; frames are `folder/0.png`, `folder/1.png`… |
| `model`                      | (live2d) `.model3.json` file name; when omitted, the first `*.model3.json` at the pack root is used                          |
| `scale`                      | (live2d) Scale multiplied **on top of** the automatic fit (default `1`; must be `> 0` and `<= 10`) — lets an author fix the framing instead of leaving it to the fitter |
| `translate`                  | (live2d) Offset of the model centre from the box centre: `{ "x": 0, "y": 0 }` in **logical pixels**, `+x` right, `+y` down   |
| `breath`                     | (live2d) Idle-breath amplitude (default `1`): the engine always feeds the standard Cubism breath, and this can only **lower** it (`0` = no breathing). A model's sway is meant to come from its own physics; authors use this to adapt theirs |
| `states`                     | State definitions: reference an animation/motion group + optional behavior + transform expressions + transitions             |
| `hotkeys`                    | Pack-level hotkey → action (**bypasses the state machine**, see below): `{ "<id>": { key, modifiers?, animation?, motionIndex?, motionPriority?, expression?, durationMs? } }` |
| `keyParams`                  | Typing reaction (Live2D only): `{ "<key>": "<model parameter id>" }` — holding the key sets the parameter to 1, releasing to 0 |
| `mouseParams`                | Mouse feedback (Live2D only): `{ left?, right?, smooth? }` — the follow parameters/magnitudes come from the model; only buttons and easing (not derivable from the model) stay here; see "Mouse Feedback" |
| `params`                     | Tunable slot groups (Live2D only): `{ "<slot>": { label?, type?, default?, params? \| offParams? \| options? } }` — adjusted in the pet editor; see "Tunable Parameters" |

Example state definition:

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

#### Triggers

| Trigger                                    | Fires when                                                                 |
|--------------------------------------------|----------------------------------------------------------------------------|
| `click`                                    | The pet is clicked                                                         |
| `drag`                                     | Dragging starts                                                            |
| `arrived`                                  | Movement reaches its target point                                          |
| `moveUp / moveDown / moveLeft / moveRight` | Directional movement events                                                |
| `limitTimer`                               | Random timer (`minMs`–`maxMs`), useful for periodically switching behavior |
| `waitTimer`                                | Fixed delay (`afterMs`) elapses                                            |
| `hotkey`                                   | Global hotkey pressed (`key` + `modifiers`)                                |
| `complete`                                 | A one-shot (non-looping) animation finishes                                |

#### Behaviors

| Behavior       | Description                                                              |
|----------------|--------------------------------------------------------------------------|
| `moveToTarget` | Move to a target point (`targetPos` for a fixed point, random otherwise) |
| `moveToEdge`   | Move to the screen edge                                                  |
| _(none)_       | Stay in place                                                            |

#### Transform Expressions

Every state can describe how it transforms over time `t` (0→1, reset each loop):

- `scaleX` / `scaleY`: scaling — great for bouncy motion
- `rotation`: rotation (radians)
- `offsetX` / `offsetY`: translation
- `opacity`: opacity
- `mirrorH`: horizontal mirroring (auto-flip when moving left)

Expressions support `+ - * / ^ ( )`, numbers, the constant `PI`, the variable `t`, and the functions `sin cos abs clamp lerp`.

### Pack-level Hotkeys (`hotkeys`)

The top-level `hotkeys` map binds a key **directly** to an action/expression, **bypassing the
state machine** — unlike a state's `hotkey` transition (which switches the current state), this
just means “press this key, play this motion/expression”. It suits Live2D models that ship a
pile of motions you want to fire one key at a time (toggle accessories, switch expressions…).

```json
"hotkeys": {
  "ear": { "key": "1", "modifiers": ["ctrl", "alt"],
           "animation": "CAT_motion_lock", "motionIndex": 1, "motionPriority": 3 },
  "cry": { "key": "2", "modifiers": ["ctrl", "alt"], "expression": 3 }
}
```

- `key` (required) + `modifiers?`: physical key and modifiers, same notation as a state's
  `hotkey` rule.
- `animation?`: motion group name (Live2D) / animation name (sprite); omit for an
  expression-only action.
- `motionIndex?` / `motionPriority?`: index within the group and priority (`0` none / `1` idle /
  `2` normal / `3` force, default `3`).
- `expression?`: Live2D only, switches the expression index.
- `durationMs?`: the action's length in ms (from the motion's `Meta.Duration`). When set, actions
  are **serialized**: while one is playing, later requests **queue** (the newest replaces the
  pending one) and play only after it finishes — matching Bongo ("the next animation is allowed
  only after the current one finishes"). `0`/omitted = preempt immediately.
- `requires?`: **parameter preconditions** — `{ "<slotId>": "<label>" | [<label>, ...] }`. The
  action is ignored unless the current choice of every listed slot (compared by option label) is in
  the list. A boolean slot's labels are `on` / `off`. Omitted = no precondition.
- `sets?`: **parameter changes** — `{ "<slotId>": "<label>" }`. When the action plays, those slots
  switch to the given options (written back into the pet's saved choices).

Priority: **state transitions win** — if the current state declares a `hotkey` transition for
the combo, the state machine runs; otherwise the pack-level action fires. Global hotkeys are
Windows-only, and the key is **not swallowed** (other apps still receive it).

> Pack-level actions are currently implemented by the Live2D renderer only; the sprite renderer ignores them.

### Tunable Parameters (`params`) — slots

The top-level `params` map declares **mutually-exclusive slot groups** (Live2D only). Each group is
one control in the pet editor; **within** a group exactly one option is active, **across** groups
several can be active at once. Options write model parameters directly:

```json
"params": {
  "glasses": {
    "label": "Glasses", "default": "None",
    "options": [
      { "label": "None" },
      { "label": "Round", "params": { "ParamCheek70": 1 } }
    ]
  },
  "whale": { "label": "Whale", "type": "bool", "default": false, "params": { "jingyu": 1 } }
}
```

- `type: "bool"` → a switch; the group's `params` are written while it is on. Turning it off
  restores the model default, so a part whose default is itself "on" (e.g. cat ears) needs
  `offParams` to state the parameters to write when off.
- Otherwise a dropdown of `options`; `default` is an option label (or index).
- Switching an option clears the previous one's parameters, so slots never "fight" — this replaced
  the exclusive Cubism expression manager (accessories and mood expressions are meant to stack).
- Values are saved per pet; a pack action may read/change slots with `requires` / `sets`.

### Typing Reaction (`keyParams`)

The top-level `keyParams` map binds a **physical key** to a Live2D **parameter id**: holding the
key sets the parameter to `1`, releasing sets it to `0` (i.e. “press a key and the cat presses
it too”). An empty map disables it; the sprite renderer ignores it.

```json
"keyParams": {
  "space": "Space", "enter": "Enter1", "alt": "Alt", "ctrl": "Ctrl", "shift": "Shift",
  "q": "Q1", "w": "W1", "e": "E1", "r": "R1", "t": "T1",
  "a": "A1", "s": "S1", "d": "D1", "f": "F1", "g": "G1",
  "z": "Z1", "x": "X1", "c": "C1", "v": "V1", "b": "B1",
  "1": "F0", "2": "F2", "3": "F3", "4": "F4", "5": "F5"
}
```

Key names are lowercase (`space`/`enter`/`alt`/…; letters/digits as themselves). Global hotkeys
are Windows-only, and the key is **not swallowed** (other apps still receive it).

### Mouse Feedback (`mouseParams`)

**The cursor-follow parameters and their magnitudes are read from the model**: the renderer picks
the **standard follow parameters** that actually exist in the model — `ParamAngleX` / `ParamAngleY`
/ `ParamAngleZ` / `ParamBodyAngleX` / `ParamEyeBallX` / `ParamEyeBallY` — takes each parameter's
`min`/`max` range radius as `scale`, and its **default value** as the neutral baseline (so a centred
cursor returns the model to its rest pose instead of being forced to 0). A pack therefore **does
not** declare follow mappings; each pet can additionally scale the follow with the X/Y sliders in
the pet editor (`0`–`2`, default `1`, `0` disables following).

Only what cannot be derived from the model stays in the manifest:

```json
"mouseParams": {
  "left": "ParamMouseLeftDown",
  "right": "ParamMouseRightDown",
  "smooth": 1.0
}
```

- `left` / `right`: left/right mouse button down → `1`, up → `0` (effective only if the model has
  the parameter).
- `smooth`: easing speed multiplier (default `1.0`). When `> 0` the follow uses Bongo's /
  Cubism's `CubismTargetPoint` model — an **acceleration-limited** servo: max speed `4.0/s`,
  `0.15 s` to reach max speed, braking near the target, stop threshold `0.01` (all in the
  normalized `±1` range). `1.0` is **exactly Bongo**; `0` = instant follow, `> 1` faster, `< 1`
  slower.
- Empty / absent = no mouse-button feedback (the cursor follow still comes from the model).

> Direction and magnitude come from each parameter's range; the negative sign on `ParamAngleZ`
> (head tilt) is the standard look-at convention and lives in the engine. In the **pet editor**, the
> "cursor-follow parameters" section lists **only the parameters that are in the same group(s) as
> the standard follow parameters AND whose id or name contains an uppercase `X`/`Y`/`Z`** — authors
> already keep follow-related parameters together (e.g. the cat's "basic parameters", the whale's
> "face / body / expression"), and axis parameters carry that letter as a marker (lowercase does not
> count). Pick the axis per parameter (don't follow / X / Y / XY, prefilled from the standard set);
> leave it untouched to keep the automatic set. Use the same page's "mouse follow" X/Y sliders to make
> it weaker or stronger overall — no need to touch the pack.

### Live2D Pet Packs

- Put the `.model3.json` along with the `.moc3` / textures / motions it references in the directory. The **`.model3.json` must be at the pack root** (a subdirectory is rejected) so the pack directory is the model directory and the model's internal relative references resolve.
- The state machine is shared with sprites: `state.animation` is treated as a **motion group name** (`startMotion`).
- v1 trade-offs: only “state → motion group” is wired up — **no** expression/parameter mapping; hit-testing is the whole **rectangle**; hiding the pet unloads the model (showing it again reloads).

## Usage

**Interacting with a pet**
- Click → fires an interaction (e.g. idle → happy).
- Drag → pick the pet up and drop it anywhere; it is clamped to the screen.
- Lock / click-through → lock or unlock from the tray. A locked pet ignores the mouse entirely (perfect as a pure decorative overlay).

**Managing pets**
- The main window lists every pet, letting you:
  - Create a pet (name it, pick a pet pack, adjust scale / opacity / mouse-follow strength)
  - Edit or delete existing pets
- Global settings tune base scale and opacity for all pets (multiplied with per-pet multipliers).

**Quick Launch (Windows)**
- Hold the **middle mouse button** (~1 s) to summon the radial dial around the pet.
- Keep holding and move the cursor onto a button, then release to launch that app.
- Manage items under "Settings → 快捷启动应用" (add / edit / reorder / delete), up to 8 items.

**System tray (Windows)**
- Lock / unlock all pets, show the main window (settings), and quit.

## Technical Highlights

- **Single-overlay architecture (Windows)**: every pet and the radial quick-launch dial are drawn in one full-desktop transparent overlay, and the settings form opens on demand in a `desktop_multi_window` child engine. The desktop stays usable because that window is permanently `WS_EX_LAYERED | WS_EX_TRANSPARENT` — the system skips it during hit-testing, so not even a hung Flutter side can block a click.
- **Global input hooks**: the overlay receives no mouse messages, so pet clicks/drags and global hotkeys all go through process-wide `WH_MOUSE_LL` / `WH_KEYBOARD_LL` hooks. Dart publishes each unlocked pet's **hit regions** as "grabbable regions"; the hook forwards pointer events only inside them and *swallows* the press so it never reaches the window underneath. Each region carries an extensible `shape` field (`rect` / `grid`): v1 is always the whole rectangle, while **per-pixel (grid) hit-testing is reserved** — native decides **synchronously** inside the hook callback, with no native→Dart→native round-trip.
- **Render boundary `PetVisual`**: `PetWidget` does exactly two things — draw `PetState`, and pick a visual implementation by pack type. Sprites use `SpritePetVisual` (animation + atlas + `CustomPaint`); Live2D uses `Live2DPetVisual` (native runtime + `Texture` + motion groups). The behavior engine / `PetNotifier` / `PetState` are **decoupled** from the renderer.
- **Single-instance lock**: On Windows a mutex (`flutter_alone`) guarantees a single overlay instance; relaunching focuses the existing instance instead.
- **Cross-process storage**: MMKV is opened in `MULTI_PROCESS_MODE`, so all engines share one config store; writes trigger a broadcast refresh callback.
- **Runtime sprite atlas**: Frame PNGs are stitched into one GPU-friendly atlas at runtime (sides capped at ≤ 4096 px with an optimal auto grid), drawn frame-by-frame via `CustomPaint` to cut texture-switch overhead. Atlases are **cached on disk** per (pack, animation): the expensive decode-and-stitch pass happens once per pack, shared by every pet engine and reused across restarts.
- **Locking & dragging**: on Windows "locked" simply means the pet's hit regions are not published to the hook, so clicking it is clicking the desktop; dragging is pure Dart scene-coordinate movement (the raw click was already swallowed by the hook). On Android each pet is a real system overlay window, so "locked" uses `FLAG_NOT_TOUCHABLE` for whole-window pass-through and dragging is handed to the OS window drag (`startDragging`).
- **Expression evaluator**: A tiny hand-written recursive-descent parser lets pack transforms be authored as plain math formulas — bouncing, swaying and breathing effects with zero code changes.
- **State ownership**: three kinds of state, each with exactly one source of truth — kept deliberately separate:
  1. **Persisted data** (settings / pets / pet packs / shortcuts): owned by `StorageService`, which **broadcasts on every write** (the `changes` stream). The UI only reads `appDataProvider` — a plain `Provider` driven by that stream — so there is **no** manual `ref.invalidate` anywhere. Across engines only one fact is sent ("storage changed"): a dmw message on Windows, the native `settings_updated` on Android; the receiving side just calls `notifySettingsChanged()`, and the rest of the refresh is identical to the in-engine case.
  2. **Transient scene state** (scene size, pet rectangles/hit shapes, the frozen pet, the ring presentation): in-process, never persisted, written only by `OverlayScene` / `QuickLaunchInputHost`, read-only everywhere else.
  3. **Process-level services** (`InputService` / `ShortcutLauncher` / tray / settings-window host): must exist before `runApp` or across window roles, so they stay singletons — but they are only driven from the assembly points (`main` / `AppHost`).

## Roadmap

- [x] Wire global hotkeys (pet pack `hotkey` rules now go through the global input layer)
- [x] Wire up pack audio (entering a state plays its `audio` at `audioVolume`; the built-in pack ships no audio assets yet)
- [x] Live2D Cubism pet packs (Windows + Android)
- [ ] Live2D per-pixel hit-testing (grid shape) and expression/parameter mapping
- [ ] More events & behaviors (feeding, dialogue, weather…)
- [ ] Pet-to-pet interaction (approach, chase, hang out together)
- [ ] More platform support

## License

This project is licensed under the [MIT](LICENSE) license.

Third-party components and licenses (see [NOTICES](NOTICES)):

- **Live2D Cubism Core / Native SDK**: owned by Live2D Inc., subject to its Free Material / Proprietary / Distribution Licenses. The repo does **not** contain the SDK (it is fetched by `tool/fetch_live2d_sdk.ps1` - see [NOTICES](NOTICES)), but `plugins/pet_live2d/` **statically links** the Cubism Core into `pet_live2d_plugin.dll`, so a **build embeds that Core binary** and distributing it is likewise subject to those licenses (carry the license text). `.moc3` supports versions 3.0–5.3. Please follow Live2D Inc.'s terms when using the Live2D features.
