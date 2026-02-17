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
		loadstring(game:HttpGet('https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-all-in-one.lua'))()

	Hoặc nếu host trên Pastebin:
		loadstring(game:HttpGet('https://pastebin.com/raw/YOUR_CODE'))()
]]

local AllInOne = {}
local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end
local HttpService = game:GetService("HttpService")

local function compileChunk(source, label)
	if type(source) ~= "string" then
		error("Invalid Lua source for " .. tostring(label) .. ": " .. type(source))
	end
	source = source:gsub("^\239\187\191", "")
	source = source:gsub("^\0+", "")
	local chunk, err = compileString(source)
	if not chunk then
		error("Failed to compile " .. tostring(label) .. ": " .. tostring(err))
	end
	return chunk
end

local MODULE_ROOT_URL = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
_G.__RAYFIELD_RUNTIME_ROOT_URL = MODULE_ROOT_URL
local apiClientSource = game:HttpGet(MODULE_ROOT_URL .. "src/api/client.lua")
local ApiClient = compileChunk(apiClientSource, "src/api/client.lua")()
if _G then
	_G.__RayfieldApiClient = ApiClient
end

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
	-- "ui" = return UI table from quickSetup
	-- "none" = return nil
	AUTO_EXECUTE_RETURN = "loader",

	-- Auto reload when GitHub has a new commit
	AUTO_RELOAD_ENABLED = true,
	AUTO_RELOAD_INTERVAL = 120, -- seconds
	AUTO_RELOAD_REPO = "Ahlstarr-Mayjishan/Rayfield-mod",
	AUTO_RELOAD_BRANCH = "main",
	AUTO_RELOAD_CLEAR_CACHE = true,
	
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
		return ApiClient.fetchAndExecute(url)
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
			enhanced = "src/entry/rayfield-enhanced.entry.lua",
			advanced = "src/feature/enhanced/advanced.lua"
		}
		return CONFIG.BASE_URL .. fileNames[moduleName]
	end
end

-- ============================================
-- AUTO RELOAD (COMMIT WATCHER)
-- ============================================

_G.RayfieldAllInOneAutoReloadState = _G.RayfieldAllInOneAutoReloadState or {
	running = false,
	reloading = false,
	token = 0,
	lastCommit = nil,
	lastReloadAt = nil,
	onReload = nil
}
local AutoReloadState = _G.RayfieldAllInOneAutoReloadState

local function shortCommit(commit)
	if type(commit) ~= "string" then
		return "unknown"
	end
	return string.sub(commit, 1, 7)
end

local function resolveRepoBranch()
	local repo = CONFIG.AUTO_RELOAD_REPO
	local branch = CONFIG.AUTO_RELOAD_BRANCH

	if (not repo or repo == "") and type(CONFIG.BASE_URL) == "string" then
		local owner, repoName, parsedBranch = string.match(CONFIG.BASE_URL, "raw%.githubusercontent%.com/([^/]+)/([^/]+)/([^/]+)/")
		if owner and repoName then
			repo = owner .. "/" .. repoName
			if not branch or branch == "" then
				branch = parsedBranch or "main"
			end
		end
	end

	if not branch or branch == "" then
		branch = "main"
	end

	return repo, branch
end

local function fetchLatestCommit()
	if CONFIG.USE_PASTEBIN then
		return nil, "auto reload only supports GitHub source"
	end

	local repo, branch = resolveRepoBranch()
	if not repo or repo == "" then
		return nil, "cannot resolve repository for auto reload"
	end

	local stamp = tostring(math.floor(os.clock() * 1000))
	local url = "https://api.github.com/repos/" .. repo .. "/commits/" .. branch .. "?_=" .. stamp

	local okHttp, body = pcall(function()
		return game:HttpGet(url)
	end)
	if not okHttp then
		return nil, tostring(body)
	end

	local okDecode, payload = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not okDecode or type(payload) ~= "table" then
		return nil, "failed to decode GitHub response"
	end

	if type(payload.sha) ~= "string" or payload.sha == "" then
		return nil, "commit sha missing from response"
	end

	return payload.sha
end

local function exportCurrentUI(ui)
	if not ui or type(ui) ~= "table" then
		return
	end
	AllInOne.currentUI = ui
	_G.RayfieldUI = ui
	_G.Rayfield = ui.Rayfield
end

