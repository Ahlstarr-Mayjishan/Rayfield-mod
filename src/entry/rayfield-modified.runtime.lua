--[[

	Rayfield Interface Suite
	by Sirius

	shlex  | Designing + Programming
	iRay   | Programming
	Max    | Programming
	Damian | Programming

	Modified Version with Extended API:
	- Element:Destroy() - Remove elements after creation
	- Element:Show() / :Hide() - Toggle element visibility
	- Element:SetVisible(bool) - Set visibility programmatically
	- Tab:Clear() - Remove all elements in tab
	- Section:Clear() - Remove all elements in section
	- Tab:GetElements() - Get list of all elements
	- Tab:FindElement(name) - Find element by name
	- Element:GetParent() - Get parent tab/section
	- Dropdown:Clear() visual fix - Updates UI immediately

]]

if debugX then
	warn('Initialising Rayfield')
end

local Compatibility = nil
local function getService(name)
	return game:GetService(name)
end

-- Loads and executes a function hosted on a remote URL. Cancels the request if the requested URL takes too long to respond.
-- Errors with the function are caught and logged to the output
local function loadWithTimeout(url: string, timeout: number?): ...any
	assert(type(url) == "string", "Expected string, got " .. type(url))
	timeout = timeout or 5
	local requestCompleted = false
	local success, result = false, nil

	local requestThread = task.spawn(function()
		local fetchSuccess, fetchResult = pcall(game.HttpGet, game, url) -- game:HttpGet(url)
		-- Handle executor/network edge-cases where fetchResult can be nil/non-string.
		if not fetchSuccess then
			success, result = false, tostring(fetchResult or "HTTP request failed")
			requestCompleted = true
			return
		end

		if type(fetchResult) ~= "string" then
			success, result = false, "Invalid HTTP response type: " .. type(fetchResult)
			requestCompleted = true
			return
		end

		-- If the request succeeds but content is empty, surface a readable error.
		if #fetchResult == 0 then
			success, result = false, "Empty response"
			requestCompleted = true
			return
		end
		local content = fetchResult -- Fetched content

		-- Improvement 2: Validate content before passing to loadstring
		if type(content) ~= "string" then
			success, result = false, "Invalid content type: expected string, got " .. type(content)
			requestCompleted = true
			return
		end

		if #content == 0 then
			success, result = false, "Content is empty"
			requestCompleted = true
			return
		end

		local execSuccess, execResult = pcall(function()
			return loadstring(content)()
		end)
		success, result = execSuccess, execResult
		requestCompleted = true
	end)

	local timeoutThread = task.delay(timeout, function()
		if not requestCompleted then
			warn("Request for " .. url .. " timed out after " .. tostring(timeout) .. " seconds")
			task.cancel(requestThread)
			result = "Request timed out"
			requestCompleted = true
		end
	end)

	-- Wait for completion or timeout
	while not requestCompleted do
		task.wait()
	end
	-- Cancel timeout thread if still running when request completes
	if coroutine.status(timeoutThread) ~= "dead" then
		task.cancel(timeoutThread)
	end
	if not success then
		warn("Failed to process " .. tostring(url) .. ": " .. tostring(result))
	end
	return if success then result else nil
end

local requestsDisabled = true --getgenv and getgenv().DISABLE_RAYFIELD_REQUESTS
local InterfaceBuild = '3K3W'
local Release = "Build 1.68"
local RayfieldFolder = "Rayfield"
local ConfigurationFolder = RayfieldFolder.."/Configurations"
local ConfigurationExtension = ".rfld"
local settingsTable = {
	General = {
		-- if needs be in order just make getSetting(name)
		rayfieldOpen = {Type = 'bind', Value = 'K', Name = 'Rayfield Keybind'},
		-- buildwarnings
		-- rayfieldprompts

	},
	System = {
		usageAnalytics = {Type = 'toggle', Value = true, Name = 'Anonymised Analytics'},
	}
}

local HttpService = getService('HttpService')
local RunService = getService('RunService')

-- Environment Check
local useStudio = RunService:IsStudio() or false

local prompt = useStudio and require(script.Parent.prompt) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Sirius/refs/heads/request/prompt.lua')
local requestFunc = (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request) or http_request or request

-- Validate prompt loaded correctly
if not prompt and not useStudio then
	warn("Failed to load prompt library, using fallback")
	prompt = {
		create = function() end -- No-op fallback
	}
end


-- The function below provides a safe alternative for calling error-prone functions
-- Especially useful for filesystem function (writefile, makefolder, etc.)
local function callSafely(func, ...)
	if func then
		local success, result = pcall(func, ...)
		if not success then
			warn("Rayfield | Function failed with error: ", result)
			return false
		else
			return result
		end
	end
end

-- Ensures a folder exists by creating it if needed
local function ensureFolder(folderPath)
	if isfolder and not callSafely(isfolder, folderPath) then
		callSafely(makefolder, folderPath)
	end
end

if debugX then
	warn('Now Loading Settings Configuration')
end

-- Note: Settings functions will be initialized after modules are loaded

if debugX then
	warn('Settings Loaded')
end

local analyticsLib
local sendReport = function(ev_n, sc_n) warn("Failed to load report function") end
if not requestsDisabled then
	if debugX then
		warn('Querying Settings for Reporter Information')
	end	
	analyticsLib = loadWithTimeout("https://analytics.sirius.menu/script")
	if not analyticsLib then
		warn("Failed to load analytics reporter")
		analyticsLib = nil
	elseif analyticsLib and type(analyticsLib.load) == "function" then
		analyticsLib:load()
	else
		warn("Analytics library loaded but missing load function")
		analyticsLib = nil
	end
	sendReport = function(ev_n, sc_n)
		if not (type(analyticsLib) == "table" and type(analyticsLib.isLoaded) == "function" and analyticsLib:isLoaded()) then
			warn("Analytics library not loaded")
			return
		end
		if useStudio then
			print('Sending Analytics')
		else
			if debugX then warn('Reporting Analytics') end
			analyticsLib:report(
				{
					["name"] = ev_n,
					["script"] = {["name"] = sc_n, ["version"] = Release}
				},
				{
					["version"] = InterfaceBuild
				}
			)
			if debugX then warn('Finished Report') end
		end
	end
	local shouldReportExecution = false
	if type(cachedSettings) == "table" then
		shouldReportExecution = (next(cachedSettings) == nil) or (cachedSettings.System and cachedSettings.System.usageAnalytics and cachedSettings.System.usageAnalytics.Value)
	elseif cachedSettings == nil then
		shouldReportExecution = true
	end

	if shouldReportExecution then
		sendReport("execution", "Rayfield")
	end
end

local promptUser = 2

if promptUser == 1 and prompt and type(prompt.create) == "function" then
	prompt.create(
		'Be cautious when running scripts',
	    [[Please be careful when running scripts from unknown developers. This script has already been ran.

<font transparency='0.3'>Some scripts may steal your items or in-game goods.</font>]],
		'Okay',
		'',
		function()

		end
	)
end

if debugX then
	warn('Moving on to continue initialisation')
end

local RayfieldLibrary = {
	Flags = {},
	Theme = {}
}

-- Compatibility wrapper for loadstring (some executors use different names)
local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load). Your executor may not support dynamic code loading.")
end

-- Load external modules through shared API loader
local MODULE_ROOT_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
_G.__RAYFIELD_RUNTIME_ROOT_URL = MODULE_ROOT_URL

local ApiClient = compileString(game:HttpGet(MODULE_ROOT_URL .. "src/api/client.lua"))()
local function fetchExecuteSafely(path)
	local ok, result = pcall(ApiClient.fetchAndExecute, MODULE_ROOT_URL .. path)
	if ok then
		return true, result
	end
	return false, tostring(result)
end

local okCompatibility, compatibilityResult = fetchExecuteSafely("src/services/compatibility.lua")
if okCompatibility and type(compatibilityResult) == "table" then
	Compatibility = compatibilityResult
else
	warn("Rayfield Mod: [W_BOOTSTRAP_COMPAT] Failed to load compatibility service; using fallback compatibility.")
	if not okCompatibility then
		warn("Rayfield Mod: [W_BOOTSTRAP_COMPAT_REASON] " .. tostring(compatibilityResult))
	end
	Compatibility = {
		getService = function(name)
			return game:GetService(name)
		end,
		getCompileString = function()
			return compileString
		end,
		protectAndParent = function(gui, preferredContainer, opts)
			local inStudio = opts and opts.useStudio
			if inStudio then
				return nil
			end
			local okCore, core = pcall(function()
				return game:GetService("CoreGui")
			end)
			if okCore and core then
				gui.Parent = core
				return core
			end
			return nil
		end,
		dedupeGuiByName = function()
			return
		end
	}
end
if _G then
	_G.__RayfieldCompatibility = Compatibility
end
if type(Compatibility.getService) == "function" then
	getService = Compatibility.getService
end
if type(Compatibility.getCompileString) == "function" then
	compileString = Compatibility.getCompileString()
end

local okWidgetBootstrap, widgetBootstrapResult = fetchExecuteSafely("src/ui/elements/widgets/bootstrap.lua")
local WidgetBootstrap = okWidgetBootstrap and widgetBootstrapResult or nil
if type(WidgetBootstrap) ~= "table" or type(WidgetBootstrap.bootstrapWidget) ~= "function" then
	warn("Rayfield Mod: [W_BOOTSTRAP_WIDGETS] Failed to load widget bootstrap; using fallback widget loader.")
	if not okWidgetBootstrap then
		warn("Rayfield Mod: [W_BOOTSTRAP_WIDGETS_REASON] " .. tostring(widgetBootstrapResult))
	end
	WidgetBootstrap = {
		bootstrapWidget = function(widgetName, targetPath, exportAdapter, opts)
			local moduleValue = ApiClient.fetchAndExecute(MODULE_ROOT_URL .. tostring(targetPath))
			if opts and opts.expectedType and type(moduleValue) ~= opts.expectedType then
				error("Rayfield Mod: [E_WIDGET_BOOTSTRAP] " .. tostring(widgetName) .. " expected " .. tostring(opts.expectedType) .. ", got " .. type(moduleValue))
			end
			if type(exportAdapter) == "function" then
				return exportAdapter(moduleValue)
			end
			return moduleValue
		end
	}
end
if _G then
	_G.__RayfieldWidgetBootstrap = WidgetBootstrap
end
local okApiLoader, apiLoaderResult = fetchExecuteSafely("src/api/loader.lua")
if not okApiLoader then
	error("Rayfield Mod: [E_BOOTSTRAP_LOADER] Failed to load API loader: " .. tostring(apiLoaderResult))
end
local ApiLoader = apiLoaderResult
if type(ApiLoader) ~= "table" or type(ApiLoader.load) ~= "function" then
	error("Rayfield Mod: [E_BOOTSTRAP_LOADER] Invalid API loader contract")
end

local function getScriptRef()
	local scriptRef = nil
	pcall(function()
		scriptRef = script
	end)
	return scriptRef
end

local function loadModule(moduleName)
	local opts = {
		tryStudioRequire = useStudio,
		scriptRef = getScriptRef(),
		allowLegacyFallback = true
	}
	if type(ApiLoader.tryLoad) == "function" then
		return ApiLoader.tryLoad(moduleName, opts)
	end
	local ok, result = pcall(ApiLoader.load, moduleName, opts)
	if ok then
		return true, result
	end
	return false, tostring(result)
end

local function formatLoaderError(code, message)
	return string.format("Rayfield Mod: [%s] %s", tostring(code or "E_LOADER"), tostring(message or "Unknown loader error"))
end

local function requireModule(moduleName, hint)
	local ok, result = loadModule(moduleName)
	if ok then
		return result
	end
	local reason = tostring(result)
	if hint then
		reason = tostring(hint) .. "\n" .. reason
	end
	error(formatLoaderError("E_REQUIRED_MODULE", "Failed to load required module '" .. tostring(moduleName) .. "'.\n" .. reason))
end

local loaderDiagnostics = {
	optionalFailed = {},
	notified = false,
	performanceProfile = nil
}
if _G then
	_G.__RAYFIELD_LOADER_DIAGNOSTICS = loaderDiagnostics
end

local function optionalModule(moduleName, fallbackModule, hint)
	local ok, result = loadModule(moduleName)
	if ok then
		return result
	end
	table.insert(loaderDiagnostics.optionalFailed, {
		module = moduleName,
		error = tostring(result)
	})
	local message = "Optional module '" .. tostring(moduleName) .. "' failed to load. Using fallback."
	if hint then
		message = message .. " " .. tostring(hint)
	end
	warn(formatLoaderError("W_OPTIONAL_MODULE", message .. " | " .. tostring(result)))
	return fallbackModule
end

local function maybeNotifyLoaderFallback()
	if loaderDiagnostics.notified or #loaderDiagnostics.optionalFailed == 0 then
		return
	end
	loaderDiagnostics.notified = true
	local moduleNames = {}
	for _, item in ipairs(loaderDiagnostics.optionalFailed) do
		table.insert(moduleNames, tostring(item.module))
	end
	local message = "Loaded with fallback modules: " .. table.concat(moduleNames, ", ")
	if type(RayfieldLibrary.Notify) == "function" then
		pcall(function()
			RayfieldLibrary:Notify({
				Title = "Rayfield Loader",
				Content = message,
				Duration = 8
			})
		end)
	else
		warn(formatLoaderError("W_OPTIONAL_MODULE", message))
	end
end

local FallbackElementSyncModule = {
	init = function()
		return nil
	end
}

local FallbackOwnershipTrackerModule = {
	init = function()
		local function noopReturnFalse()
			return false
		end
		local function noopReturnNil()
			return nil
		end
		return {
			createScope = function(scopeId)
				return tostring(scopeId or "")
			end,
			makeScopeId = function(kind, id)
				return tostring(kind or "scope") .. ":" .. tostring(id or "")
			end,
			claimInstance = noopReturnFalse,
			trackConnection = noopReturnFalse,
			trackTask = noopReturnFalse,
			trackCleanup = noopReturnFalse,
			cleanupScope = noopReturnFalse,
			cleanupByInstance = noopReturnFalse,
			cleanupSession = noopReturnFalse,
			getStats = function()
				return {
					scopes = 0,
					instances = 0,
					connections = 0,
					tasks = 0,
					cleanups = 0
				}
			end,
			getSignature = noopReturnNil
		}
	end
}

local FallbackDragModule = {
	init = function()
		local function noop() end
		return {
			makeElementDetachable = function()
				return nil
			end,
			setLayoutDirtyCallback = noop,
			getLayoutSnapshot = function()
				return {}
			end,
			applyLayoutSnapshot = function()
				return false
			end
		}
	end
}

local FallbackTabSplitModule = {
	init = function()
		local function noop() end
		return {
			registerTab = noop,
			unregisterTab = noop,
			splitTab = function() return false end,
			dockTab = function() return false end,
			layoutPanels = noop,
			syncHidden = noop,
			syncMinimized = noop,
			setLayoutDirtyCallback = noop,
			getLayoutSnapshot = function() return {} end,
			applyLayoutSnapshot = function() return false end,
			destroy = noop
		}
	end
}

local FallbackLayoutPersistenceModule = {
	init = function()
		local function noop() end
		return {
			registerProvider = noop,
			unregisterProvider = noop,
			getLayoutSnapshot = function() return nil end,
			applyLayoutSnapshot = function() return false end,
			markDirty = noop,
			flush = noop,
			isApplying = function() return false end,
			isDirty = function() return false end
		}
	end
}

local FallbackViewportVirtualizationModule = {
	init = function()
		local function noopReturnFalse()
			return false
		end
		local function noopReturnNil()
			return nil
		end
		return {
			registerHost = noopReturnFalse,
			unregisterHost = noopReturnFalse,
			refreshHost = noopReturnFalse,
			setHostSuppressed = noopReturnFalse,
			registerElement = noopReturnNil,
			unregisterElement = noopReturnFalse,
			moveElementToHost = noopReturnFalse,
			setElementBusy = noopReturnFalse,
			notifyElementHostChanged = noopReturnFalse,
			getStats = function()
				return {
					hosts = 0,
					elements = 0,
					sleeping = 0
				}
			end,
			destroy = function() end
		}
	end
}

local ThemeModule = requireModule("theme")
-- Load utilities early so shared helpers are registered globally before other services initialize.
local UtilitiesModuleLib = requireModule("utilities")
local SettingsModuleLib = requireModule("settings")
local OwnershipTrackerModuleLib = optionalModule("ownershipTracker", FallbackOwnershipTrackerModule, "Scoped ownership cleanup will run in compatibility mode.")
local ElementSyncModuleLib = optionalModule("elementSync", FallbackElementSyncModule, "Element state sync will run in compatibility mode.")
local KeybindSequenceLib = requireModule("keybindSequence")
local DragModuleLib = optionalModule("drag", FallbackDragModule, "Detach/reorder advanced drag features are disabled for this session.")
local UIStateModuleLib = requireModule("uiState")
local ElementsModuleLib = requireModule("elements")
local ConfigModuleLib = requireModule("config")
local LayoutPersistenceModuleLib = optionalModule("layoutPersistence", FallbackLayoutPersistenceModule, "Layout persistence is disabled for this session.")
local ViewportVirtualizationModuleLib = optionalModule("viewportVirtualization", FallbackViewportVirtualizationModule, "Viewport virtualization is disabled for this session.")
local TabSplitModuleLib = optionalModule("tabSplit", FallbackTabSplitModule, "Tab split features are disabled for this session.")
local AnimationEngineLib = requireModule("animationEngine")
local AnimationPublicLib = requireModule("animationPublic")
local AnimationSequenceLib = requireModule("animationSequence")
local AnimationUILib = requireModule("animationUI")
local AnimationTextLib = requireModule("animationText")
local AnimationCleanupLib = requireModule("animationCleanup")
local VisibilityControllerLib = requireModule("runtimeVisibilityController")
local ExperienceBindingsLib = requireModule("runtimeExperienceBindings")
local RuntimeApiLib = requireModule("runtimeApi")

-- Services
local UserInputService = getService("UserInputService")
local TweenService = getService("TweenService")
local Players = getService("Players")
local CoreGui = getService("CoreGui")

local AnimationEngine = AnimationEngineLib.new({
	TweenService = TweenService,
	RunService = RunService,
	Cleanup = AnimationCleanupLib,
	mode = "raw"
})
local Animation = AnimationEngine
local RayfieldAnimate = AnimationPublicLib.bindToRayfield(RayfieldLibrary, AnimationEngine, {
	Sequence = AnimationSequenceLib,
	UI = AnimationUILib,
	Text = AnimationTextLib
})
if _G then
	_G.__RayfieldSharedAnimationEngine = AnimationEngine
	_G.__RayfieldSharedAnimateFacade = RayfieldAnimate
end

-- Interface Management

local Rayfield
if useStudio then
	Rayfield = script.Parent:FindFirstChild('Rayfield')
else
	-- Try to load GUI from Roblox asset
	local success, result = pcall(function()
		return game:GetObjects("rbxassetid://10804731440")[1]
	end)

	if success and result then
		Rayfield = result
	else
		-- Fallback: Some executors don't support game:GetObjects()
		warn("Rayfield | game:GetObjects() failed. Your executor may not support loading GUI assets.")
		warn("Rayfield | Error: " .. tostring(result))
		error("Unable to load Rayfield GUI. Your executor may not support game:GetObjects(). Try using a different executor or loading from a local file.")
	end
end

if not Rayfield then
	error("Rayfield GUI failed to load. Please check your executor compatibility.")
end

local buildAttempts = 0
local correctBuild = false
local warned
local globalLoaded
local rayfieldDestroyed = false -- True when RayfieldLibrary:Destroy() is called

