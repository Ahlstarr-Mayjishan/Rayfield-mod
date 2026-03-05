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

local function decodeBundlePath(path)
	if type(path) ~= "string" then
		return nil
	end
	return (path:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local function buildLegacyRuntimeConfig(globalEnv)
	if type(globalEnv) ~= "table" then
		return {}
	end
	return {
		runtimeRootUrl = globalEnv.__RAYFIELD_RUNTIME_ROOT_URL,
		httpTimeoutSec = globalEnv.__RAYFIELD_HTTP_TIMEOUT_SEC,
		httpCancelOnTimeout = globalEnv.__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT,
		httpDefaultCancelOnTimeout = globalEnv.__RAYFIELD_HTTP_DEFAULT_CANCEL_ON_TIMEOUT,
		execPolicy = {
			mode = globalEnv.__RAYFIELD_EXEC_POLICY_MODE,
			escalateAfter = globalEnv.__RAYFIELD_EXEC_POLICY_ESCALATE_AFTER,
			windowSec = globalEnv.__RAYFIELD_EXEC_POLICY_WINDOW_SEC
		},
		bundleSources = type(globalEnv.__RAYFIELD_BUNDLE_SOURCES) == "table" and globalEnv.__RAYFIELD_BUNDLE_SOURCES or nil,
		bundleBrokenPaths = type(globalEnv.__RAYFIELD_BUNDLE_BROKEN_PATHS) == "table" and globalEnv.__RAYFIELD_BUNDLE_BROKEN_PATHS or nil,
		compatFlags = type(globalEnv.__RAYFIELD_COMPAT_FLAGS) == "table" and globalEnv.__RAYFIELD_COMPAT_FLAGS or nil
	}
end

local LegacyRuntimeConfig = buildLegacyRuntimeConfig(_G)
local MODULE_ROOT_URL = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
_G.__RAYFIELD_RUNTIME_ROOT_URL = MODULE_ROOT_URL

local function fetchBootstrapSource(path)
	local bundleSources = type(_G) == "table" and _G.__RAYFIELD_BUNDLE_SOURCES or nil
	if type(bundleSources) == "table" then
		local decodedPath = decodeBundlePath(path)
		local bundled = bundleSources[decodedPath or path]
		if type(bundled) == "string" and bundled ~= "" then
			return bundled
		end
	end
	return game:HttpGet(MODULE_ROOT_URL .. path)
end

local ApiClient = type(_G) == "table" and _G.__RayfieldApiClient or nil
if type(ApiClient) ~= "table" or type(ApiClient.fetchAndExecute) ~= "function" then
	local apiClientSource = fetchBootstrapSource("src/api/client.lua")
	ApiClient = compileChunk(apiClientSource, "src/api/client.lua")()
	if _G then
		_G.__RayfieldApiClient = ApiClient
	end
end
if type(ApiClient) == "table" and type(ApiClient.configureRuntime) == "function" then
	pcall(ApiClient.configureRuntime, LegacyRuntimeConfig)
end
if type(ApiClient) == "table" and type(ApiClient.getRuntimeConfig) == "function" then
	local okRuntimeConfig, runtimeConfig = pcall(ApiClient.getRuntimeConfig)
	if okRuntimeConfig and type(runtimeConfig) == "table" and type(runtimeConfig.runtimeRootUrl) == "string" and runtimeConfig.runtimeRootUrl ~= "" then
		MODULE_ROOT_URL = runtimeConfig.runtimeRootUrl
		if type(_G) == "table" then
			_G.__RAYFIELD_RUNTIME_ROOT_URL = MODULE_ROOT_URL
		end
	end
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

local function applyGlobalOverrides()
	if type(_G) ~= "table" then
		return
	end
	if _G.__RAYFIELD_AIO_AUTO_EXECUTE ~= nil then
		CONFIG.AUTO_EXECUTE = _G.__RAYFIELD_AIO_AUTO_EXECUTE == true
	end
	if _G.__RAYFIELD_AIO_AUTO_EXECUTE_RETURN ~= nil then
		local mode = string.lower(tostring(_G.__RAYFIELD_AIO_AUTO_EXECUTE_RETURN))
		if mode == "loader" or mode == "ui" or mode == "none" then
			CONFIG.AUTO_EXECUTE_RETURN = mode
		end
	end
end

applyGlobalOverrides()

local function logInfo(...)
	print("[Rayfield]", ...)
end

local function logWarn(message)
	warn("[Rayfield] " .. tostring(message))
end

local function logBanner(title)
	print("")
	print("[Rayfield] ========================================")
	print("[Rayfield] " .. tostring(title))
	print("[Rayfield] ========================================")
end

-- ============================================
-- CACHE SYSTEM
-- ============================================

_G.RayfieldCache = _G.RayfieldCache or {}

local function getCached(key)
	if CONFIG.CACHE_ENABLED and _G.RayfieldCache[key] then
		logInfo("Using cached module:", key)
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

	local cached = getCached(cacheKey)
	if cached then
		if isCachedModuleUsable(name, cached) then
			return cached
		end
		_G.RayfieldCache[cacheKey] = nil
		logInfo("Cache invalidated:", cacheKey)
	end

	logInfo("Loading module:", name)

	local success, result = pcall(function()
		return ApiClient.fetchAndExecute(url)
	end)

	if not success then
		error("[Rayfield] Failed to load " .. name .. ": " .. tostring(result))
	end

	setCache(cacheKey, result)
	logInfo("Loaded module:", name)
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
		logInfo("Auto reload stopped")
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
		logInfo("Auto reload watching " .. repo .. "@" .. branch .. " (" .. shortCommit(initialCommit) .. ")")
	elseif initialError then
		logWarn("Auto reload initial check failed: " .. tostring(initialError))
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
					logInfo("New commit detected: " .. shortCommit(knownCommit) .. " -> " .. shortCommit(latestCommit))
					local okReload, reloadError = reloadForNewCommit(latestCommit)
					if okReload then
						logInfo("UI reloaded from latest commit (" .. shortCommit(latestCommit) .. ")")
					else
						logWarn("Auto reload failed: " .. tostring(reloadError))
					end
				elseif not knownCommit then
					AutoReloadState.lastCommit = latestCommit
				end
			elseif err then
				logWarn("Auto reload check failed: " .. tostring(err))
			end
		end
	end)

	return true
