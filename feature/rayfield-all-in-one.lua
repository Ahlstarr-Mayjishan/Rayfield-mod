--[[
	Rayfield Enhanced V2 - All-in-One Loader

	===========================================
	DUAL-EXECUTION BEHAVIOR (Improvement 3)
	===========================================

	This loader has two different behaviors depending on how it's called:

	1. FIRST EXECUTION (Auto-Execute Mode):
	   - When loaded for the first time (_G.RayfieldAllInOneLoaded is nil/false)
	   - Automatically loads Rayfield based on CONFIG.AUTO_MODE setting
	   - Exports loaded UI to _G.Rayfield and _G.RayfieldUI
	   - Returns loader table by default (safer for executors that freeze on large return values)
	   - Sets _G.RayfieldAllInOneLoaded = true to track state

	   Example:
	     local loader = loadstring(game:HttpGet('...'))()
	     -- UI is exported globally:
	     local Window = _G.Rayfield:CreateWindow({...})

	2. SUBSEQUENT EXECUTIONS (Loader Table Mode):
	   - When loaded again (_G.RayfieldAllInOneLoaded is true)
	   - Returns the AllInOne loader table with all methods
	   - Does NOT auto-execute to prevent duplicate loading
	   - Allows manual control via loader.loadBase(), loader.loadEnhanced(), etc.

	   Example:
	     local loader = loadstring(game:HttpGet('...'))()
	     -- loader is the AllInOne table with methods
	     local UI = loader.loadEnhanced()

	To control this behavior:
	   - Set AUTO_EXECUTE = false in CONFIG (or configure({autoExecute = false}))
	     to disable auto-execution
	   - Set AUTO_EXECUTE_RETURN (or configure({autoExecuteReturn = "ui"/"loader"/"none"}))
	     to control what first execution returns
	   - Reset _G.RayfieldAllInOneLoaded = nil to force auto-execution again

	===========================================

	Usage:
		loadstring(game:HttpGet('https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/feature/rayfield-all-in-one.lua'))()

	Hoặc nếu host trên Pastebin:
		loadstring(game:HttpGet('https://pastebin.com/raw/YOUR_CODE'))()
]]

local AllInOne = {}

-- ============================================
-- CONFIGURATION
-- ============================================

local CONFIG = {
	-- URLs của các modules (thay bằng URLs thật của bạn)
	BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/",
	
	-- Hoặc dùng Pastebin
	USE_PASTEBIN = false,
	PASTEBIN_CODES = {
		base = "XXXXXXXX",
		enhanced = "YYYYYYYY",
		advanced = "ZZZZZZZZ"
	},
	
	-- Cache modules để tránh load lại
	CACHE_ENABLED = true,
	
	-- Auto mode selection
	AUTO_MODE = "enhanced", -- "base", "enhanced", "advanced"

	-- Auto execute on first load (set false for loader-table only behavior)
	AUTO_EXECUTE = true,

	-- Return mode for first auto-execution:
	-- "loader" = return AllInOne (recommended)
	-- "ui" = return UI table from quickSetup (legacy behavior)
	-- "none" = return nil
	AUTO_EXECUTE_RETURN = "loader",
	
	-- Default settings
	DEFAULT_SETTINGS = {
		errorThreshold = 5,
		rateLimit = 10,
		autoCleanup = true
	}
}

-- ============================================
-- CACHE SYSTEM
-- ============================================

_G.RayfieldCache = _G.RayfieldCache or {}

local function getCached(key)
	if CONFIG.CACHE_ENABLED and _G.RayfieldCache[key] then
		print("📦 [Rayfield] Using cached:", key)
		return _G.RayfieldCache[key]
	end
	return nil
end

local function setCache(key, value)
	if CONFIG.CACHE_ENABLED then
		_G.RayfieldCache[key] = value
	end
end

local function getCacheKey(name, url)
	return tostring(name) .. "|" .. tostring(url)
end

local function isCachedModuleUsable(name, moduleValue)
	if type(moduleValue) ~= "table" then
		return false
	end

	-- Base module holds live GUI refs; if destroyed, force reload instead of reusing stale cache.
	if name == "base" then
		if type(moduleValue.CreateWindow) ~= "function" then
			return false
		end
		if type(moduleValue.IsDestroyed) == "function" then
			local ok, destroyed = pcall(moduleValue.IsDestroyed, moduleValue)
			if ok and destroyed then
				return false
			end
		end
	end

	return true
end