repeat
	if Rayfield:FindFirstChild('Build') and Rayfield.Build.Value == InterfaceBuild then
		correctBuild = true
		break
	end

	correctBuild = false

	if not warned then
		warn('Rayfield | Build Mismatch')
		print('Rayfield may encounter issues as you are running an incompatible interface version ('.. ((Rayfield:FindFirstChild('Build') and Rayfield.Build.Value) or 'No Build') ..').\n\nThis version of Rayfield is intended for interface build '..InterfaceBuild..'.')
		warned = true
	end

	local oldRayfield = Rayfield
	if useStudio then
		Rayfield = script.Parent:FindFirstChild('Rayfield')
	else
		local success, result = pcall(function()
			return game:GetObjects("rbxassetid://10804731440")[1]
		end)
		if success and result then
			Rayfield = result
		else
			warn("Rayfield | Failed to reload GUI on retry: " .. tostring(result))
			break
		end
	end

	if oldRayfield and not useStudio then
		oldRayfield:Destroy()
	end

	buildAttempts = buildAttempts + 1
until buildAttempts >= 2

Rayfield.Enabled = false

local rayfieldContainer = nil
if Compatibility and type(Compatibility.protectAndParent) == "function" then
	rayfieldContainer = Compatibility.protectAndParent(Rayfield, nil, {
		useStudio = useStudio
	})
elseif not useStudio then
	Rayfield.Parent = CoreGui
	rayfieldContainer = CoreGui
end

if Compatibility and type(Compatibility.dedupeGuiByName) == "function" then
	Compatibility.dedupeGuiByName(rayfieldContainer, Rayfield.Name, Rayfield, "-Old")
elseif not useStudio and rayfieldContainer then
	for _, Interface in ipairs(rayfieldContainer:GetChildren()) do
		if Interface.Name == Rayfield.Name and Interface ~= Rayfield then
			Interface.Enabled = false
			Interface.Name = "Rayfield-Old"
		end
	end
end


local minSize = Vector2.new(1024, 768)
local useMobileSizing
local useMobilePrompt = false

if Rayfield.AbsoluteSize.X < minSize.X and Rayfield.AbsoluteSize.Y < minSize.Y then
	useMobileSizing = true
end

if UserInputService.TouchEnabled then
	useMobilePrompt = true
end


-- Object Variables

local Main = Rayfield.Main
if not Main then
	error("Rayfield GUI structure error: Main container not found. The GUI asset may be corrupted or incompatible.")
end

local MPrompt = Rayfield:FindFirstChild('Prompt')
local Topbar = Main.Topbar
local Elements = Main.Elements
local LoadingFrame = Main.LoadingFrame
local TabList = Main.TabList

-- Validate critical GUI components
if not Elements then
	error("Rayfield GUI structure error: Elements container not found. The GUI asset may be corrupted.")
end
if not Elements:FindFirstChild('Template') then
	error("Rayfield GUI structure error: Elements.Template not found. The GUI asset may be corrupted.")
end
if not TabList then
	error("Rayfield GUI structure error: TabList container not found. The GUI asset may be corrupted.")
end

local dragBar = Rayfield:FindFirstChild('Drag')
local dragInteract = dragBar and dragBar.Interact or nil
local dragBarCosmetic = dragBar and dragBar.Drag or nil

local dragOffset = 255
local dragOffsetMobile = 150

Rayfield.DisplayOrder = 100
LoadingFrame.Version.Text = Release

-- Thanks to Latte Softworks for the Lucide integration for Roblox
local Icons = useStudio and require(script.Parent.icons) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua')

-- Variables
local CFileName = nil
local CEnabled = false
local Minimised = false
local Hidden = false
local Debounce = false
local searchOpen = false
local Notifications = Rayfield.Notifications
local ElementsSystem = nil
local ElementSyncSystem = nil
local OwnershipSystem = nil
local keybindConnections = {} -- For storing keybind connections to disconnect when Rayfield is destroyed
local layoutConnections = {}
local LayoutPersistenceSystem = nil
local ViewportVirtualizationSystem = nil
local layoutSavingEnabled = false
local layoutDebounceMs = 300
local detachPathEnabled = true
local activePerformanceProfile = {
	enabled = false,
	requestedMode = "normal",
	resolvedMode = "normal",
	aggressive = false,
	disableDetach = false,
	disableTabSplit = false,
	disableAnimations = false,
	appliedFields = {}
}
local ExperienceState = {
	uiPreset = "Comfort",
	transitionProfile = "Smooth",
	onboardingSuppressed = false,
	favoritesTab = nil,
	favoritesTabWindow = nil,
	onboardingOverlay = nil,
	onboardingRendered = false,
	audioState = {
		enabled = false,
		pack = "Mute",
		volume = 0.45,
		customPack = {},
		hoverRateLimitSec = 0.08,
		lastCueAt = {},
		sounds = nil,
		soundFolder = nil
	},
	glassState = {
		mode = "auto",
		intensity = 0.32,
		resolvedMode = "off",
		root = nil,
		masks = nil,
		highlight = nil
	},
	themeStudioState = {
		baseTheme = "Default",
		useCustom = false,
		customThemePacked = {}
	}
}
local experienceSuppressPromoPrompts = false
local favoritesRegistryUnsubscribe = nil
local uiToggleKeybindMatcher = KeybindSequenceLib.newMatcher({
	maxSteps = 4,
	stepTimeoutMs = 800
})
local cachedUiToggleKeybindRaw = nil
local cachedUiToggleKeybindSpec = nil

local function initializeOwnershipTracking()
	local okInit, trackerOrErr = pcall(OwnershipTrackerModuleLib.init, {
		owner = "rayfield-mod",
		scopePrefix = "rayfield",
		HttpService = HttpService,
		getRootGui = function()
			return Rayfield
		end
	})
	if not okInit or type(trackerOrErr) ~= "table" then
		warn("Rayfield Mod: [W_OWNERSHIP_INIT] Failed to initialize ownership tracker: " .. tostring(trackerOrErr))
		return nil
	end

	local tracker = trackerOrErr
	local runtimeScope = "runtime:root"
	local hotkeyScope = "runtime:hotkeys"
	local layoutScope = "runtime:layout"

	if type(tracker.createScope) == "function" then
		pcall(tracker.createScope, runtimeScope, {
			kind = "runtime"
		})
		pcall(tracker.createScope, hotkeyScope, {
			kind = "runtime_hotkeys"
		})
		pcall(tracker.createScope, layoutScope, {
			kind = "runtime_layout"
		})
	end
	if type(tracker.claimInstance) == "function" then
		pcall(tracker.claimInstance, Rayfield, runtimeScope, { node = "RayfieldRoot" })
		pcall(tracker.claimInstance, Main, runtimeScope, { node = "Main" })
		pcall(tracker.claimInstance, Topbar, runtimeScope, { node = "Topbar" })
		pcall(tracker.claimInstance, Elements, runtimeScope, { node = "Elements" })
		pcall(tracker.claimInstance, TabList, runtimeScope, { node = "TabList" })
		pcall(tracker.claimInstance, Notifications, runtimeScope, { node = "Notifications" })
	end

	if _G then
		_G.__RayfieldOwnership = tracker
	end
	return tracker
end

OwnershipSystem = initializeOwnershipTracking()

local function resolveUiToggleKeybindSpec(rawBinding)
	if rawBinding == cachedUiToggleKeybindRaw and cachedUiToggleKeybindSpec then
		return cachedUiToggleKeybindSpec
	end

	local canonical, steps = KeybindSequenceLib.normalize(rawBinding, {
		maxSteps = 4
	})
	if not canonical then
		cachedUiToggleKeybindRaw = nil
		cachedUiToggleKeybindSpec = nil
		return nil
	end

	cachedUiToggleKeybindRaw = rawBinding
	cachedUiToggleKeybindSpec = {
		canonical = canonical,
		steps = steps
	}
	return cachedUiToggleKeybindSpec
end

