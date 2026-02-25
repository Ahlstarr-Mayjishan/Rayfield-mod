# API Reference

This file documents the public runtime API used by scripts in exploiter environments.

## Base Library (`rayfield-modified.lua`)

Load:

```lua
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
))()
```

Production bundle load (ít request HTTP hơn):

```lua
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/dist/rayfield-production.bootstrap.lua"
))()
```

Main methods:
- `Rayfield:Notify(data)`
- `Rayfield:CreateWindow(settings)`
- `Rayfield:SetVisibility(boolean)`
- `Rayfield:IsVisible() -> boolean`
- `Rayfield:Destroy()`
- `Rayfield:LoadConfiguration()`
- `Rayfield:ImportCode(code) -> (boolean, string)`
- `Rayfield:ImportSettings() -> (boolean, string)`
- `Rayfield:ExportSettings() -> (string|nil, string)`
- `Rayfield:CopyShareCode() -> (boolean, string)`
- `Rayfield:SetUIPreset(name) -> (boolean, string)`
- `Rayfield:GetUIPreset() -> string`
- `Rayfield:SetTransitionProfile(name) -> (boolean, string)`
- `Rayfield:GetTransitionProfile() -> string`
- `Rayfield:ListControls() -> {id, tabId, name, type, flag, pinned}[]`
- `Rayfield:PinControl(idOrFlag) -> (boolean, string)`
- `Rayfield:UnpinControl(idOrFlag) -> (boolean, string)`
- `Rayfield:GetPinnedControls() -> string[]`
- `Rayfield:ShowOnboarding(force?) -> (boolean, string)`
- `Rayfield:SetOnboardingSuppressed(boolean) -> (boolean, string)`
- `Rayfield:IsOnboardingSuppressed() -> boolean`
- `Rayfield:SetAudioFeedbackEnabled(boolean) -> (boolean, string)`
- `Rayfield:IsAudioFeedbackEnabled() -> boolean`
- `Rayfield:SetAudioFeedbackPack(name, packDefinition?) -> (boolean, string)`
- `Rayfield:GetAudioFeedbackState() -> table`
- `Rayfield:PlayUICue(cueName) -> (boolean, string)`
- `Rayfield:SetGlassMode(mode) -> (boolean, string)`
- `Rayfield:GetGlassMode() -> string`
- `Rayfield:SetGlassIntensity(number0to1) -> (boolean, string)`
- `Rayfield:GetGlassIntensity() -> number`
- `Rayfield:GetThemeStudioState() -> table`
- `Rayfield:ApplyThemeStudioTheme(themeOrName) -> (boolean, string)`
- `Rayfield:ResetThemeStudio() -> (boolean, string)`
- `Rayfield:CreateFeatureScope(name?) -> (string|nil, string)`
- `Rayfield:TrackFeatureConnection(scopeId, connection) -> (boolean, string)`
- `Rayfield:TrackFeatureTask(scopeId, taskHandle) -> (boolean, string)`
- `Rayfield:TrackFeatureInstance(scopeId, instance, metadata?) -> (boolean, string)`
- `Rayfield:TrackFeatureCleanup(scopeId, cleanupFn) -> (boolean, string)`
- `Rayfield:CleanupFeatureScope(scopeId, destroyInstances?) -> (boolean, string)`
- `Rayfield:GetFeatureCleanupStats() -> table`
- `Rayfield:GetRuntimeDiagnostics() -> table`
- `Rayfield:GetAnimationEngine()`

### Share Code API

- Share code format: `RFSC1:<base64(json)>`
- Payload contract:
  - `type = "rayfield_share"`
  - `version = 1`
  - `configuration = table`
  - `internalSettings = table`
  - `meta = { generatedAt, interfaceBuild, release }`
- Import is strict and requires full payload (`configuration` + `internalSettings`).
- `ImportCode` only validates and stores active code.
- `ImportSettings` applies the active code payload and then auto-persists both config + internal settings.
- `ExportSettings` works even when `ConfigurationSaving.Enabled = false`.

### UI Experience API

- UI presets:
  - `SetUIPreset("Compact"|"Comfort"|"Focus"|"Cripware")`
  - Non-destructive: preset does not overwrite script business flags.
