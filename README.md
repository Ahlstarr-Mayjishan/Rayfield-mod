# Rayfield Mod (Exploiter Focus)

Modified Rayfield UI package for executor environments.

Source layout:
- Canonical logic: `src/*`
- Legacy compatibility wrappers: `feature/*` and `Main loader/*`

Canonical test layout:
- `tests/smoke/*`
- `tests/regression/*`
- `tests/helpers/*`

## Requirements

- `loadstring`
- `game:HttpGet`
- Optional for config saving: `writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`

## jsDelivr Loader Links

- Main Loader (recommended):
  - https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Rayfield-mod@main/Main%20loader/rayfield-modified.lua
- Main All-in-One Loader:
  - https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Rayfield-mod@main/Main%20loader/rayfield-all-in-one.lua
- Main All-in-One 3-Tab Elements Check Loader (5:5 + Settings):
  - https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Rayfield-mod@main/Main%20loader/rayfield-all-in-one-2tabs-elements-check.lua
- Legacy All-in-One Loader:
  - https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Rayfield-mod@main/feature/rayfield-all-in-one.lua
- Enhanced Wrapper Loader:
  - https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Rayfield-mod@main/feature/rayfield-enhanced.lua

## Quick Start (Direct)

```lua
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
))()

local Window = Rayfield:CreateWindow({
    Name = "My Hub",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "Rayfield Mod",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MyHub",
        FileName = "main"
    }
})

local MainTab = Window:CreateTab("Main")
MainTab:CreateButton({
    Name = "Ping",
    Callback = function()
        print("pong")
    end
})
```

## Quick Start (All-in-One)

```lua
local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-all-in-one.lua"
))()

-- UI.Rayfield, UI.ErrorManager, UI.GarbageCollector, etc.
```

Note:
- `rayfield-all-in-one.lua` auto-loads once per session (`_G.RayfieldAllInOneLoaded`).
- If already loaded once, loading it again returns the loader table instead of auto-booting.

## Extended API Highlights

Every created element gets:
- `:Destroy()`
- `:Show()`
- `:Hide()`
- `:SetVisible(boolean)`
- `:GetParent()`
- `.Name`
- `.Type`

Tab helpers:
- `Tab:GetElements()`
- `Tab:FindElement(name)`
- `Tab:Clear()`

Dropdown helper:
- `Dropdown:Clear()`

## Enhanced Layer

Load enhanced wrapper:

```lua
local Enhancement = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/feature/rayfield-enhanced.lua"
))()

local EnhancedRayfield, ErrorMgr, GC, RemoteProt, LeakDetector, Profiler =
    Enhancement.createEnhancedRayfield(Rayfield)
```

## Documentation

- `Documentation/API.md`
- `Documentation/TROUBLESHOOTING.md`
- `Documentation/CHANGELOG.md`

## Examples

- `Examples/01-base-quickstart.lua`
- `Examples/02-extended-api.lua`
- `Examples/03-enhanced-wrapper.lua`
- `Examples/04-all-in-one.lua`
- `Main loader/rayfield-all-in-one-2tabs-elements-check.lua` (3 tabs: Elements A, Elements B, Settings)
