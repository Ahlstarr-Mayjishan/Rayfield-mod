-- All-in-one loader example.
-- Handles both first-run auto-load and later manual quickSetup flow.

local Loaded = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/feature/rayfield-all-in-one.lua"
))()

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