- Transition profiles:
  - `SetTransitionProfile("Minimal"|"Smooth"|"Snappy"|"Off")`
  - Applied globally through animation engine.
- Favorites:
  - `ListControls()` returns control metadata.
  - `PinControl/UnpinControl` accepts either favorite ID or raw `Flag`.
  - Element API also supports `GetFavoriteId/Pin/Unpin/IsPinned`.
- Theme Studio:
  - `GetThemeStudioState()` returns `{ baseTheme, useCustom, customThemePacked }`.
  - `ApplyThemeStudioTheme("ThemeName")` applies built-in theme.
  - `ApplyThemeStudioTheme({ key = Color3|{R,G,B}, ... })` applies custom palette.
- Onboarding:
  - `ShowOnboarding(true)` bypasses suppression.
  - Checkbox label in onboarding UI: `Don't show this again`.
- Audio feedback:
  - default state: `enabled = false`, `pack = "Mute"`.
  - custom pack contract:
    - `{ click, hover, success, error }` with values as `rbxassetid://...` (or numeric IDs).
  - `PlayUICue("click"|"hover"|"success"|"error")` uses current audio state.
- Glass mode:
  - `SetGlassMode("auto"|"off"|"canvas"|"fallback")`.
  - `auto` attempts canvas first when supported, otherwise degrades to fallback.
  - `SetGlassIntensity(0..1)` controls tint/stroke strength.

`CreateWindow` setting note:
- `ToggleUIKeybind` hỗ trợ key đơn (`"K"`) hoặc sequence canonical (`"LeftControl+K>LeftShift+M"`).
- `FastLoad` (optional, default: `true`):
  - giảm delay startup + thời lượng tween để UI lên nhanh hơn.
  - set `FastLoad = false` nếu muốn giữ timing animation cũ.
- `ConfigurationSaving.Layout` (optional):
  - `Enabled` (default: follow `ConfigurationSaving.Enabled`)
  - `DebounceMs` (default: `300`)
  - layout is stored internally under config key `__rayfield_layout`.
- `ViewportVirtualization` (optional, non-breaking):
  - `Enabled` (default: `true`)
  - `AlwaysOn` (default: `true`)
  - `FullSuspend` (default: `true`)
  - `OverscanPx` (default: `120`)
  - `UpdateHz` (default: `30`)
  - `FadeOnScroll` (default: `true`)
  - `DisableFadeDuringResize` (default: `true`)
  - `ResizeDebounceMs` (default: `100`)
  - `MinElementsToActivate` (default: `0`)
  - scope: main tab, split tab panels, detached floating windows, mini-window scrolling hosts.
- `PerformanceProfile` (optional, non-breaking, opt-in):
  - `Enabled` (default: `false`)
  - `Mode` = `"auto" | "potato" | "mobile" | "normal"` (default: `"auto"`)
  - `Aggressive` (default: `true`)
  - `DisableDetach` (optional override)
  - `DisableTabSplit` (optional override)
  - `DisableAnimations` (optional override)
  - `ViewportVirtualization` (optional override block for low-spec tuning)
  - behavior rules:
    - if `Enabled ~= true`: no behavior changes from legacy/default flow
    - if `Enabled == true`: profile only fills missing fields; explicit user settings win
    - `Mode="auto"` uses performance-first rule: touch device => `mobile`, non-touch => `potato`

### Unified Animation API

Rayfield now exposes a shared animation facade:

- `Rayfield.Animate(object, tweenInfo?, goals?)`
  - Returns sequence builder (supports `.SetInfo().To().Then().Wait().Call().Play()`).
  - Direct usage example: `Rayfield.Animate(frame, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()`
- `Rayfield.Animate.Create(object, tweenInfo, goals, opts?)`
  - Low-level tween creation (same semantics as `TweenService:Create`, no auto-play).
- `Rayfield.Animate.Play(object, tweenInfo, goals, opts?)`
  - Create + play shortcut.
- `Rayfield.Animate.UI(object)`
  - UI helpers: `FadeIn`, `FadeOut`, `Pop`, `SlideIn`, `SlideOut`.
- `Rayfield.Animate.Text(textObject)`
  - Text helpers: `Type`, `Ghosting`, `Scramble`, `Rainbow`, `Glow`.
  - Continuous effects return handle with `:Stop()` and `:IsRunning()`.
