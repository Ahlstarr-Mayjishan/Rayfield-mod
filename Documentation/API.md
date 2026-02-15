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
- `IsHealthy()`
- `GetErrorLog()`
- `ForceCleanup()`
- `GetMemoryReport()`
- `GetPerformanceReport()`
- `GetAuditLog()`

## All-In-One Loader (`feature/rayfield-all-in-one.lua`)

Load:

```lua
local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/feature/rayfield-all-in-one.lua"
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
- `AllInOne.info()`

