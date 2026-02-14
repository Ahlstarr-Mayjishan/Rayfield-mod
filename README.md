# Rayfield Enhanced V2 - Complete Package

> **Enhanced Rayfield UI Library with Memory Leak Detection, Performance Profiling, and Advanced Error Handling**

Version: 2.0.0 | License: MIT

---

## 📦 Package Contents

### Core Files (Required)
- **rayfield-modified.lua** - Base Rayfield with Extended API
- **rayfield-enhanced-v2.lua** - Enhanced features (V2)
- **rayfield-loader.lua** - One-line loader system

### Optional Modules
- **rayfield-advanced-features.lua** - Animation API, State Persistence
- **mini-window-system.lua** - Floating mini windows

### Examples
- **example-v2-usage.lua** - Complete V2 usage examples
- **example-exception-system.lua** - Exception system demo
- **example-loader-quickstart.lua** - Loader quick start

### Documentation
- **COMPLETE_GUIDE_V2.md** - Complete guide (all-in-one)
- **API_REFERENCE_V2.md** - Full API documentation
- **BEST_PRACTICES_V2.md** - Best practices guide
- **CHANGELOG_V2.md** - Version history
- **SUMMARY_V2.md** - Feature summary

---

## 🚀 Quick Start

### Method 1: Direct Load (Recommended)

```lua
-- Load modules
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/your-repo/Modified%20Ver/rayfield-modified.lua'))()
local Enhancement = loadstring(game:HttpGet('https://raw.githubusercontent.com/your-repo/Modified%20Ver/rayfield-enhanced-v2.lua'))()

-- Initialize
local EnhancedRayfield, ErrorMgr, GC, RemoteProt, LeakDetector, Profiler = 
    Enhancement.createEnhancedRayfield(Rayfield)

-- Create window
local Window = EnhancedRayfield:CreateWindow({
    Name = "My Script V2",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "Enhanced V2"
})

-- Create protected callback
local Tab = Window:CreateTab("Main")
Tab:CreateButton({
    Name = "Protected Button",
    Callback = Enhancement.createHybridCallback(function()
        print("Hello Enhanced V2!")
    end, "MyButton", ErrorMgr, Profiler, {
        mode = "protected",
        rateLimit = 5
    })
})
```

### Method 2: Using Loader

```lua
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/your-repo/Modified%20Ver/rayfield-loader.lua'))()

-- Load all features
local UI = Rayfield.loadAll()

-- Or quick setup
local UI = Rayfield.quickSetup({
    mode = "enhanced",
    errorThreshold = 5,
    rateLimit = 10
})
```

---

## ✨ Features

### V2 New Features

#### 1. 🧠 Memory Leak Detector (AUTO)
Automatically detects memory leaks every 30 seconds.

```lua
local LeakDetector = EnhancedRayfield:GetMemoryLeakDetector()
LeakDetector.onLeakDetected = function(leak)
    warn("⚠️ Leak detected:", leak.message)
end
```

#### 2. 📊 Performance Profiler (AUTO)
Automatically profiles all callbacks.

```lua
local Profiler = EnhancedRayfield:GetProfiler()
EnhancedRayfield:GetPerformanceReport()
```

#### 3. ⚡ Hybrid Callback System
Choose between fast mode (5% overhead) or protected mode (25% overhead).

```lua
-- Fast mode for ESP
{mode = "fast"}

-- Protected mode for UI
{mode = "protected", rateLimit = 5}
```

#### 4. 📡 Priority Remote Queue
4 priority levels: critical > high > normal > low

```lua
RemoteProt:safeRemoteCall(remote, "FireServer", "critical", data)
```

#### 5. 🔒 Exception System V2
Auto-disable and security audit log.

```lua
ErrorMgr:addException("FastCallback", 10) -- 10 seconds
ErrorMgr:setExceptionMode(true, 60, true) -- 60 seconds
```

#### 6. 📋 Security Audit Log
Track all exception changes.

```lua
ErrorMgr:printAuditLog()
```

### V1 Features (Included)