- `Rayfield.Animate.GetActiveAnimationCount()`
- `Rayfield.Animate.GetEngine()`

## Window + Tab API

Create:
- `Window:CreateTab(name, icon?, ext?)`

Tab element factories:
- `Tab:CreateButton(settings)`
- `Tab:CreateColorPicker(settings)`
- `Tab:CreateSection(sectionName)`
- `Tab:CreateCollapsibleSection(settings)`
- `Tab:CreateDivider()`
- `Tab:CreateLabel(text, icon?, color?, ignoreTheme?)`
- `Tab:CreateParagraph(settings)`
- `Tab:CreateInput(settings)`
- `Tab:CreateDropdown(settings)`
- `Tab:CreateNumberStepper(settings)`
- `Tab:CreateConfirmButton(settings)`
- `Tab:CreateImage(settings)`
- `Tab:CreateGallery(settings)`
- `Tab:CreateChart(settings)`
- `Tab:CreateLogConsole(settings)`
- `Tab:CreateLoadingSpinner(settings)`
- `Tab:CreateLoadingBar(settings)`
- `Tab:CreateKeybind(settings)`
- `Tab:CreateToggle(settings)`
- `Tab:CreateToggleBind(settings)` (wrapper bật keybind cho toggle)
- `Tab:CreateHotToggle(settings)` (alias của `CreateToggleBind`)
- `Tab:CreateKeybindToggle(settings)` (alias rõ nghĩa của `CreateToggleBind`)
- `Tab:CreateSlider(settings)`
- `Tab:CreateTrackBar(settings)`
- `Tab:CreateStatusBar(settings)`
- `Tab:CreateDragBar(settings)` (alias of `CreateTrackBar`)
- `Tab:CreateSliderLite(settings)` (alias of `CreateTrackBar`)
- `Tab:CreateInfoBar(settings)` (alias of `CreateStatusBar`)
- `Tab:CreateSliderDisplay(settings)` (alias of `CreateStatusBar`)

### New Slider Variants

`CreateTrackBar`:
- Drag bar without number/text display.
- Default `Draggable = true`.

`CreateStatusBar`:
- Rounded, taller status-style bar with centered text.
- Default text format is `current/max`.
- Supports `TextFormatter(current, max, percent)`.
- Default `Draggable = false`.

### Dynamic Sequence Keybind

`CreateKeybind` hỗ trợ sequence canonical (tối đa 4 bước, timeout mặc định 800ms):

- `CurrentKeybind = "LeftControl+A>LeftShift+K"`
- vẫn hỗ trợ key đơn cũ, ví dụ `"Q"`
- custom:
  - `DisplayFormatter(canonical, steps)` để đổi text hiển thị
  - `ParseInput(text)` để parse text nhập tay
  - `MaxSteps` (mặc định `4`)
  - `StepTimeoutMs` (mặc định `800`)

### Toggle With Keybind

`CreateToggle` hỗ trợ keybind riêng:

- `Keybind = {`
- `Enabled = true,`
- `CurrentKeybind = "LeftControl+T",`
- `DisplayFormatter = function(canonical, steps) ... end,`
- `ParseInput = function(text) ... end,`
- `MaxSteps = 4,`
- `StepTimeoutMs = 800,`
- `Flag = "MyToggleKeybindFlag" -- optional, để lưu config riêng`
- `}`

Khi `Keybind.Enabled = true`, toggle hiển thị ô keybind ở bên trái switch.
Keybind của toggle vẫn hoạt động khi UI đang hidden/minimized.

Tab utility methods:
- `Tab:GetElements()`
- `Tab:FindElement(name)`
- `Tab:Clear()`

## Extended Element API

Each created element is extended with:
- `:Destroy()`
- `:Show()`
- `:Hide()`
- `:SetVisible(boolean)`
- `:GetParent()`
- `:SetTooltip(textOrOptions)`
- `:ClearTooltip()`
- `:GetFavoriteId()`
- `:Pin()`
- `:Unpin()`
- `:IsPinned()`
- `.Name`
- `.Type`

If detach system is active, elements also expose:
- `:Detach(position?)`
- `:Dock()`
- `:GetRememberedState()`
- `:IsDetached()`

