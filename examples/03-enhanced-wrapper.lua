-- Enhanced wrapper example: hybrid callback, memory report, cleanup

local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
))()

local Enhancement = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/feature/rayfield-enhanced.lua"
))()

local EnhancedRayfield, ErrorMgr, GC, RemoteProt, LeakDetector, Profiler =
    Enhancement.createEnhancedRayfield(Rayfield)

local Window = EnhancedRayfield:CreateWindow({
    Name = "Rayfield Mod - Enhanced Example",
    LoadingTitle = "Rayfield Enhanced",
    LoadingSubtitle = "03-enhanced-wrapper",
    ConfigurationSaving = {
        Enabled = false
    }
})

local Tab = Window:CreateTab("Enhanced")

local FastCallback = Enhancement.createHybridCallback(function()
    print("Fast callback executed")
end, "FastCallback", ErrorMgr, Profiler, {
    mode = "fast",
    profile = true
})

local ProtectedCallback = Enhancement.createHybridCallback(function()
    print("Protected callback executed")
end, "ProtectedCallback", ErrorMgr, Profiler, {
    mode = "protected",
    rateLimit = 5,
    profile = true
})

Tab:CreateButton({
    Name = "Run Fast Callback",
    Callback = FastCallback
})

Tab:CreateButton({
    Name = "Run Protected Callback",
    Callback = ProtectedCallback
})

Tab:CreateButton({
    Name = "Print Memory Report",
    Callback = function()
        local report = EnhancedRayfield:GetMemoryReport()
        print("Memory MB:", report.currentMemory)
        print("Instance count:", report.instanceCount or 0)
        print("Snapshots:", report.snapshots)
        print("Suspected leaks:", report.suspectedLeaks)
    end
})

Tab:CreateButton({
    Name = "Print Health",
    Callback = function()
        print("IsHealthy:", EnhancedRayfield:IsHealthy())
    end
})

Tab:CreateButton({
    Name = "Force Cleanup",
    Callback = function()
        local cleaned = EnhancedRayfield:ForceCleanup()
        print("ForceCleanup removed:", cleaned)
    end
})

Tab:CreateButton({
    Name = "Disable Leak Detector",
    Callback = function()
        local detector = EnhancedRayfield:GetMemoryLeakDetector()
        detector:setEnabled(false)
        print("Leak detector disabled")
    end
})