-- ============================================
-- MODULE LOADER
-- ============================================

local function loadModule(name, url)
	local cacheKey = getCacheKey(name, url)

	-- Check cache
	local cached = getCached(cacheKey)
	if cached then
		if isCachedModuleUsable(name, cached) then
			return cached
		end
		_G.RayfieldCache[cacheKey] = nil
		print("♻️ [Rayfield] Cache invalidated:", cacheKey)
	end
	
	print("⬇️ [Rayfield] Loading:", name)
	
	local success, result = pcall(function()
		local code = game:HttpGet(url)
		return loadstring(code)()
	end)
	
	if not success then
		error("❌ Failed to load " .. name .. ": " .. tostring(result))
	end
	
	-- Cache result
	setCache(cacheKey, result)
	
	print("✅ [Rayfield] Loaded:", name)
	return result
end

-- ============================================
-- URL BUILDER
-- ============================================

local function getModuleUrl(moduleName)
	if CONFIG.USE_PASTEBIN then
		local code = CONFIG.PASTEBIN_CODES[moduleName]
		if not code then
			error("No Pastebin code for: " .. moduleName)
		end
		return "https://pastebin.com/raw/" .. code
	else
		local fileNames = {
			base = "Main%20loader/rayfield-modified.lua",
			enhanced = "feature/rayfield-enhanced.lua",
			advanced = "feature/rayfield-advanced-features.lua"
		}
		return CONFIG.BASE_URL .. fileNames[moduleName]
	end
end

-- ============================================
-- LOAD FUNCTIONS
-- ============================================

function AllInOne.loadBase()
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🚀 Rayfield All-in-One: Base Mode")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	local Rayfield = loadModule("base", getModuleUrl("base"))
	
	print("✅ Ready: Base UI")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	
	return {
		Rayfield = Rayfield,
		mode = "base"
	}
end

function AllInOne.loadEnhanced()
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🛡️ Rayfield All-in-One: Enhanced Mode")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	local Rayfield = loadModule("base", getModuleUrl("base"))
	local Enhancement = loadModule("enhanced", getModuleUrl("enhanced"))
	
	local EnhancedRayfield, ErrorMgr, GC, RemoteProt, LeakDetector, Profiler = 
		Enhancement.createEnhancedRayfield(Rayfield)
	
	print("✅ Ready: Base + Enhanced V2")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	
	return {
		Rayfield = EnhancedRayfield,
		ErrorManager = ErrorMgr,
		GarbageCollector = GC,
		RemoteProtection = RemoteProt,
		MemoryLeakDetector = LeakDetector,
		Profiler = Profiler,
		Enhancement = Enhancement,
		mode = "enhanced"
	}
end

function AllInOne.loadAdvanced()
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("⚡ Rayfield All-in-One: Advanced Mode")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	local Rayfield = loadModule("base", getModuleUrl("base"))
	local Enhancement = loadModule("enhanced", getModuleUrl("enhanced"))
	local Advanced = loadModule("advanced", getModuleUrl("advanced"))
	
	local EnhancedRayfield, ErrorMgr, GC, RemoteProt, LeakDetector, Profiler = 
		Enhancement.createEnhancedRayfield(Rayfield)
	
	print("✅ Ready: Full Stack (Base + Enhanced + Advanced)")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	
	return {
		Rayfield = EnhancedRayfield,
		ErrorManager = ErrorMgr,
		GarbageCollector = GC,
		RemoteProtection = RemoteProt,
		MemoryLeakDetector = LeakDetector,
		Profiler = Profiler,
		Enhancement = Enhancement,
		Advanced = Advanced,
		AnimationAPI = Advanced.AnimationAPI,
		StatePersistence = Advanced.StatePersistence,
		mode = "advanced"
	}
end

function AllInOne.loadAll()
	return AllInOne.loadAdvanced()
end

-- ============================================
-- QUICK SETUP
-- ============================================

function AllInOne.quickSetup(config)
	config = config or {}
	local mode = config.mode or CONFIG.AUTO_MODE
	
	local UI
	if mode == "base" then
		UI = AllInOne.loadBase()
	elseif mode == "enhanced" then
		UI = AllInOne.loadEnhanced()
	elseif mode == "advanced" or mode == "all" then
		UI = AllInOne.loadAdvanced()
	else
		error("Invalid mode: " .. tostring(mode))
	end
	
	-- Apply settings
	if UI.ErrorManager then
		if config.errorThreshold then
			UI.ErrorManager.errorThreshold = config.errorThreshold
		end
		if config.rateLimit then
			UI.ErrorManager.defaultRateLimit = config.rateLimit
		end
	end
	
	if UI.GarbageCollector and config.autoCleanup then
		UI.GarbageCollector.autoCleanupInterval = config.cleanupInterval or 60
	end
	
	return UI
