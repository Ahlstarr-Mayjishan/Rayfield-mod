# Changelog

## 2026-02-17

### Added
- Added all-in-one GitHub commit watcher with optional auto UI reload:
  - `autoReload` / `autoReloadEnabled`
  - `autoReloadInterval`
  - `autoReloadRepo`
  - `autoReloadBranch`
  - `autoReloadClearCache`
  - new loader methods: `checkForUpdates`, `reloadNow`, `startAutoReload`, `stopAutoReload`, `setAutoReloadCallback`
- Added new tab slider variants:
  - `Tab:CreateTrackBar(settings)` (draggable, no numeric text)
  - `Tab:CreateStatusBar(settings)` (rounded, taller bar with in-bar text)
- Added slider variant aliases:
  - `CreateDragBar` and `CreateSliderLite` -> `CreateTrackBar`
  - `CreateInfoBar` and `CreateSliderDisplay` -> `CreateStatusBar`
- Added unified animation core package:
  - `src/core/animation/engine.lua`
  - `src/core/animation/public.lua`
  - `src/core/animation/sequence.lua`
  - `src/core/animation/ui.lua`
  - `src/core/animation/text.lua`
  - `src/core/animation/easing.lua`
  - `src/core/animation/cleanup.lua`
- Added new public base API:
  - `Rayfield.Animate(...)`
  - `Rayfield.Animate.UI(...)`
  - `Rayfield.Animate.Text(...)`
  - `Rayfield:GetAnimationEngine()`
- Added tween guardrail script:
  - `scripts/verify-no-direct-tweencreate.lua`
- Added unified animation smoke regression:
  - `tests/regression/test-unified-animation-api.lua`
- Added canonical orchestration split for modified entry:
  - `src/entry/rayfield-modified.runtime.lua`
  - `src/core/runtime-env.lua`
  - `src/core/window-controller.lua`
  - `src/ui/window/init.lua`
  - `src/ui/topbar/init.lua`
  - `src/ui/tabs/init.lua`
  - `src/ui/notifications/init.lua`
- Added deep feature split scaffolding (non-breaking wrappers):
  - Drag: `src/feature/drag/controller.lua`, `detach-gesture.lua`, `merge-indicator.lua`, `cleanup.lua`
  - TabSplit: `src/feature/tabsplit/controller.lua`, `zindex.lua`, `hover-effects.lua`, `layout-free-drag.lua`
  - Enhanced: `src/feature/enhanced/create-enhanced-rayfield.lua`, `error-manager.lua`, `garbage-collector.lua`, `remote-protection.lua`, `memory-leak-detector.lua`, `profiler.lua`
  - Mini-window: `src/feature/mini-window/controller.lua`, `layout.lua`, `drag.lua`, `dock.lua`
- Added elements canonical split entrypoints:
  - `src/ui/elements/factory/init.lua`
  - `src/ui/elements/factory/create-tab.lua`
  - `src/ui/elements/factory/create-section.lua`
  - `src/ui/elements/common/*`
  - `src/ui/elements/widgets/index.lua`
  - `src/ui/elements/widgets/button.lua`
  - `src/ui/elements/widgets/toggle.lua`
  - `src/ui/elements/widgets/dropdown.lua`
  - `src/ui/elements/widgets/slider.lua`
  - `src/ui/elements/widgets/input.lua`
  - `src/ui/elements/widgets/keybind.lua`
- Added architecture document:
  - `Documentation/architecture/module-boundaries.md`
- Added canonical test tree:
  - `tests/smoke/rayfield-smoke-test.lua`
  - `tests/regression/test-animation-api.lua`
  - `tests/helpers/assert.lua`
- Added validation scripts:
  - `scripts/verify-module-map.lua`
  - `scripts/verify-no-direct-httpget.lua`

### Changed
- Changed runtime module map/registry/manifest to include unified animation modules.
- Changed core runtime to initialize one shared animation engine and bind it onto `RayfieldLibrary`.
- Changed animation call-sites in canonical runtime/UI/features to use shared animation layer (`Animation:Create`) instead of direct `TweenService:Create`.
- Changed API loader to canonical-only resolution (no automatic legacy path fallback in `src/api/loader.lua`).
- Changed animation regression `tests/regression/test-animation-api.lua` to validate unified `Rayfield.Animate` surface instead of legacy advanced bridge.
- Changed canonical elements mapping from:
  - `src/ui/elements/factory.lua` -> `src/ui/elements/factory/init.lua`
  - `src/ui/elements/widgets/extracted.lua` -> `src/ui/elements/widgets/index.lua`
- Changed `src/entry/rayfield-modified.entry.lua` to orchestration-only entry that delegates runtime behavior to `src/entry/rayfield-modified.runtime.lua`.
- Updated `src/api/registry.lua`, `src/entry/module-map.lua`, and `src/manifest.json` to align canonical `src/feature/*` paths and new split module structure.
- Updated `src/README.md` with current canonical tree and split status.
- Reintroduced top-level test entry files as compatibility wrappers:
  - `rayfield-smoke-test.lua`
  - `test-animation-api.lua`

### Removed
- Removed canonical export of `RayfieldAdvanced.AnimationAPI` from `src/feature/enhanced/advanced.lua`.
- Removed enhanced bridge method `GetAnimateFacade()` from `src/feature/enhanced/create-enhanced-rayfield.lua`.
- Removed compatibility regression script `tests/compatibility/legacy-wrapper-parity.lua`.

## 2026-02-16