local function cleanupLayoutConnections()
	for _, connection in ipairs(layoutConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	table.clear(layoutConnections)
end

local function markLayoutDirty(scope, reason)
	if LayoutPersistenceSystem and type(LayoutPersistenceSystem.markDirty) == "function" then
		LayoutPersistenceSystem.markDirty((scope or "layout") .. ":" .. (reason or "update"))
	end
end

AnimationEngine:SetUiSuppressionProvider(function()
	return Hidden == true or Minimised == true or rayfieldDestroyed == true
end)

-- Initialize Theme Module
local ThemeSystem = ThemeModule.init({
	Rayfield = Rayfield,
	Main = Main,
	Topbar = Topbar,
	Elements = Elements,
	Notifications = Notifications,
	Icons = Icons
})

local bindTheme = ThemeSystem.bindTheme

-- Apply Reactive Theme to Main UI (with nil guards for UI structure resilience)
bindTheme(Main, "BackgroundColor3", "Background")
bindTheme(Topbar, "BackgroundColor3", "Topbar")

local cornerRepair = Topbar:FindFirstChild("CornerRepair")
if cornerRepair then
	bindTheme(cornerRepair, "BackgroundColor3", "Topbar")
end

local shadow = Main:FindFirstChild("Shadow")
if shadow and shadow:FindFirstChild("Image") then
	bindTheme(shadow.Image, "ImageColor3", "Shadow")
end

if Topbar:FindFirstChild("ChangeSize") then
	bindTheme(Topbar.ChangeSize, "ImageColor3", "TextColor")
end
if Topbar:FindFirstChild("Hide") then
	bindTheme(Topbar.Hide, "ImageColor3", "TextColor")
end
if Topbar:FindFirstChild("Search") then
	bindTheme(Topbar.Search, "ImageColor3", "TextColor")
end

if Topbar:FindFirstChild('Settings') then
	bindTheme(Topbar.Settings, "ImageColor3", "TextColor")
	if Topbar:FindFirstChild('Divider') then
		bindTheme(Topbar.Divider, "BackgroundColor3", "ElementStroke")
	end
end

-- Search UI Reactive (guarded)
local searchFrame = Main:FindFirstChild("Search")
if searchFrame then
	bindTheme(searchFrame, "BackgroundColor3", "TextColor")
	if searchFrame:FindFirstChild("Shadow") then
		bindTheme(searchFrame.Shadow, "ImageColor3", "TextColor")
	end
	if searchFrame:FindFirstChild("Search") then
		bindTheme(searchFrame.Search, "ImageColor3", "TextColor")
	end
	if searchFrame:FindFirstChild("Input") then
		bindTheme(searchFrame.Input, "PlaceholderColor3", "TextColor")
	end
	if searchFrame:FindFirstChild("UIStroke") then
		bindTheme(searchFrame.UIStroke, "Color", "SecondaryElementStroke")
	end
end

-- Initialize Settings Module
local SettingsSystem = SettingsModuleLib.init({
	RayfieldFolder = RayfieldFolder,
	ConfigurationExtension = ConfigurationExtension,
	HttpService = HttpService,
	useStudio = useStudio,
	callSafely = callSafely,
	Topbar = Topbar,
	TabList = TabList,
	Elements = Elements
})

-- Initialize Configuration Module
local ConfigSystem = ConfigModuleLib.init({
	HttpService = HttpService,
	TweenService = TweenService,
	Animation = Animation,
	RayfieldLibrary = RayfieldLibrary,
	callSafely = callSafely,
	ConfigurationFolder = ConfigurationFolder,
	ConfigurationExtension = ConfigurationExtension,
	getCFileName = function() return CFileName end,
	getCEnabled = function() return CEnabled end,
	getGlobalLoaded = function() return globalLoaded end,
	getLayoutSnapshot = function()
		if LayoutPersistenceSystem and type(LayoutPersistenceSystem.getLayoutSnapshot) == "function" then
			return LayoutPersistenceSystem.getLayoutSnapshot()
		end
		return nil
	end,
	applyLayoutSnapshot = function(layoutData)
		if LayoutPersistenceSystem and type(LayoutPersistenceSystem.applyLayoutSnapshot) == "function" then
			return LayoutPersistenceSystem.applyLayoutSnapshot(layoutData)
		end
		return false
	end,
	getElementsSystem = function()
		return ElementsSystem
	end,
	layoutKey = "__rayfield_layout",
	useStudio = useStudio,
	debugX = debugX
})

-- Initialize Utilities Module (will be fully initialized after UI elements are created)
local UtilitiesSystem = nil -- Initialized later after UI elements exist

-- Expose theme definitions to RayfieldLibrary
RayfieldLibrary.Theme = ThemeModule.Themes

-- Use theme system's selected theme
local SelectedTheme = ThemeSystem.SelectedTheme

-- Theme helpers
local function ChangeTheme(Theme)
	ThemeSystem.ChangeTheme(Theme)
	SelectedTheme = ThemeSystem.SelectedTheme
end

local function getIcon(name)
	return ThemeSystem.getIcon(name)
end

-- Settings wrapper functions
local function getSetting(category, name)
	return SettingsSystem.getSetting(category, name)
end

local function overrideSetting(category, name, value)
	return SettingsSystem.overrideSetting(category, name, value)
end

local function saveSettings()
	return SettingsSystem.saveSettings()
end

local function updateSetting(category, setting, value)
	return SettingsSystem.updateSetting(category, setting, value)
end

local function setSettingValue(category, setting, value, persist)
	if SettingsSystem and type(SettingsSystem.setSettingValue) == "function" then
		return SettingsSystem.setSettingValue(category, setting, value, persist)
	end
	return false, "Settings system unavailable."
end

local function loadSettings()
	return SettingsSystem.loadSettings()
end

local function createSettings(window)
	return SettingsSystem.createSettings(window)
end

-- Local settings references
local settingsTable = SettingsSystem.settingsTable
local settingsCreated = SettingsSystem.settingsCreated
local settingsInitialized = SettingsSystem.settingsInitialized
local overriddenSettings = SettingsSystem.overriddenSettings
local cachedSettings = SettingsSystem.cachedSettings

-- Call initial loadSettings
loadSettings()

-- If requests/analytics have been disabled by developer, set the user-facing setting to false as well
if requestsDisabled then
	overrideSetting("System", "usageAnalytics", false)
end

-- Initialize Drag Module
local DragSystem = DragModuleLib.init({
	UserInputService = UserInputService,
	TweenService = TweenService,
	Animation = Animation,
	RunService = RunService,
	HttpService = HttpService,
	Main = Main,
	Topbar = Topbar,
	Elements = Elements,
	Rayfield = Rayfield,
	Icons = Icons,
	getIcon = getIcon,
	getAssetUri = getAssetUri,
	getSelectedTheme = function() return SelectedTheme end,
	getSetting = getSetting,
	useMobileSizing = useMobileSizing,
	getDetachEnabled = function()
		return detachPathEnabled
	end,
	rayfieldDestroyed = function() return rayfieldDestroyed end,
	onLayoutDirty = function(scope, reason)
		markLayoutDirty(scope, reason)
	end,
	getViewportVirtualization = function()
		return ViewportVirtualizationSystem
	end,
	ElementSync = {
		resync = function(token, reason)
			if ElementSyncSystem and type(ElementSyncSystem.resync) == "function" then
				return ElementSyncSystem.resync(token, reason)
			end
			return false
		end
	}
})

-- Detach helper wrapper
local function makeElementDetachable(guiObject, elementName, elementType)
	if detachPathEnabled == false then
		return nil
	end
	return DragSystem.makeElementDetachable(guiObject, elementName, elementType)
end

-- Initialize UI State Module
local UIStateSystem = UIStateModuleLib.init({
	TweenService = TweenService,
	Animation = Animation,
	Main = Main,
	Topbar = Topbar,
	TabList = TabList,
	Elements = Elements,
	Notifications = Notifications,
	MPrompt = MPrompt,
	dragInteract = dragInteract,
	dragBarCosmetic = dragBarCosmetic,
	dragBar = dragBar,
	dragOffset = dragOffset,
	dragOffsetMobile = dragOffsetMobile,
	getIcon = getIcon,
	getAssetUri = getAssetUri,
	getSelectedTheme = function() return SelectedTheme end,
	rayfieldDestroyed = function() return rayfieldDestroyed end,
	getSetting = getSetting,
	useMobileSizing = useMobileSizing,
	useMobilePrompt = useMobilePrompt
})

local TabSplitSystem = nil

-- Wrapper functions for UI State
local function openSearch()
	UIStateSystem.openSearch()
	searchOpen = UIStateSystem.getSearchOpen()
end

local function closeSearch()
	UIStateSystem.closeSearch()
	searchOpen = UIStateSystem.getSearchOpen()
end

local applyGlassLayer = nil
local VisibilityController = VisibilityControllerLib.create({
	getUIStateSystem = function()
		return UIStateSystem
	end,
	getUtilitiesSystem = function()
		return UtilitiesSystem
	end,
	applyRuntimeState = function(state)
		if state.hidden ~= nil then
			Hidden = state.hidden == true
		end
		if state.minimised ~= nil then
			Minimised = state.minimised == true
		end
		if state.debounce ~= nil then
			Debounce = state.debounce == true
		end
	end,
	onVisibilityChanged = function(state)
		local action = state.action
		AnimationEngine:SetUiSuppressed(Hidden or Minimised or rayfieldDestroyed)
		if TabSplitSystem then
			if action == "hide" or action == "unhide" then
				TabSplitSystem.syncHidden(Hidden)
				TabSplitSystem.syncMinimized(Minimised)
			elseif action == "maximise" or action == "minimise" then
				TabSplitSystem.syncMinimized(Minimised)
			elseif action == "set_visible_true" or action == "set_visible_false" then
				TabSplitSystem.syncHidden(Hidden)
			end
		end
		if applyGlassLayer then
			applyGlassLayer()
		end
		markLayoutDirty("main", action)
	end
})

local function Hide(notify)
	VisibilityController.Hide(notify)
end

local function Unhide()
	VisibilityController.Unhide()
end

local function Maximise()
	VisibilityController.Maximise()
end

local function Minimise()
	VisibilityController.Minimise()
end

-- Converts ID to asset URI. Returns rbxassetid://0 if ID is not a number
local function getAssetUri(id: any): string
	return UtilitiesSystem and UtilitiesSystem.getAssetUri(id, Icons) or ("rbxassetid://" .. (type(id) == "number" and id or 0))
end

local function makeDraggable(object, dragObject, enableTaptic, tapticOffset)
	if UtilitiesSystem then
		UtilitiesSystem.makeDraggable(object, dragObject, enableTaptic, tapticOffset)
	else
		warn("Rayfield | UtilitiesSystem not initialized yet")
	end
end

-- Note: Old makeDraggable implementation moved to rayfield-utilities.lua module

-- Note: Drag/Detach system code has been moved to rayfield-drag.lua module

-- Configuration wrapper functions
local function PackColor(Color)
	return ConfigSystem.PackColor(Color)
end

local function UnpackColor(Color)
	return ConfigSystem.UnpackColor(Color)
end

local function LoadConfiguration(Configuration)
	return ConfigSystem.LoadConfiguration(Configuration)
end

local function SaveConfiguration()
	return ConfigSystem.SaveConfiguration()
end

local SHARE_CODE_PREFIX = "RFSC1:"
local SHARE_PAYLOAD_VERSION = 1
local SHARE_PAYLOAD_TYPE = "rayfield_share"
local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local activeShareCode = ""
local activeSharePayload = nil

local function trimString(value)
	value = tostring(value or "")
	value = value:gsub("^%s+", "")
	value = value:gsub("%s+$", "")
	return value
end

local function fallbackBase64Encode(input)
	local source = tostring(input or "")
	local bits = source:gsub(".", function(character)
		local byteValue = string.byte(character)
		local chunk = ""
		for index = 8, 1, -1 do
			if byteValue % (2 ^ index) - byteValue % (2 ^ (index - 1)) > 0 then
				chunk = chunk .. "1"
			else
				chunk = chunk .. "0"
			end
		end
		return chunk
	end)

	local paddedBits = bits .. "0000"
	local encoded = paddedBits:gsub("%d%d%d?%d?%d?%d?", function(chunk)
		if #chunk < 6 then
			return ""
		end
		local value = 0
		for index = 1, 6 do
			if chunk:sub(index, index) == "1" then
				value += 2 ^ (6 - index)
			end
		end
		return BASE64_ALPHABET:sub(value + 1, value + 1)
	end)

	return encoded .. ({ "", "==", "=" })[#source % 3 + 1]
end

local function fallbackBase64Decode(input)
	local source = tostring(input or "")
	source = source:gsub("%s+", "")
	source = source:gsub("[^" .. BASE64_ALPHABET .. "=]", "")

	local bits = source:gsub(".", function(character)
		if character == "=" then
			return ""
		end
		local index = BASE64_ALPHABET:find(character, 1, true)
		if not index then
			return ""
		end
		local value = index - 1
		local chunk = ""
		for bit = 6, 1, -1 do
			if value % (2 ^ bit) - value % (2 ^ (bit - 1)) > 0 then
				chunk = chunk .. "1"
			else
				chunk = chunk .. "0"
			end
		end
		return chunk
	end)

	return bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(chunk)
		if #chunk ~= 8 then
			return ""
		end
		local value = 0
		for index = 1, 8 do
			if chunk:sub(index, index) == "1" then
				value += 2 ^ (8 - index)
			end
		end
		return string.char(value)
	end)
end

local function encodeBase64(input)
	if HttpService and type(HttpService.Base64Encode) == "function" then
		local okEncoded, encoded = pcall(HttpService.Base64Encode, HttpService, input)
		if okEncoded and type(encoded) == "string" then
			return true, encoded
		end
	end

	local okFallback, encoded = pcall(fallbackBase64Encode, input)
	if not okFallback then
		return false, tostring(encoded)
	end
	return true, encoded
end

local function decodeBase64(input)
	if HttpService and type(HttpService.Base64Decode) == "function" then
		local okDecoded, decoded = pcall(HttpService.Base64Decode, HttpService, input)
		if okDecoded and type(decoded) == "string" then
			return true, decoded
		end
	end

	local okFallback, decoded = pcall(fallbackBase64Decode, input)
	if not okFallback then
		return false, tostring(decoded)
	end
	return true, decoded
end

local function buildGeneratedAtStamp()
	local okDate, value = pcall(function()
		return os.date("!%Y-%m-%dT%H:%M:%SZ")
	end)
	if okDate and type(value) == "string" then
		return value
	end
	local okTick, tickValue = pcall(function()
		return tostring(math.floor((tick and tick() or 0) * 1000))
	end)
	if okTick and type(tickValue) == "string" then
		return tickValue
	end
	return "unknown"
end

local function validateSharePayload(payload)
	if type(payload) ~= "table" then
		return false, "Share code payload is invalid."
	end
	if payload.type ~= SHARE_PAYLOAD_TYPE then
		return false, "Share code payload type is invalid."
	end
	if tonumber(payload.version) ~= SHARE_PAYLOAD_VERSION then
		return false, "Share code version is unsupported."
	end
	if type(payload.configuration) ~= "table" then
		return false, "Share code is missing configuration data."
	end
	if type(payload.internalSettings) ~= "table" then
		return false, "Share code is missing internal settings data."
	end
	return true
end

local function setActiveSharePayload(code, payload)
	activeShareCode = tostring(code or "")
	activeSharePayload = payload
	if SettingsSystem and type(SettingsSystem.setShareCodeInputValue) == "function" then
		pcall(SettingsSystem.setShareCodeInputValue, activeShareCode)
	end
end

local function encodeSharePayload(payload)
	local okJson, jsonOrErr = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not okJson or type(jsonOrErr) ~= "string" then
		return nil, "Failed to encode share payload."
	end

	local okBase64, encodedOrErr = encodeBase64(jsonOrErr)
	if not okBase64 then
		return nil, "Failed to encode share payload as Base64."
	end

	return SHARE_CODE_PREFIX .. encodedOrErr
end

local function decodeShareCode(code)
	local normalized = trimString(code)
	if normalized == "" then
		return false, "Share code cannot be empty."
	end
	if normalized:sub(1, #SHARE_CODE_PREFIX) ~= SHARE_CODE_PREFIX then
		return false, "Share code prefix is invalid."
	end

	local encodedBody = normalized:sub(#SHARE_CODE_PREFIX + 1):gsub("%s+", "")
	if encodedBody == "" then
		return false, "Share code payload is empty."
	end

	local okDecode, decodedOrErr = decodeBase64(encodedBody)
	if not okDecode or type(decodedOrErr) ~= "string" then
		return false, "Share code Base64 payload is invalid."
	end

	local okJson, payloadOrErr = pcall(function()
		return HttpService:JSONDecode(decodedOrErr)
	end)
	if not okJson or type(payloadOrErr) ~= "table" then
		return false, "Share code JSON payload is invalid."
	end

	return true, SHARE_CODE_PREFIX .. encodedBody, payloadOrErr
end

local function notifyShareCodeStatus(success, message)
	if not UIStateSystem or type(UIStateSystem.Notify) ~= "function" then
		return
	end
	local content = tostring(message or "")
	if content == "" then
		if success then
			content = "Share code operation completed."
		else
			content = "Share code operation failed."
		end
	end
	pcall(UIStateSystem.Notify, {
		Title = "Rayfield Share Code",
		Content = content,
		Image = success and 4483362458 or 4384402990
	})
end

function RayfieldLibrary:ImportCode(code)
	local okDecode, canonicalOrMessage, payload = decodeShareCode(code)
	if not okDecode then
		return false, tostring(canonicalOrMessage)
	end

	local validPayload, payloadMessage = validateSharePayload(payload)
	if not validPayload then
		return false, tostring(payloadMessage)
	end

	setActiveSharePayload(canonicalOrMessage, payload)
	return true, "Share code imported."
end

function RayfieldLibrary:ImportSettings()
	if type(activeSharePayload) ~= "table" then
		return false, "No active share code. Import code first."
	end

	local validPayload, payloadMessage = validateSharePayload(activeSharePayload)
	if not validPayload then
		return false, tostring(payloadMessage)
	end

	if not ConfigSystem or type(ConfigSystem.ImportConfigurationData) ~= "function" then
		return false, "Configuration import is unavailable."
	end
	if not SettingsSystem or type(SettingsSystem.ImportInternalSettingsData) ~= "function" then
		return false, "Internal settings import is unavailable."
	end

	local okConfig, configSuccess, configDetail = pcall(ConfigSystem.ImportConfigurationData, activeSharePayload.configuration)
	if not okConfig then
		return false, "Failed to apply configuration data: " .. tostring(configSuccess)
	end
	if configSuccess ~= true then
		return false, tostring(configDetail or "Failed to apply configuration data.")
	end

	local okInternal, internalSuccess, internalDetail = pcall(SettingsSystem.ImportInternalSettingsData, activeSharePayload.internalSettings)
	if not okInternal then
		return false, "Failed to apply internal settings: " .. tostring(internalSuccess)
	end
	if internalSuccess ~= true then
		return false, tostring(internalDetail or "Failed to apply internal settings.")
	end

	local persistenceWarnings = {}
	if ConfigSystem and type(ConfigSystem.SaveConfigurationForced) == "function" then
		local okPersistConfig, persistedConfig = pcall(ConfigSystem.SaveConfigurationForced)
		if not okPersistConfig or persistedConfig == false then
			table.insert(persistenceWarnings, "configuration")
		end
	end

	if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
		local okPersistSettings, persistedSettings = pcall(SettingsSystem.saveSettings)
		if not okPersistSettings or persistedSettings == false then
			table.insert(persistenceWarnings, "internal settings")
		end
	end

	if #persistenceWarnings > 0 then
		return true, "Share settings applied, but persistence failed for: " .. table.concat(persistenceWarnings, ", ") .. "."
	end

	local changedConfiguration = configDetail == true
	local appliedInternalCount = tonumber(internalDetail) or 0
	if changedConfiguration or appliedInternalCount > 0 then
		return true, "Share settings applied."
	end

	return true, "Share settings were already up to date."
end

function RayfieldLibrary:ExportSettings()
	if not ConfigSystem or type(ConfigSystem.ExportConfigurationData) ~= "function" then
		return nil, "Configuration export is unavailable."
	end
	if not SettingsSystem or type(SettingsSystem.ExportInternalSettingsData) ~= "function" then
		return nil, "Internal settings export is unavailable."
	end

	local okConfig, configurationData = pcall(ConfigSystem.ExportConfigurationData)
	if not okConfig or type(configurationData) ~= "table" then
		return nil, "Failed to collect configuration data."
	end

	local okSettings, internalSettingsData = pcall(SettingsSystem.ExportInternalSettingsData)
	if not okSettings or type(internalSettingsData) ~= "table" then
		return nil, "Failed to collect internal settings data."
	end

	local payload = {
		type = SHARE_PAYLOAD_TYPE,
		version = SHARE_PAYLOAD_VERSION,
		configuration = configurationData,
		internalSettings = internalSettingsData,
		meta = {
			generatedAt = buildGeneratedAtStamp(),
			interfaceBuild = InterfaceBuild,
			release = Release
		}
	}

	local encodedCode, encodedErr = encodeSharePayload(payload)
	if type(encodedCode) ~= "string" then
		return nil, tostring(encodedErr or "Failed to export share code.")
	end

	setActiveSharePayload(encodedCode, payload)
	return encodedCode, "ok"
end

function RayfieldLibrary:CopyShareCode(suppressNotify)
	local shouldNotify = suppressNotify ~= true

	if type(activeShareCode) ~= "string" or activeShareCode == "" then
		local message = "No active share code. Export or import a code first."
		if shouldNotify then
			notifyShareCodeStatus(false, message)
		end
		return false, message
	end

	local clipboardWriter = nil
	if type(setclipboard) == "function" then
		clipboardWriter = setclipboard
	elseif type(toclipboard) == "function" then
		clipboardWriter = toclipboard
	end

	if type(clipboardWriter) ~= "function" then
		if SettingsSystem and type(SettingsSystem.setShareCodeInputValue) == "function" then
			pcall(SettingsSystem.setShareCodeInputValue, activeShareCode)
		end
		local message = "Clipboard is unavailable. Share code was placed in the Share Code input."
		if shouldNotify then
			notifyShareCodeStatus(false, message)
		end
		return false, message
	end

	local okCopy, copyErr = pcall(clipboardWriter, activeShareCode)
	if not okCopy then
		if SettingsSystem and type(SettingsSystem.setShareCodeInputValue) == "function" then
			pcall(SettingsSystem.setShareCodeInputValue, activeShareCode)
		end
		local message = "Failed to copy share code: " .. tostring(copyErr)
		if shouldNotify then
			notifyShareCodeStatus(false, message)
		end
		return false, message
	end

	local message = "Share code copied to clipboard."
	if shouldNotify then
		notifyShareCodeStatus(true, message)
	end
	return true, message
end

if SettingsSystem and type(SettingsSystem.setShareCodeHandlers) == "function" then
	SettingsSystem.setShareCodeHandlers({
		importCode = function(code)
			local ok, message = RayfieldLibrary:ImportCode(code)
			return ok, message
		end,
		importSettings = function()
			local ok, message = RayfieldLibrary:ImportSettings()
			return ok, message
		end,
		exportSettings = function()
			local code, message = RayfieldLibrary:ExportSettings()
			return code, message
		end,
		copyShareCode = function()
			local ok, message = RayfieldLibrary:CopyShareCode(true)
			return ok, message
		end,
		getActiveShareCode = function()
			return activeShareCode
		end,
		notify = function(success, message)
			notifyShareCodeStatus(success == true, message)
		end
	})
end

local UI_PRESET_NAMES = {
	Compact = true,
	Comfort = true,
	Focus = true,
	Cripware = true
}
local TRANSITION_PROFILE_NAMES = {
	Minimal = true,
	Smooth = true,
	Snappy = true,
	Off = true
}
local THEME_STUDIO_KEYS = {}
for themeKey in pairs(ThemeModule.Themes.Default or {}) do
	table.insert(THEME_STUDIO_KEYS, themeKey)
end
table.sort(THEME_STUDIO_KEYS)

local function cloneValue(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, nested in pairs(value) do
		out[cloneValue(key)] = cloneValue(nested)
	end
	return out
end

local function cloneArray(values)
	local out = {}
	if type(values) ~= "table" then
		return out
	end
	for index, value in ipairs(values) do
		out[index] = value
	end
	return out
end

local function normalizePresetName(name)
	if type(name) ~= "string" then
		return nil
	end
	local normalized = string.lower(name)
	if normalized == "compact" then
		return "Compact"
	elseif normalized == "comfort" then
		return "Comfort"
	elseif normalized == "focus" then
		return "Focus"
	elseif normalized == "cripware" then
		return "Cripware"
	end
	return nil
end

local function normalizeTransitionProfileName(name)
	if type(name) ~= "string" then
		return nil
	end
	local normalized = string.lower(name)
	if normalized == "minimal" then
		return "Minimal"
	elseif normalized == "smooth" then
		return "Smooth"
	elseif normalized == "snappy" then
		return "Snappy"
	elseif normalized == "off" then
		return "Off"
	end
	return nil
end

local function color3ToPacked(color)
	if typeof(color) ~= "Color3" then
		return nil
	end
	return {
		R = math.floor(color.R * 255 + 0.5),
		G = math.floor(color.G * 255 + 0.5),
		B = math.floor(color.B * 255 + 0.5)
	}
end

local function packedToColor3(packed)
	if type(packed) ~= "table" then
		return nil
	end
	local r = tonumber(packed.R)
	local g = tonumber(packed.G)
	local b = tonumber(packed.B)
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(math.clamp(math.floor(r + 0.5), 0, 255), math.clamp(math.floor(g + 0.5), 0, 255), math.clamp(math.floor(b + 0.5), 0, 255))
end

local function listThemeNames()
	local names = {}
	for themeName in pairs(ThemeModule.Themes or {}) do
		table.insert(names, themeName)
	end
	table.sort(names)
	return names
end

local AUDIO_PACK_NAMES = {
	mute = "Mute",
	custom = "Custom"
}

local function normalizeAudioPackName(name)
	local normalized = string.lower(tostring(name or ""))
	return AUDIO_PACK_NAMES[normalized]
end

local function sanitizeSoundId(value)
	if value == nil then
		return nil
	end
	local text = tostring(value)
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return nil
	end
	if text:match("^rbxassetid://%d+$") then
		return text
	end
	local numeric = tonumber(text)
	if numeric then
		return "rbxassetid://" .. tostring(math.floor(numeric))
	end
	return nil
end

local function cloneAudioPack(pack)
	local out = {}
	if type(pack) ~= "table" then
		return out
	end
	for _, key in ipairs({"click", "hover", "success", "error"}) do
		local sanitized = sanitizeSoundId(pack[key])
		if sanitized then
			out[key] = sanitized
		end
	end
	return out
end

local function ensureAudioSoundFolder()
	if not Rayfield then
		return nil
	end
	local audioState = ExperienceState.audioState
	if audioState.soundFolder and audioState.soundFolder.Parent == Rayfield then
		return audioState.soundFolder
	end
	local folder = Rayfield:FindFirstChild("RayfieldAudioFeedback")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RayfieldAudioFeedback"
		folder.Parent = Rayfield
	end
	audioState.soundFolder = folder
	return folder
end

local function ensureAudioCueSound(cueName)
	local folder = ensureAudioSoundFolder()
	if not folder then
		return nil
	end
	local audioState = ExperienceState.audioState
	audioState.sounds = audioState.sounds or {}
	local existing = audioState.sounds[cueName]
	if existing and existing.Parent == folder then
		return existing
	end
	local sound = folder:FindFirstChild("Cue_" .. tostring(cueName))
	if not (sound and sound:IsA("Sound")) then
		sound = Instance.new("Sound")
		sound.Name = "Cue_" .. tostring(cueName)
		sound.RollOffMode = Enum.RollOffMode.Inverse
		sound.Volume = tonumber(audioState.volume) or 0.45
		sound.Parent = folder
	end
	audioState.sounds[cueName] = sound
	return sound
end

local function syncAudioCueSounds()
	local audioState = ExperienceState.audioState
	local pack = audioState.pack == "Custom" and audioState.customPack or {}
	for _, cueName in ipairs({"click", "hover", "success", "error"}) do
		local sound = ensureAudioCueSound(cueName)
		if sound then
			local soundId = sanitizeSoundId(pack[cueName])
			sound.SoundId = soundId or ""
			sound.Volume = math.clamp(tonumber(audioState.volume) or 0.45, 0, 1)
		end
	end
end

local function setAudioFeedbackVolumeInternal(volume, persist)
	local audioState = ExperienceState.audioState
	audioState.volume = math.clamp(tonumber(volume) or audioState.volume or 0.45, 0, 1)
	syncAudioCueSounds()
	if persist ~= false then
		setSettingValue("Audio", "volume", audioState.volume, true)
	end
	return true, "Audio volume updated."
end

local function setAudioFeedbackEnabledInternal(enabled, persist)
	local audioState = ExperienceState.audioState
	audioState.enabled = enabled == true
	syncAudioCueSounds()
	if persist ~= false then
		setSettingValue("Audio", "enabled", audioState.enabled, true)
	end
	return true, audioState.enabled and "Audio feedback enabled." or "Audio feedback disabled."
end

local function setAudioFeedbackPackInternal(name, packDefinition, persist)
	local audioState = ExperienceState.audioState
	local canonical = normalizeAudioPackName(name)
	if not canonical then
		return false, "Invalid audio pack name."
	end
	if canonical == "Custom" and packDefinition ~= nil then
		if type(packDefinition) ~= "table" then
			return false, "Custom audio pack must be a table."
		end
		audioState.customPack = cloneAudioPack(packDefinition)
	end
	audioState.pack = canonical
	syncAudioCueSounds()
	if persist ~= false then
		setSettingValue("Audio", "pack", audioState.pack, false)
		setSettingValue("Audio", "customPack", cloneValue(audioState.customPack), true)
	end
	return true, "Audio pack set to " .. tostring(audioState.pack) .. "."
end

local function getAudioFeedbackStateSnapshot()
	local audioState = ExperienceState.audioState
	return {
		enabled = audioState.enabled == true,
		pack = audioState.pack,
		volume = tonumber(audioState.volume) or 0.45,
		customPack = cloneValue(audioState.customPack)
	}
end

local function playUICueInternal(cueName, options)
	options = options or {}
	if rayfieldDestroyed then
		return false, "Rayfield destroyed."
	end
	local audioState = ExperienceState.audioState
	if audioState.enabled ~= true then
		return false, "Audio feedback disabled."
	end
	local cueKey = string.lower(tostring(cueName or ""))
	if cueKey ~= "click" and cueKey ~= "hover" and cueKey ~= "success" and cueKey ~= "error" then
		return false, "Unknown cue."
	end

	if cueKey == "hover" then
		local now = os.clock()
		local lastAt = tonumber(audioState.lastCueAt.hover) or 0
		local minDelta = tonumber(audioState.hoverRateLimitSec) or 0.08
		if (now - lastAt) < minDelta then
			return false, "Hover cue rate-limited."
		end
		audioState.lastCueAt.hover = now
	end

	local pack = audioState.pack == "Custom" and audioState.customPack or {}
	local soundId = sanitizeSoundId(pack[cueKey])
	if not soundId then
		return false, "Cue sound not configured."
	end

	local sound = ensureAudioCueSound(cueKey)
	if not sound then
		return false, "Audio cue sound unavailable."
	end
	sound.SoundId = soundId
	sound.Volume = math.clamp(tonumber(audioState.volume) or 0.45, 0, 1)

	local okPlay, playErr = pcall(function()
		sound.TimePosition = 0
		sound:Play()
	end)
	if not okPlay then
		return false, tostring(playErr)
	end
	return true, "played"
end

local canvasGroupSupportCache = nil

local function canUseCanvasGroup()
	if canvasGroupSupportCache ~= nil then
		return canvasGroupSupportCache
	end
	local ok, instanceOrErr = pcall(function()
		return Instance.new("CanvasGroup")
	end)
	if ok and instanceOrErr then
		instanceOrErr:Destroy()
		canvasGroupSupportCache = true
	else
		canvasGroupSupportCache = false
	end
	return canvasGroupSupportCache
end

local function cleanupGlassLayer()
	local glassState = ExperienceState.glassState
	if glassState.root and glassState.root.Parent then
		glassState.root:Destroy()
	end
	glassState.root = nil
	glassState.masks = nil
	glassState.highlight = nil
	glassState.resolvedMode = "off"
end

local function resolveGlassMode(mode)
	local normalized = string.lower(tostring(mode or "auto"))
	if normalized ~= "auto" and normalized ~= "off" and normalized ~= "canvas" and normalized ~= "fallback" then
		normalized = "auto"
	end
	if normalized == "off" then
		return "off"
	end

	local lowSpecMode = activePerformanceProfile
		and activePerformanceProfile.enabled == true
		and (
			activePerformanceProfile.aggressive == true
			or activePerformanceProfile.resolvedMode == "potato"
			or activePerformanceProfile.resolvedMode == "mobile"
		)
	if lowSpecMode and normalized ~= "fallback" then
		return "fallback"
	end

	if normalized == "canvas" then
		return canUseCanvasGroup() and "canvas" or "fallback"
	end
	if normalized == "fallback" then
		return "fallback"
	end
	return canUseCanvasGroup() and "canvas" or "fallback"
end

local function ensureGlassLayerRoot(resolvedMode)
	local glassState = ExperienceState.glassState
	if resolvedMode == "off" then
		cleanupGlassLayer()
		return nil
	end
	local requiredClass = resolvedMode == "canvas" and "CanvasGroup" or "Frame"
	if glassState.root and glassState.root.Parent == Main and glassState.root.ClassName == requiredClass then
		return glassState.root
	end
	cleanupGlassLayer()

	local root = Instance.new(requiredClass)
	root.Name = "RayfieldGlassLayer"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BorderSizePixel = 0
	root.ZIndex = 1
	root.Active = false
	root.Selectable = false
	root.Parent = Main

	local gradient = Instance.new("UIGradient")
	gradient.Name = "GlassGradient"
	gradient.Rotation = 120
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.35, 0.32),
		NumberSequenceKeypoint.new(1, 0.65)
	})
	gradient.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Name = "GlassStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1
	stroke.Transparency = 0.45
	stroke.Parent = root

	if resolvedMode == "canvas" and root:IsA("CanvasGroup") then
		root.GroupTransparency = 0.08
	end

	glassState.root = root
	glassState.resolvedMode = resolvedMode
	return root
end

applyGlassLayer = function()
	local glassState = ExperienceState.glassState
	local resolvedMode = resolveGlassMode(glassState.mode)
	local root = ensureGlassLayerRoot(resolvedMode)
	if not root then
		return true, "Glass mode off."
	end

	local intensity = math.clamp(tonumber(glassState.intensity) or 0.32, 0, 1)
	local tint = (SelectedTheme and (SelectedTheme.GlassTint or SelectedTheme.Topbar or SelectedTheme.Background)) or Color3.fromRGB(28, 28, 34)
	local strokeColor = (SelectedTheme and (SelectedTheme.GlassStroke or SelectedTheme.ElementStroke or SelectedTheme.TabStroke)) or Color3.fromRGB(135, 145, 165)
	local accent = (SelectedTheme and (SelectedTheme.GlassAccent or SelectedTheme.SliderProgress or SelectedTheme.ToggleEnabled)) or Color3.fromRGB(120, 175, 235)

	root.BackgroundColor3 = tint:Lerp(accent, 0.09 + (intensity * 0.12))
	root.BackgroundTransparency = 0.78 - (intensity * 0.28)
	root.Visible = not Hidden

	local gradient = root:FindFirstChild("GlassGradient")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, tint:Lerp(Color3.fromRGB(255, 255, 255), 0.2)),
			ColorSequenceKeypoint.new(1, tint:Lerp(accent, 0.35))
		})
	end

	local stroke = root:FindFirstChild("GlassStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = strokeColor
		stroke.Transparency = 0.68 - (intensity * 0.35)
	end

	if root:IsA("CanvasGroup") then
		root.GroupTransparency = 0.2 - (intensity * 0.12)
	end

	glassState.resolvedMode = resolvedMode
	return true, "Glass applied (" .. tostring(resolvedMode) .. ")."
end

local function setGlassModeInternal(mode, persist)
	local normalized = string.lower(tostring(mode or "auto"))
	if normalized ~= "auto" and normalized ~= "off" and normalized ~= "canvas" and normalized ~= "fallback" then
		return false, "Invalid glass mode."
	end
	ExperienceState.glassState.mode = normalized
	local okApply, applyMessage = applyGlassLayer()
	if persist ~= false then
		setSettingValue("Glass", "mode", normalized, true)
	end
	return okApply, applyMessage
end

local function setGlassIntensityInternal(value, persist)
	ExperienceState.glassState.intensity = math.clamp(tonumber(value) or ExperienceState.glassState.intensity or 0.32, 0, 1)
	local okApply, applyMessage = applyGlassLayer()
	if persist ~= false then
		setSettingValue("Glass", "intensity", ExperienceState.glassState.intensity, true)
	end
	return okApply, applyMessage
end

local function getMainScale()
	if not Main then
		return nil
	end
	local existing = Main:FindFirstChild("RayfieldMainScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "RayfieldMainScale"
	scale.Scale = 1
	scale.Parent = Main
	return scale
end

local presetLayoutBaseline = nil
local function capturePresetLayoutBaseline()
	if presetLayoutBaseline then
		return
	end
	presetLayoutBaseline = {
		tabListPosition = TabList and TabList.Position or nil,
		tabListSize = TabList and TabList.Size or nil,
		elementsPosition = Elements and Elements.Position or nil,
		elementsSize = Elements and Elements.Size or nil
	}
end

local function applyPresetLayoutInternal(presetName)
	capturePresetLayoutBaseline()
	if not TabList or not Elements or not presetLayoutBaseline then
		return false
	end

	if presetName == "Cripware" then
		local mainWidth = math.max(420, tonumber(Main and Main.Size and Main.Size.X.Offset) or 500)
		local topPadding = 45
		local leftPadding = 10
		local rightPadding = 10
		local bottomPadding = 10
		local spacing = 8
		local availableWidth = math.max(260, mainWidth - leftPadding - rightPadding)
		local sidebarWidth = math.clamp(math.floor(availableWidth * 0.28), 130, 170)
		local contentX = leftPadding + sidebarWidth + spacing
		local contentWidth = math.max(120, mainWidth - contentX - rightPadding)

		TabList.Position = UDim2.fromOffset(leftPadding, topPadding)
		TabList.Size = UDim2.new(0, sidebarWidth, 1, -(topPadding + bottomPadding))

		Elements.Position = UDim2.fromOffset(contentX, topPadding)
		Elements.Size = UDim2.new(0, contentWidth, 1, -(topPadding + bottomPadding))
	else
		if presetLayoutBaseline.tabListPosition then
			TabList.Position = presetLayoutBaseline.tabListPosition
		end
		if presetLayoutBaseline.tabListSize then
			TabList.Size = presetLayoutBaseline.tabListSize
		end
		if presetLayoutBaseline.elementsPosition then
			Elements.Position = presetLayoutBaseline.elementsPosition
		end
		if presetLayoutBaseline.elementsSize then
			Elements.Size = presetLayoutBaseline.elementsSize
		end
	end

	return true
end

local function setTransitionProfileInternal(name, persist)
	local canonical = normalizeTransitionProfileName(name)
	if not canonical then
		return false, "Invalid transition profile."
	end
	if not TRANSITION_PROFILE_NAMES[canonical] then
		return false, "Invalid transition profile."
	end
	if not AnimationEngine or type(AnimationEngine.SetTransitionProfile) ~= "function" then
		return false, "Animation engine unavailable."
	end

	local okSet, resultOrErr = AnimationEngine:SetTransitionProfile(canonical)
	if not okSet then
		return false, tostring(resultOrErr or "Failed to apply transition profile.")
	end

	ExperienceState.transitionProfile = canonical
	if persist ~= false then
		setSettingValue("Appearance", "transitionProfile", canonical, true)
	end
	return true, "Transition profile set to " .. canonical .. "."
end

local function setUIPresetInternal(name, persist)
	local canonical = normalizePresetName(name)
	if not canonical then
		return false, "Invalid UI preset."
	end
	if not UI_PRESET_NAMES[canonical] then
		return false, "Invalid UI preset."
	end

	local uiScale = getMainScale()
	if uiScale then
		if canonical == "Compact" then
			uiScale.Scale = 0.93
		elseif canonical == "Cripware" then
			uiScale.Scale = 0.96
		else
			uiScale.Scale = 1.0
		end
	end

	local topbarSearch = Topbar and Topbar:FindFirstChild("Search")
	if topbarSearch then
		topbarSearch.Visible = canonical ~= "Focus"
		if canonical == "Focus" and searchOpen then
			pcall(closeSearch)
		end
	end

	experienceSuppressPromoPrompts = canonical == "Focus"
	ExperienceState.uiPreset = canonical

	local defaultTransitionByPreset = {
		Compact = "Snappy",
		Comfort = "Smooth",
		Focus = "Minimal",
		Cripware = "Snappy"
	}
	local transitionName = defaultTransitionByPreset[canonical] or "Smooth"
	setTransitionProfileInternal(transitionName, persist ~= false)
	applyPresetLayoutInternal(canonical)

	if persist ~= false then
		setSettingValue("Appearance", "uiPreset", canonical, true)
	end

	applyGlassLayer()
	markLayoutDirty("main", "preset_" .. string.lower(canonical))

	return true, "UI preset set to " .. canonical .. "."
end

local function buildThemeStudioTheme(baseThemeName, packedOverrides)
	local baseTheme = ThemeModule.Themes[baseThemeName] or ThemeModule.Themes.Default or {}
	local out = {}
	for themeKey, value in pairs(baseTheme) do
		out[themeKey] = value
	end

	if type(packedOverrides) == "table" then
		for themeKey, packedColor in pairs(packedOverrides) do
			local color = packedToColor3(packedColor)
			if color and out[themeKey] ~= nil then
				out[themeKey] = color
			end
		end
	end
	return out
end

local function getThemeStudioColor(themeKey)
	if type(themeKey) ~= "string" or themeKey == "" then
		return nil
	end
	local packed = ExperienceState.themeStudioState.customThemePacked[themeKey]
	if packed then
		local unpacked = packedToColor3(packed)
		if unpacked then
			return unpacked
		end
	end
	local baseThemeName = ExperienceState.themeStudioState.baseTheme
	local baseTheme = ThemeModule.Themes[baseThemeName] or ThemeModule.Themes.Default
	return baseTheme and baseTheme[themeKey] or nil
end

local function applyThemeStudioState(persist)
	local baseThemeName = ExperienceState.themeStudioState.baseTheme
	local useCustom = ExperienceState.themeStudioState.useCustom == true
	if not ThemeModule.Themes[baseThemeName] then
		baseThemeName = "Default"
		ExperienceState.themeStudioState.baseTheme = baseThemeName
	end

	if useCustom then
		local customTheme = buildThemeStudioTheme(baseThemeName, ExperienceState.themeStudioState.customThemePacked)
		ChangeTheme(customTheme)
	else
		ChangeTheme(baseThemeName)
	end
	applyGlassLayer()

	if persist ~= false then
		setSettingValue("ThemeStudio", "baseTheme", ExperienceState.themeStudioState.baseTheme, false)
		setSettingValue("ThemeStudio", "useCustom", ExperienceState.themeStudioState.useCustom == true, false)
		setSettingValue("ThemeStudio", "customThemePacked", cloneValue(ExperienceState.themeStudioState.customThemePacked), true)
	end

	return true, "Theme studio state applied."
end

local function setThemeStudioBaseTheme(name, persist)
	local themeName = tostring(name or "")
	if not ThemeModule.Themes[themeName] then
		return false, "Theme not found."
	end
	ExperienceState.themeStudioState.baseTheme = themeName
	return applyThemeStudioState(persist ~= false)
end

local function setThemeStudioUseCustom(value, persist)
	ExperienceState.themeStudioState.useCustom = value == true
	return applyThemeStudioState(persist ~= false)
end

local function setThemeStudioColor(themeKey, color)
	if type(themeKey) ~= "string" or themeKey == "" then
		return false, "Theme key is invalid."
	end
	if typeof(color) ~= "Color3" then
		return false, "Color must be Color3."
	end
	if (ThemeModule.Themes.Default or {})[themeKey] == nil then
		return false, "Unknown theme key."
	end
	ExperienceState.themeStudioState.customThemePacked[themeKey] = color3ToPacked(color)
	ExperienceState.themeStudioState.useCustom = true
	return applyThemeStudioState(false)
end

local function resetThemeStudioState(persist)
	ExperienceState.themeStudioState.useCustom = false
	ExperienceState.themeStudioState.customThemePacked = {}
	return applyThemeStudioState(persist ~= false)
end

local function refreshFavoritesSettingsPersistence()
	if ElementsSystem and type(ElementsSystem.getPinnedIds) == "function" then
		local pinnedIds = ElementsSystem.getPinnedIds(true)
		setSettingValue("Favorites", "pinnedIds", cloneArray(pinnedIds), true)
	end
end

local function highlightFavoriteControl(record)
	if not record or not record.GuiObject or not record.GuiObject.Parent then
		return
	end
	local guiObject = record.GuiObject
	local okColor, originalColor = pcall(function()
		return guiObject.BackgroundColor3
	end)
	if not okColor then
		return
	end
	local targetColor = (SelectedTheme and SelectedTheme.SliderProgress) or originalColor
	Animation:Create(guiObject, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
	task.delay(0.22, function()
		if guiObject and guiObject.Parent then
			Animation:Create(guiObject, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = originalColor}):Play()
		end
	end)
end

local function renderFavoritesTab()
	local favoritesTab = ExperienceState.favoritesTab
	if not favoritesTab or type(favoritesTab.Clear) ~= "function" then
		return false
	end

	favoritesTab:Clear()
	favoritesTab:CreateSection("Pinned Controls")

	if not ElementsSystem or type(ElementsSystem.listControlsForFavorites) ~= "function" then
		favoritesTab:CreateLabel("Control registry unavailable.")
		return false
	end

	local controls = ElementsSystem.listControlsForFavorites(true)
	local pinnedControls = {}
	for _, control in ipairs(controls) do
		if control.pinned == true then
			table.insert(pinnedControls, control)
		end
	end

	if #pinnedControls <= 0 then
		favoritesTab:CreateLabel("No pinned controls yet.")
		return true
	end

	for _, control in ipairs(pinnedControls) do
		favoritesTab:CreateButton({
			Name = string.format("[%s] %s", tostring(control.type or "Element"), tostring(control.name or control.id)),
			Callback = function()
				if ElementsSystem and type(ElementsSystem.activateTabByPersistenceId) == "function" then
					ElementsSystem.activateTabByPersistenceId(control.tabId, true)
				end
				if ElementsSystem and type(ElementsSystem.getControlRecordById) == "function" then
					local record = ElementsSystem.getControlRecordById(control.id)
					highlightFavoriteControl(record)
				end
			end
		})
	end

	return true
end

local function ensureFavoritesTab(windowRef)
	if not windowRef then
		return nil, "Window unavailable."
	end
	if ExperienceState.favoritesTab and ExperienceState.favoritesTabWindow == windowRef then
		return ExperienceState.favoritesTab
	end
	ExperienceState.favoritesTabWindow = windowRef
	ExperienceState.favoritesTab = windowRef:CreateTab("Favorites", 0)
	renderFavoritesTab()
	return ExperienceState.favoritesTab
end

local function openFavoritesTab(windowRef)
	local favoritesTab, err = ensureFavoritesTab(windowRef or ExperienceState.favoritesTabWindow)
	if not favoritesTab then
		return false, tostring(err or "Unable to create Favorites tab.")
	end
	if type(favoritesTab.GetInternalRecord) == "function" and ElementsSystem and type(ElementsSystem.activateTabByPersistenceId) == "function" then
		local okRecord, record = pcall(favoritesTab.GetInternalRecord, favoritesTab)
		if okRecord and record and record.PersistenceId then
			ElementsSystem.activateTabByPersistenceId(record.PersistenceId, true)
		end
	end
	return true, "Favorites tab opened."
end

local function ensureOnboardingOverlay()
	if ExperienceState.onboardingOverlay and ExperienceState.onboardingOverlay.Root and ExperienceState.onboardingOverlay.Root.Parent then
		return ExperienceState.onboardingOverlay
	end
	if not Main then
		return nil
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "ExperienceOnboardingOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Visible = false
	overlay.ZIndex = 80
	overlay.ClipsDescendants = true
	overlay.Parent = Main

	local maskTop = Instance.new("Frame")
	maskTop.Name = "MaskTop"
	maskTop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	maskTop.BackgroundTransparency = 0.42
	maskTop.BorderSizePixel = 0
	maskTop.ZIndex = 80
	maskTop.Parent = overlay

	local maskLeft = Instance.new("Frame")
	maskLeft.Name = "MaskLeft"
	maskLeft.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	maskLeft.BackgroundTransparency = 0.42
	maskLeft.BorderSizePixel = 0
	maskLeft.ZIndex = 80
	maskLeft.Parent = overlay

	local maskRight = Instance.new("Frame")
	maskRight.Name = "MaskRight"
	maskRight.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	maskRight.BackgroundTransparency = 0.42
	maskRight.BorderSizePixel = 0
	maskRight.ZIndex = 80
	maskRight.Parent = overlay

	local maskBottom = Instance.new("Frame")
	maskBottom.Name = "MaskBottom"
	maskBottom.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	maskBottom.BackgroundTransparency = 0.42
	maskBottom.BorderSizePixel = 0
	maskBottom.ZIndex = 80
	maskBottom.Parent = overlay

	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BackgroundTransparency = 1
	highlight.BorderSizePixel = 0
	highlight.Visible = false
	highlight.ZIndex = 81
	highlight.Parent = overlay

	local highlightStroke = Instance.new("UIStroke")
	highlightStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	highlightStroke.Thickness = 2
	highlightStroke.Transparency = 0.1
	highlightStroke.Parent = highlight

	local highlightCorner = Instance.new("UICorner")
	highlightCorner.CornerRadius = UDim.new(0, 8)
	highlightCorner.Parent = highlight

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -18)
	panel.Size = UDim2.new(0, 390, 0, 250)
	panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	panel.BackgroundTransparency = 0.06
	panel.ZIndex = 81
	panel.Parent = overlay

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Position = UDim2.new(0, 12, 0, 10)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(245, 245, 245)
	title.ZIndex = 82
	title.Parent = panel

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -24, 0, 112)
	body.Position = UDim2.new(0, 12, 0, 46)
	body.Font = Enum.Font.Gotham
	body.TextSize = 14
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(220, 220, 220)
	body.ZIndex = 82
	body.Parent = panel

	local stepLabel = Instance.new("TextLabel")
	stepLabel.Name = "Step"
	stepLabel.BackgroundTransparency = 1
	stepLabel.Size = UDim2.new(1, -24, 0, 20)
	stepLabel.Position = UDim2.new(0, 12, 1, -108)
	stepLabel.Font = Enum.Font.Gotham
	stepLabel.TextSize = 12
	stepLabel.TextXAlignment = Enum.TextXAlignment.Left
	stepLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	stepLabel.ZIndex = 82
	stepLabel.Parent = panel

	local checkbox = Instance.new("TextButton")
	checkbox.Name = "DontShowAgain"
	checkbox.BackgroundTransparency = 1
	checkbox.Size = UDim2.new(1, -24, 0, 22)
	checkbox.Position = UDim2.new(0, 12, 1, -84)
	checkbox.Font = Enum.Font.Gotham
	checkbox.TextSize = 13
	checkbox.TextXAlignment = Enum.TextXAlignment.Left
	checkbox.TextColor3 = Color3.fromRGB(220, 220, 220)
	checkbox.ZIndex = 82
	checkbox.AutoButtonColor = false
	checkbox.Parent = panel

	local nextButton = Instance.new("TextButton")
	nextButton.Name = "Next"
	nextButton.AnchorPoint = Vector2.new(1, 1)
	nextButton.Position = UDim2.new(1, -12, 1, -12)
	nextButton.Size = UDim2.new(0, 88, 0, 30)
	nextButton.Font = Enum.Font.GothamBold
	nextButton.TextSize = 13
	nextButton.TextColor3 = Color3.fromRGB(245, 245, 245)
	nextButton.BackgroundColor3 = Color3.fromRGB(60, 120, 210)
	nextButton.ZIndex = 82
	nextButton.Parent = panel

	local nextCorner = Instance.new("UICorner")
	nextCorner.CornerRadius = UDim.new(0, 8)
	nextCorner.Parent = nextButton

	local backButton = Instance.new("TextButton")
	backButton.Name = "Back"
	backButton.AnchorPoint = Vector2.new(1, 1)
	backButton.Position = UDim2.new(1, -108, 1, -12)
	backButton.Size = UDim2.new(0, 88, 0, 30)
	backButton.Font = Enum.Font.GothamBold
	backButton.TextSize = 13
	backButton.Text = "Back"
	backButton.TextColor3 = Color3.fromRGB(235, 235, 235)
	backButton.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
	backButton.ZIndex = 82
	backButton.Parent = panel

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 8)
	backCorner.Parent = backButton

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(0, 1)
	closeButton.Position = UDim2.new(0, 12, 1, -12)
	closeButton.Size = UDim2.new(0, 88, 0, 30)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 13
	closeButton.Text = "Close"
	closeButton.TextColor3 = Color3.fromRGB(235, 235, 235)
	closeButton.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
	closeButton.ZIndex = 82
	closeButton.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	local steps = {
		{
			title = "Welcome to Rayfield",
			body = "This guided tour highlights key controls so you can navigate large scripts faster.",
			targetResolver = function()
				return Topbar and Topbar:FindFirstChild("Search")
			end
		},
		{
			title = "Search Controls",
			body = "Use Search to quickly find controls in the active tab. It's faster than manually browsing long lists.",
			targetResolver = function()
				return Main and Main:FindFirstChild("Search")
			end
		},
		{
			title = "Settings & Experience",
			body = "Open Settings to manage presets, theme studio, share code, and Premium UX preferences.",
			targetResolver = function()
				return Topbar and Topbar:FindFirstChild("Settings")
			end
		},
		{
			title = "Tabs & Elements",
			body = "Switch tabs here, then use the elements panel to interact with script features.",
			targetResolver = function()
				return TabList
			end
		}
	}
	local state = {
		step = 1,
		dontShowAgain = false
	}

	local function resolveTarget(stepInfo)
		if type(stepInfo) ~= "table" then
			return nil
		end
		local resolver = stepInfo.targetResolver
		if type(resolver) ~= "function" then
			return nil
		end
		local okTarget, target = pcall(resolver)
		if not okTarget then
			return nil
		end
		if typeof(target) ~= "Instance" then
			return nil
		end
		if not target:IsA("GuiObject") then
			return nil
		end
		if not target.Parent then
			return nil
		end
		return target
	end

	local function applySpotlight(stepInfo)
		local target = resolveTarget(stepInfo)
		local overlayPos = overlay.AbsolutePosition
		local overlaySize = overlay.AbsoluteSize

		local function showFullDimmer()
			maskTop.Position = UDim2.new(0, 0, 0, 0)
			maskTop.Size = UDim2.new(1, 0, 1, 0)
			maskLeft.Size = UDim2.new(0, 0, 0, 0)
			maskRight.Size = UDim2.new(0, 0, 0, 0)
			maskBottom.Size = UDim2.new(0, 0, 0, 0)
			highlight.Visible = false
		end

		if not target or overlaySize.X <= 0 or overlaySize.Y <= 0 then
			showFullDimmer()
			return
		end

		local margin = 8
		local absPos = target.AbsolutePosition
		local absSize = target.AbsoluteSize
		local x = math.floor(absPos.X - overlayPos.X - margin)
		local y = math.floor(absPos.Y - overlayPos.Y - margin)
		local w = math.floor(absSize.X + margin * 2)
		local h = math.floor(absSize.Y + margin * 2)

		if w <= 4 or h <= 4 then
			showFullDimmer()
			return
		end

		x = math.clamp(x, 0, math.max(0, overlaySize.X - 4))
		y = math.clamp(y, 0, math.max(0, overlaySize.Y - 4))
		w = math.clamp(w, 4, math.max(4, overlaySize.X - x))
		h = math.clamp(h, 4, math.max(4, overlaySize.Y - y))

		maskTop.Position = UDim2.new(0, 0, 0, 0)
		maskTop.Size = UDim2.new(1, 0, 0, y)

		maskBottom.Position = UDim2.new(0, 0, 0, y + h)
		maskBottom.Size = UDim2.new(1, 0, 0, math.max(0, overlaySize.Y - (y + h)))

		maskLeft.Position = UDim2.new(0, 0, 0, y)
		maskLeft.Size = UDim2.new(0, x, 0, h)

		maskRight.Position = UDim2.new(0, x + w, 0, y)
		maskRight.Size = UDim2.new(0, math.max(0, overlaySize.X - (x + w)), 0, h)

		highlight.Position = UDim2.new(0, x, 0, y)
		highlight.Size = UDim2.new(0, w, 0, h)
		highlight.Visible = true
		highlightStroke.Color = (SelectedTheme and (SelectedTheme.SliderProgress or SelectedTheme.ToggleEnabled)) or Color3.fromRGB(120, 185, 255)
	end

	local function render()
		local active = steps[state.step] or steps[1]
		title.Text = tostring(active.title or "Welcome")
		body.Text = tostring(active.body or "")
		stepLabel.Text = string.format("Step %d/%d", state.step, #steps)
		checkbox.Text = string.format("%s Don't show this again", state.dontShowAgain and "[x]" or "[ ]")
		nextButton.Text = state.step >= #steps and "Done" or "Next"
		backButton.Visible = state.step > 1
		applySpotlight(active)
	end

	checkbox.MouseButton1Click:Connect(function()
		state.dontShowAgain = not state.dontShowAgain
		render()
	end)
	closeButton.MouseButton1Click:Connect(function()
		overlay.Visible = false
		highlight.Visible = false
		if state.dontShowAgain then
			RayfieldLibrary:SetOnboardingSuppressed(true)
		end
	end)
	backButton.MouseButton1Click:Connect(function()
		if state.step <= 1 then
			return
		end
		state.step -= 1
		render()
	end)
	nextButton.MouseButton1Click:Connect(function()
		if state.step >= #steps then
			overlay.Visible = false
			highlight.Visible = false
			if state.dontShowAgain then
				RayfieldLibrary:SetOnboardingSuppressed(true)
			end
			return
		end
		state.step += 1
		render()
	end)

	overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if overlay.Visible then
			render()
		end
	end)

	ExperienceState.onboardingOverlay = {
		Root = overlay,
		State = state,
		Render = render,
		ApplySpotlight = applySpotlight
	}
	render()
	return ExperienceState.onboardingOverlay