end

local function startAutoReloadWatcherAsync(errorPrefix)
	task.spawn(function()
		local okStart, errStart = startAutoReloadWatcher()
		if not okStart and errStart then
			logWarn((errorPrefix or "Auto reload start failed: ") .. tostring(errStart))
		end
	end)
end

-- ============================================
-- LOAD FUNCTIONS
-- ============================================

function AllInOne.loadBase()
	logBanner("All-in-One: Base Mode")
	local Rayfield = loadModule("base", getModuleUrl("base"))
	logInfo("Ready: Base UI")
	return {
		Rayfield = Rayfield,
		mode = "base"
	}
end

function AllInOne.loadEnhanced()
	logBanner("All-in-One: Enhanced Mode")
	local Rayfield = loadModule("base", getModuleUrl("base"))
	local Enhancement = loadModule("enhanced", getModuleUrl("enhanced"))

	local EnhancedRayfield, ErrorMgr, GC, RemoteProt, LeakDetector, Profiler =
		Enhancement.createEnhancedRayfield(Rayfield)

	logInfo("Ready: Base + Enhanced V2")
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
	logBanner("All-in-One: Advanced Mode")
	local Rayfield = loadModule("base", getModuleUrl("base"))
	local Enhancement = loadModule("enhanced", getModuleUrl("enhanced"))
	local Advanced = loadModule("advanced", getModuleUrl("advanced"))

	local EnhancedRayfield, ErrorMgr, GC, RemoteProt, LeakDetector, Profiler =
		Enhancement.createEnhancedRayfield(Rayfield)

	logInfo("Ready: Full Stack (Base + Enhanced + Advanced)")
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

local function isUIReusable(ui, mode)
	if type(ui) ~= "table" or type(ui.Rayfield) ~= "table" then
		return false
	end
	if type(mode) == "string" and type(ui.mode) == "string" and ui.mode ~= mode then
		return false
	end
	if type(ui.Rayfield.IsDestroyed) == "function" then
		local okDestroyed, isDestroyed = pcall(ui.Rayfield.IsDestroyed, ui.Rayfield)
		if okDestroyed and isDestroyed then
			return false
		end
	end
	return true
end

-- ============================================
-- QUICK SETUP
-- ============================================