### Added
- Officialized `AnimationAPI:GetActiveAnimationCount()` for runtime visibility of live tweens.
- Added `AnimationAPI:Sequence(guiObject)` for chaining animation steps.
- Added layered `src/` architecture scaffold:
  - `src/api`
  - `src/core`
  - `src/services`
  - `src/ui`
  - `src/feature`
  - `src/legacy`
  - `src/entry`
- Added shared Lua API loading layer:
  - `src/api/client.lua`
  - `src/api/cache.lua`
  - `src/api/resolver.lua`
  - `src/api/registry.lua`
  - `src/api/loader.lua`
  - `src/api/errors.lua`
- Added legacy wrapper helper:
  - `src/legacy/forward.lua`
- Added build/manifest foundation:
  - `scripts/build-rayfield.lua`
  - `src/manifest.json`
- Added tab split panel system (hold 3 seconds on a tab, then drag outside main UI to split).
- Added multi split-panel support with dock-back flow by hold-dragging panel header into main `TabList`.
- Added `CreateWindow` options for tab splitting:
  - `EnableTabSplit`
  - `TabSplitHoldDuration`
  - `AllowSettingsTabSplit`
  - `MaxSplitTabs`

### Changed
- Bumped `RayfieldAdvanced.Version` from `1.0.0` to `1.1.0`.
- Hardened `test-animation-api.lua` to load advanced module from a commit-pinned raw URL.
- Added preflight checks in `test-animation-api.lua` to fail fast on stale/wrong artifacts.
- Improved Test 1 timing checks with `waitUntil(...)` to reduce false negatives on slower executors.
- Updated all-in-one cache keying from `name` to `name|url` to prevent stale module reuse across URL changes.
- Updated all-in-one auto-exec return strategy:
  - default first-run return is now lightweight loader table
  - exported UI remains accessible via `_G.Rayfield` and `_G.RayfieldUI`
  - configurable via `autoExecuteReturn = "loader" | "ui" | "none"`.
- Synced split panel visibility with main UI hide/minimize transitions.
- Updated split-panel docking UX to support drop-to-dock by dragging panel header into main `TabList`.
- Updated split-panel layout behavior to `Free drag + clamp` (manual panel position is preserved).
- Updated first-use UX by prewarming split/detach layers to reduce first drag hitch.
- Updated split-tab drag ghost movement to frame-synced follow for smoother first long-hold drag.
- Updated tab split gesture visuals to use element-style hold/ready border cue on tab buttons.
- Updated hover/hold visual style to soft multi-layer glow (blur-like) to avoid harsh bright outlines.
- Tuned glow thickness/transparency to a thinner, subtler profile across tabs, split panels, and detach/tab-split cues.
- Changed `Main loader/rayfield-modified.lua` module loading to hybrid fallback order:
  - prefer `src/*` runtime modules
  - fallback to legacy `feature/*` modules
- Changed all-in-one canonical location to `Main loader/rayfield-all-in-one.lua` while preserving old URL compatibility via wrapper at `feature/rayfield-all-in-one.lua`.
- Changed repository module organization so canonical logic is now under `src/*`; legacy files under `feature/*` and `Main loader/*` now forward through `src/legacy/forward.lua`.
- Replaced PowerShell build tooling with Lua-only build script (`scripts/build-rayfield.lua`).

### Fixed
- Fixed animation collision risk by keying active tween tracking by `Instance` instead of `tostring(guiObject)`.
- Added deterministic animation cleanup on object removal/destruction (`AncestryChanged` + `Destroying` hooks).
- Optimized `AnimationAPI:Pulse()` to use a single repeat/reverse tween cycle instead of chained bounce spawning.
- Restored full startup animation pipeline in `CreateWindow` so loading intro transitions cleanly into the main UI.
- Fixed loading overlay persistence by explicitly finalizing startup visibility state (`LoadingFrame` hidden, `Topbar`/`TabList`/`Elements` visible).
- Fixed `UIState` topbar reference bug (`self.Main.self.Topbar` -> `self.Topbar`) in hide/unhide transitions.
- Fixed `UIState` drag-bar dependency usage by injecting `dragBar`, `dragOffset`, and `dragOffsetMobile` via init context.
- Fixed split-tab content visibility/interaction by applying and restoring `ZIndex` for `TabPage` descendants during split/dock.
- Fixed split-panel hover feedback with explicit border glow state for hover and drag.
- Fixed tab hover polish with consistent hover transitions on tab buttons.
- Fixed element detach cue styling to use stronger glow/hold/ready feedback during hold-drag.
- Fixed split-panel hover state sticking by switching to explicit hover booleans instead of counter-based accumulation.
- Fixed residual idle glow by forcing detach/split cue glow transparency to fully hide (`1`) when not hovered/holding.
- Fixed re-run-after-destroy crash by resetting global Rayfield cache/state on `Rayfield:Destroy()` and invalidating stale cached base modules in all-in-one loader.

## 2026-02-15

### Fixed
- Updated exploiter runtime module URLs to the correct GitHub repo owner/path.
- Added shared `MODULE_BASE_URL` usage in `Main loader/rayfield-modified.lua`.
- Fixed all-in-one URL mapping for:
  - `Main loader/rayfield-modified.lua`
  - `feature/rayfield-enhanced.lua`
  - `feature/rayfield-advanced-features.lua`
- Fixed minimized-state handling in elements modules by injecting `getMinimised`.
- Stabilized `Tab:Clear()` flow against concurrent tracking modifications.
- Added lifecycle cleanup for `MemoryLeakDetector`:
  - `stopMonitoring()`
  - `destroy()`
  - cleanup on shutdown and explicit `Rayfield:Destroy()`.

### Notes
- These changes target executor/exploiter runtime reliability.
- Studio-only flow remains secondary.