local function reloadForNewCommit(newCommit)
	if AutoReloadState.reloading then
		return false, "reload is already in progress"
	end

	AutoReloadState.reloading = true
	local previousRayfield = _G.Rayfield
	local previousUI = AllInOne.currentUI or _G.RayfieldUI
	local mode = (previousUI and previousUI.mode) or CONFIG.AUTO_MODE

	if CONFIG.AUTO_RELOAD_CLEAR_CACHE then
		AllInOne.clearCache()
	end

	local okLoad, reloadedUI = pcall(AllInOne.quickSetup, {
		mode = mode,
		errorThreshold = CONFIG.DEFAULT_SETTINGS.errorThreshold,
		rateLimit = CONFIG.DEFAULT_SETTINGS.rateLimit,
		autoCleanup = CONFIG.DEFAULT_SETTINGS.autoCleanup
	})

	if not okLoad then
		AutoReloadState.reloading = false
		return false, "reload failed: " .. tostring(reloadedUI)
	end

	if previousRayfield and previousRayfield ~= reloadedUI.Rayfield and type(previousRayfield.Destroy) == "function" then
		pcall(function()
			previousRayfield:Destroy()
		end)
	end

	exportCurrentUI(reloadedUI)
	AutoReloadState.lastCommit = newCommit or AutoReloadState.lastCommit
	AutoReloadState.lastReloadAt = os.time()

	if type(AutoReloadState.onReload) == "function" then
		pcall(AutoReloadState.onReload, reloadedUI, previousUI, newCommit)
	end

	AutoReloadState.reloading = false
	return true
end

local function stopAutoReloadWatcher(silent)
	AutoReloadState.running = false
	AutoReloadState.token = (AutoReloadState.token or 0) + 1
	if not silent then
		print("🛑 [Rayfield] Auto reload stopped")
	end
end

local function startAutoReloadWatcher()
	if not CONFIG.AUTO_RELOAD_ENABLED then
		return false, "auto reload is disabled"
	end
	if CONFIG.USE_PASTEBIN then
		return false, "auto reload requires GitHub source"
	end
	if AutoReloadState.running then
		return true
	end

	local interval = tonumber(CONFIG.AUTO_RELOAD_INTERVAL) or 120
	if interval < 30 then
		interval = 30
	end
	CONFIG.AUTO_RELOAD_INTERVAL = interval

	local repo, branch = resolveRepoBranch()
	if not repo or repo == "" then
		return false, "cannot resolve repository"
	end

	AutoReloadState.running = true
	AutoReloadState.token = (AutoReloadState.token or 0) + 1
	local token = AutoReloadState.token

	local initialCommit, initialError = fetchLatestCommit()
	if initialCommit then
		AutoReloadState.lastCommit = initialCommit
		print("🔄 [Rayfield] Auto reload watching " .. repo .. "@" .. branch .. " (" .. shortCommit(initialCommit) .. ")")
	elseif initialError then
		warn("⚠️ [Rayfield] Auto reload initial check failed: " .. tostring(initialError))
	end

	task.spawn(function()
		while AutoReloadState.running and AutoReloadState.token == token do
			task.wait(interval)
			if not AutoReloadState.running or AutoReloadState.token ~= token then
				break
			end

			local latestCommit, err = fetchLatestCommit()
			if latestCommit then
				local knownCommit = AutoReloadState.lastCommit
				if knownCommit and knownCommit ~= latestCommit then
					print("🆕 [Rayfield] New commit detected: " .. shortCommit(knownCommit) .. " -> " .. shortCommit(latestCommit))
					local okReload, reloadError = reloadForNewCommit(latestCommit)
					if okReload then
						print("♻️ [Rayfield] UI reloaded from latest commit (" .. shortCommit(latestCommit) .. ")")
					else
						warn("⚠️ [Rayfield] Auto reload failed: " .. tostring(reloadError))
					end
				elseif not knownCommit then
					AutoReloadState.lastCommit = latestCommit
				end
			elseif err then
				warn("⚠️ [Rayfield] Auto reload check failed: " .. tostring(err))
			end
		end
	end)

	return true
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

	AllInOne.currentUI = UI

	if CONFIG.AUTO_RELOAD_ENABLED and not AutoReloadState.running then
		local okStart, errStart = startAutoReloadWatcher()
		if not okStart and errStart then
			warn("⚠️ [Rayfield] Auto reload is enabled but failed to start: " .. tostring(errStart))
		end
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

	if config.autoReload ~= nil then
		CONFIG.AUTO_RELOAD_ENABLED = config.autoReload and true or false
	end

	if config.autoReloadEnabled ~= nil then
		CONFIG.AUTO_RELOAD_ENABLED = config.autoReloadEnabled and true or false
	end

	if config.autoReloadInterval ~= nil then
		local interval = tonumber(config.autoReloadInterval)
		if interval and interval > 0 then
			CONFIG.AUTO_RELOAD_INTERVAL = interval
		else
			warn("⚠️ [Rayfield] Invalid autoReloadInterval: " .. tostring(config.autoReloadInterval))
		end
	end

	if config.autoReloadRepo then
		CONFIG.AUTO_RELOAD_REPO = tostring(config.autoReloadRepo)
	end

	if config.autoReloadBranch then
		CONFIG.AUTO_RELOAD_BRANCH = tostring(config.autoReloadBranch)
	end

	if config.autoReloadClearCache ~= nil then
		CONFIG.AUTO_RELOAD_CLEAR_CACHE = config.autoReloadClearCache and true or false
	end

	if config.autoReloadCallback ~= nil then
		if type(config.autoReloadCallback) == "function" then
			AutoReloadState.onReload = config.autoReloadCallback
		else
			warn("⚠️ [Rayfield] autoReloadCallback must be a function")
		end
	end

	if CONFIG.AUTO_RELOAD_ENABLED then
		if AutoReloadState.running then
			stopAutoReloadWatcher(true)
		end
		local okStart, errStart = startAutoReloadWatcher()
		if not okStart and errStart then
			warn("⚠️ [Rayfield] Auto reload start failed: " .. tostring(errStart))
		end
	else
		stopAutoReloadWatcher(true)
	end
	
	print("✅ [Rayfield] Configuration updated")
