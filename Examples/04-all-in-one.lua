-- All-in-one loader example.
-- Handles both first-run auto-load and later manual quickSetup flow.

local Loaded = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-all-in-one.lua"
))()

-- Legacy URL (still supported):
-- https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/feature/rayfield-all-in-one.lua

local UI

if type(Loaded) == "table" and Loaded.Rayfield then
    -- First run: all-in-one returned an initialized UI table
    UI = Loaded
elseif type(Loaded) == "table" and type(Loaded.quickSetup) == "function" then
    -- Subsequent runs: all-in-one returned the loader table
    UI = Loaded.quickSetup({
        mode = "enhanced",
        errorThreshold = 5,
        rateLimit = 10,
        autoCleanup = true
    })
else
    error("All-in-one loader returned unexpected value")
end

local Window = UI.Rayfield:CreateWindow({
    Name = "Rayfield Mod - All-in-One",
    LoadingTitle = "Rayfield Mod",
    LoadingSubtitle = "04-all-in-one",
    ConfigurationSaving = {
        Enabled = false
    }
})

local Tab = Window:CreateTab("AllInOne")
local lastShareCode = nil
local favoriteToggle = Tab:CreateToggle({
    Name = "Favorite Candidate",
    CurrentValue = false,
    Callback = function() end
})

Tab:CreateLabel("Mode: " .. tostring(UI.mode))

Tab:CreateButton({
    Name = "Print Loaded Components",
    Callback = function()
        print("Has ErrorManager:", UI.ErrorManager ~= nil)
        print("Has GarbageCollector:", UI.GarbageCollector ~= nil)
        print("Has RemoteProtection:", UI.RemoteProtection ~= nil)
        print("Has MemoryLeakDetector:", UI.MemoryLeakDetector ~= nil)
        print("Has Profiler:", UI.Profiler ~= nil)
        print("Has Advanced:", UI.Advanced ~= nil)
    end
})

Tab:CreateButton({
    Name = "Export Settings (Share Code)",
    Callback = function()
        local code, status = UI.Rayfield:ExportSettings()
        if type(code) == "string" then
            lastShareCode = code
            print("Exported share code:", status, "length =", #code)
        else
            warn("Export failed:", status)
        end
    end
})

Tab:CreateButton({
    Name = "Import Code (Last Export)",
    Callback = function()
        if type(lastShareCode) ~= "string" or lastShareCode == "" then
            warn("No cached share code yet. Export first.")
            return
        end
        local ok, message = UI.Rayfield:ImportCode(lastShareCode)
        print("ImportCode:", ok, message)
    end
})

Tab:CreateButton({
    Name = "Import Settings (Apply Active)",
    Callback = function()
        local ok, message = UI.Rayfield:ImportSettings()
        print("ImportSettings:", ok, message)
    end
})

Tab:CreateButton({
    Name = "Copy Share code",
    Callback = function()
        local ok, message = UI.Rayfield:CopyShareCode()
        print("CopyShareCode:", ok, message)
    end
})

Tab:CreateButton({
    Name = "Set UI Preset: Focus",
    Callback = function()
        local ok, message = UI.Rayfield:SetUIPreset("Focus")
        print("SetUIPreset:", ok, message)
    end
})

Tab:CreateButton({
    Name = "Set Transition: Snappy",
    Callback = function()
        local ok, message = UI.Rayfield:SetTransitionProfile("Snappy")
        print("SetTransitionProfile:", ok, message)
    end
})

Tab:CreateButton({
    Name = "Pin Candidate (Element API)",
    Callback = function()
        local ok, message = favoriteToggle:Pin()
        print("Element:Pin:", ok, message, "id =", favoriteToggle:GetFavoriteId())
    end
})

Tab:CreateButton({
    Name = "List Controls",
    Callback = function()
        local controls = UI.Rayfield:ListControls()
        print("ListControls count:", #controls)
    end
})

Tab:CreateButton({
    Name = "Replay Onboarding",
    Callback = function()
        local ok, message = UI.Rayfield:ShowOnboarding(true)
        print("ShowOnboarding:", ok, message)
    end
})

Tab:CreateButton({
    Name = "Theme Studio Reset",
    Callback = function()
        local ok, message = UI.Rayfield:ResetThemeStudio()
        print("ResetThemeStudio:", ok, message)
    end
})

Tab:CreateSection("Element Expansion Pack v1")

local searchableDropdown = Tab:CreateDropdown({
    Name = "Searchable Dropdown",
    Options = {"Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"},
    CurrentOption = {"Alpha"},
    MultipleOptions = false,
    SearchEnabled = true,
    SearchPlaceholder = "Search options...",
    ResetSearchOnRefresh = false,
    Callback = function(selection)
        print("Searchable dropdown:", selection[1])
    end
})

Tab:CreateButton({
    Name = "Dropdown search query = 'ga'",
    Callback = function()
        searchableDropdown:SetSearchQuery("ga")
    end
})

local collapsible = Tab:CreateCollapsibleSection({
    Name = "Advanced Controls",
    Id = "advanced-controls",
    Collapsed = false
})

local stepper = Tab:CreateNumberStepper({
    Name = "Precision Value",
    CurrentValue = 1.25,
    Min = 0,
    Max = 10,
    Step = 0.01,
    Precision = 2,
    ParentSection = collapsible,
    Callback = function(value)
        print("Stepper value:", value)
    end
})
stepper:SetTooltip("Adjust value with +/- for precise control.")

Tab:CreateConfirmButton({
    Name = "Danger Action (Hold/Double)",
    ConfirmMode = "either",
    HoldDuration = 1.2,
    DoubleWindow = 0.4,
    Callback = function()
        warn("Danger action confirmed.")
    end
})

Tab:CreateImage({
    Name = "Preview Image",
    Source = "rbxassetid://4483362458",
    FitMode = "fill",
    Height = 110,
    Caption = "Rayfield Icon"
})

Tab:CreateGallery({
    Name = "Quick Gallery",
    SelectionMode = "multi",
    Columns = "auto",
    Items = {
        {id = "one", name = "One", image = "rbxassetid://4483362458"},
        {id = "two", name = "Two", image = "rbxassetid://4483362458"},
        {id = "three", name = "Three", image = "rbxassetid://4483362458"}
    },
    Callback = function(selection)
        print("Gallery selection:", selection)
    end
})

local chart = Tab:CreateChart({
    Name = "Runtime Chart",
    MaxPoints = 300,
    UpdateHz = 10,
    Preset = "fps",
    ShowAreaFill = true
})
chart:AddPoint(60)
chart:AddPoint(58)
chart:AddPoint(62)

local console = Tab:CreateLogConsole({
    Name = "Runtime Logs",
    CaptureMode = "both",
    MaxEntries = 120
})
console:Info("Log console ready.")
console:Warn("This is a warning sample.")
