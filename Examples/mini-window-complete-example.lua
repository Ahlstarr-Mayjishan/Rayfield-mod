-- Complete Mini Window Example with All Features
-- Shows Button, Label, Toggle, and Slider

local MiniWindow = loadstring(readfile("mini-window-system.lua"))()

-- Create mini window
local miniWin = MiniWindow.new({
    Title = "Quick Panel",
    Size = UDim2.new(0, 200, 0, 400),
    Position = UDim2.new(1, -220, 0, 50)
})

-- === TOGGLES ===
local anchorToggle = miniWin:AddToggle("Anchor", false, function(value)
    if value then
        startAnchor()
    else
        stopAnchor()
    end
end)

local antiAnimToggle = miniWin:AddToggle("Anti-Animation", false, function(value)
    if value then
        blockAnimations()
    else
        unblockAnimations()
    end
end)

-- === BUTTONS ===
miniWin:AddButton("Execute All Work", function()
    local count = 0
    for abnoName, dropdown in pairs(abnormalityDropdowns) do
        if dropdown.CurrentOption and #dropdown.CurrentOption > 0 then
            local workType = dropdown.CurrentOption[1]
            executeWork(abnoName, workType)
            count = count + 1
            task.wait(0.1)
        end
    end
    print("✓ Executed work on " .. count .. " abnormalities")
end)

miniWin:AddButton("Clear Selections", function()
    for _, element in ipairs(AbnoManagerTab:GetElements()) do
        if element.Type == "Dropdown" and element.Object.Clear then
            element.Object:Clear()
        end
    end
    print("✓ Cleared all selections")
end)

miniWin:AddButton("Extract All EGO", function()
    local count = 0
    for _, child in ipairs(workspace.Abnormalities:GetChildren()) do
        if child:IsA("Model") then
            extractEGO(child.Name)
            count = count + 1
        end
    end
    print("✓ Extracted " .. count .. " E.G.O equipment")
end)

miniWin:AddButton("Hide Completed", function()
    local count = 0
    for _, element in ipairs(AbnoManagerTab:GetElements()) do
        if element.Type == "Dropdown" then
            local dropdown = element.Object
            if dropdown.CurrentOption and #dropdown.CurrentOption > 0 then
                dropdown:Hide()
                count = count + 1
            end
        end
    end
    print("✓ Hidden " .. count .. " completed abnormalities")
end)

miniWin:AddButton("Show All", function()
    for _, element in ipairs(AbnoManagerTab:GetElements()) do
        if element.Type == "Dropdown" then
            element.Object:Show()
        end
    end
    print("✓ Showed all abnormalities")
end)

-- === STATUS LABELS ===
local statusLabel = miniWin:AddLabel("Status: Ready")
local hpLabel = miniWin:AddLabel("HP: 100/100")
local abnoCountLabel = miniWin:AddLabel("Abnormalities: 0")

-- Update status
RunService.Heartbeat:Connect(function()
    local player = Players.LocalPlayer
    local char = player.Character
    
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            hpLabel.Text = string.format("HP: %.0f/%.0f", humanoid.Health, humanoid.MaxHealth)
            
            if humanoid.Health < humanoid.MaxHealth * 0.3 then
                hpLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            elseif humanoid.Health < humanoid.MaxHealth * 0.6 then
                hpLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            else
                hpLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            end
        end
    end
    
    local abnoCount = #workspace.Abnormalities:GetChildren()
    abnoCountLabel.Text = "Abnormalities: " .. abnoCount
    
    if ANCHOR_ENABLED then
        statusLabel.Text = "Status: Anchored"
        statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    else
        statusLabel.Text = "Status: Ready"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end)

-- Sync toggles with global state
RunService.Heartbeat:Connect(function()
    if anchorToggle.GetValue() ~= ANCHOR_ENABLED then
        anchorToggle.SetValue(ANCHOR_ENABLED)
    end
end)

-- Add toggle button to main UI
MiscTab:CreateButton({
    Name = "Toggle Mini Window",
    Callback = function()
        miniWin:Toggle()
    end
})

-- Cleanup
local originalDestroy = destroyScript
destroyScript = function()
    miniWin:Destroy()
    if originalDestroy then
        originalDestroy()
    end
end

print("✓ Mini window created!")
print("  - Drag title bar to move")
print("  - Click × to hide/show")
print("  - Use 'Toggle Mini Window' button in Misc tab")