Dropdown special method:
- `Dropdown:Clear()`
- `Dropdown:SetSearchQuery(text)` (khi `SearchEnabled = true`)
- `Dropdown:GetSearchQuery()`
- `Dropdown:ClearSearch()`

Dropdown searchable mode:
- `SearchEnabled` (default: `false`)
- `SearchPlaceholder` (default: `"Search..."`)
- `ResetSearchOnRefresh` (default: `true`)
- search matcher: case-insensitive contains

Dropdown state normalization:
- `CurrentOption` is normalized internally as a table (including single-select).
- `DefaultSelection` (optional):
  - used as fallback when selection is cleared/invalid and `ClearBehavior` allows fallback.
- `ClearBehavior` (optional):
  - `"default"` (default): clear invalid/empty selection to `DefaultSelection` if valid, otherwise `None`.
  - `"none"`: clear to empty selection (`None`) without default fallback.
- `OnSelectionNormalized(selection, meta)` (optional callback):
  - receives normalized selection and metadata (`reason`, `fallbackApplied`, `changed`).

Element state sync contract (core stateful elements):
- `CreateDropdown`, `CreateToggle`, `CreateInput`, `CreateSlider`, `CreateTrackBar`, `CreateStatusBar`, `CreateLoadingSpinner`, `CreateLoadingBar`
  now run internal pipeline:
  - `normalize -> applyVisual -> emitCallback -> persist`
- auto-normalize/fallback paths emit callback and persist normalized value (unless `Ext`).

### Element Expansion Pack v1

`CreateNumberStepper(settings)`:
- `Name, Flag?, CurrentValue, Min, Max, Step, Precision, Callback`
- methods: `Set, Get, Increment, Decrement`
- persist: numeric value (`Flag` required)

`CreateConfirmButton(settings)`:
- `Name, Callback`
- `ConfirmMode = "hold" | "double" | "either"` (default: `hold`)
- `HoldDuration` default `1.2`
- `DoubleWindow` default `0.4`
- `Timeout` default `2.0`
- methods: `Arm, Cancel, SetMode, SetHoldDuration, SetDoubleWindow`

`CreateCollapsibleSection(settings)`:
- `Name, Id?, Collapsed?, PersistState?, ImplicitScope?`
- methods: `Collapse, Expand, Toggle, IsCollapsed, Set`
- hybrid grouping:
  - implicit: element tạo sau section sẽ vào section đó
  - explicit override: truyền `ParentSection = sectionObject` vào element settings
- collapsed state lưu ở internal settings: `Layout.collapsedSections`

`CreateImage(settings)`:
- `Name?, Flag?, Source, FitMode("fill"|"fit"), Height, CornerRadius, Caption?`
- methods: `SetSource, GetSource, SetFitMode, SetCaption`
- source hỗ trợ `rbxassetid://` + URL (best-effort theo executor)

`CreateGallery(settings)`:
- `Name, Flag?, Items, SelectionMode("single"|"multi"), Columns("auto"|number), Callback`
- methods: `SetItems, AddItem, RemoveItem, Select, Deselect, ClearSelection, SetSelection, GetSelection`
- persist: selected id(s)

`CreateChart(settings)`:
- `Name, Flag?, MaxPoints=300, UpdateHz=10, Preset?, ShowAreaFill=true`
- methods: `AddPoint(y, x?), SetData(points), GetData(), Clear(), SetPreset(name|nil), Zoom(factor), Pan(delta)`
- supports zoom buttons + drag pan
- persist: full retained snapshot (`points + viewport`, capped by `MaxPoints`)

`CreateLogConsole(settings)`:
- `Name, Flag?, CaptureMode("manual"|"global"|"both"), MaxEntries=500, AutoScroll=true, ShowTimestamp=true`
- methods: `Log(level,text), Info, Warn, Error, Clear, SetCaptureMode, GetEntries`
- global mode uses `LogService.MessageOut` (all output)
- persist: full retained entries (`MaxEntries` cap)

`CreateLoadingSpinner(settings)`:
- `Name, Flag?, Size, Thickness, Speed, AutoStart, Color, Callback, ParentSection?`
- methods: `Start, Stop, IsRunning, SetSpeed, GetSpeed, SetColor, SetSize`
- persist (optional): only when `Flag` is present

