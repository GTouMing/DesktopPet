<h1><a href="README_CN.md">桌宠</a>&nbsp;|&nbsp;Desktop Pet</h1>

A desktop pet application built with Flutter, supporting both **Windows** and **Android**.

On Windows a single full-desktop transparent overlay window hosts every pet, the radial quick-launch dial and the tray icon, while the settings form opens in a separate child window on demand; on Android each pet is its own system overlay window floating above any app. Every pet is driven by a **JSON skin definition** — animations, behaviors and interaction triggers are all configurable, and you can import your own `.zip` skin packages.

![platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android-blue)

## Features

- **Multiple pets at once**: Create several pets, each with its own position, scale and behavior — fully independent of one another. On Windows they share one overlay scene; on Android each gets its own system overlay window.
- **Wander anywhere**: Pets are not pinned to one corner. They move around on their own, and respond to your clicks, drags and pokes.
- **Behavior state machine**: `skin.json` declares states and transition rules (click, drag, timers, direction, arrival, animation complete, global hotkeys, etc.), combined with programmable transform expressions (scale / rotation / offset / opacity with `sin/cos/lerp/clamp`) for lively animation.
- **The desktop stays usable**: the overlay is frameless, transparent and permanently **click-through** (the system skips it during hit-testing), so pets can never block anything else on your desktop. Each pet can be locked/unlocked; a locked pet neither reacts to the mouse nor takes part in hit-testing.
- **Global hotkeys**: A state's `hotkey` rule in the skin JSON becomes a system-wide shortcut (e.g. `Ctrl+Alt+S` to sleep, `Ctrl+Alt+K` to walk to the screen edge). *Which* state a key applies in is decided entirely by the skin data: on press the app looks up “current state + combo”.
- **Sound effects**: declare `audio` / `audioVolume` on a state and it plays on entry (`assets/...` for bundled resources, an absolute path for local files). The built-in skin ships no audio assets yet — fill one in and it plays.
- **Quick Launch (Windows)**: Hold the middle mouse button to summon a radial quick-launch dial (up to 8 apps); release over an item to launch it.
- **System tray (Windows)**: Lock / unlock all pets, open settings, and quit.
- **Skin system**:
  - Built-in default skin (idle / walk / sleep / happy / eat / drag animations).
  - One-click import from **ZIP skin packages** — automatically extracted, validated and registered.
  - Configurable **custom skin directory**, auto-scanned for packages, with one-click migration of already-imported skins.