function AllInOne.quickSetup(config)
	config = config or {}
	local mode = config.mode or CONFIG.AUTO_MODE

	if config.forceReload ~= true then
		local existing = AllInOne.currentUI
		if not isUIReusable(existing, mode) then
			existing = _G and _G.RayfieldUI or nil
		end
		if isUIReusable(existing, mode) then
			AllInOne.currentUI = existing
			return existing
		end
	end
	
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
		startAutoReloadWatcherAsync("Auto reload is enabled but failed to start: ")
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
			logWarn("Invalid autoExecuteReturn: " .. tostring(config.autoExecuteReturn) .. " (use 'loader', 'ui', or 'none')")
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
			logWarn("Invalid autoReloadInterval: " .. tostring(config.autoReloadInterval))
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
			logWarn("autoReloadCallback must be a function")
		end
	end

	if CONFIG.AUTO_RELOAD_ENABLED then
		if AutoReloadState.running then
			stopAutoReloadWatcher(true)
		end
		local okStart, errStart = startAutoReloadWatcher()
		if not okStart and errStart then
			logWarn("Auto reload start failed: " .. tostring(errStart))
		end
	else
		stopAutoReloadWatcher(true)
	end

	logInfo("Configuration updated")
end

-- ============================================
-- UTILITIES
-- ============================================

function AllInOne.clearCache()
	_G.RayfieldCache = {}
	if type(_G.__RayfieldApiModuleCache) == "table" then
		table.clear(_G.__RayfieldApiModuleCache)
	end
	logInfo("Cache cleared")
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
	logBanner("All-in-One Loader")
	logInfo("Version:", "2.1.0")
	logInfo("Cache Enabled:", CONFIG.CACHE_ENABLED)
	logInfo("Auto Mode:", CONFIG.AUTO_MODE)
	logInfo("Auto Execute:", CONFIG.AUTO_EXECUTE)
	logInfo("Auto Execute Return:", CONFIG.AUTO_EXECUTE_RETURN)
	logInfo("Auto Reload:", CONFIG.AUTO_RELOAD_ENABLED)
	logInfo("Auto Reload Interval:", CONFIG.AUTO_RELOAD_INTERVAL)
	logInfo("Auto Reload Repo:", CONFIG.AUTO_RELOAD_REPO .. "@" .. CONFIG.AUTO_RELOAD_BRANCH)
	logInfo("Last Seen Commit:", AutoReloadState.lastCommit and shortCommit(AutoReloadState.lastCommit) or "n/a")

	logInfo("Cached Modules:")
	for name, _ in pairs(_G.RayfieldCache) do
		logInfo(" -", name)
	end

	logInfo("Available Modes:")
	logInfo(" - loadBase() - Base UI only")
	logInfo(" - loadEnhanced() - Base + Enhanced V2")
	logInfo(" - loadAdvanced() - Full Stack")
	logInfo(" - loadAll() - Same as loadAdvanced()")
	logInfo(" - quickSetup({mode = 'enhanced'}) - Quick setup")
	logInfo(" - startAutoReload() / stopAutoReload()")
	logInfo(" - checkForUpdates() / reloadNow()")
end

-- ============================================
-- AUTO EXECUTE
-- ============================================

-- Improvement 3: Dual-execution behavior with clear documentation
-- First execution: Auto-loads UI and returns per CONFIG.AUTO_EXECUTE_RETURN
-- Subsequent executions: Returns AllInOne loader table (manual control)
if CONFIG.AUTO_EXECUTE and not _G.RayfieldAllInOneLoaded then
	_G.RayfieldAllInOneLoaded = true

	logBanner("All-in-One Auto-Loading")
	logInfo("Mode:", CONFIG.AUTO_MODE)

	local UI = AllInOne.quickSetup({
		mode = CONFIG.AUTO_MODE,
		errorThreshold = CONFIG.DEFAULT_SETTINGS.errorThreshold,
		rateLimit = CONFIG.DEFAULT_SETTINGS.rateLimit,
		autoCleanup = CONFIG.DEFAULT_SETTINGS.autoCleanup
	})

	_G.Rayfield = UI.Rayfield
	_G.RayfieldUI = UI
	AllInOne.currentUI = UI

	logInfo("Auto-loaded successfully")
	logInfo("Access via: _G.Rayfield or _G.RayfieldUI")
	logInfo("Return mode:", CONFIG.AUTO_EXECUTE_RETURN)

	if CONFIG.AUTO_EXECUTE_RETURN == "ui" then
		return UI
	elseif CONFIG.AUTO_EXECUTE_RETURN == "none" then
		return nil
	end
	return AllInOne
end

-- Return loader table on subsequent executions (allows manual control)
return AllInOne

