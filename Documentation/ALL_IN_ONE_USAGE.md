# Rayfield All-in-One Loader - Usage Guide

## 🚀 Cách sử dụng trong Executor

### Method 1: Auto Load (Simplest)

```lua
-- Chỉ cần 1 dòng, tự động load Enhanced mode
loadstring(game:HttpGet('https://raw.githubusercontent.com/your-repo/Modified%20Ver/rayfield-all-in-one.lua'))()

-- Sử dụng ngay
local Window = _G.Rayfield:CreateWindow({
    Name = "My Script",
    LoadingTitle = "Loading..."
})
```

### Method 2: Manual Load

```lua
-- Load loader
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/your-repo/Modified%20Ver/rayfield-all-in-one.lua'))()

-- Chọn mode
local UI = Rayfield.loadEnhanced() -- Recommended

-- Sử dụng
local Window = UI.Rayfield:CreateWindow({Name = "My Script"})
```

### Method 3: Quick Setup

```lua
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/your-repo/Modified%20Ver/rayfield-all-in-one.lua'))()

local UI = Rayfield.quickSetup({
    mode = "enhanced",
    errorThreshold = 5,
    rateLimit = 10
})

local Window = UI.Rayfield:CreateWindow({Name = "My Script"})
```

---

## 📦 Sử dụng với Pastebin

### Bước 1: Upload files lên Pastebin

1. Upload `rayfield-modified.lua` → Code: `ABC123XY`
2. Upload `rayfield-enhanced-v2.lua` → Code: `DEF456ZW`
3. Upload `rayfield-all-in-one.lua` → Code: `LOADER123`

### Bước 2: Configure

```lua
local Rayfield = loadstring(game:HttpGet('https://pastebin.com/raw/LOADER123'))()

Rayfield.configure({
    usePastebin = true,
    pastebinCodes = {
        base = "ABC123XY",
        enhanced = "DEF456ZW"
    }
})

local UI = Rayfield.loadEnhanced()
```

---

## 💡 Complete Example

```lua
-- 1. Load (1 dòng duy nhất)
loadstring(game:HttpGet('https://raw.githubusercontent.com/your-repo/Modified%20Ver/rayfield-all-in-one.lua'))()

-- 2. Sử dụng ngay
local Window = _G.Rayfield:CreateWindow({
    Name = "My Script Hub",
    LoadingTitle = "Loading..."
})

local Tab = Window:CreateTab("Main")

Tab:CreateButton({
    Name = "Auto Farm",
    Callback = function()
        print("Farming...")
    end
})

print("✅ Script loaded!")
```

---

## 🎯 Modes Available

| Mode | Features | Use Case |
|------|----------|----------|
| Base | UI only | Simple scripts |
| Enhanced | UI + Protection | Production scripts |
| Advanced | UI + Protection + Animations | Advanced scripts |

---

## 📝 Quick Reference

### One-Liner
```lua
loadstring(game:HttpGet('YOUR_URL'))()
```

### Access Global
```lua
_G.Rayfield -- Main object
_G.RayfieldUI -- Full UI object
```

---

**End of Guide**