end

local ExperienceBindings = ExperienceBindingsLib.bind({
	RayfieldLibrary = RayfieldLibrary,
	SettingsSystem = SettingsSystem,
	ThemeModule = ThemeModule,
	HttpService = HttpService,
	themeStudioKeys = THEME_STUDIO_KEYS,
	getExperienceState = function()
		return ExperienceState
	end,
	getElementsSystem = function()
		return ElementsSystem
	end,
	getUIStateSystem = function()
		return UIStateSystem
	end,
	getSetting = getSetting,
	setSettingValue = setSettingValue,
	setTransitionProfileInternal = setTransitionProfileInternal,
	setUIPresetInternal = setUIPresetInternal,
	setAudioFeedbackEnabledInternal = setAudioFeedbackEnabledInternal,
	setAudioFeedbackPackInternal = setAudioFeedbackPackInternal,
	getAudioFeedbackStateSnapshot = getAudioFeedbackStateSnapshot,
	playUICueInternal = playUICueInternal,
	setGlassModeInternal = setGlassModeInternal,
	setGlassIntensityInternal = setGlassIntensityInternal,
	applyGlassLayer = function()
		if applyGlassLayer then
			return applyGlassLayer()
		end
		return false, "Glass layer unavailable."
	end,
	ensureOnboardingOverlay = ensureOnboardingOverlay,
	setThemeStudioBaseTheme = setThemeStudioBaseTheme,
	applyThemeStudioState = applyThemeStudioState,
	resetThemeStudioState = resetThemeStudioState,
	cloneValue = cloneValue,
	cloneArray = cloneArray,
	color3ToPacked = color3ToPacked,
	packedToColor3 = packedToColor3,
	normalizeAudioPackName = normalizeAudioPackName,
	cloneAudioPack = cloneAudioPack,
	syncAudioCueSounds = syncAudioCueSounds,
	setAudioFeedbackVolumeInternal = setAudioFeedbackVolumeInternal,
	listThemeNames = listThemeNames,
	getThemeStudioColor = getThemeStudioColor,
	setThemeStudioUseCustom = setThemeStudioUseCustom,
	setThemeStudioColor = setThemeStudioColor,
	refreshFavoritesSettingsPersistence = refreshFavoritesSettingsPersistence,
	ensureFavoritesTab = ensureFavoritesTab,
	renderFavoritesTab = renderFavoritesTab,
	openFavoritesTab = openFavoritesTab
})