end

-- ============================================
-- UTILITIES
-- ============================================

function AllInOne.clearCache()
	_G.RayfieldCache = {}
	if type(_G.__RayfieldApiModuleCache) == "table" then
		table.clear(_G.__RayfieldApiModuleCache)
	end
	print("🗑️ [Rayfield] Cache cleared")
end

function AllInOne.checkForUpdates()
	local latestCommit, err = fetchLatestCommit()
	if not latestCommit then
		return {
			ok = false,
			error = err
		}
	end

	local currentCommit = AutoReloadState.lastCommit
	return {
		ok = true,
		latestCommit = latestCommit,
		currentCommit = currentCommit,
		hasUpdate = currentCommit ~= nil and latestCommit ~= currentCommit
	}
end

function AllInOne.reloadNow()
	local latestCommit, err = fetchLatestCommit()
	if not latestCommit then
		return false, "cannot fetch latest commit: " .. tostring(err)
	end
	local okReload, errReload = reloadForNewCommit(latestCommit)
	return okReload, errReload
end

function AllInOne.startAutoReload()
	CONFIG.AUTO_RELOAD_ENABLED = true
	return startAutoReloadWatcher()
end

function AllInOne.stopAutoReload()
	CONFIG.AUTO_RELOAD_ENABLED = false
	stopAutoReloadWatcher()
end

function AllInOne.setAutoReloadCallback(callback)
	if callback ~= nil and type(callback) ~= "function" then
		error("auto reload callback must be a function or nil")
	end
	AutoReloadState.onReload = callback
end

function AllInOne.info()
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📦 Rayfield All-in-One Loader")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("Version: 2.1.0")
	print("Cache Enabled:", CONFIG.CACHE_ENABLED)
	print("Auto Mode:", CONFIG.AUTO_MODE)
	print("Auto Execute:", CONFIG.AUTO_EXECUTE)
	print("Auto Execute Return:", CONFIG.AUTO_EXECUTE_RETURN)
	print("Auto Reload:", CONFIG.AUTO_RELOAD_ENABLED)
	print("Auto Reload Interval:", CONFIG.AUTO_RELOAD_INTERVAL)
	print("Auto Reload Repo:", CONFIG.AUTO_RELOAD_REPO .. "@" .. CONFIG.AUTO_RELOAD_BRANCH)
	print("Last Seen Commit:", AutoReloadState.lastCommit and shortCommit(AutoReloadState.lastCommit) or "n/a")
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
	print("  • startAutoReload() / stopAutoReload()")
	print("  • checkForUpdates() / reloadNow()")
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

	if CONFIG.AUTO_RELOAD_ENABLED then
		local okStart, errStart = startAutoReloadWatcher()
		if not okStart and errStart then
			warn("⚠️ [Rayfield] Auto reload start failed: " .. tostring(errStart))
		end
	end

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