- ✅ Circuit Breaker Pattern
- ✅ Rate Limiting
- ✅ Garbage Collector
- ✅ Remote Call Protection
- ✅ Error Logging
- ✅ Fatal Error Recovery

---

## 📊 Performance

| Mode | Overhead | Use Case |
|------|----------|----------|
| Fast | ~5% | ESP, Aimbot, Game loops |
| Protected | ~25% | UI, Settings, File I/O |
| No Protection | 0% | Baseline |

**Memory Usage:** +75 KB overhead

---

## 📚 Documentation

### Quick Links

- **[Complete Guide](COMPLETE_GUIDE_V2.md)** - All-in-one documentation
- **[API Reference](API_REFERENCE_V2.md)** - Full API docs
- **[Best Practices](BEST_PRACTICES_V2.md)** - Usage guidelines
- **[Changelog](CHANGELOG_V2.md)** - Version history
- **[Summary](SUMMARY_V2.md)** - Feature summary

### Examples

- **[V2 Usage](example-v2-usage.lua)** - Complete examples
- **[Exception System](example-exception-system.lua)** - Exception demo
- **[Loader Quick Start](example-loader-quickstart.lua)** - Loader examples

---

## 🔄 Migration

### From V1 to V2

```lua
-- V1
local Enhancement = loadstring(game:HttpGet('.../rayfield-enhanced.lua'))()
local EnhancedRayfield, ErrorMgr, GC, RemoteProt = 
    Enhancement.createEnhancedRayfield(Rayfield)

-- V2
local Enhancement = loadstring(game:HttpGet('.../rayfield-enhanced-v2.lua'))()
local EnhancedRayfield, ErrorMgr, GC, RemoteProt, LeakDetector, Profiler = 
    Enhancement.createEnhancedRayfield(Rayfield)
```

See [Complete Guide](COMPLETE_GUIDE_V2.md#migration-guide) for details.

---

## 🎯 Use Cases

### ESP/Aimbot (Fast Mode)
```lua
local espCallback = Enhancement.createHybridCallback(function()
    updateESP()
end, "ESP", ErrorMgr, Profiler, {mode = "fast"})
```

### Auto Farm (Protected Mode)
```lua
local farmCallback = Enhancement.createHybridCallback(function()
    collectCoins()
end, "Farm", ErrorMgr, Profiler, {
    mode = "protected",
    rateLimit = 10
})
```

### Settings Save (Protected Mode)
```lua
local saveCallback = Enhancement.createHybridCallback(function()
    writefile("config.json", data)
end, "Save", ErrorMgr, Profiler, {
    mode = "protected",
    rateLimit = 1
})
```

---

## 🐛 Troubleshooting

### Memory Leak Detected
```lua
local report = EnhancedRayfield:GetMemoryReport()
print("Leaks:", report.suspectedLeaks)
EnhancedRayfield:ForceCleanup()
```

### Slow Performance
```lua
EnhancedRayfield:GetPerformanceReport()
-- Switch slow callbacks to fast mode
```

### Circuit Breaker Opens
```lua
ErrorMgr.errorThreshold = 10 -- Increase threshold
```

See [Complete Guide](COMPLETE_GUIDE_V2.md#troubleshooting) for more.

---

## 📈 Statistics

- **Total Lines:** ~2,500
- **Features:** 14 major
- **Files:** 20+
- **Documentation:** ~50 pages equivalent

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create feature branch
3. Submit pull request

---

## 📄 License

MIT License (same as original Rayfield)

---

## 🙏 Credits

- **Original Rayfield:** Sirius
- **Enhanced V1:** Community
- **Enhanced V2:** Community + AI Assistant

---

## 📞 Support

If you encounter issues:
1. Check [Complete Guide](COMPLETE_GUIDE_V2.md)
2. Review [Troubleshooting](COMPLETE_GUIDE_V2.md#troubleshooting)
3. Check console logs
4. Run diagnostic reports

---

## 🔗 Links

- **Original Rayfield:** https://sirius.menu/rayfield
- **Documentation:** See COMPLETE_GUIDE_V2.md
- **Examples:** See example-v2-usage.lua

---

**Version:** 2.0.0  
**Last Updated:** 2024  
**Status:** Production Ready ✅