local function restoreExperienceStateFromSettings(windowRef)
	if ExperienceBindings and type(ExperienceBindings.restoreFromSettings) == "function" then
		return ExperienceBindings.restoreFromSettings(windowRef)
	end
	return false, "Experience bindings unavailable."
end

-- Note: UI State Management (Notify, Search, Hide/Minimize) moved to rayfield-ui-state.lua module

-- Wrapper for RayfieldLibrary:Notify
function RayfieldLibrary:Notify(data)
	return UIStateSystem.Notify(data)
end

local function ensureOwnershipSystem()
	if not OwnershipSystem then
		return false, "Ownership tracker is unavailable."
	end
	return true
end

local function sanitizeScopeName(rawName)
	local value = tostring(rawName or "")
	value = value:gsub("^%s+", "")
	value = value:gsub("%s+$", "")
	value = value:gsub("[%s/\\]+", "_")
	value = value:gsub("[^%w_%-:]", "")
	if value == "" then
		local okGuid, guid = pcall(function()
			return HttpService:GenerateGUID(false)
		end)
		if okGuid and type(guid) == "string" and guid ~= "" then
			value = guid
		else
			value = tostring(math.floor(os.clock() * 100000))
		end
	end
	return value
end

function RayfieldLibrary:CreateFeatureScope(name)
	local okOwnership, ownershipErr = ensureOwnershipSystem()
	if not okOwnership then
		return nil, ownershipErr
	end

	local normalizedName = sanitizeScopeName(name or "feature")
	local scopeId = "feature:" .. normalizedName
	if type(OwnershipSystem.createScope) == "function" then
		pcall(OwnershipSystem.createScope, scopeId, {
			kind = "feature",
			name = normalizedName
		})
	end
	return scopeId, "ok"
end

function RayfieldLibrary:TrackFeatureConnection(scopeId, connection)
	local okOwnership, ownershipErr = ensureOwnershipSystem()
	if not okOwnership then
		return false, ownershipErr
	end
	if type(scopeId) ~= "string" or scopeId == "" then
		return false, "Invalid scopeId."
	end
	if not connection then
		return false, "Invalid connection."
	end
	if type(OwnershipSystem.trackConnection) ~= "function" then
		return false, "Ownership tracker does not support connection tracking."
	end
	local okTrack, tracked = pcall(OwnershipSystem.trackConnection, connection, scopeId)
	if not okTrack then
		return false, tostring(tracked)
	end
	if tracked ~= true then
		return false, "Failed to track connection."
	end
	return true, "ok"
end

function RayfieldLibrary:TrackFeatureTask(scopeId, taskHandle)
	local okOwnership, ownershipErr = ensureOwnershipSystem()
	if not okOwnership then
		return false, ownershipErr
	end
	if type(scopeId) ~= "string" or scopeId == "" then
		return false, "Invalid scopeId."
	end
	if taskHandle == nil then
		return false, "Invalid task handle."
	end
	if type(OwnershipSystem.trackTask) ~= "function" then
		return false, "Ownership tracker does not support task tracking."
	end
	local okTrack, tracked = pcall(OwnershipSystem.trackTask, taskHandle, scopeId)
	if not okTrack then
		return false, tostring(tracked)
	end
	if tracked ~= true then
		return false, "Failed to track task."
	end
	return true, "ok"
end

function RayfieldLibrary:TrackFeatureInstance(scopeId, instance, metadata)
	local okOwnership, ownershipErr = ensureOwnershipSystem()
	if not okOwnership then
		return false, ownershipErr
	end
	if type(scopeId) ~= "string" or scopeId == "" then
		return false, "Invalid scopeId."
	end
	if typeof(instance) ~= "Instance" then
		return false, "Invalid instance."
	end
	if type(OwnershipSystem.claimInstance) ~= "function" then
		return false, "Ownership tracker does not support instance tracking."
	end
	local okClaim, claimResult = pcall(OwnershipSystem.claimInstance, instance, scopeId, metadata)
	if not okClaim then
		return false, tostring(claimResult)
	end
	if claimResult ~= true then
		return false, "Failed to track instance."
	end
	return true, "ok"
end

function RayfieldLibrary:TrackFeatureCleanup(scopeId, cleanupFn)
	local okOwnership, ownershipErr = ensureOwnershipSystem()
	if not okOwnership then
		return false, ownershipErr
	end
	if type(scopeId) ~= "string" or scopeId == "" then
		return false, "Invalid scopeId."
	end
	if type(cleanupFn) ~= "function" then
		return false, "cleanupFn must be a function."
	end
	if type(OwnershipSystem.trackCleanup) ~= "function" then
		return false, "Ownership tracker does not support cleanup callbacks."
	end
	local okTrack, trackResult = pcall(OwnershipSystem.trackCleanup, cleanupFn, scopeId)
	if not okTrack then
		return false, tostring(trackResult)
	end
	if trackResult ~= true then
		return false, "Failed to track cleanup callback."
	end
	return true, "ok"
end

function RayfieldLibrary:CleanupFeatureScope(scopeId, destroyInstances)
	local okOwnership, ownershipErr = ensureOwnershipSystem()
	if not okOwnership then
		return false, ownershipErr
	end
	if type(scopeId) ~= "string" or scopeId == "" then
		return false, "Invalid scopeId."
	end
	if type(OwnershipSystem.cleanupScope) ~= "function" then
		return false, "Ownership tracker does not support scope cleanup."
	end
	local okCleanup, cleanupResult = pcall(OwnershipSystem.cleanupScope, scopeId, {
		destroyInstances = destroyInstances == true,
		clearAttributes = true
	})
	if not okCleanup then
		return false, tostring(cleanupResult)
	end
	if cleanupResult ~= true then
		return false, "Scope was not found."
	end
	return true, "ok"
end

function RayfieldLibrary:GetFeatureCleanupStats()
	local okOwnership, _ = ensureOwnershipSystem()
	if not okOwnership then
		return {
			scopes = 0,
			instances = 0,
			connections = 0,
			tasks = 0,
			cleanups = 0
		}
	end
	if type(OwnershipSystem.getStats) ~= "function" then
		return {
			scopes = 0,
			instances = 0,
			connections = 0,
			tasks = 0,
			cleanups = 0
		}
	end
	local okStats, stats = pcall(OwnershipSystem.getStats)
	if not okStats or type(stats) ~= "table" then
		return {
			scopes = 0,
			instances = 0,
			connections = 0,
			tasks = 0,
			cleanups = 0
		}
	end
	return stats
end

function RayfieldLibrary:GetRuntimeDiagnostics()
	local animationStats = {}
	if AnimationEngine and type(AnimationEngine.GetRuntimeStats) == "function" then
		local ok, stats = pcall(function()
			return AnimationEngine:GetRuntimeStats()
		end)
		if ok and type(stats) == "table" then
			animationStats = stats
		end
	end

	local activeTweens = animationStats.activeTweens
	if type(activeTweens) ~= "number" and AnimationEngine and type(AnimationEngine.GetActiveAnimationCount) == "function" then
		local ok, value = pcall(function()
			return AnimationEngine:GetActiveAnimationCount()
		end)
		activeTweens = ok and value or 0
	end

	local activeTextHandles = animationStats.activeTextHandles
	if type(activeTextHandles) ~= "number" and AnimationEngine and type(AnimationEngine.GetTextHandleCount) == "function" then
		local ok, value = pcall(function()
			return AnimationEngine:GetTextHandleCount()
		end)
		activeTextHandles = ok and value or 0
	end

	local themeBindings = { objectsBound = 0, propertiesBound = 0 }
	if ThemeSystem and type(ThemeSystem.GetBindingStats) == "function" then
		local ok, stats = pcall(function()
			return ThemeSystem.GetBindingStats()
		end)
		if ok and type(stats) == "table" then
			themeBindings = {
				objectsBound = tonumber(stats.objectsBound) or 0,
				propertiesBound = tonumber(stats.propertiesBound) or 0
			}
		end
	end

	local ownershipStats = {
		scopes = 0,
		instances = 0,
		connections = 0,
		tasks = 0,
		cleanups = 0
	}
	if OwnershipSystem and type(OwnershipSystem.getStats) == "function" then
		local okOwnershipStats, stats = pcall(OwnershipSystem.getStats)
		if okOwnershipStats and type(stats) == "table" then
			ownershipStats = {
				scopes = tonumber(stats.scopes) or 0,
				instances = tonumber(stats.instances) or 0,
				connections = tonumber(stats.connections) or 0,
				tasks = tonumber(stats.tasks) or 0,
				cleanups = tonumber(stats.cleanups) or 0
			}
		end
	end

	return {
		activeTweens = tonumber(activeTweens) or 0,
		activeTextHandles = tonumber(activeTextHandles) or 0,
		themeBindings = themeBindings,
		ownership = ownershipStats,
		rayfieldVisible = not Hidden,
		rayfieldMinimized = Minimised == true,
		rayfieldDestroyed = rayfieldDestroyed == true,
		performanceProfile = {
			enabled = activePerformanceProfile.enabled == true,
			requestedMode = activePerformanceProfile.requestedMode,
			resolvedMode = activePerformanceProfile.resolvedMode,
			aggressive = activePerformanceProfile.aggressive == true,
			disableDetach = activePerformanceProfile.disableDetach == true,
			disableTabSplit = activePerformanceProfile.disableTabSplit == true,
			disableAnimations = activePerformanceProfile.disableAnimations == true
		},
		experience = {
			audioEnabled = ExperienceState.audioState.enabled == true,
			audioPack = ExperienceState.audioState.pack,
			glassMode = ExperienceState.glassState.mode,
			glassResolvedMode = ExperienceState.glassState.resolvedMode,
			glassIntensity = tonumber(ExperienceState.glassState.intensity) or 0.32,
			onboardingSuppressed = ExperienceState.onboardingSuppressed == true
		}
	}
end

local function shallowArrayCopy(input)
	local out = {}
	if type(input) ~= "table" then
		return out
	end
	for index, value in ipairs(input) do
		out[index] = value
	end
	return out
