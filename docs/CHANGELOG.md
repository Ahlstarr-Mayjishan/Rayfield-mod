# Changelog

## 2026-02-25

### Added
- Added Premium UX Pack v1 runtime APIs:
  - `SetAudioFeedbackEnabled`, `IsAudioFeedbackEnabled`, `SetAudioFeedbackPack`, `GetAudioFeedbackState`, `PlayUICue`
  - `SetGlassMode`, `GetGlassMode`, `SetGlassIntensity`, `GetGlassIntensity`
- Added Guided Tour V2 overlay (spotlight masks + step navigation + replay support) while keeping onboarding API signatures unchanged.
- Added premium settings controls in Rayfield Settings tab:
  - Audio enable/pack + custom JSON pack apply
  - Glass mode + intensity
  - Replay Guided Tour
- Added Premium UX regression test:
  - `tests/regression/test-premium-ux-pack.lua`

### Changed
- Changed element factory interaction flow to emit premium cues on:
  - hover (via extended API hover binding)
  - click/success/error paths for `Button`, `Toggle`, `Dropdown`, `Input`, `Keybind`, `ConfirmButton`
- Changed theme fallback map with glass keys:
  - `GlassTint`, `GlassStroke`, `GlassAccent`
- Changed runtime diagnostics payload to include `experience` state:
  - audio enabled/pack, glass mode/resolved mode/intensity, onboarding suppression
- Changed runtime visibility transitions (`Hide/Unhide/Minimise/Maximise/SetVisibility`) to re-apply glass layer.

## 2026-02-24

### Added
- Added Element Expansion Pack v1 (additive, no breaking changes):
  - New tab factories: `CreateCollapsibleSection`, `CreateNumberStepper`, `CreateConfirmButton`, `CreateImage`, `CreateGallery`, `CreateChart`, `CreateLogConsole`.
  - `CreateDropdown` searchable extension: `SearchEnabled`, `SearchPlaceholder`, `ResetSearchOnRefresh`, methods `SetSearchQuery/GetSearchQuery/ClearSearch`.
  - Extended element API tooltip methods: `SetTooltip(textOrOptions)`, `ClearTooltip()`.
  - Collapsible section hybrid layout behavior:
    - implicit grouping for subsequent elements
    - explicit override via `ParentSection`.
  - Chart push API + viewport state:
    - `AddPoint`, `SetData`, `GetData`, `Zoom`, `Pan`.
  - Log console capture modes:
    - `manual`, `global`, `both` (`global` backed by `LogService.MessageOut` fan-out hub).
  - Image URL fallback behavior:
    - when executor asset bridge is unavailable, URL source falls back safely to empty asset.
- Added UI Experience Pack v1:
  - Theme Studio full key editor (live preview, base theme + custom packed colors).
  - UI Presets (`Compact`, `Comfort`, `Focus`) with non-destructive behavior bundles.
  - Favorites/Pin system with per-element pin badge + Favorites manager.
  - Global Transition Profiles (`Minimal`, `Smooth`, `Snappy`, `Off`) wired into animation engine.
  - Onboarding overlay flow with suppression checkbox text: `Don't show this again`.
- Added public APIs on base runtime:
  - `SetUIPreset`, `GetUIPreset`
  - `SetTransitionProfile`, `GetTransitionProfile`
  - `ListControls`, `PinControl`, `UnpinControl`, `GetPinnedControls`
  - `ShowOnboarding`, `SetOnboardingSuppressed`, `IsOnboardingSuppressed`
  - `GetThemeStudioState`, `ApplyThemeStudioTheme`, `ResetThemeStudio`
- Added element-level favorites APIs:
  - `Element:GetFavoriteId()`
  - `Element:Pin()`
  - `Element:Unpin()`
  - `Element:IsPinned()`

### Changed
- Changed settings defaults:
  - added internal `Layout.collapsedSections` for collapsible section persistence.
- Changed runtime element module init to pass internal settings callbacks:
  - `getInternalSetting(category, key)`
  - `setInternalSetting(category, key, value, persist?)`
- Changed theme schema with additive keys + fallback consistency:
  - `TooltipBackground`, `TooltipTextColor`, `TooltipStroke`
  - `ChartLine`, `ChartGrid`, `ChartFill`
  - `LogInfo`, `LogWarn`, `LogError`
  - `ConfirmArmed`, `SectionChevron`
