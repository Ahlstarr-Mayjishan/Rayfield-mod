-- Base quickstart for exploiter environments

local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
))()

local Window = Rayfield:CreateWindow({
    Name = "Rayfield Mod - Base Example",
    LoadingTitle = "Rayfield Mod",
    LoadingSubtitle = "01-base-quickstart",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = false
    }
})

local MainTab = Window:CreateTab("Main")

MainTab:CreateLabel("Base example loaded")

MainTab:CreateButton({
    Name = "Notify",
    Callback = function()
        Rayfield:Notify({
            Title = "Base",
            Content = "Button callback works",
            Duration = 4
        })
    end
})

MainTab:CreateToggle({
    Name = "Sample Toggle",
    CurrentValue = false,
    Callback = function(value)
        print("Sample Toggle:", value)
    end
})

MainTab:CreateSlider({
    Name = "Sample Slider",
    Range = {0, 100},
    Increment = 5,
    Suffix = "%",
    CurrentValue = 25,
    Callback = function(value)
        print("Sample Slider:", value)
    end
})

