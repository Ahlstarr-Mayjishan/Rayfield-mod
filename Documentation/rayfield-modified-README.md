# Rayfield Modified - Extended API Documentation

Modified version of Rayfield UI Library with extended element management capabilities.

## New Features

### 1. Element Destruction
All elements now support `:Destroy()` method to remove them after creation.

```lua
local button = Tab:CreateButton({Name = "Test", Callback = function() end})
button:Destroy() -- Removes the button from UI
```

### 2. Element Visibility Control
Toggle element visibility without destroying them.

```lua
local dropdown = Tab:CreateDropdown({Name = "Test", Options = {"A", "B"}})

dropdown:Hide()              -- Hide element
dropdown:Show()              -- Show element
dropdown:SetVisible(false)   -- Set visibility programmatically
```

### 3. Dropdown Clear Fix
Dropdown now has `:Clear()` method that updates UI immediately.

```lua
local dropdown = Tab:CreateDropdown({
    Name = "Work Type",
    Options = {"Instinct", "Insight", "Attachment", "Repression"},
    CurrentOption = {"Instinct"}
})

dropdown:Clear() -- Clears selection and updates UI to show "None"
```

### 4. Tab Management
Get and manage all elements in a tab.

```lua
-- Get all elements
local elements = Tab:GetElements()
for _, element in ipairs(elements) do
    print(element.Name, element.Type)
end

-- Find specific element
local myButton = Tab:FindElement("My Button Name")
if myButton then
    myButton:Hide()
end

-- Clear all elements in tab
Tab:Clear() -- Destroys all elements
```

### 5. Element Parent Access
Get the parent tab of any element.

```lua
local button = Tab:CreateButton({Name = "Test", Callback = function() end})
local parentTab = button:GetParent()
```

## Use Cases for Abnormality Manager

### Dynamic UI Updates
```lua
-- When abnormality is removed from game
local dropdown = Tab:FindElement(abnoName)
if dropdown then
    dropdown:Destroy()
end
```

### Hide Completed Work
```lua
-- Hide abnormalities that are already worked on
for _, element in ipairs(Tab:GetElements()) do
    if element.Type == "Dropdown" and isCompleted(element.Name) then
        element.Object:Hide()
    end
end
```

### Clear All Selections
```lua
-- Clear all dropdowns visually
for _, element in ipairs(Tab:GetElements()) do
    if element.Type == "Dropdown" and element.Object.Clear then
        element.Object:Clear()
    end
end
```

### Rebuild UI
```lua
-- Clear old UI and rebuild
Tab:Clear()
-- Then recreate elements
buildAbnoUI()
```

## Supported Elements

All elements support the extended API:
- Button
- Dropdown (with `:Clear()` method)
- Toggle
- Slider
- Label
- Paragraph
- Input
- Section
- Divider
- Keybind
- ColorPicker

## Migration from Original Rayfield

Simply replace the loadstring URL with the modified version:

```lua
-- Original
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/...'))()

-- Modified (local file)
local Rayfield = loadstring(readfile("rayfield-modified.lua"))()
```

All existing code remains compatible. New features are opt-in.

## Implementation Notes

- Element tracking is per-tab (each tab maintains its own element list)
- `:Destroy()` automatically removes element from tracking
- Visibility methods don't affect element state, only GUI visibility
- `:Clear()` on tabs destroys all elements permanently
- `:Clear()` on dropdowns only clears selection, doesn't destroy

## Performance

- Element tracking adds minimal overhead (simple table operations)
- No performance impact on existing Rayfield features
- Recommended for UIs with 100+ dynamic elements

