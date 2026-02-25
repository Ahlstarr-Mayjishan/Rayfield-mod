-- Extended API example: Show/Hide, SetVisible, FindElement, Tab:Clear, Dropdown:Clear

local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
))()

local Window = Rayfield:CreateWindow({
    Name = "Rayfield Mod - Extended API",
    LoadingTitle = "Rayfield Mod",
    LoadingSubtitle = "02-extended-api",
    ConfigurationSaving = {
        Enabled = false
    }
})

local Tab = Window:CreateTab("Extended")

local Label = Tab:CreateLabel("StatusLabel")

local Dropdown = Tab:CreateDropdown({
    Name = "Target Option",
    Options = {"Alpha", "Beta", "Gamma"},
    CurrentOption = {"Alpha"},
    MultipleOptions = false,
    Callback = function(options)
        print("Dropdown current option:", options[1] or "None")
    end
})

Tab:CreateButton({
    Name = "Hide StatusLabel",
    Callback = function()
        local element = Tab:FindElement("StatusLabel")
        if element then
            element:Hide()
        end
    end
})

Tab:CreateButton({
    Name = "Show StatusLabel",
    Callback = function()
        local element = Tab:FindElement("StatusLabel")
        if element then
            element:Show()
        end
    end
})

Tab:CreateButton({
    Name = "Toggle StatusLabel Visible",
    Callback = function()
        local element = Tab:FindElement("StatusLabel")
        if element then
            local shouldShow = math.random(0, 1) == 1
            element:SetVisible(shouldShow)
            print("StatusLabel visible:", shouldShow)
        end
    end
})

Tab:CreateButton({
    Name = "Print Element Count",
    Callback = function()
        local elements = Tab:GetElements()
        print("Element count:", #elements)
        for _, item in ipairs(elements) do
            print(item.Type, item.Name)
        end
    end
})

Tab:CreateButton({
    Name = "Clear Dropdown Selection",
    Callback = function()
        Dropdown:Clear()
    end
})

Tab:CreateButton({
    Name = "Clear Entire Tab",
    Callback = function()
        Tab:Clear()
    end
})

Tab:CreateButton({
    Name = "Destroy StatusLabel",
    Callback = function()
        local element = Tab:FindElement("StatusLabel")
        if element then
            element:Destroy()
        end
    end
})

