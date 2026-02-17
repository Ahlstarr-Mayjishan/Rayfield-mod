# API Reference

This file documents the public runtime API used by scripts in exploiter environments.

## Base Library (`rayfield-modified.lua`)

Load:

```lua
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
))()
```

Main methods:
- `Rayfield:Notify(data)`
- `Rayfield:CreateWindow(settings)`
- `Rayfield:SetVisibility(boolean)`
- `Rayfield:IsVisible() -> boolean`
- `Rayfield:Destroy()`
- `Rayfield:LoadConfiguration()`
- `Rayfield:GetAnimationEngine()`

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
- `Tab:CreateDivider()`
- `Tab:CreateLabel(text, icon?, color?, ignoreTheme?)`
- `Tab:CreateParagraph(settings)`
- `Tab:CreateInput(settings)`
- `Tab:CreateDropdown(settings)`
- `Tab:CreateKeybind(settings)`
- `Tab:CreateToggle(settings)`
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
- `.Name`
- `.Type`

If detach system is active, elements also expose:
- `:Detach(position?)`
- `:Dock()`
- `:GetRememberedState()`
- `:IsDetached()`

Dropdown special method:
- `Dropdown:Clear()`

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
- `GetPerformanceReport()`
- `GetAuditLog()`

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

Root wrapper scripts:
- `rayfield-smoke-test.lua`
- `test-animation-api.lua`