- Changed settings system:
  - added internal categories `Appearance`, `Favorites`, `Onboarding`, `ThemeStudio`
  - added dropdown renderer support in generic settings UI
  - added experience handler injection channel (`setExperienceHandlers`)
- Changed animation engine to support runtime transition profiles and profile-aware tween scaling.
- Changed runtime window boot flow to restore experience settings in order:
  - transition profile -> ui preset -> theme studio -> favorites -> onboarding decision.

## 2026-02-20

### Added
- Added executor compatibility service:
  - `src/services/compatibility.lua`
  - unified helpers for `getService`, `getCompileString`, GUI container resolve, protect/parent, and duplicate GUI cleanup.
- Added production bundle builder:
  - `scripts/build-bundle.lua`
  - outputs:
    - `dist/rayfield-runtime-core.bundle.lua`
    - `dist/rayfield-runtime-ui.bundle.lua`
    - `dist/rayfield-production.bootstrap.lua`
- Added bundle runtime globals (non-breaking):
  - `_G.__RAYFIELD_BUNDLE_SOURCES`
  - `_G.__RAYFIELD_BUNDLE_MODE`
- Added leak cause attribution APIs on enhanced memory detector:
  - `setAttributionPolicy(policy)`
  - `getAttributionReport()`
- Added enhanced passthrough API:
  - `EnhancedRayfield:GetAttributionReport()`
- Added runtime diagnostics provider on base runtime:
  - `Rayfield:GetRuntimeDiagnostics()`
  - includes animation/text/theme visibility diagnostics for attribution.
- Added layout persistence service:
  - `src/services/layout-persistence.lua`
  - internal layout namespace key: `__rayfield_layout`
  - supports debounced config save and ordered apply (`main -> split -> floating`).
- Added viewport virtualization/hibernation service:
  - `src/services/viewport-virtualization.lua`
  - event-based sleep/wake with spacer preservation (no `while true`)
  - default always-on policy with overscan + throttled updates
  - wired for main tab hosts, split tab panels, detached floating hosts, and mini-window scrolling hosts.
- Added low-spec loader profile support in `CreateWindow` (opt-in, non-breaking):
  - `Settings.PerformanceProfile = { Enabled, Mode, Aggressive, DisableDetach, DisableTabSplit, DisableAnimations, ViewportVirtualization }`
  - hybrid auto/manual profile resolution
  - performance-first auto rule: touch => `mobile`, non-touch => `potato`.

### Changed
- Changed API client fetch path to `bundle-first` behavior with safe fallback:
  - `src/api/client.lua` now resolves bundled sources before `game:HttpGet`.
  - `fetchAndExecute` retries once via network when bundled source fails compile/execute.
- Changed API loader to mark bundle mode automatically when bundle sources are present:
  - `src/api/loader.lua`
- Changed runtime GUI parenting/dedup logic to use compatibility service instead of repeated inline branches:
  - `src/entry/rayfield-modified.runtime.lua`
- Changed runtime env service resolution to reuse compatibility service:
  - `src/core/runtime-env.lua`
- Changed memory leak detector defaults to UI-centric scanning:
  - `src/feature/enhanced/create-enhanced-rayfield.lua`
  - new scan modes: `ui`, `mixed`, `game`
  - new APIs: `setScanMode`, `setScanRoots`
- Changed memory leak response flow to classification-based handling:
  - weighted cause attribution (`rayfield_ui` vs `unknown`)
  - emergency cleanup now only runs when cause is confirmed `rayfield_ui` across configured confirm cycles.
- Changed unknown-cause path to notification-only behavior (no emergency trigger, no warn spam).
- Changed configuration pipeline to persist and restore UI layout (non-breaking):
  - `ConfigurationSaving.Layout = { Enabled, DebounceMs }`
  - layout now merges into existing config payload and is applied after element flags.
- Changed runtime initialization to wire viewport virtualization into elements/drag/tabsplit:
  - `src/entry/rayfield-modified.runtime.lua`
  - wake path now re-syncs element state and hover evaluation.