end

local function normalizeProfileMode(mode)
	if type(mode) ~= "string" then
		return "auto"
	end
	local normalized = string.lower(mode)
	if normalized == "auto" or normalized == "potato" or normalized == "mobile" or normalized == "normal" then
		return normalized
	end
	return "auto"
end

local function mergeTable(target, source)
	if type(source) ~= "table" then
		return
	end
	if type(target) ~= "table" then
		return
	end
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			mergeTable(target[key], value)
		else
			target[key] = value
		end
	end
end

local function applyPresetFillNil(target, preset, appliedFields, pathPrefix)
	if type(target) ~= "table" or type(preset) ~= "table" then
		return
	end
	for key, value in pairs(preset) do
		local path = pathPrefix and (pathPrefix .. "." .. tostring(key)) or tostring(key)
		if type(value) == "table" then
			local existing = target[key]
			if existing == nil then
				target[key] = {}
				existing = target[key]
			end
			if type(existing) == "table" then
				applyPresetFillNil(existing, value, appliedFields, path)
			end
		else
			if target[key] == nil then
				target[key] = value
				table.insert(appliedFields, path)
			end
		end
	end
end

local function buildLowSpecPreset(resolvedMode, aggressive, profileSettings)
	local isLowSpecMode = resolvedMode == "potato" or resolvedMode == "mobile"
	local disableDetach = profileSettings.DisableDetach
	if disableDetach == nil then
		disableDetach = aggressive and isLowSpecMode
	end
	local disableTabSplit = profileSettings.DisableTabSplit
	if disableTabSplit == nil then
		disableTabSplit = aggressive and isLowSpecMode
	end
	local disableAnimations = profileSettings.DisableAnimations
	if disableAnimations == nil then
		disableAnimations = aggressive and isLowSpecMode
	end

	local preset = {}
	if isLowSpecMode then
		preset.DisableRayfieldPrompts = true
		preset.DisableBuildWarnings = true
		preset.ViewportVirtualization = {
			Enabled = true,
			AlwaysOn = true,
			FullSuspend = true,
			FadeOnScroll = false,
			DisableFadeDuringResize = true
		}

		if resolvedMode == "potato" then
			preset.ViewportVirtualization.OverscanPx = 80
			preset.ViewportVirtualization.UpdateHz = 20
			preset.ViewportVirtualization.ResizeDebounceMs = 120
		elseif resolvedMode == "mobile" then
			preset.ViewportVirtualization.OverscanPx = 100
			preset.ViewportVirtualization.UpdateHz = 24
			preset.ViewportVirtualization.ResizeDebounceMs = 100
		end
	end

	if disableAnimations then
		preset.ViewportVirtualization = preset.ViewportVirtualization or {}
		preset.ViewportVirtualization.FadeOnScroll = false
		preset.ViewportVirtualization.DisableFadeDuringResize = true
	end

	if disableTabSplit then
		preset.EnableTabSplit = false
	end

	if type(profileSettings.ViewportVirtualization) == "table" then
		preset.ViewportVirtualization = preset.ViewportVirtualization or {}
		mergeTable(preset.ViewportVirtualization, profileSettings.ViewportVirtualization)
	end

	return preset, {
		disableDetach = disableDetach == true,
		disableTabSplit = disableTabSplit == true,
		disableAnimations = disableAnimations == true,
		aggressive = aggressive == true
	}
end

local function resolvePerformanceProfile(Settings, runtimeCtx)
	local resolved = {
		enabled = false,
		requestedMode = "normal",
		resolvedMode = "normal",
		aggressive = false,
		disableDetach = false,
		disableTabSplit = false,
		disableAnimations = false,
		appliedFields = {}
	}
	local profile = Settings and Settings.PerformanceProfile
	if type(profile) ~= "table" or profile.Enabled ~= true then
		return resolved
	end

	resolved.enabled = true
	local requestedMode = normalizeProfileMode(profile.Mode or "auto")
	resolved.requestedMode = requestedMode

	local resolvedMode = requestedMode
	if requestedMode == "auto" then
		if runtimeCtx and runtimeCtx.touchEnabled == true then
			resolvedMode = "mobile"
		else
			resolvedMode = "potato"
		end
	end
	resolved.resolvedMode = resolvedMode

	local aggressive = profile.Aggressive ~= false
	local preset, flags = buildLowSpecPreset(resolvedMode, aggressive, profile)
	applyPresetFillNil(Settings, preset, resolved.appliedFields)

	resolved.aggressive = flags.aggressive
	resolved.disableDetach = flags.disableDetach
	resolved.disableTabSplit = flags.disableTabSplit
	resolved.disableAnimations = flags.disableAnimations
	if type(Settings.EnableTabSplit) == "boolean" then
		resolved.disableTabSplit = Settings.EnableTabSplit == false
	end

	return resolved
end

local function applySystemOverridesForProfile(profile)
	local lowSpecActive = type(profile) == "table" and profile.enabled == true and profile.resolvedMode ~= "normal"
	local disableAnimations = type(profile) == "table" and profile.disableAnimations == true
	if lowSpecActive or disableAnimations then
		overrideSetting("System", "reducedEffects", true)
		overrideSetting("System", "performanceMode", true)
	else
		overrideSetting("System", "reducedEffects", nil)
		overrideSetting("System", "performanceMode", nil)
	end

	if lowSpecActive then
		overrideSetting("System", "usageAnalytics", false)
	elseif not requestsDisabled then
		overrideSetting("System", "usageAnalytics", nil)
	end
end

-- Note: saveSettings, updateSetting, and createSettings are now handled by SettingsModule