end

-- ============================================
-- CONFIGURE
-- ============================================

function AllInOne.configure(config)
	if config.baseUrl then
		CONFIG.BASE_URL = config.baseUrl
	end
	
	if config.usePastebin ~= nil then
		CONFIG.USE_PASTEBIN = config.usePastebin
	end
	
	if config.pastebinCodes then
		for k, v in pairs(config.pastebinCodes) do
			CONFIG.PASTEBIN_CODES[k] = v
		end
	end
	
	if config.cacheEnabled ~= nil then
		CONFIG.CACHE_ENABLED = config.cacheEnabled
	end
	
	if config.autoMode then
		CONFIG.AUTO_MODE = config.autoMode
	end

	if config.autoExecute ~= nil then
		CONFIG.AUTO_EXECUTE = config.autoExecute
	end

	if config.autoExecuteReturn then
		local mode = tostring(config.autoExecuteReturn):lower()
		if mode == "loader" or mode == "ui" or mode == "none" then
			CONFIG.AUTO_EXECUTE_RETURN = mode
		else
			warn("⚠️ [Rayfield] Invalid autoExecuteReturn: " .. tostring(config.autoExecuteReturn) .. " (use 'loader', 'ui', or 'none')")
		end
	end
	
	print("✅ [Rayfield] Configuration updated")
end

-- ============================================
-- UTILITIES
-- ============================================

function AllInOne.clearCache()
	_G.RayfieldCache = {}
	print("🗑️ [Rayfield] Cache cleared")
end

function AllInOne.info()
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📦 Rayfield All-in-One Loader")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("Version: 2.0.0")
	print("Cache Enabled:", CONFIG.CACHE_ENABLED)
	print("Auto Mode:", CONFIG.AUTO_MODE)
	print("Auto Execute:", CONFIG.AUTO_EXECUTE)
	print("Auto Execute Return:", CONFIG.AUTO_EXECUTE_RETURN)
	print("\nCached Modules:")
	for name, _ in pairs(_G.RayfieldCache) do
		print("  ✅", name)
	end
	print("\nAvailable Modes:")
	print("  • loadBase() - Base UI only")
	print("  • loadEnhanced() - Base + Enhanced V2")
	print("  • loadAdvanced() - Full Stack")
	print("  • loadAll() - Same as loadAdvanced()")
	print("  • quickSetup({mode = 'enhanced'}) - Quick setup")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
end

-- ============================================
-- AUTO EXECUTE
-- ============================================

-- Improvement 3: Dual-execution behavior with clear documentation
-- First execution: Auto-loads UI and returns per CONFIG.AUTO_EXECUTE_RETURN
-- Subsequent executions: Returns AllInOne loader table (manual control)
if CONFIG.AUTO_EXECUTE and not _G.RayfieldAllInOneLoaded then
	_G.RayfieldAllInOneLoaded = true

	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🚀 Rayfield All-in-One Auto-Loading")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("Mode:", CONFIG.AUTO_MODE)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	-- Auto load theo config
	local UI = AllInOne.quickSetup({
		mode = CONFIG.AUTO_MODE,
		errorThreshold = CONFIG.DEFAULT_SETTINGS.errorThreshold,
		rateLimit = CONFIG.DEFAULT_SETTINGS.rateLimit,
		autoCleanup = CONFIG.DEFAULT_SETTINGS.autoCleanup
	})

	-- Export to global
	_G.Rayfield = UI.Rayfield
	_G.RayfieldUI = UI
	AllInOne.currentUI = UI

	print("✅ [Rayfield] Auto-loaded successfully!")
	print("Access via: _G.Rayfield or _G.RayfieldUI")
	print("Return mode:", CONFIG.AUTO_EXECUTE_RETURN, "\n")

	-- Return lightweight loader by default to avoid executor freeze on large return objects
	if CONFIG.AUTO_EXECUTE_RETURN == "ui" then
		return UI
	elseif CONFIG.AUTO_EXECUTE_RETURN == "none" then
		return nil
	end
	return AllInOne
end

-- Return loader table on subsequent executions (allows manual control)
return AllInOne
