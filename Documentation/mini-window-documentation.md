# Mini Window System Documentation

## Overview

Custom lightweight floating window system for quick access to common actions. Works alongside Rayfield UI.

## Features

- **Draggable** - Drag from title bar to reposition
- **Collapsible** - Click × to hide/show
- **Scrollable** - Auto-scrolls when content exceeds height
- **Lightweight** - ~380 lines, minimal performance impact
- **Customizable** - Size, position, colors

## API Reference

### Creating Window

```lua
local MiniWindow = loadstring(readfile("mini-window-system.lua"))()

local miniWin = MiniWindow.new({
    Title = "Quick Actions",           -- Window title
    Size = UDim2.new(0, 200, 0, 300),  -- Width, Height
    Position = UDim2.new(1, -220, 0, 100)  -- X, Y from top-right
})
```

### Adding Elements

#### Button
```lua
miniWin:AddButton("Button Name", function()
    print("Button clicked!")
end)
```

#### Label
```lua
local label = miniWin:AddLabel("Status: Ready")

-- Update label text
label.Text = "Status: Working"
label.TextColor3 = Color3.fromRGB(255, 100, 100)
```

#### Toggle
```lua
local toggle = miniWin:AddToggle("Feature Name", false, function(value)
    print("Toggle:", value)
end)

-- Get/Set value
local isOn = toggle.GetValue()
toggle.SetValue(true)
```

#### Slider
```lua
local slider = miniWin:AddSlider("Range", 10, 100, 50, function(value)
    print("Slider:", value)
end)

-- Get/Set value
local current = slider.GetValue()
slider.SetValue(75)
```

### Window Methods

```lua
miniWin:Toggle()   -- Hide/show window
miniWin:Show()     -- Show window
miniWin:Hide()     -- Hide window
miniWin:Destroy()  -- Remove window completely
```

## Integration with Main Script

### Step 1: Load System
Add at the top of your script:
```lua
local MiniWindow = loadstring(readfile("mini-window-system.lua"))()
```

### Step 2: Create Window
After Rayfield initialization:
```lua
local miniWin = MiniWindow.new({
    Title = "Quick Panel",
    Size = UDim2.new(0, 200, 0, 400),
    Position = UDim2.new(1, -220, 0, 50)
})
```

### Step 3: Add Controls
```lua
-- Anchor toggle
miniWin:AddToggle("Anchor", false, function(value)
    if value then startAnchor() else stopAnchor() end
end)

-- Quick action buttons
miniWin:AddButton("Execute All", function()
    -- Execute work on all selected abnormalities
end)
```

### Step 4: Add Status Display
```lua
local statusLabel = miniWin:AddLabel("Status: Ready")
local hpLabel = miniWin:AddLabel("HP: 100/100")

RunService.Heartbeat:Connect(function()
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if humanoid then
        hpLabel.Text = string.format("HP: %.0f/%.0f", 
            humanoid.Health, humanoid.MaxHealth)
    end
end)
```

### Step 5: Add Cleanup
```lua
local originalDestroy = destroyScript
destroyScript = function()
    miniWin:Destroy()
    if originalDestroy then originalDestroy() end
end
```

## Use Cases

### 1. Quick Actions Panel
- Toggle Anchor
- Execute All Work
- Clear Selections
- Extract All EGO

### 2. Status Monitor
- Current HP
- Anchor status
- Abnormality count
- Current work

### 3. Settings Panel
- Anchor movement amplitude
- Auto-execute interval
- Feature toggles

## Styling

### Colors
```lua
-- Background colors
BackgroundColor3 = Color3.fromRGB(25, 25, 35)  -- Main frame
BackgroundColor3 = Color3.fromRGB(35, 35, 50)  -- Title bar
BackgroundColor3 = Color3.fromRGB(45, 45, 60)  -- Elements

-- Accent colors
Color3.fromRGB(100, 255, 100)  -- Toggle ON / Success
Color3.fromRGB(255, 100, 100)  -- Toggle OFF / Error
Color3.fromRGB(100, 150, 255)  -- Slider fill
```

### Sizes
```lua
-- Compact (minimal)
Size = UDim2.new(0, 150, 0, 200)

-- Standard (recommended)
Size = UDim2.new(0, 200, 0, 300)

-- Large (many features)
Size = UDim2.new(0, 250, 0, 500)
```

### Positions
```lua
-- Top-right corner
Position = UDim2.new(1, -220, 0, 50)

-- Bottom-right corner
Position = UDim2.new(1, -220, 1, -350)

-- Center-right
Position = UDim2.new(1, -220, 0.5, -150)
```

## Performance

- **Memory**: ~50KB per window
- **CPU**: Negligible (only updates on interaction)
- **Rendering**: Uses ScreenGui (no 3D rendering)

## Comparison with Rayfield

| Feature | Rayfield | Mini Window |
|---------|----------|-------------|
| Size | Large, full-featured | Small, compact |
| Elements | 11 types | 4 types (Button, Label, Toggle, Slider) |
| Tabs | Yes | No (single page) |
| Themes | Yes | No (fixed dark theme) |
| Config Save | Yes | No |
| Use Case | Main UI | Quick access |
| Load Time | ~1s | Instant |

## Best Practices

1. **Keep it minimal** - Only add essential controls
2. **Use short names** - "Anchor" not "Toggle Anchor Feature"
3. **Group related items** - Toggles first, then sliders, then buttons
4. **Update labels efficiently** - Use Heartbeat but check if value changed
5. **Position wisely** - Don't block important game UI

## Examples

See these files:
- `mini-window-usage-example.lua` - Basic usage
- `mini-window-complete-example.lua` - Full featured example

## Troubleshooting

**Window not appearing:**
- Check if ScreenGui is parented to PlayerGui
- Verify Position is on-screen

**Dragging not working:**
- Make sure TitleBar InputBegan is connected
- Check if another UI is blocking input

**Elements not showing:**
- Call UpdateContentSize() after adding elements
- Check ScrollingFrame CanvasSize

**Performance issues:**
- Reduce Heartbeat update frequency
- Only update labels when values change
- Limit number of elements (< 20 recommended)