function RayfieldLibrary:CreateWindow(Settings)
	Settings = type(Settings) == "table" and Settings or {}
	local runtimeCtx = {
		touchEnabled = UserInputService and UserInputService.TouchEnabled == true
	}
	local resolvedPerformanceProfile = resolvePerformanceProfile(Settings, runtimeCtx)
	activePerformanceProfile = resolvedPerformanceProfile
	detachPathEnabled = resolvedPerformanceProfile.disableDetach ~= true
	applySystemOverridesForProfile(resolvedPerformanceProfile)
	ExperienceState.onboardingRendered = false
	local fastLoadEnabled = Settings.FastLoad ~= false
	if resolvedPerformanceProfile.disableAnimations == true then
		fastLoadEnabled = true
	end
	local startupTimeScale = fastLoadEnabled and 0.2 or 1
	if resolvedPerformanceProfile.disableAnimations == true then
		startupTimeScale = 0.08
	end

	local function waitForStartup(seconds)
		local duration = tonumber(seconds) or 0
		if duration <= 0 then
			return
		end
		local scaled = duration * startupTimeScale
		if scaled > 0 then
			task.wait(scaled)
		end
	end

	local function startupTweenDuration(seconds)
		local duration = tonumber(seconds) or 0
		if duration <= 0 then
			return 0
		end
		if startupTimeScale >= 1 then
			return duration
		end
		return math.max(0.04, duration * startupTimeScale)
	end

	if type(loaderDiagnostics) == "table" then
		loaderDiagnostics.performanceProfile = {
			enabled = resolvedPerformanceProfile.enabled == true,
			requestedMode = resolvedPerformanceProfile.requestedMode,
			resolvedMode = resolvedPerformanceProfile.resolvedMode,
			aggressive = resolvedPerformanceProfile.aggressive == true,
			disableDetach = resolvedPerformanceProfile.disableDetach == true,
			disableTabSplit = resolvedPerformanceProfile.disableTabSplit == true,
			disableAnimations = resolvedPerformanceProfile.disableAnimations == true,
			appliedFields = shallowArrayCopy(resolvedPerformanceProfile.appliedFields)
		}
	end

	if Rayfield:FindFirstChild('Loading') then
		if getgenv and not getgenv().rayfieldCached then
			Rayfield.Enabled = true
			Rayfield.Loading.Visible = true

			waitForStartup(1.4)
			Rayfield.Loading.Visible = false
		end
	end

	if getgenv then getgenv().rayfieldCached = true end

	if not correctBuild and not Settings.DisableBuildWarnings then
		task.delay(3, 
			function() 
				RayfieldLibrary:Notify({Title = 'Build Mismatch', Content = 'Rayfield may encounter issues as you are running an incompatible interface version ('.. ((Rayfield:FindFirstChild('Build') and Rayfield.Build.Value) or 'No Build') ..').\n\nThis version of Rayfield is intended for interface build '..InterfaceBuild..'.\n\nTry rejoining and then run the script twice.', Image = 4335487866, Duration = 15})		
			end)
	end

	if Settings.ToggleUIKeybind then -- Can either be a string, sequence, or an Enum.KeyCode
		local canonical, _, normalizeErr = KeybindSequenceLib.normalize(Settings.ToggleUIKeybind, {
			maxSteps = 4
		})
		assert(canonical, "ToggleUIKeybind must be a valid keybind/sequence: " .. tostring(normalizeErr))
		overrideSetting("General", "rayfieldOpen", canonical)
		cachedUiToggleKeybindRaw = nil
		cachedUiToggleKeybindSpec = nil
		uiToggleKeybindMatcher:reset()
	end

	ensureFolder(RayfieldFolder)

	-- Attempt to report an event to analytics
	if not requestsDisabled then
		sendReport("window_created", Settings.Name or "Unknown")
	end
	local Passthrough = false
	Topbar.Title.Text = Settings.Name

	Main.Size = UDim2.new(0, 420, 0, 100)
	Main.Visible = true
	Main.BackgroundTransparency = 1
	if Main:FindFirstChild('Notice') then Main.Notice.Visible = false end
	Main.Shadow.Image.ImageTransparency = 1

	LoadingFrame.Title.TextTransparency = 1
	LoadingFrame.Subtitle.TextTransparency = 1

	if Settings.ShowText then
		MPrompt.Title.Text = 'Show '..Settings.ShowText
	end

	LoadingFrame.Version.TextTransparency = 1
	LoadingFrame.Title.Text = Settings.LoadingTitle or "Rayfield"
	LoadingFrame.Subtitle.Text = Settings.LoadingSubtitle or "Interface Suite"

	if Settings.LoadingTitle ~= "Rayfield Interface Suite" then
		LoadingFrame.Version.Text = "Rayfield UI"
	end

	if Settings.Icon and Settings.Icon ~= 0 and Topbar:FindFirstChild('Icon') then
		Topbar.Icon.Visible = true
		Topbar.Title.Position = UDim2.new(0, 47, 0.5, 0)

		if Settings.Icon then
			if typeof(Settings.Icon) == 'string' and Icons then
				local asset = getIcon(Settings.Icon)

				Topbar.Icon.Image = 'rbxassetid://'..asset.id
				Topbar.Icon.ImageRectOffset = asset.imageRectOffset
				Topbar.Icon.ImageRectSize = asset.imageRectSize
			else
				Topbar.Icon.Image = getAssetUri(Settings.Icon)
			end
		else
			Topbar.Icon.Image = "rbxassetid://" .. 0
		end
	end

	if dragBar then
		dragBar.Visible = false
		dragBarCosmetic.BackgroundTransparency = 1
		dragBar.Visible = true
	end

	if Settings.Theme then
		local success, result = pcall(ChangeTheme, Settings.Theme)
		if not success then
			local success, result2 = pcall(ChangeTheme, 'Default')
			if not success then
				warn('CRITICAL ERROR - NO DEFAULT THEME')
				print(result2)
			end
			warn('issue rendering theme. no theme on file')
			print(result)
		end
	end

	Topbar.Visible = false
	TabList.Visible = false
	Elements.Visible = false
	LoadingFrame.Visible = true

	-- Improvement 1: Disable notification loop by default to reduce resource usage
	-- Users can explicitly set DisableRayfieldPrompts = false to enable notifications
	if Settings.DisableRayfieldPrompts == nil then
		Settings.DisableRayfieldPrompts = true -- Default to disabled
	end

	-- Tab split settings
	if Settings.EnableTabSplit == nil then
		Settings.EnableTabSplit = true
	end
	if type(Settings.TabSplitHoldDuration) ~= "number" or Settings.TabSplitHoldDuration <= 0 then
		Settings.TabSplitHoldDuration = 3
	end
	if Settings.AllowSettingsTabSplit == nil then
		Settings.AllowSettingsTabSplit = false
	end
	if Settings.MaxSplitTabs ~= nil then
		local maxSplitTabs = tonumber(Settings.MaxSplitTabs)
		if maxSplitTabs and maxSplitTabs >= 1 then
			Settings.MaxSplitTabs = math.floor(maxSplitTabs)
		else
			Settings.MaxSplitTabs = nil
		end
	end

	if type(Settings.ViewportVirtualization) ~= "table" then
		Settings.ViewportVirtualization = {}
	end
	local viewportSettings = Settings.ViewportVirtualization
	if viewportSettings.Enabled == nil then
		viewportSettings.Enabled = true
	end
	if viewportSettings.AlwaysOn == nil then
		viewportSettings.AlwaysOn = true
	end
	if viewportSettings.FullSuspend == nil then
		viewportSettings.FullSuspend = true
	end
	if viewportSettings.OverscanPx == nil then
		viewportSettings.OverscanPx = 120
	end
	if viewportSettings.UpdateHz == nil then
		viewportSettings.UpdateHz = 30
	end
	if viewportSettings.FadeOnScroll == nil then
		viewportSettings.FadeOnScroll = true
	end
	if viewportSettings.DisableFadeDuringResize == nil then
		viewportSettings.DisableFadeDuringResize = true
	end
	if viewportSettings.ResizeDebounceMs == nil then
		viewportSettings.ResizeDebounceMs = 100
	end
	if viewportSettings.MinElementsToActivate == nil then
		viewportSettings.MinElementsToActivate = 0
	end

	if not Settings.DisableRayfieldPrompts then
		task.spawn(function()
			while true do
				task.wait(math.random(180, 600))
				if experienceSuppressPromoPrompts then
					continue
				end
				RayfieldLibrary:Notify({
					Title = "Rayfield Interface",
					Content = "Enjoying this UI library? Find it at sirius.menu/discord",
					Duration = 7,
					Image = 4370033185,
				})
			end
		end)
	end

	pcall(function()
		if type(Settings.ConfigurationSaving) ~= "table" then
			Settings.ConfigurationSaving = {}
		end
		if not Settings.ConfigurationSaving.FileName then
			Settings.ConfigurationSaving.FileName = tostring(game.PlaceId)
		end

		if Settings.ConfigurationSaving.Enabled == nil then
			Settings.ConfigurationSaving.Enabled = false
		end

		CFileName = Settings.ConfigurationSaving.FileName
		ConfigurationFolder = Settings.ConfigurationSaving.FolderName or ConfigurationFolder
		CEnabled = Settings.ConfigurationSaving.Enabled
		if type(Settings.ConfigurationSaving.Layout) ~= "table" then
			Settings.ConfigurationSaving.Layout = {}
		end
		local layoutConfig = Settings.ConfigurationSaving.Layout
		if layoutConfig.Enabled == nil then
			layoutSavingEnabled = CEnabled == true
		else
			layoutSavingEnabled = layoutConfig.Enabled == true and CEnabled == true
		end
		local configuredDebounce = tonumber(layoutConfig.DebounceMs)
		if configuredDebounce and configuredDebounce >= 50 then
			layoutDebounceMs = math.floor(configuredDebounce)
		else
			layoutDebounceMs = 300
		end
		layoutConfig.Enabled = layoutSavingEnabled
		layoutConfig.DebounceMs = layoutDebounceMs

		if Settings.ConfigurationSaving.Enabled then
			ensureFolder(ConfigurationFolder)
		end
	end)

	-- Initialize Utilities Module now that UI elements exist
	UtilitiesSystem = UtilitiesModuleLib.init({
		TweenService = TweenService,
		Animation = Animation,
		RunService = RunService,
		UserInputService = UserInputService,
		getService = getService,
		Main = Main,
		Rayfield = Rayfield,
		dragBar = dragBar,
		dragBarCosmetic = dragBarCosmetic,
		getHidden = function() return Hidden end,
		useMobileSizing = useMobileSizing,
		Hide = Hide,
		Unhide = Unhide,
		getDebounce = function() return Debounce end,
		setRayfieldDestroyed = function(val) rayfieldDestroyed = val end,
		keybindConnections = keybindConnections
	})

	makeDraggable(Main, Topbar, false, {dragOffset, dragOffsetMobile})
	if dragBar then dragBar.Position = useMobileSizing and UDim2.new(0.5, 0, 0.5, dragOffsetMobile) or UDim2.new(0.5, 0, 0.5, dragOffset) makeDraggable(Main, dragInteract, true, {dragOffset, dragOffsetMobile}) end

	for _, TabButton in ipairs(TabList:GetChildren()) do
		if TabButton.ClassName == "Frame" and TabButton.Name ~= "Placeholder" then
			TabButton.BackgroundTransparency = 1
			TabButton.Title.TextTransparency = 1
			TabButton.Image.ImageTransparency = 1
			TabButton.UIStroke.Transparency = 1
		end
	end

	if Settings.Discord and Settings.Discord.Enabled and not useStudio then
		ensureFolder(RayfieldFolder.."/Discord Invites")

		if callSafely(isfile, RayfieldFolder.."/Discord Invites".."/"..Settings.Discord.Invite..ConfigurationExtension) then
			if requestFunc then
				pcall(function()
					requestFunc({
						Url = 'http://127.0.0.1:6463/rpc?v=1',
						Method = 'POST',
						Headers = {
							['Content-Type'] = 'application/json',
							Origin = 'https://discord.com'
						},
						Body = HttpService:JSONEncode({
							cmd = 'INVITE_BROWSER',
							nonce = HttpService:GenerateGUID(false),
							args = {code = Settings.Discord.Invite}
						})
					})
				end)
			end

			if Settings.Discord.RememberJoins then -- We do logic this way so if the developer changes this setting, the user still won't be prompted, only new users
				callSafely(writefile, RayfieldFolder.."/Discord Invites".."/"..Settings.Discord.Invite..ConfigurationExtension,"Rayfield RememberJoins is true for this invite, this invite will not ask you to join again")
			end
		end
	end

	if (Settings.KeySystem) then
		if not Settings.KeySettings then
			Passthrough = true
			return
		end

		ensureFolder(RayfieldFolder.."/Key System")

		if typeof(Settings.KeySettings.Key) == "string" then Settings.KeySettings.Key = {Settings.KeySettings.Key} end

		if Settings.KeySettings.GrabKeyFromSite then
			for i, Key in ipairs(Settings.KeySettings.Key) do
				local Success, Response = pcall(function()
					Settings.KeySettings.Key[i] = tostring(game:HttpGet(Key):gsub("[\n\r]", " "))
					Settings.KeySettings.Key[i] = string.gsub(Settings.KeySettings.Key[i], " ", "")
				end)
				if not Success then
					print("Rayfield | "..Key.." Error " ..tostring(Response))
					warn('Check docs.sirius.menu for help with Rayfield specific development.')
				end
			end
		end

		if not Settings.KeySettings.FileName then
			Settings.KeySettings.FileName = "No file name specified"
		end

		if callSafely(isfile, RayfieldFolder.."/Key System".."/"..Settings.KeySettings.FileName..ConfigurationExtension) then
			for _, MKey in ipairs(Settings.KeySettings.Key) do
				local savedKeys = callSafely(readfile, RayfieldFolder.."/Key System".."/"..Settings.KeySettings.FileName..ConfigurationExtension)
				if savedKeys and string.find(savedKeys, MKey) then
					Passthrough = true
				end
			end
		end

		if not Passthrough then
			local AttemptsRemaining = math.random(2, 5)
			Rayfield.Enabled = false
			local KeyUI = useStudio and script.Parent:FindFirstChild('Key') or game:GetObjects("rbxassetid://11380036235")[1]

			KeyUI.Enabled = true

			local keyUiContainer = nil
			if Compatibility and type(Compatibility.protectAndParent) == "function" then
				keyUiContainer = Compatibility.protectAndParent(KeyUI, nil, {
					useStudio = useStudio
				})
			elseif not useStudio then
				KeyUI.Parent = CoreGui
				keyUiContainer = CoreGui
			end

			if Compatibility and type(Compatibility.dedupeGuiByName) == "function" then
				Compatibility.dedupeGuiByName(keyUiContainer, KeyUI.Name, KeyUI, "-Old")
			elseif not useStudio and keyUiContainer then
				for _, Interface in ipairs(keyUiContainer:GetChildren()) do
					if Interface.Name == KeyUI.Name and Interface ~= KeyUI then
						Interface.Enabled = false
						Interface.Name = "KeyUI-Old"
					end
				end
			end

			local KeyMain = KeyUI.Main
			KeyMain.Title.Text = Settings.KeySettings.Title or Settings.Name
			KeyMain.Subtitle.Text = Settings.KeySettings.Subtitle or "Key System"
			KeyMain.NoteMessage.Text = Settings.KeySettings.Note or "No instructions"

			KeyMain.Size = UDim2.new(0, 467, 0, 175)
			KeyMain.BackgroundTransparency = 1
			KeyMain.Shadow.Image.ImageTransparency = 1
			KeyMain.Title.TextTransparency = 1
			KeyMain.Subtitle.TextTransparency = 1
			KeyMain.KeyNote.TextTransparency = 1
			KeyMain.Input.BackgroundTransparency = 1
			KeyMain.Input.UIStroke.Transparency = 1
			KeyMain.Input.InputBox.TextTransparency = 1
			KeyMain.NoteTitle.TextTransparency = 1
			KeyMain.NoteMessage.TextTransparency = 1
			KeyMain.Hide.ImageTransparency = 1

			Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
			Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 500, 0, 187)}):Play()
			Animation:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5}):Play()
			task.wait(0.05)
			Animation:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
			Animation:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
			task.wait(0.05)
			Animation:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
			Animation:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
			Animation:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
			Animation:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
			task.wait(0.05)
			Animation:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
			Animation:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
			task.wait(0.15)
			Animation:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 0.3}):Play()


			KeyUI.Main.Input.InputBox.FocusLost:Connect(function()
				if #KeyUI.Main.Input.InputBox.Text == 0 then return end
				local KeyFound = false
				local FoundKey = ''
				for _, MKey in ipairs(Settings.KeySettings.Key) do
					--if string.find(KeyMain.Input.InputBox.Text, MKey) then
					--	KeyFound = true
					--	FoundKey = MKey
					--end


					-- stricter key check
					if KeyMain.Input.InputBox.Text == MKey then
						KeyFound = true
						FoundKey = MKey
					end
				end
				if KeyFound then 
					Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
					Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 467, 0, 175)}):Play()
					Animation:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
					Animation:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
					Animation:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
					Animation:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
					Animation:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
					Animation:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
					Animation:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
					Animation:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
					Animation:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
					Animation:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
					task.wait(0.51)
					Passthrough = true
					KeyMain.Visible = false
					if Settings.KeySettings.SaveKey then
						callSafely(writefile, RayfieldFolder.."/Key System".."/"..Settings.KeySettings.FileName..ConfigurationExtension, FoundKey)
						RayfieldLibrary:Notify({Title = "Key System", Content = "The key for this script has been saved successfully.", Image = 3605522284})
					end
				else
					if AttemptsRemaining == 0 then
						Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
						Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 467, 0, 175)}):Play()
						Animation:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
						Animation:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						Animation:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						Animation:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						Animation:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
						Animation:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						Animation:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						Animation:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						Animation:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						Animation:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
						task.wait(0.45)
						Players.LocalPlayer:Kick("No Attempts Remaining")
						game:Shutdown()
					end
					KeyMain.Input.InputBox.Text = ""
					AttemptsRemaining = AttemptsRemaining - 1
					Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 467, 0, 175)}):Play()
					Animation:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), {Position = UDim2.new(0.495,0,0.5,0)}):Play()
					task.wait(0.1)
					Animation:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), {Position = UDim2.new(0.505,0,0.5,0)}):Play()
					task.wait(0.1)
					Animation:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5,0,0.5,0)}):Play()
					Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 500, 0, 187)}):Play()
				end
			end)

			KeyMain.Hide.MouseButton1Click:Connect(function()
				Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
				Animation:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 467, 0, 175)}):Play()
				Animation:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
				Animation:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
				Animation:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
				Animation:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
				Animation:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
				Animation:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
				Animation:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
				Animation:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
				Animation:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
				Animation:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
				task.wait(0.51)
				RayfieldLibrary:Destroy()
				KeyUI:Destroy()
			end)
		else
			Passthrough = true
		end
	end
	if Settings.KeySystem then
		repeat task.wait() until Passthrough
	end

	Notifications.Template.Visible = false
	Notifications.Visible = true
	Rayfield.Enabled = true

	waitForStartup(0.5)
	Animation:Create(Main, TweenInfo.new(startupTweenDuration(0.7), Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	Animation:Create(Main.Shadow.Image, TweenInfo.new(startupTweenDuration(0.7), Enum.EasingStyle.Exponential), {ImageTransparency = 0.6}):Play()
	waitForStartup(0.1)
	Animation:Create(LoadingFrame.Title, TweenInfo.new(startupTweenDuration(0.7), Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	waitForStartup(0.05)
	Animation:Create(LoadingFrame.Subtitle, TweenInfo.new(startupTweenDuration(0.7), Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	waitForStartup(0.05)
	Animation:Create(LoadingFrame.Version, TweenInfo.new(startupTweenDuration(0.7), Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()


	Elements.Template.LayoutOrder = 100000
	Elements.Template.Visible = false

	Elements.UIPageLayout.FillDirection = Enum.FillDirection.Horizontal
	TabList.Template.Visible = false

	-- Tab
	local FirstTab = false
	local Window = {}
	ExperienceState.favoritesTabWindow = Window
	ExperienceState.favoritesTab = nil

	-- Recreate tab split system per-window setup to keep references fresh
	if TabSplitSystem and TabSplitSystem.destroy then
		TabSplitSystem.destroy()
		TabSplitSystem = nil
	end

	if ViewportVirtualizationSystem and type(ViewportVirtualizationSystem.destroy) == "function" then
		pcall(ViewportVirtualizationSystem.destroy)
	end
	ViewportVirtualizationSystem = ViewportVirtualizationModuleLib.init({
		Settings = Settings.ViewportVirtualization,
		RunService = RunService,
		TweenService = TweenService,
		UserInputService = UserInputService,
		AnimationEngine = AnimationEngine,
		RootGui = Rayfield,
		warn = function(message)
			warn("Rayfield | ViewportVirtualization " .. tostring(message))
		end
	})
	if _G then
		_G.__RayfieldViewportVirtualization = ViewportVirtualizationSystem
	end

	-- Initialize Elements Module
	if ElementSyncSystem and ElementSyncSystem.destroy then
		ElementSyncSystem.destroy()
	end
	ElementSyncSystem = ElementSyncModuleLib.init({
		warn = function(message)
			warn("Rayfield | ElementSync " .. tostring(message))
		end
	})

	ElementsSystem = ElementsModuleLib.init({
		TweenService = TweenService,
		Animation = Animation,
		RunService = RunService,
		UserInputService = UserInputService,
		HttpService = HttpService,
		Main = Main,
		Topbar = Topbar,
		TabList = TabList,
		Elements = Elements,
		Rayfield = Rayfield,
		RayfieldLibrary = RayfieldLibrary,
		Icons = Icons,
		getIcon = getIcon,
		getAssetUri = getAssetUri,
		getSelectedTheme = function() return SelectedTheme end,
		rayfieldDestroyed = function() return rayfieldDestroyed end,
		getMinimised = function() return Minimised end,
		getSetting = getSetting,
		getInternalSetting = function(category, setting)
			return getSetting(category, setting)
		end,
		setInternalSetting = function(category, setting, value, persist)
			return setSettingValue(category, setting, value, persist)
		end,
		bindTheme = bindTheme,
		SaveConfiguration = SaveConfiguration,
		makeElementDetachable = makeElementDetachable,
		KeybindSequence = KeybindSequenceLib,
		keybindConnections = keybindConnections,
		getDebounce = function() return Debounce end,
		setDebounce = function(val) Debounce = val end,
		playUICue = function(cueName)
			return playUICueInternal(cueName)
		end,
		useMobileSizing = useMobileSizing,
		ElementSync = ElementSyncSystem,
		ViewportVirtualization = ViewportVirtualizationSystem,
		ResourceOwnership = OwnershipSystem,
		Settings = Settings
	})
	if favoritesRegistryUnsubscribe then
		pcall(favoritesRegistryUnsubscribe)
		favoritesRegistryUnsubscribe = nil
	end
	if ElementsSystem and type(ElementsSystem.subscribeControlRegistry) == "function" then
		favoritesRegistryUnsubscribe = ElementsSystem.subscribeControlRegistry(function(reason)
			if reason == "pin" or reason == "unpin" or reason == "set_pinned_ids" or reason == "control_removed" then
				refreshFavoritesSettingsPersistence()
			end
			if reason == "pin" and ExperienceState.favoritesTabWindow then
				ensureFavoritesTab(ExperienceState.favoritesTabWindow)
			end
			renderFavoritesTab()
		end)
	end

	TabSplitSystem = TabSplitModuleLib.init({
		UserInputService = UserInputService,
		RunService = RunService,
		TweenService = TweenService,
		Animation = Animation,
		HttpService = HttpService,
		Rayfield = Rayfield,
		Main = Main,
		Topbar = Topbar,
		TabList = TabList,
		Elements = Elements,
		getSelectedTheme = function() return SelectedTheme end,
		rayfieldDestroyed = function() return rayfieldDestroyed end,
		useMobileSizing = useMobileSizing,
		Notify = function(data)
			RayfieldLibrary:Notify(data)
		end,
		getBlockedState = function()
			return Debounce or searchOpen
		end,
		onLayoutDirty = function(scope, reason)
			markLayoutDirty(scope, reason)
		end,
		ViewportVirtualization = ViewportVirtualizationSystem,
		enabled = Settings.EnableTabSplit,
		holdDuration = Settings.TabSplitHoldDuration,
		allowSettingsSplit = Settings.AllowSettingsTabSplit,
		maxSplitTabs = Settings.MaxSplitTabs
	})
	TabSplitSystem.syncHidden(Hidden)
	TabSplitSystem.syncMinimized(Minimised)

	if LayoutPersistenceSystem and type(LayoutPersistenceSystem.flush) == "function" then
		LayoutPersistenceSystem.flush("window_recreate")
	end
	LayoutPersistenceSystem = LayoutPersistenceModuleLib.init({
		layoutKey = "__rayfield_layout",
		version = 1,
		getEnabled = function()
			return layoutSavingEnabled == true and CEnabled == true
		end,
		getDebounceMs = function()
			return layoutDebounceMs
		end,
		requestSave = function()
			return SaveConfiguration()
		end
	})
	LayoutPersistenceSystem.registerProvider("main", {
		order = 10,
		snapshot = function()
			if UIStateSystem and type(UIStateSystem.getLayoutSnapshot) == "function" then
				return UIStateSystem.getLayoutSnapshot()
			end
			return nil
		end,
		apply = function(section)
			if UIStateSystem and type(UIStateSystem.applyLayoutSnapshot) == "function" then
				UIStateSystem.applyLayoutSnapshot(section)
			end
		end
	})
	LayoutPersistenceSystem.registerProvider("split", {
		order = 20,
		snapshot = function()
			if TabSplitSystem and type(TabSplitSystem.getLayoutSnapshot) == "function" then
				return TabSplitSystem.getLayoutSnapshot()
			end
			return nil
		end,
		apply = function(section)
			if TabSplitSystem and type(TabSplitSystem.applyLayoutSnapshot) == "function" then
				TabSplitSystem.applyLayoutSnapshot(section)
			end
		end
	})
	LayoutPersistenceSystem.registerProvider("floating", {
		order = 30,
		snapshot = function()
			if DragSystem and type(DragSystem.getLayoutSnapshot) == "function" then
				return DragSystem.getLayoutSnapshot()
			end
			return nil
		end,
		apply = function(section)
			if DragSystem and type(DragSystem.applyLayoutSnapshot) == "function" then
				DragSystem.applyLayoutSnapshot(section)
			end
		end
	})

	if type(ConfigSystem.setLayoutHandlers) == "function" then
		ConfigSystem.setLayoutHandlers(
			function()
				if LayoutPersistenceSystem and type(LayoutPersistenceSystem.getLayoutSnapshot) == "function" then
					return LayoutPersistenceSystem.getLayoutSnapshot()
				end
				return nil
			end,
			function(layoutData)
				if LayoutPersistenceSystem and type(LayoutPersistenceSystem.applyLayoutSnapshot) == "function" then
					return LayoutPersistenceSystem.applyLayoutSnapshot(layoutData)
				end
				return false
			end,
			"__rayfield_layout"
		)
	end

	if DragSystem and type(DragSystem.setLayoutDirtyCallback) == "function" then
		DragSystem.setLayoutDirtyCallback(function(scope, reason)
			markLayoutDirty(scope, reason)
		end)
	end

	if TabSplitSystem and type(TabSplitSystem.setLayoutDirtyCallback) == "function" then
		TabSplitSystem.setLayoutDirtyCallback(function(scope, reason)
			markLayoutDirty(scope, reason)
		end)
	end

	cleanupLayoutConnections()
	if layoutSavingEnabled and CEnabled then
		table.insert(layoutConnections, Main:GetPropertyChangedSignal("Position"):Connect(function()
			markLayoutDirty("main", "position")
		end))
		table.insert(layoutConnections, Main:GetPropertyChangedSignal("Size"):Connect(function()
			if UIStateSystem
				and type(UIStateSystem.setExpandedSize) == "function"
				and type(UIStateSystem.getMinimised) == "function"
				and type(UIStateSystem.getHidden) == "function"
				and not UIStateSystem.getMinimised()
				and not UIStateSystem.getHidden() then
				UIStateSystem.setExpandedSize(Main.Size)
			end
			markLayoutDirty("main", "size")
		end))
	end

	-- Wrapper for Window:CreateTab
	function Window:CreateTab(Name, Image, Ext)
		local tab = ElementsSystem.CreateTab(Name, Image, Ext)
		FirstTab = ElementsSystem.getFirstTab()
		if TabSplitSystem and tab and tab.GetInternalRecord then
			local ok, tabRecord = pcall(function()
				return tab:GetInternalRecord()
			end)
			if ok and tabRecord then
				TabSplitSystem.registerTab(tabRecord)
			end
		end
		return tab
	end

	local function playStartupAnimation()
		Elements.Visible = true

		waitForStartup(1.1)
		Animation:Create(Main, TweenInfo.new(startupTweenDuration(0.7), Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 390, 0, 90)}):Play()
		waitForStartup(0.3)
		Animation:Create(LoadingFrame.Title, TweenInfo.new(startupTweenDuration(0.2), Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
		Animation:Create(LoadingFrame.Subtitle, TweenInfo.new(startupTweenDuration(0.2), Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
		Animation:Create(LoadingFrame.Version, TweenInfo.new(startupTweenDuration(0.2), Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
		waitForStartup(0.1)
		Animation:Create(Main, TweenInfo.new(startupTweenDuration(0.6), Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475)}):Play()
		Animation:Create(Main.Shadow.Image, TweenInfo.new(startupTweenDuration(0.5), Enum.EasingStyle.Exponential), {ImageTransparency = 0.6}):Play()

		local topbarDivider = Topbar:FindFirstChild("Divider")
		local topbarCornerRepair = Topbar:FindFirstChild("CornerRepair")
		local topbarTitle = Topbar:FindFirstChild("Title")
		local topbarSearch = Topbar:FindFirstChild("Search")
		local topbarSettings = Topbar:FindFirstChild("Settings")
		local topbarChangeSize = Topbar:FindFirstChild("ChangeSize")
		local topbarHide = Topbar:FindFirstChild("Hide")

		Topbar.BackgroundTransparency = 1
		if topbarDivider then
			topbarDivider.Size = UDim2.new(0, 0, 0, 1)
			topbarDivider.BackgroundColor3 = SelectedTheme.ElementStroke
		end
		if topbarCornerRepair then
			topbarCornerRepair.BackgroundTransparency = 1
		end
		if topbarTitle then
			topbarTitle.TextTransparency = 1
		end
		if topbarSearch then
			topbarSearch.ImageTransparency = 1
		end
		if topbarSettings then
			topbarSettings.ImageTransparency = 1
		end
		if topbarChangeSize then
			topbarChangeSize.ImageTransparency = 1
		end
		if topbarHide then
			topbarHide.ImageTransparency = 1
		end

		waitForStartup(0.5)
		Topbar.Visible = true
		TabList.Visible = true
		Animation:Create(Topbar, TweenInfo.new(startupTweenDuration(0.7), Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		if topbarCornerRepair then
			Animation:Create(topbarCornerRepair, TweenInfo.new(startupTweenDuration(0.7), Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		end
		waitForStartup(0.1)
		if topbarDivider then
			Animation:Create(topbarDivider, TweenInfo.new(startupTweenDuration(1), Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, 1)}):Play()
		end
		if topbarTitle then
			Animation:Create(topbarTitle, TweenInfo.new(startupTweenDuration(0.6), Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
		end
		waitForStartup(0.05)
		if topbarSearch then
			Animation:Create(topbarSearch, TweenInfo.new(startupTweenDuration(0.6), Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
		end
		waitForStartup(0.05)
		if topbarSettings then
			Animation:Create(topbarSettings, TweenInfo.new(startupTweenDuration(0.6), Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
			waitForStartup(0.05)
		end
		if topbarChangeSize then
			Animation:Create(topbarChangeSize, TweenInfo.new(startupTweenDuration(0.6), Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
			waitForStartup(0.05)
		end
		if topbarHide then
			Animation:Create(topbarHide, TweenInfo.new(startupTweenDuration(0.6), Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
		end
		waitForStartup(0.3)

		if dragBar and dragBarCosmetic then
			Animation:Create(dragBarCosmetic, TweenInfo.new(startupTweenDuration(0.6), Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
		end

		LoadingFrame.Visible = false
		Topbar.Visible = true
		TabList.Visible = true
		Elements.Visible = true
	end

	function Window.ModifyTheme(NewTheme)
		local success = pcall(ChangeTheme, NewTheme)
		if not success then
			RayfieldLibrary:Notify({Title = 'Unable to Change Theme', Content = 'We are unable find a theme on file.', Image = 4400704299})
		else
			applyGlassLayer()
			RayfieldLibrary:Notify({Title = 'Theme Changed', Content = 'Successfully changed theme to '..(typeof(NewTheme) == 'string' and NewTheme or 'Custom Theme')..'.', Image = 4483362748})
		end
	end

	local success, result = pcall(function()
		createSettings(Window)
	end)

	if not success then warn('Rayfield had an issue creating settings.') end

	local function restoreExperienceStateSafely()
		local okRestore, restoreErr = pcall(function()
			restoreExperienceStateFromSettings(Window)
		end)
		if not okRestore then
			warn("Rayfield | Failed to restore experience settings: " .. tostring(restoreErr))
		end
	end
	restoreExperienceStateSafely()
	task.delay(0.9, restoreExperienceStateSafely)

	local startupSuccess, startupResult = pcall(function()
		playStartupAnimation()
	end)
	if not startupSuccess then
		warn("Rayfield had an issue during startup animation: " .. tostring(startupResult))
		LoadingFrame.Visible = false
		Topbar.Visible = true
		TabList.Visible = true
		Elements.Visible = true
	end

	maybeNotifyLoaderFallback()

	task.delay(1.1, function()
		if not ExperienceState.onboardingRendered and not ExperienceState.onboardingSuppressed then
			RayfieldLibrary:ShowOnboarding(false)
		end
	end)

	return Window
end

local function setVisibility(visibility: boolean, notify: boolean?)
	VisibilityController.SetVisibility(visibility, notify)
end

local hideHotkeyConnection -- Has to be initialized here since the connection is made later in the script
local function destroyRuntime()
	AnimationEngine:SetUiSuppressed(true)
	detachPathEnabled = true
	activePerformanceProfile = {
		enabled = false,
		requestedMode = "normal",
		resolvedMode = "normal",
		aggressive = false,
		disableDetach = false,
		disableTabSplit = false,
		disableAnimations = false,
		appliedFields = {}
	}
	cleanupLayoutConnections()
	if LayoutPersistenceSystem and type(LayoutPersistenceSystem.flush) == "function" then
		pcall(LayoutPersistenceSystem.flush, "destroy")
	end
	-- Cleanup theme connections to prevent memory leaks on reload
	if ThemeSystem and ThemeSystem.cleanup then
		ThemeSystem.cleanup()
	end
	if TabSplitSystem and TabSplitSystem.destroy then
		TabSplitSystem.destroy()
		TabSplitSystem = nil
	end
	if favoritesRegistryUnsubscribe then
		pcall(favoritesRegistryUnsubscribe)
		favoritesRegistryUnsubscribe = nil
	end
	if OwnershipSystem and type(OwnershipSystem.cleanupSession) == "function" then
		pcall(OwnershipSystem.cleanupSession, {
			destroyInstances = false,
			clearAttributes = true,
			sweepRoot = false
		})
	end
	if UtilitiesSystem then
		UtilitiesSystem.destroy(hideHotkeyConnection)
	end
	if AnimationEngine and AnimationEngine.Destroy then
		AnimationEngine:Destroy()
	end
	if ElementSyncSystem and ElementSyncSystem.destroy then
		ElementSyncSystem.destroy()
		ElementSyncSystem = nil
	end
	if ViewportVirtualizationSystem and type(ViewportVirtualizationSystem.destroy) == "function" then
		pcall(ViewportVirtualizationSystem.destroy)
		ViewportVirtualizationSystem = nil
	end
	if _G then
		_G.__RayfieldViewportVirtualization = nil
		_G.__RayfieldOwnership = nil
	end
	cleanupGlassLayer()
	local audioState = ExperienceState.audioState
	if audioState then
		audioState.lastCueAt = {}
		audioState.sounds = {}
		if audioState.soundFolder and audioState.soundFolder.Parent then
			audioState.soundFolder:Destroy()
		end
		audioState.soundFolder = nil
	end
	if ExperienceState.onboardingOverlay and ExperienceState.onboardingOverlay.Root and ExperienceState.onboardingOverlay.Root.Parent then
		ExperienceState.onboardingOverlay.Root:Destroy()
	end
	ExperienceState.onboardingOverlay = nil
	ExperienceState.favoritesTab = nil
	ExperienceState.favoritesTabWindow = nil
	ExperienceState.onboardingRendered = false
	experienceSuppressPromoPrompts = false
	LayoutPersistenceSystem = nil

	-- Reset global runtime/cache flags so the next execution reloads a fresh UI tree.
	pcall(function()
		if getgenv then
			local env = getgenv()
			env.rayfieldCached = nil
		end
	end)
	_G.Rayfield = nil
	_G.RayfieldUI = nil
	_G.RayfieldAllInOneLoaded = nil
	if type(_G.RayfieldCache) == "table" then
		table.clear(_G.RayfieldCache)
	end
	if type(_G.__RayfieldApiModuleCache) == "table" then
		table.clear(_G.__RayfieldApiModuleCache)
	end
	OwnershipSystem = nil
end

local function isRuntimeDestroyed()
	if rayfieldDestroyed then
		return true
	end
	local ok, parent = pcall(function()
		return Rayfield.Parent
	end)
	return (not ok) or parent == nil
end

RuntimeApiLib.bind({
	RayfieldLibrary = RayfieldLibrary,
	setVisibility = setVisibility,
	getHidden = function()
		return Hidden
	end,
	destroyRuntime = destroyRuntime,
	isDestroyed = isRuntimeDestroyed
})

Topbar.ChangeSize.MouseButton1Click:Connect(function()
	if Debounce then return end
	if Minimised then
		Minimised = false
		Maximise()
	else
		Minimised = true
		Minimise()
	end
end)

Main.Search.Input:GetPropertyChangedSignal('Text'):Connect(function()
	if #Main.Search.Input.Text > 0 then
		if not Elements.UIPageLayout.CurrentPage:FindFirstChild('SearchTitle-fsefsefesfsefesfesfThanks') then 
			local searchTitle = Elements.Template.SectionTitle:Clone()
			searchTitle.Parent = Elements.UIPageLayout.CurrentPage
			searchTitle.Name = 'SearchTitle-fsefsefesfsefesfesfThanks'
			searchTitle.LayoutOrder = -100
			searchTitle.Title.Text = "Results from '"..Elements.UIPageLayout.CurrentPage.Name.."'"
			searchTitle.Visible = true
		end
	else
		local searchTitle = Elements.UIPageLayout.CurrentPage:FindFirstChild('SearchTitle-fsefsefesfsefesfesfThanks')

		if searchTitle then
			searchTitle:Destroy()
		end
	end

	for _, element in ipairs(Elements.UIPageLayout.CurrentPage:GetChildren()) do
		if element.ClassName ~= 'UIListLayout' and element.Name ~= 'Placeholder' and element.Name ~= 'SearchTitle-fsefsefesfsefesfesfThanks' then
			if element.Name == 'SectionTitle' then
				if #Main.Search.Input.Text == 0 then
					element.Visible = true
				else
					element.Visible = false
				end
			else
				if string.lower(element.Name):find(string.lower(Main.Search.Input.Text), 1, true) then
					element.Visible = true
				else
					element.Visible = false
				end
			end
		end
	end
end)

Main.Search.Input.FocusLost:Connect(function(enterPressed)
	if #Main.Search.Input.Text == 0 and searchOpen then
		task.wait(0.12)
		closeSearch()
	end
end)

Topbar.Search.MouseButton1Click:Connect(function()
	task.spawn(function()
		if searchOpen then
			closeSearch()
		else
			openSearch()
		end
	end)
end)

if Topbar:FindFirstChild('Settings') then
	Topbar.Settings.MouseButton1Click:Connect(function()
		task.spawn(function()
			for _, OtherTabButton in ipairs(TabList:GetChildren()) do
				if OtherTabButton.Name ~= "Template" and OtherTabButton.ClassName == "Frame" and OtherTabButton ~= TabButton and OtherTabButton.Name ~= "Placeholder" then
					Animation:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundColor3 = SelectedTheme.TabBackground}):Play()
					Animation:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextColor3 = SelectedTheme.TabTextColor}):Play()
					Animation:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageColor3 = SelectedTheme.TabTextColor}):Play()
					Animation:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
					Animation:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
					Animation:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
					Animation:Create(OtherTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
				end
			end

			local settingsPage = Elements:FindFirstChild("Rayfield Settings")
			if settingsPage then
				Elements.UIPageLayout:JumpTo(settingsPage)
			else
				RayfieldLibrary:Notify({
					Title = "Settings Tab",
					Content = "Settings tab is currently split. Dock it back to open from topbar.",
					Duration = 3
				})
			end
		end)
	end)

end


Topbar.Hide.MouseButton1Click:Connect(function()
	setVisibility(Hidden, not useMobileSizing)
end)

hideHotkeyConnection = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	local currentBinding = getSetting("General", "rayfieldOpen")
	local uiBindingSpec = resolveUiToggleKeybindSpec(currentBinding)
	if not uiBindingSpec then
		return
	end

	local matched = uiToggleKeybindMatcher:consume(input, uiBindingSpec, UserInputService, processed)
	if matched then
		if Debounce then return end
		if Hidden then
			Hidden = false
			Unhide()
		else
			Hidden = true
			Hide()
		end
	end
end)
if OwnershipSystem and type(OwnershipSystem.trackConnection) == "function" then
	pcall(OwnershipSystem.trackConnection, hideHotkeyConnection, "runtime:hotkeys")
end

if MPrompt then
	MPrompt.Interact.MouseButton1Click:Connect(function()
		if Debounce then return end
		if Hidden then
			Hidden = false
			Unhide()
		end
	end)
end

for _, TopbarButton in ipairs(Topbar:GetChildren()) do
	if TopbarButton.ClassName == "ImageButton" and TopbarButton.Name ~= 'Icon' then
		TopbarButton.MouseEnter:Connect(function()
			Animation:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
		end)

		TopbarButton.MouseLeave:Connect(function()
			Animation:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
		end)
	end
end


function RayfieldLibrary:LoadConfiguration()
	local config

	if debugX then
		warn('Loading Configuration')
	end

	if useStudio then
		config = [[{"Toggle1adwawd":true,"ColorPicker1awd":{"B":255,"G":255,"R":255},"Slider1dawd":100,"ColorPicfsefker1":{"B":255,"G":255,"R":255},"Slidefefsr1":80,"dawdawd":"","Input1":"hh","Keybind1":"B","Dropdown1":["Ocean"]}]]
	end

	if CEnabled then
		local notified
		local loaded

		local success, result = pcall(function()
			if useStudio and config then
				loaded = LoadConfiguration(config)
				return
			end

			if isfile then 
				if callSafely(isfile, ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension) then
					loaded = LoadConfiguration(callSafely(readfile, ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension))
				end
			else
				notified = true
				RayfieldLibrary:Notify({Title = "Rayfield Configurations", Content = "We couldn't enable Configuration Saving as you are not using software with filesystem support.", Image = 4384402990})
			end
		end)

		if success and loaded and not notified then
			RayfieldLibrary:Notify({Title = "Rayfield Configurations", Content = "The configuration file for this script has been loaded from a previous session.", Image = 4384403532})
		elseif not success and not notified then
			warn('Rayfield Configurations Error | '..tostring(result))
			RayfieldLibrary:Notify({Title = "Rayfield Configurations", Content = "We've encountered an issue loading your configuration correctly.\n\nCheck the Developer Console for more information.", Image = 4384402990})
		end
	end

	globalLoaded = true
end



if useStudio then
	-- run w/ studio
	-- Feel free to place your own script here to see how it'd work in Roblox Studio before running it on your execution software.


	--local Window = RayfieldLibrary:CreateWindow({
	--	Name = "Rayfield Example Window",
	--	LoadingTitle = "Rayfield Interface Suite",
	--	Theme = 'Default',
	--	Icon = 0,
	--	LoadingSubtitle = "by Sirius",
	--	ConfigurationSaving = {
	--		Enabled = true,
	--		FolderName = nil, -- Create a custom folder for your hub/game
	--		FileName = "Big Hub52"
	--	},
	--	Discord = {
	--		Enabled = false,
	--		Invite = "noinvitelink", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ABCD would be ABCD
	--		RememberJoins = true -- Set this to false to make them join the discord every time they load it up
	--	},
	--	KeySystem = false, -- Set this to true to use our key system
	--	KeySettings = {
	--		Title = "Untitled",
	--		Subtitle = "Key System",
	--		Note = "No method of obtaining the key is provided",
	--		FileName = "Key", -- It is recommended to use something unique as other scripts using Rayfield may overwrite your key file
	--		SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
	--		GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
	--		Key = {"Hello"} -- List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22")
	--	}
	--})

	--local Tab = Window:CreateTab("Tab Example", 'key-round') -- Title, Image
	--local Tab2 = Window:CreateTab("Tab Example 2", 4483362458) -- Title, Image

	--local Section = Tab2:CreateSection("Section")


	--local ColorPicker = Tab2:CreateColorPicker({
	--	Name = "Color Picker",
	--	Color = Color3.fromRGB(255,255,255),
	--	Flag = "ColorPicfsefker1", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	--	Callback = function(Value)
	--		-- The function that takes place every time the color picker is moved/changed
	--		-- The variable (Value) is a Color3fromRGB value based on which color is selected
	--	end
	--})

	--local Slider = Tab2:CreateSlider({
	--	Name = "Slider Example",
	--	Range = {0, 100},
	--	Increment = 10,
	--	Suffix = "Bananas",
	--	CurrentValue = 40,
	--	Flag = "Slidefefsr1", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	--	Callback = function(Value)
	--		-- The function that takes place when the slider changes
	--		-- The variable (Value) is a number which correlates to the value the slider is currently at
	--	end,
	--})

	--local Input = Tab2:CreateInput({
	--	Name = "Input Example",
	--	CurrentValue = '',
	--	PlaceholderText = "Input Placeholder",
	--	Flag = 'dawdawd',
	--	RemoveTextAfterFocusLost = false,
	--	Callback = function(Text)
	--		-- The function that takes place when the input is changed
	--		-- The variable (Text) is a string for the value in the text box
	--	end,
	--})


	----RayfieldLibrary:Notify({Title = "Rayfield Interface", Content = "Welcome to Rayfield. These - are the brand new notification design for Rayfield, with custom sizing and Rayfield calculated wait times.", Image = 4483362458})

	--local Section = Tab:CreateSection("Section Example")

	--local Button = Tab:CreateButton({
	--	Name = "Change Theme",
	--	Callback = function()
	--		-- The function that takes place when the button is pressed
	--		Window.ModifyTheme('DarkBlue')
	--	end,
	--})

	--local Toggle = Tab:CreateToggle({
	--	Name = "Toggle Example",
	--	CurrentValue = false,
	--	Flag = "Toggle1adwawd", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	--	Callback = function(Value)
	--		-- The function that takes place when the toggle is pressed
	--		-- The variable (Value) is a boolean on whether the toggle is true or false
	--	end,
	--})

	--local ColorPicker = Tab:CreateColorPicker({
	--	Name = "Color Picker",
	--	Color = Color3.fromRGB(255,255,255),
	--	Flag = "ColorPicker1awd", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	--	Callback = function(Value)
	--		-- The function that takes place every time the color picker is moved/changed
	--		-- The variable (Value) is a Color3fromRGB value based on which color is selected
	--	end
	--})

	--local Slider = Tab:CreateSlider({
	--	Name = "Slider Example",
	--	Range = {0, 100},
	--	Increment = 10,
	--	Suffix = "Bananas",
	--	CurrentValue = 40,
	--	Flag = "Slider1dawd", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	--	Callback = function(Value)
	--		-- The function that takes place when the slider changes
	--		-- The variable (Value) is a number which correlates to the value the slider is currently at
	--	end,
	--})

	--local Input = Tab:CreateInput({
	--	Name = "Input Example",
	--	CurrentValue = "Helo",
	--	PlaceholderText = "Adaptive Input",
	--	RemoveTextAfterFocusLost = false,
	--	Flag = 'Input1',
	--	Callback = function(Text)
	--		-- The function that takes place when the input is changed
	--		-- The variable (Text) is a string for the value in the text box
	--	end,
	--})

	--local thoptions = {}
	--for themename, theme in pairs(RayfieldLibrary.Theme) do
	--	table.insert(thoptions, themename)
	--end

	--local Dropdown = Tab:CreateDropdown({
	--	Name = "Theme",
	--	Options = thoptions,
	--	CurrentOption = {"Default"},
	--	MultipleOptions = false,
	--	Flag = "Dropdown1", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	--	Callback = function(Options)
	--		--Window.ModifyTheme(Options[1])
	--		-- The function that takes place when the selected option is changed
	--		-- The variable (Options) is a table of strings for the current selected options
	--	end,
	--})


	--Window.ModifyTheme({
	--	TextColor = Color3.fromRGB(50, 55, 60),
	--	Background = Color3.fromRGB(240, 245, 250),
	--	Topbar = Color3.fromRGB(215, 225, 235),
	--	Shadow = Color3.fromRGB(200, 210, 220),

	--	NotificationBackground = Color3.fromRGB(210, 220, 230),
	--	NotificationActionsBackground = Color3.fromRGB(225, 230, 240),

	--	TabBackground = Color3.fromRGB(200, 210, 220),
	--	TabStroke = Color3.fromRGB(180, 190, 200),
	--	TabBackgroundSelected = Color3.fromRGB(175, 185, 200),
	--	TabTextColor = Color3.fromRGB(50, 55, 60),
	--	SelectedTabTextColor = Color3.fromRGB(30, 35, 40),

	--	ElementBackground = Color3.fromRGB(210, 220, 230),
	--	ElementBackgroundHover = Color3.fromRGB(220, 230, 240),
	--	SecondaryElementBackground = Color3.fromRGB(200, 210, 220),
	--	ElementStroke = Color3.fromRGB(190, 200, 210),
	--	SecondaryElementStroke = Color3.fromRGB(180, 190, 200),

	--	SliderBackground = Color3.fromRGB(200, 220, 235),  -- Lighter shade
	--	SliderProgress = Color3.fromRGB(70, 130, 180),
	--	SliderStroke = Color3.fromRGB(150, 180, 220),

	--	ToggleBackground = Color3.fromRGB(210, 220, 230),
	--	ToggleEnabled = Color3.fromRGB(70, 160, 210),
	--	ToggleDisabled = Color3.fromRGB(180, 180, 180),
	--	ToggleEnabledStroke = Color3.fromRGB(60, 150, 200),
	--	ToggleDisabledStroke = Color3.fromRGB(140, 140, 140),
	--	ToggleEnabledOuterStroke = Color3.fromRGB(100, 120, 140),
	--	ToggleDisabledOuterStroke = Color3.fromRGB(120, 120, 130),

	--	DropdownSelected = Color3.fromRGB(220, 230, 240),
	--	DropdownUnselected = Color3.fromRGB(200, 210, 220),

	--	InputBackground = Color3.fromRGB(220, 230, 240),
	--	InputStroke = Color3.fromRGB(180, 190, 200),
	--	PlaceholderColor = Color3.fromRGB(150, 150, 150)
	--})

	--local Keybind = Tab:CreateKeybind({
	--	Name = "Keybind Example",
	--	CurrentKeybind = "Q",
	--	HoldToInteract = false,
	--	Flag = "Keybind1", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	--	Callback = function(Keybind)
	--		-- The function that takes place when the keybind is pressed
	--		-- The variable (Keybind) is a boolean for whether the keybind is being held or not (HoldToInteract needs to be true)
	--	end,
	--})

	--local Label = Tab:CreateLabel("Label Example")

	--local Label2 = Tab:CreateLabel("Warning", 4483362458, Color3.fromRGB(255, 159, 49),  true)

	--local Paragraph = Tab:CreateParagraph({Title = "Paragraph Example", Content = "Paragraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph ExampleParagraph Example"})
end

if CEnabled and Main:FindFirstChild('Notice') then
	Main.Notice.BackgroundTransparency = 1
	Main.Notice.Title.TextTransparency = 1
	Main.Notice.Size = UDim2.new(0, 0, 0, 0)
	Main.Notice.Position = UDim2.new(0.5, 0, 0, -100)
	Main.Notice.Visible = true


	Animation:Create(Main.Notice, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 280, 0, 35), Position = UDim2.new(0.5, 0, 0, -50), BackgroundTransparency = 0.5}):Play()
	Animation:Create(Main.Notice.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0.1}):Play()
end
-- AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA why :(
--if not useStudio then
--	task.spawn(loadWithTimeout, "https://raw.githubusercontent.com/SiriusSoftwareLtd/Sirius/refs/heads/request/boost.lua")
--end

task.delay(4, function()
	RayfieldLibrary.LoadConfiguration()
	if Main:FindFirstChild('Notice') and Main.Notice.Visible then
		Animation:Create(Main.Notice, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 100, 0, 25), Position = UDim2.new(0.5, 0, 0, -100), BackgroundTransparency = 1}):Play()
		Animation:Create(Main.Notice.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()

		task.wait(0.5)
		Main.Notice.Visible = false
	end
end)

return RayfieldLibrary
