# Troubleshooting

## 1) `HttpGet` returns 404

Cause:
- Wrong raw URL, wrong path, or wrong repo owner.

Use these known-good paths:
- Base: `.../main/Main%20loader/rayfield-modified.lua`
- Enhanced: `.../main/feature/rayfield-enhanced.lua`
- All-in-one (canonical): `.../main/Main%20loader/rayfield-all-in-one.lua`

## 2) `attempt to index nil with 'CreateWindow'`

Cause:
- Base loader failed and returned `nil` (usually URL/load error).

Check:
- Executor supports `loadstring` + `game:HttpGet`
- Raw URL opens in browser and returns code

## 3) Config saving does not work

Cause:
- Executor missing filesystem APIs.

Needed:
- `writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`

If unavailable, run with `ConfigurationSaving.Enabled = false`.

## 4) Buttons/toggles do nothing

Cause:
- Callback error thrown inside `Callback`.

Check:
- Wrap risky logic with `pcall`
- Print detailed errors in callback

## 5) UI does not toggle with keybind

Cause:
- Invalid `ToggleUIKeybind` or key conflicts.

Use:
- A valid key string (`"K"`, `"RightShift"`, etc.) or `Enum.KeyCode`

## 6) Too much overhead after multiple reloads

Cause:
- Multiple wrappers loaded without cleanup.

Fix:
- Call `Rayfield:Destroy()` before reloading.
- If using enhanced wrapper, detector cleanup is handled on destroy/shutdown.

## 7) Memory leak detector too noisy

You can disable it:

```lua
local detector = EnhancedRayfield:GetMemoryLeakDetector()
detector:setEnabled(false)
```

## 8) All-in-one behaves differently on second run

Expected behavior:
- First run auto-loads and returns UI.
- Later runs return loader table when `_G.RayfieldAllInOneLoaded` is already set.

If needed:
- Use `AllInOne.quickSetup(...)` manually.