- Changed drag/tabsplit lifecycle to emit host/element move and busy signals for virtualization:
  - `src/feature/drag/controller.lua`
  - `src/feature/drag/detacher.lua`
  - `src/feature/tabsplit/controller.lua`
- Changed mini-window controller to register/unregister virtualization host and widget elements:
  - `src/feature/mini-window/controller.lua`
- Changed drag module to support runtime detach gating:
  - `src/feature/drag/controller.lua`
  - when low-spec profile disables detach, element detach API is not attached and drag snapshot methods return lightweight defaults.
- Changed runtime `CreateWindow` pipeline to resolve and apply performance profile before window bootstrap:
  - `src/entry/rayfield-modified.runtime.lua`
  - profile diagnostics exposed via `_G.__RAYFIELD_LOADER_DIAGNOSTICS.performanceProfile`.
- Changed configuration apply flow for heavy config files:
  - `src/services/config.lua`
  - flags are now applied in tab-priority batches instead of one unordered full pass
  - each applied element gets a lightweight fade-in to smooth visual load.

### Fixed
- Fixed potential stale theme bindings by tracking per-object/per-property bindings and disconnecting on lifecycle events:
  - `src/services/theme.lua`
  - `Destroying` primary cleanup + `AncestryChanged` fallback.
- Reduced risk of periodic FPS spikes from full-game descendant scans in enhanced memory leak monitor by defaulting to Rayfield UI root scope.

## 2026-02-17

### Added
- Added dynamic sequence keybind service:
  - `src/services/keybind-sequence.lua`
  - canonical sequence format with max 4 steps and 800ms default step timeout
- Added sequence support to `Tab:CreateKeybind(settings)` with custom parse/display hooks:
  - `DisplayFormatter(canonical, steps)`
  - `ParseInput(text)`
  - `MaxSteps`
  - `StepTimeoutMs`
- Added toggle keybind UI and wrappers:
  - `Tab:CreateToggle(settings)` now supports `Keybind = { ... }`
  - `Tab:CreateToggleBind(settings)`
  - `Tab:CreateHotToggle(settings)`
  - keybind box renders on the left side of toggle switch when enabled
- Added sequence support for window setting `ToggleUIKeybind` (single key or multi-step canonical sequence).
- Added keybind-sequence regression script:
  - `tests/regression/test-keybind-sequence.lua`
  - root wrapper: `test-keybind-sequence.lua`
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
- Added shared widget bootstrap contract:
  - `src/ui/elements/widgets/bootstrap.lua`
  - standardized fail-fast error codes (`E_CLIENT_MISSING`, `E_CLIENT_INVALID`, `E_ROOT_INVALID`, `E_TARGET_INVALID`, `E_FETCH_FAILED`, `E_EXPORT_INVALID`)
  - structured branch tracing with `branch_id`
- Added widget bootstrap regression test:
  - `tests/regression/test-widget-bootstrap.lua`
- Added architecture document:
  - `docs/architecture/module-boundaries.md`
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
- Hardened drag/reorder behavior for main UI:
  - in-place reorder is now handled during hold-drag-drop inside current tab page
  - detached -> main dock preview and dock insertion use consistent candidate filtering
  - `src/feature/drag/dock.lua` now enforces `UIListLayout.SortOrder = LayoutOrder` when applicable
- Hardened hover synchronization for fast tab switching/mouse movement:
  - detach cue now re-syncs with pointer and page lifecycle changes
  - element hover state in canonical elements factory is tracked by a per-tab hover registry with throttled sync
- `src/ui/elements/widgets/index.lua` now forwards to canonical `src/ui/elements/factory/init.lua` to avoid behavior drift.
- Widget wrappers (`src/ui/elements/widgets/*.lua`) now route through one canonical bootstrap branch tree instead of per-file ad-hoc checks.
- Dropdown state pipeline is now normalized and deterministic:
  - `normalize -> visual -> callback -> persist`
  - supports `DefaultSelection` fallback on clear/refresh when selection becomes invalid
  - supports `ClearBehavior = "default" | "none"`
  - auto-fallback emits callback and persists normalized state
- Added canonical element sync service (`src/services/element-sync.lua`) and wired core stateful elements
  (`Dropdown`, `Toggle`, `Input`, `Slider`, `TrackBar`, `StatusBar`) to one shared commit contract.

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