- **Settings hub**: Global scale / opacity / playback speed (multiplied with each pet's own multipliers), applied live across all pets.
- **Persistence**: MMKV multi-process storage — config changes are written back and broadcast to every pet in real time.

## Platform Support

| Platform | Form                                                                   | Notes                                                                                                                   |
|----------|------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| Windows  | Full-desktop transparent overlay + settings child window + system tray | Single engine: every pet and the radial dial are drawn in one overlay window; settings open in a child window on demand |
| Android  | System overlay window (one per pet)                                    | Requires the "display over other apps" permission; multiple overlays supported                                          |

> Other platforms (Linux / macOS / iOS) throw an `UnsupportedError` at startup and are not currently supported.

## Getting Started

### Prerequisites

- Flutter SDK `^3.12.2` (Dart `^3.12.2`)
- Windows: Windows 10 / 11
- Android: Android 7.0+ (API 24+; overlays need system authorization)

### Run

```bash
flutter pub get
flutter run -d windows   # Windows desktop
flutter run -d <device>  # Android device / emulator
```

On first launch the app seeds default data in the app documents directory and creates a pet named "默认桌宠" (Default Pet).

### Build & Release

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
├── core/                         # Leaf layer: constants, enums, DPR, shared scene state, cross-engine messages
├── input/                        # Global input: InputService / KeyRegistry / platform input source
├── pet/                          # Pet runtime: state machine, behavior, animation, hotkeys, pointer routing
│   ├── pet_notifier.dart         #   State manager (Riverpod StateNotifier)
│   ├── pet_state.dart            #   Runtime state snapshot of a pet
│   ├── pet_providers.dart        #   petId / petState providers
│   ├── pet_metrics.dart          #   Derived render values (global × per-pet, pure functions)
│   ├── pet_window_binding.dart   #   Android-only system overlay sync
│   ├── behavior_engine.dart      #   Target generation & interpolation, direction/arrival events
│   ├── pet_pointer_router.dart   #   Hook pointer events → per-pet hit-testing and dragging
│   ├── hotkey_engine.dart        #   Skin `hotkey` rules → global input layer
│   ├── pet_animation.dart        #   Load & play a single animation (loop / repeat)
│   ├── pet_widget.dart           #   Rendering widget (sprite sheet + transform + opacity)
│   └── pet_context.dart          #   Context interface consumed by the behavior engine
├── skin/                         # Skin system
│   ├── skin_package.dart         #   Skin package model (animations / states / skin.json)
│   ├── expression.dart           #   Lightweight expression evaluator (sin/cos/lerp/clamp…)
│   ├── audio/                    #   Per-state sound service (plays on state entry; built-in skin ships none)
│   ├── sheet/                    #   Frame PNG → sprite atlas (runtime stitching) + renderer
│   ├── import/                   #   ZIP import, validation, repository, directory migration
│   └── state/  animation/        #   JSON models for states / animations
├── platform/                     # Platform abstraction & implementations
│   ├── window_interface.dart     #   WindowController abstract interface (Android only)
│   ├── windows/                  #   Windows: host wiring, overlay/settings channels, tray
│   └── android/                  #   Android: multi overlay (vendored plugin), settings-change broadcast
├── shortcut/                     # Quick launch: ring geometry & painting, host gesture machine, icon extraction
├── storage/                      # MMKV persistence + data models (settings / pets / skins / shortcuts)
└── ui/
    ├── common/                   #   Main list, pet editor, skin picker, language, dialogs
    │   └── settings/             #   Settings page split into sections (appearance / skin / shortcuts / language / about)
    ├── host/                     #   Roots of the two windows and their support pieces
    │   ├── overlay_scene.dart    #     The pet overlay scene (every pet + the radial dial)
    │   ├── settings_window_root.dart #  Settings window root
    │   ├── scene_geometry.dart   #     Scene geometry (= desktop geometry) and DPR conversion
    │   ├── grab_rects.dart       #     Publishes pet rectangles to the global hook
    │   └── settings_window_channel.dart # Listens for "storage changed" from the settings window
    ├── android/                  #   Content of one pet's system overlay
    └── widgets/                  #   Shared widgets (window frame, pet list/card, info overlay)
```

## Skin Packages

A skin is a directory containing `skin.json` plus animation frame images; `frameWidth/frameHeight` define the single-frame canvas.

- The **built-in skin** lives in `assets/default_skin/`.
- **Imported skins** are extracted to `<app documents>/imported_skins/<petId>/` by default, or to `<skinDir>/<petId>/` when a custom skin directory is configured.
- **Custom directory**: pick any folder in Settings to use as the skin directory; every subdirectory containing a `skin.json` is discovered automatically.

### skin.json Reference

| Field                        | Description                                                                                                                 |
|------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `name` / `version`           | Skin name and version                                                                                                       |
| `frameWidth` / `frameHeight` | Single-frame canvas size (logical pixels)                                                                                   |
| `initialState`               | Initial state name (defaults to `idle`)                                                                                     |
| `animations`                 | Animation definitions: `{ folder, fps, frameCount, framePrefix?, frameStart? }`; frames are `folder/0.png`, `folder/1.png`… |
| `states`                     | State definitions: reference an animation + optional behavior + transform expressions + transitions                         |

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

## Usage

**Interacting with a pet**
- Click → fires an interaction (e.g. idle → happy).
- Drag → pick the pet up and drop it anywhere; it is clamped to the screen.
- Lock / click-through → lock or unlock from the tray. A locked pet ignores the mouse entirely (perfect as a pure decorative overlay).

**Managing pets**
- The main window lists every pet, letting you:
  - Create a pet (name it, pick a skin, adjust scale / opacity / speed)
  - Edit or delete existing pets
- Global settings tune base scale, opacity and animation speed for all pets (multiplied with per-pet multipliers).

**Quick Launch (Windows)**
- Hold the **middle mouse button** (~1 s) to summon the radial dial around the pet.
- Keep holding and move the cursor onto a button, then release to launch that app.
- Manage items under "Settings → 快捷启动应用" (add / edit / reorder / delete), up to 8 items.

**System tray (Windows)**
- Lock / unlock all pets, show the main window (settings), and quit.

## Technical Highlights

- **Single-overlay architecture (Windows)**: every pet and the radial quick-launch dial are drawn in one full-desktop transparent overlay, and the settings form opens on demand in a `desktop_multi_window` child engine. The desktop stays usable because that window is permanently `WS_EX_LAYERED | WS_EX_TRANSPARENT` — the system skips it during hit-testing, so not even a hung Flutter side can block a click.
- **Global input hooks**: the overlay receives no mouse messages, so pet clicks/drags and global hotkeys all go through process-wide `WH_MOUSE_LL` / `WH_KEYBOARD_LL` hooks. Dart publishes each unlocked pet's rectangles as "grabbable regions"; the hook forwards pointer events only inside them and *swallows* the press so it never reaches the window underneath.
- **Single-instance lock**: On Windows a mutex (`flutter_alone`) guarantees a single overlay instance; relaunching focuses the existing instance instead.
- **Cross-process storage**: MMKV is opened in `MULTI_PROCESS_MODE`, so all engines share one config store; writes trigger a broadcast refresh callback.
- **Runtime sprite atlas**: Frame PNGs are stitched into one GPU-friendly atlas at runtime (sides capped at ≤ 4096 px with an optimal auto grid), drawn frame-by-frame via `CustomPaint` to cut texture-switch overhead. Atlases are **cached on disk** per (skin, animation): the expensive decode-and-stitch pass happens once per skin, shared by every pet engine and reused across restarts.
- **Locking & dragging**: on Windows "locked" simply means the pet's rectangle is not published to the hook, so clicking it is clicking the desktop; dragging is pure Dart scene-coordinate movement (the raw click was already swallowed by the hook). On Android each pet is a real system overlay window, so "locked" uses `FLAG_NOT_TOUCHABLE` for whole-window pass-through and dragging is handed to the OS window drag (`startDragging`).
- **Expression evaluator**: A tiny hand-written recursive-descent parser lets skin transforms be authored as plain math formulas — bouncing, swaying and breathing effects with zero code changes.
- **State ownership**: three kinds of state, each with exactly one source of truth — kept deliberately separate:
  1. **Persisted data** (settings / pets / skins / shortcuts): owned by `StorageService`, which **broadcasts on every write** (the `changes` stream). The UI only reads `appDataProvider` — a plain `Provider` driven by that stream — so there is **no** manual `ref.invalidate` anywhere. Across engines only one fact is sent ("storage changed"): a dmw message on Windows, the native `settings_updated` on Android; the receiving side just calls `notifySettingsChanged()`, and the rest of the refresh is identical to the in-engine case.
  2. **Transient scene state** (scene size, pet rectangles, the frozen pet, the ring presentation): in-process, never persisted, written only by `OverlayScene` / `QuickLaunchInputHost`, read-only everywhere else.
  3. **Process-level services** (`InputService` / `ShortcutLauncher` / tray / settings-window host): must exist before `runApp` or across window roles, so they stay singletons — but they are only driven from the assembly points (`main` / `AppHost`).

## Roadmap

- [x] Wire global hotkeys (skin `hotkey` rules now go through the global input layer)
- [x] Wire up skin audio (entering a state plays its `audio` at `audioVolume`; the built-in skin ships no audio assets yet)
- [ ] More events & behaviors (feeding, dialogue, weather…)
- [ ] Pet-to-pet interaction (approach, chase, hang out together)
- [ ] More platform support

## License

This project is licensed under the [MIT](LICENSE) license.