`CreateLoadingBar(settings)`:
- `Name, Flag?, Mode("indeterminate"|"determinate"), AutoStart, Speed, ChunkScale, Progress, ShowLabel, LabelFormatter, Height, Callback, ParentSection?`
- hybrid behavior:
  - default mode: `indeterminate`
  - `SetProgress(number)` auto-switches to `determinate`
- methods: `Start, Stop, IsRunning, SetMode, GetMode, SetProgress, GetProgress, SetSpeed, SetLabel`
- persist (optional): only when `Flag` is present

## Enhanced Wrapper (`rayfield-enhanced.lua`)

Load:

```lua
local Enhancement = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/feature/rayfield-enhanced.lua"
))()
```

Factory:
- `Enhancement.createEnhancedRayfield(originalRayfield)`
  - Returns:
    - `EnhancedRayfield`
    - `ErrorManager`
    - `GarbageCollector`
    - `RemoteProtection`
    - `MemoryLeakDetector`
    - `PerformanceProfiler`

Callback helper:
- `Enhancement.createHybridCallback(callback, identifier, errorManager, profiler, options)`
  - `options.mode`: `"protected"` or `"fast"`
  - `options.rateLimit`
  - `options.circuitBreaker`
  - `options.profile`

Added methods on `EnhancedRayfield`:
- `GetErrorManager()`
- `GetGarbageCollector()`
- `GetRemoteProtection()`
- `GetMemoryLeakDetector()`
- `GetProfiler()`
- `GetAnimationEngine()`
- `IsHealthy()`
- `GetErrorLog()`
- `ForceCleanup()`
- `GetMemoryReport()`
- `GetAttributionReport()`
- `GetPerformanceReport()`
- `GetAuditLog()`

Memory leak detector scan control:
- `detector:setScanMode("ui" | "mixed" | "game")`
- `detector:setScanRoots({instance1, instance2, ...})` (or `nil` to reset)
- default mode: `"ui"` (quét UI roots của Rayfield)
- `detector:setAttributionPolicy(policy)`
  - `mode = "weighted"` (default)
  - `triggerScore = 70` (default)
  - `confirmCycles = 2` (default)
  - `unknownNotifyOncePerSession = true` (default)
- `detector:getAttributionReport()`
  - `lastScore`
  - `lastClassification` (`"rayfield_ui"` | `"unknown"`)
  - `confirmStreak`
  - `lastEvidence`

Attribution behavior:
- Emergency cleanup chỉ được phép trigger khi leak được phân loại `rayfield_ui` và đạt confirm streak theo policy.
- Nếu phân loại `unknown`, hệ thống chỉ thông báo qua notification (throttle theo policy), không emergency.

Compatibility:
- Backward-compat animation API (`RayfieldAdvanced.AnimationAPI.new()`) is no longer part of canonical runtime.

## All-In-One Loader (`Main loader/rayfield-all-in-one.lua`)

Load:

```lua
local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-all-in-one.lua"
))()
```

Public loader methods:
- `AllInOne.loadBase()`
- `AllInOne.loadEnhanced()`
- `AllInOne.loadAdvanced()`
- `AllInOne.loadAll()`
- `AllInOne.quickSetup(config)`
- `AllInOne.configure(config)`
- `AllInOne.clearCache()`
- `AllInOne.checkForUpdates()`
- `AllInOne.reloadNow()`
- `AllInOne.startAutoReload()`
- `AllInOne.stopAutoReload()`
- `AllInOne.setAutoReloadCallback(functionOrNil)`
- `AllInOne.info()`

## Test Scripts

Canonical test paths:
- `tests/smoke/rayfield-smoke-test.lua`
- `tests/regression/test-animation-api.lua`
- `tests/regression/test-unified-animation-api.lua`
- `tests/regression/test-keybind-sequence.lua`
- `tests/regression/test-element-sync-consistency.lua`
- `tests/regression/test-share-code-workflow.lua`
- `tests/regression/test-element-expansion-pack.lua`

Root wrapper scripts:
- `rayfield-smoke-test.lua`
- `test-animation-api.lua`
- `test-keybind-sequence.lua`
