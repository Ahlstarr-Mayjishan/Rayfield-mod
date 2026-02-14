-- Example: Using Mini Window System with Main Script
-- This shows how to integrate mini window into tuantus-lobotomization-branches.lua

local MiniWindow = loadstring(readfile("mini-window-system.lua"))()

-- Create mini window
local miniWin = MiniWindow.new({
    Title = "Quick Actions",
    Size = UDim2.new(0, 180, 0, 250),
    Position = UDim2.new(1, -200, 0, 100)
})

-- Add buttons
miniWin:AddButton("Toggle Anchor", function()
    if ANCHOR_ENABLED then
        stopAnchor()
        print("Anchor disabled")
    else
        startAnchor()
        print("Anchor enabled")
    end
end)

miniWin:AddButton("Execute All", function()
    local count = 0
    for abnoName, dropdown in pairs(abnormalityDropdowns) do
        if dropdown.CurrentOption and #dropdown.CurrentOption > 0 then
            local workType = dropdown.CurrentOption[1]
            executeWork(abnoName, workType)
            count = count + 1
        end
    end
    print("Executed work on", count, "abnormalities")
end)

miniWin:AddButton("Clear All", function()
    for _, element in ipairs(AbnoManagerTab:GetElements()) do
        if element.Type == "Dropdown" and element.Object.Clear then
            element.Object:Clear()
        end
    end
    print("Cleared all selections")
end)

miniWin:AddButton("Extract All EGO", function()
    for _, child in ipairs(workspace.Abnormalities:GetChildren()) do
        if child:IsA("Model") then
            extractEGO(child.Name)
        end
    end
    print("Extracted all E.G.O equipment")
end)

-- Add status labels
local anchorLabel = miniWin:AddLabel("Anchor: OFF")
local workingLabel = miniWin:AddLabel("Working: None")

-- Update status labels
RunService.Heartbeat:Connect(function()
    anchorLabel.Text = "Anchor: " .. (ANCHOR_ENABLED and "ON" or "OFF")
    anchorLabel.TextColor3 = ANCHOR_ENABLED and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(200, 200, 200)
end)

-- Add toggle button to main Rayfield UI
MiscTab:CreateButton({
    Name = "Toggle Mini Window",
    Callback = function()
        miniWin:Toggle()
    end
})

-- Cleanup on destroy
local originalDestroy = destroyScript
destroyScript = function()
    miniWin:Destroy()
    if originalDestroy then
        originalDestroy()
    end
end

print("Mini window created! Drag from title bar to move.")

