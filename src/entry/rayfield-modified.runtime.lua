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
function getService(name)
	return game:GetService(name)
end

-- Compatibility wrapper for loadstring (some executors use different names)
local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load). Your executor may not support dynamic code loading.")
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

-- Load external modules through shared API loader
local MODULE_ROOT_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
if type(LegacyRuntimeConfig.runtimeRootUrl) == "string" and LegacyRuntimeConfig.runtimeRootUrl ~= "" then
	MODULE_ROOT_URL = LegacyRuntimeConfig.runtimeRootUrl
end
if type(_G) == "table" then
	_G.__RAYFIELD_RUNTIME_ROOT_URL = MODULE_ROOT_URL
end

function loadBootstrapService(path, validatorFn)
	local fullUrl = MODULE_ROOT_URL .. tostring(path)
	local okFetch, sourceOrErr = pcall(game.HttpGet, game, fullUrl)
	if not okFetch then
		warn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_FETCH] " .. tostring(path) .. " | " .. tostring(sourceOrErr))
		return nil
	end
	if type(sourceOrErr) ~= "string" or sourceOrErr == "" then
		warn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_EMPTY] " .. tostring(path))
		return nil
	end
	local chunk, compileErr = compileString(sourceOrErr)
	if not chunk then
		warn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_COMPILE] " .. tostring(path) .. " | " .. tostring(compileErr))
		return nil
	end
	local okExecute, moduleOrErr = pcall(chunk)
	if not okExecute then
		warn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_EXECUTE] " .. tostring(path) .. " | " .. tostring(moduleOrErr))
		return nil
	end
	if type(validatorFn) == "function" and not validatorFn(moduleOrErr) then
		warn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_CONTRACT] " .. tostring(path))
		return nil
	end
	return moduleOrErr
end

local RuntimeBootstrapperLib = loadBootstrapService("src/core/runtime/bootstrapper.lua", function(moduleValue)
	return type(moduleValue) == "table" and type(moduleValue.create) == "function"
end)
local RuntimeBootstrap = nil
if type(RuntimeBootstrapperLib) == "table" and type(RuntimeBootstrapperLib.create) == "function" then
	local okBootstrap, bootstrapOrErr = pcall(RuntimeBootstrapperLib.create, {
		compileString = compileString,
		httpGet = function(url)
			return game:HttpGet(url)
		end,
		moduleRootUrl = MODULE_ROOT_URL,
		globalEnv = _G,
		runtimeConfig = LegacyRuntimeConfig,
		taskLib = task,
		clock = os.clock,
		warn = warn
	})
	if okBootstrap and type(bootstrapOrErr) == "table" then
		RuntimeBootstrap = bootstrapOrErr
	else
		warn("Rayfield Mod: [W_BOOTSTRAPPER] Failed to initialize runtime bootstrapper.")
	end
end

local ExecutionPolicyServiceLib = RuntimeBootstrap and RuntimeBootstrap.ExecutionPolicyServiceLib
local HttpLoaderServiceLib = RuntimeBootstrap and RuntimeBootstrap.HttpLoaderServiceLib
local AnalyticsReporterServiceLib = RuntimeBootstrap and RuntimeBootstrap.AnalyticsReporterServiceLib
local AnalyticsProviderServiceLib = RuntimeBootstrap and RuntimeBootstrap.AnalyticsProviderServiceLib
local AnalyticsManagerServiceLib = RuntimeBootstrap and RuntimeBootstrap.AnalyticsManagerServiceLib
local RuntimeLoaderHelpersServiceLib = RuntimeBootstrap and RuntimeBootstrap.RuntimeLoaderHelpersServiceLib
local LoaderHelpersFallbackServiceLib = RuntimeBootstrap and RuntimeBootstrap.LoaderHelpersFallbackServiceLib
local CompatibilityInitServiceLib = RuntimeBootstrap and RuntimeBootstrap.CompatibilityInitServiceLib

if type(ExecutionPolicyServiceLib) ~= "table" or type(ExecutionPolicyServiceLib.ensure) ~= "function" then
	ExecutionPolicyServiceLib = loadBootstrapService("src/services/execution-policy.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.ensure) == "function"
	end)
end
if type(HttpLoaderServiceLib) ~= "table" or type(HttpLoaderServiceLib.create) ~= "function" then
	HttpLoaderServiceLib = loadBootstrapService("src/services/http-loader.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
end
if type(AnalyticsReporterServiceLib) ~= "table" or type(AnalyticsReporterServiceLib.create) ~= "function" then
	AnalyticsReporterServiceLib = loadBootstrapService("src/services/analytics-reporter.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
end
if type(AnalyticsProviderServiceLib) ~= "table" or type(AnalyticsProviderServiceLib.create) ~= "function" then
	AnalyticsProviderServiceLib = loadBootstrapService("src/services/analytics/analytics-provider.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
end
if type(AnalyticsManagerServiceLib) ~= "table" or type(AnalyticsManagerServiceLib.create) ~= "function" then
	AnalyticsManagerServiceLib = loadBootstrapService("src/services/analytics-manager.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
end
if type(RuntimeLoaderHelpersServiceLib) ~= "table" or type(RuntimeLoaderHelpersServiceLib.create) ~= "function" then
	RuntimeLoaderHelpersServiceLib = loadBootstrapService("src/services/runtime-loader-helpers.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
end
if type(LoaderHelpersFallbackServiceLib) ~= "table" or type(LoaderHelpersFallbackServiceLib.createFallback) ~= "function" then
	LoaderHelpersFallbackServiceLib = loadBootstrapService("src/services/loader-helpers.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.createFallback) == "function"
	end)
end
if type(CompatibilityInitServiceLib) ~= "table" or type(CompatibilityInitServiceLib.create) ~= "function" then
	CompatibilityInitServiceLib = loadBootstrapService("src/services/compatibility-init.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
end

local ExecPolicy = RuntimeBootstrap and RuntimeBootstrap.ExecPolicy or nil
if type(ExecPolicy) ~= "table" then
	if type(ExecutionPolicyServiceLib) == "table" and type(ExecutionPolicyServiceLib.ensure) == "function" then
		ExecPolicy = ExecutionPolicyServiceLib.ensure(_G)
	else
		warn("Rayfield Mod: [W_EXEC_POLICY] Using fallback execution policy.")
		ExecPolicy = {
			decideExecutionMode = function()
				return {
					mode = "soft",
					cancelOnTimeout = false,
					reason = "fallback"
				}
			end,
			markTimeout = function()
				return 0
			end,
			markSuccess = function()
				return
			end,
			getState = function()
				return {}
			end
		}
	end
end

local HttpLoaderService = RuntimeBootstrap and RuntimeBootstrap.HttpLoaderService or nil
if type(HttpLoaderService) ~= "table" and type(HttpLoaderServiceLib) == "table" and type(HttpLoaderServiceLib.create) == "function" then
	HttpLoaderService = HttpLoaderServiceLib.create({
		compileString = compileString,
		execPolicy = ExecPolicy,
		httpGet = function(url)
			return game:HttpGet(url)
		end,
		warn = warn,
		taskLib = task,
		clock = os.clock,
		runtimeConfig = LegacyRuntimeConfig
	})
end

function loadWithTimeout(url, timeout)
	if RuntimeBootstrap and type(RuntimeBootstrap.loadWithTimeout) == "function" then
		return RuntimeBootstrap.loadWithTimeout(url, timeout)
	end
	if type(HttpLoaderService) == "table" and type(HttpLoaderService.loadWithTimeout) == "function" then
		return HttpLoaderService.loadWithTimeout(url, timeout)
	end
	local okFetch, sourceOrErr = pcall(game.HttpGet, game, tostring(url))
	if not okFetch or type(sourceOrErr) ~= "string" or sourceOrErr == "" then
		warn("Rayfield Mod: [W_HTTP_LOADER_FALLBACK] " .. tostring(sourceOrErr))
		return nil
	end
	local chunk, compileErr = compileString(sourceOrErr)
	if not chunk then
		warn("Rayfield Mod: [W_HTTP_LOADER_FALLBACK] " .. tostring(compileErr))
		return nil
	end
	local okRun, runResult = pcall(chunk)
	if not okRun then
		warn("Rayfield Mod: [W_HTTP_LOADER_FALLBACK] " .. tostring(runResult))
		return nil
	end
	return runResult
end

requestsDisabled = true --getgenv and getgenv().DISABLE_RAYFIELD_REQUESTS
InterfaceBuild = '3K3W'
Release = "Build 1.68"
RayfieldFolder = "Rayfield"
ConfigurationFolder = RayfieldFolder.."/Configurations"
ConfigurationExtension = ".rfld"
settingsTable = {
	General = {
		-- if needs be in order just make getSetting(name)
		rayfieldOpen = {Type = 'bind', Value = 'K', Name = 'Rayfield Keybind'},
		-- buildwarnings
		-- rayfieldprompts

	},
	System = {
		usageAnalytics = {Type = 'toggle', Value = true, Name = 'Anonymised Analytics'},
	},
	Macros = {
		items = {Type = "hidden", Value = {}, Name = "Recorded Macros"}
	},
	Automation = {
		rules = {Type = "hidden", Value = {}, Name = "Automation Rules"}
	}
}

HttpService = getService('HttpService')
RunService = getService('RunService')

-- Environment Check
useStudio = RunService:IsStudio() or false

prompt = useStudio and require(script.Parent.prompt) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Sirius/refs/heads/request/prompt.lua')
requestFunc = (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request) or http_request or request

-- Validate prompt loaded correctly
if not prompt and not useStudio then
	warn("Failed to load prompt library, using fallback")
	prompt = {
		create = function() end -- No-op fallback
	}
end


-- The function below provides a safe alternative for calling error-prone functions
-- Especially useful for filesystem function (writefile, makefolder, etc.)
function callSafely(func, ...)
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
function ensureFolder(folderPath)
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

sendReport = function(ev_n, sc_n) warn("Failed to load report function") end
if type(AnalyticsManagerServiceLib) == "table" and type(AnalyticsManagerServiceLib.create) == "function" then
	local analyticsManager = AnalyticsManagerServiceLib.create({
		runtimeBootstrap = RuntimeBootstrap,
		analyticsProviderServiceLib = AnalyticsProviderServiceLib,
		analyticsReporterServiceLib = AnalyticsReporterServiceLib,
		requestsDisabled = requestsDisabled,
		useStudio = useStudio,
		debug = debugX == true,
		release = Release,
		interfaceBuild = InterfaceBuild,
		scriptName = "Rayfield",
		loadWithTimeout = loadWithTimeout,
		warn = warn,
		print = print
	})
	if type(analyticsManager) == "table" and type(analyticsManager.sendReport) == "function" then
		sendReport = analyticsManager.sendReport
	end
end

promptUser = 2

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

RayfieldLibrary = {
	Flags = {},
	Theme = {}
}

ApiClient = compileString(game:HttpGet(MODULE_ROOT_URL .. "src/api/client.lua"))()
if type(ApiClient) == "table" and type(ApiClient.configureRuntime) == "function" then
	pcall(ApiClient.configureRuntime, LegacyRuntimeConfig)
end

function getScriptRef()
	local scriptRef = nil
	pcall(function()
		scriptRef = script
	end)
	return scriptRef
end

local LoaderHelpers = nil
if type(RuntimeLoaderHelpersServiceLib) == "table" and type(RuntimeLoaderHelpersServiceLib.create) == "function" then
	local okHelpers, helpersOrErr = pcall(RuntimeLoaderHelpersServiceLib.create, {
		rootUrl = MODULE_ROOT_URL,
		apiClient = ApiClient,
		useStudio = useStudio,
		getScriptRef = getScriptRef,
		warn = warn,
		globalEnv = _G
	})
	if okHelpers and type(helpersOrErr) == "table" then
		LoaderHelpers = helpersOrErr
	else
		warn("Rayfield Mod: [W_LOADER_HELPERS] Failed to initialize runtime loader helpers: " .. tostring(helpersOrErr))
	end
end

if type(LoaderHelpers) ~= "table" then
	if type(LoaderHelpersFallbackServiceLib) == "table"
		and type(LoaderHelpersFallbackServiceLib.createFallback) == "function" then
		local okFallback, fallbackOrErr = pcall(LoaderHelpersFallbackServiceLib.createFallback, {
			rootUrl = MODULE_ROOT_URL,
			apiClient = ApiClient,
			useStudio = useStudio,
			getScriptRef = getScriptRef,
			warn = warn,
			globalEnv = _G
		})
		if okFallback and type(fallbackOrErr) == "table" then
			LoaderHelpers = fallbackOrErr
		else
			warn("Rayfield Mod: [W_LOADER_HELPERS] Failed to initialize loader helpers fallback: " .. tostring(fallbackOrErr))
		end
	end
end

if type(LoaderHelpers) ~= "table" then
	error("Rayfield Mod: [E_LOADER_HELPERS] Failed to initialize loader helpers.")
end

local compatibilityInit = nil
if type(CompatibilityInitServiceLib) == "table" and type(CompatibilityInitServiceLib.create) == "function" then
	local okCompatibilityInit, compatibilityInitOrErr = pcall(CompatibilityInitServiceLib.create, {
		loaderHelpers = LoaderHelpers,
		apiClient = ApiClient,
		moduleRootUrl = MODULE_ROOT_URL,
		compileString = compileString,
		useStudio = useStudio,
		warn = warn,
		globalEnv = _G,
		runtimeConfig = type(ApiClient) == "table"
			and type(ApiClient.getRuntimeConfig) == "function"
			and ApiClient.getRuntimeConfig()
			or LegacyRuntimeConfig
	})
	if okCompatibilityInit and type(compatibilityInitOrErr) == "table" then
		compatibilityInit = compatibilityInitOrErr
	else
		warn("Rayfield Mod: [W_COMPAT_INIT] Failed to initialize compatibility bootstrap: " .. tostring(compatibilityInitOrErr))
	end
end

if type(compatibilityInit) ~= "table" then
	error("Rayfield Mod: [E_BOOTSTRAP_COMPAT_INIT] Failed to initialize compatibility bootstrap service.")
end

Compatibility = compatibilityInit.Compatibility
local WidgetBootstrap = compatibilityInit.WidgetBootstrap
local ApiLoader = compatibilityInit.ApiLoader

if type(compatibilityInit.getService) == "function" then
	getService = compatibilityInit.getService
end
if type(compatibilityInit.compileString) == "function" then
	compileString = compatibilityInit.compileString
end
if type(ApiLoader) ~= "table" or type(ApiLoader.load) ~= "function" then
	error("Rayfield Mod: [E_BOOTSTRAP_LOADER] Invalid API loader contract")
end
if type(WidgetBootstrap) ~= "table" or type(WidgetBootstrap.bootstrapWidget) ~= "function" then
	error("Rayfield Mod: [E_BOOTSTRAP_WIDGETS] Invalid widget bootstrap contract")
end

function requireModule(moduleName, hint)
	return LoaderHelpers.requireModule(moduleName, hint)
end

loaderDiagnostics = type(LoaderHelpers.getDiagnostics) == "function" and LoaderHelpers.getDiagnostics() or nil

function optionalModule(moduleName, fallbackModule, hint)
	return LoaderHelpers.optionalModule(moduleName, fallbackModule, hint)
end

function optionalModuleWithContract(moduleName, validatorFn, hint)
	return LoaderHelpers.optionalModuleWithContract(moduleName, validatorFn, hint)
end

function maybeNotifyLoaderFallback()
	if type(LoaderHelpers.maybeNotifyFallback) ~= "function" then
		return
	end
	LoaderHelpers.maybeNotifyFallback(function(message)
		if type(RayfieldLibrary.Notify) == "function" then
			RayfieldLibrary:Notify({
				Title = "Rayfield Loader",
				Content = message,
				Duration = 8
			})
			return
		end
		warn("Rayfield Mod: [W_OPTIONAL_MODULE] " .. tostring(message))
	end)
end

local RuntimeFallbackModulesLib = requireModule("runtimeFallbackModules")
local FallbackElementSyncModule = RuntimeFallbackModulesLib.FallbackElementSyncModule
local FallbackOwnershipTrackerModule = RuntimeFallbackModulesLib.FallbackOwnershipTrackerModule
local FallbackDragModule = RuntimeFallbackModulesLib.FallbackDragModule
local FallbackTabSplitModule = RuntimeFallbackModulesLib.FallbackTabSplitModule
local FallbackLayoutPersistenceModule = RuntimeFallbackModulesLib.FallbackLayoutPersistenceModule
local FallbackViewportVirtualizationModule = RuntimeFallbackModulesLib.FallbackViewportVirtualizationModule

local RuntimeModuleRegistryLoaderLib = requireModule("runtimeModuleRegistryLoader")
local RuntimeModules = RuntimeModuleRegistryLoaderLib.load({
	requireModule = requireModule,
	optionalModule = optionalModule,
	fallbacks = {
		FallbackElementSyncModule = FallbackElementSyncModule,
		FallbackOwnershipTrackerModule = FallbackOwnershipTrackerModule,
		FallbackDragModule = FallbackDragModule,
		FallbackTabSplitModule = FallbackTabSplitModule,
		FallbackLayoutPersistenceModule = FallbackLayoutPersistenceModule,
		FallbackViewportVirtualizationModule = FallbackViewportVirtualizationModule
	}
})

ThemeModule = RuntimeModules.ThemeModule
ThemePresetsModuleLib = RuntimeModules.ThemePresetsModuleLib
ThemeDefaultThemesModuleLib = RuntimeModules.ThemeDefaultThemesModuleLib
UtilitiesModuleLib = RuntimeModules.UtilitiesModuleLib
SettingsModuleLib = RuntimeModules.SettingsModuleLib
SettingsStoreModuleLib = RuntimeModules.SettingsStoreModuleLib
SettingsPersistenceModuleLib = RuntimeModules.SettingsPersistenceModuleLib
SettingsUIModuleLib = RuntimeModules.SettingsUIModuleLib
SettingsShareCodeModuleLib = RuntimeModules.SettingsShareCodeModuleLib
OwnershipTrackerModuleLib = RuntimeModules.OwnershipTrackerModuleLib
ElementSyncModuleLib = RuntimeModules.ElementSyncModuleLib
KeybindSequenceLib = RuntimeModules.KeybindSequenceLib
DragModuleLib = RuntimeModules.DragModuleLib
UIStateModuleLib = RuntimeModules.UIStateModuleLib
UIStateNotificationManagerLib = RuntimeModules.UIStateNotificationManagerLib
UIStateSearchEngineLib = RuntimeModules.UIStateSearchEngineLib
UIStateWindowManagerLib = RuntimeModules.UIStateWindowManagerLib
ElementsModuleLib = RuntimeModules.ElementsModuleLib
ConfigModuleLib = RuntimeModules.ConfigModuleLib
ConfigStorageAdapterModuleLib = RuntimeModules.ConfigStorageAdapterModuleLib
LayoutPersistenceModuleLib = RuntimeModules.LayoutPersistenceModuleLib
ViewportVirtualizationModuleLib = RuntimeModules.ViewportVirtualizationModuleLib
VirtualizationEngineModuleLib = RuntimeModules.VirtualizationEngineModuleLib
VirtualHostManagerModuleLib = RuntimeModules.VirtualHostManagerModuleLib
TabSplitModuleLib = RuntimeModules.TabSplitModuleLib
AnimationEngineLib = RuntimeModules.AnimationEngineLib
AnimationPublicLib = RuntimeModules.AnimationPublicLib
AnimationSequenceLib = RuntimeModules.AnimationSequenceLib
AnimationUILib = RuntimeModules.AnimationUILib
AnimationTextLib = RuntimeModules.AnimationTextLib
AnimationCleanupLib = RuntimeModules.AnimationCleanupLib
AnimationConstantsLib = RuntimeModules.AnimationConstantsLib
AnimationSchedulerLib = RuntimeModules.AnimationSchedulerLib
MainShellModuleLib = RuntimeModules.MainShellModuleLib
VisibilityControllerLib = RuntimeModules.VisibilityControllerLib
ExperienceBindingsLib = RuntimeModules.ExperienceBindingsLib
RuntimeBindingsUXLib = RuntimeModules.RuntimeBindingsUXLib
RuntimeBindingsAudioLib = RuntimeModules.RuntimeBindingsAudioLib
RuntimeBindingsThemeLib = RuntimeModules.RuntimeBindingsThemeLib
RuntimeBindingsFavoritesLib = RuntimeModules.RuntimeBindingsFavoritesLib
RuntimeBindingsPersistenceLib = RuntimeModules.RuntimeBindingsPersistenceLib
RuntimeBindingsDiagnosticsLib = RuntimeModules.RuntimeBindingsDiagnosticsLib
RuntimeBindingsAutomationLib = RuntimeModules.RuntimeBindingsAutomationLib
RuntimeBindingsDiscoveryLib = RuntimeModules.RuntimeBindingsDiscoveryLib
RuntimeBindingsAIAssistantLib = RuntimeModules.RuntimeBindingsAIAssistantLib
RuntimeBindingsCommunicationLib = RuntimeModules.RuntimeBindingsCommunicationLib
RuntimeBindingsLocalizationLib = RuntimeModules.RuntimeBindingsLocalizationLib
RuntimeBindingsUIEventsLib = RuntimeModules.RuntimeBindingsUIEventsLib
RuntimeBindingsMovementEventsLib = RuntimeModules.RuntimeBindingsMovementEventsLib
RuntimeBindingsCombatEventsLib = RuntimeModules.RuntimeBindingsCombatEventsLib
WorkspaceServiceLib = RuntimeModules.WorkspaceServiceLib
CommandPaletteServiceLib = RuntimeModules.CommandPaletteServiceLib
CommandPaletteSearchAlgorithmsLib = RuntimeModules.CommandPaletteSearchAlgorithmsLib
SmartSearchServiceLib = RuntimeModules.SmartSearchServiceLib
MultiInstanceBridgeServiceLib = RuntimeModules.MultiInstanceBridgeServiceLib
AutomationEngineServiceLib = RuntimeModules.AutomationEngineServiceLib
UsageAnalyticsServiceLib = RuntimeModules.UsageAnalyticsServiceLib
MacroRecorderServiceLib = RuntimeModules.MacroRecorderServiceLib
DevExperienceServiceLib = RuntimeModules.DevExperienceServiceLib
LocalizationServiceLib = RuntimeModules.LocalizationServiceLib
UIStringRegistryLib = RuntimeModules.UIStringRegistryLib
ShareCodeServiceLib = RuntimeModules.ShareCodeServiceLib
EntryDiscordInviteServiceLib = RuntimeModules.EntryDiscordInviteServiceLib
EntryKeySystemServiceLib = RuntimeModules.EntryKeySystemServiceLib
RuntimeModuleLoaderLib = RuntimeModules.RuntimeModuleLoaderLib
PerformanceHUDServiceLib = RuntimeModules.PerformanceHUDServiceLib
RuntimeApiLib = RuntimeModules.RuntimeApiLib
RuntimeModuleLoader = nil
if type(RuntimeModuleLoaderLib) == "table" and type(RuntimeModuleLoaderLib.create) == "function" then
	local okModuleLoader, loaderOrErr = pcall(RuntimeModuleLoaderLib.create, {
		optionalModuleWithContract = optionalModuleWithContract
	})
	if okModuleLoader and type(loaderOrErr) == "table" then
		RuntimeModuleLoader = loaderOrErr
	else
		warn("Rayfield Mod: [W_RUNTIME_MODULE_LOADER] Failed to initialize runtime module loader: " .. tostring(loaderOrErr))
	end
end
if type(RuntimeModuleLoader) ~= "table" then
	RuntimeModuleLoader = {
		getLoaded = function()
			return nil
		end
	}
end

function resolveRuntimeModule(resolverName)
	if type(RuntimeModuleLoader[resolverName]) == "function" then
		return RuntimeModuleLoader[resolverName]()
	end
	return nil
end

function getLoadedRuntimeModule(moduleKey)
	if type(RuntimeModuleLoader.getLoaded) == "function" then
		return RuntimeModuleLoader.getLoaded(moduleKey)
	end
	return nil
end

function resolveDataGridFactoryModule()
	return resolveRuntimeModule("resolveDataGridFactoryModule")
end

function resolveChartFactoryModule()
	return resolveRuntimeModule("resolveChartFactoryModule")
end

function resolveButtonFactoryModule()
	return resolveRuntimeModule("resolveButtonFactoryModule")
end

function resolveInputFactoryModule()
	return resolveRuntimeModule("resolveInputFactoryModule")
end

function resolveDropdownFactoryModule()
	return resolveRuntimeModule("resolveDropdownFactoryModule")
end

function resolveKeybindFactoryModule()
	return resolveRuntimeModule("resolveKeybindFactoryModule")
end

function resolveToggleFactoryModule()
	return resolveRuntimeModule("resolveToggleFactoryModule")
end

function resolveSliderFactoryModule()
	return resolveRuntimeModule("resolveSliderFactoryModule")
end

function resolveTabManagerModule()
	return resolveRuntimeModule("resolveTabManagerModule")
end

function resolveHoverProviderModule()
	return resolveRuntimeModule("resolveHoverProviderModule")
end

function resolveTooltipEngineModule()
	return resolveRuntimeModule("resolveTooltipEngineModule")
end

function resolveWidgetAPIInjectorModule()
	return resolveRuntimeModule("resolveWidgetAPIInjectorModule")
end

function resolveMathUtilsModule()
	return resolveRuntimeModule("resolveMathUtilsModule")
end

function resolveResourceGuardModule()
	return resolveRuntimeModule("resolveResourceGuardModule")
end

function resolveSectionFactoryModule()
	return resolveRuntimeModule("resolveSectionFactoryModule")
end

function resolveControlRegistryModule()
	return resolveRuntimeModule("resolveControlRegistryModule")
end

function resolveLoggingProviderModule()
	return resolveRuntimeModule("resolveLoggingProviderModule")
end

function resolveTooltipProviderModule()
	return resolveRuntimeModule("resolveTooltipProviderModule")
end

function resolveGridBuilderModule()
	return resolveRuntimeModule("resolveGridBuilderModule")
end

function resolveChartBuilderModule()
	return resolveRuntimeModule("resolveChartBuilderModule")
end

function resolveRangeBarsFactoryModule()
	return resolveRuntimeModule("resolveRangeBarsFactoryModule")
end

function resolveFeedbackWidgetsFactoryModule()
	return resolveRuntimeModule("resolveFeedbackWidgetsFactoryModule")
end

function resolveComponentWidgetsFactoryModule()
	return resolveRuntimeModule("resolveComponentWidgetsFactoryModule")
end

-- Services
UserInputService = getService("UserInputService")
TweenService = getService("TweenService")
Players = getService("Players")
CoreGui = getService("CoreGui")

AnimationEngine = AnimationEngineLib.new({
	TweenService = TweenService,
	RunService = RunService,
	Cleanup = AnimationSchedulerLib or AnimationCleanupLib,
	Constants = AnimationConstantsLib,
	mode = "raw"
})
Animation = AnimationEngine
RayfieldAnimate = AnimationPublicLib.bindToRayfield(RayfieldLibrary, AnimationEngine, {
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

buildAttempts = 0
correctBuild = false
local warned
local globalLoaded
rayfieldDestroyed = false -- True when RayfieldLibrary:Destroy() is called

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

rayfieldContainer = nil
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


minSize = Vector2.new(1024, 768)
local useMobileSizing
useMobilePrompt = false

if Rayfield.AbsoluteSize.X < minSize.X and Rayfield.AbsoluteSize.Y < minSize.Y then
	useMobileSizing = true
end

if UserInputService.TouchEnabled then
	useMobilePrompt = true
end


-- Object Variables

Main = Rayfield.Main
if not Main then
	error("Rayfield GUI structure error: Main container not found. The GUI asset may be corrupted or incompatible.")
end

MPrompt = Rayfield:FindFirstChild('Prompt')
Topbar = Main.Topbar
Elements = Main.Elements
LoadingFrame = Main.LoadingFrame
TabList = Main.TabList

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

dragBar = Rayfield:FindFirstChild('Drag')
dragInteract = dragBar and dragBar.Interact or nil
dragBarCosmetic = dragBar and dragBar.Drag or nil

dragOffset = 255
dragOffsetMobile = 150

Rayfield.DisplayOrder = 100
LoadingFrame.Version.Text = Release

-- Thanks to Latte Softworks for the Lucide integration for Roblox
Icons = useStudio and require(script.Parent.icons) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua')

-- Variables
CFileName = nil
CEnabled = false
Minimised = false
Hidden = false
Debounce = false
searchOpen = false
Notifications = Rayfield.Notifications
ElementsSystem = nil
ElementSyncSystem = nil
OwnershipSystem = nil
keybindConnections = {} -- For storing keybind connections to disconnect when Rayfield is destroyed
layoutConnections = {}
LayoutPersistenceSystem = nil
ViewportVirtualizationSystem = nil
layoutSavingEnabled = false
layoutDebounceMs = 300
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
ExperienceState = {
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
experienceSuppressPromoPrompts = false
favoritesRegistryUnsubscribe = nil
ExperienceBindings = nil
uiToggleKeybindMatcher = KeybindSequenceLib.newMatcher({
	maxSteps = 4,
	stepTimeoutMs = 800
})
cachedUiToggleKeybindRaw = nil
cachedUiToggleKeybindSpec = nil

function initializeOwnershipTracking()
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

function resolveUiToggleKeybindSpec(rawBinding)
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

function cleanupLayoutConnections()
	for _, connection in ipairs(layoutConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	table.clear(layoutConnections)
end

function markLayoutDirty(scope, reason)
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
	Icons = Icons,
	ThemePresetsModule = ThemePresetsModuleLib,
	ThemeDefaultThemesModule = ThemeDefaultThemesModuleLib
})

local bindTheme = ThemeSystem.bindTheme

-- Apply Reactive Theme to Main UI (with nil guards for UI structure resilience)
if type(MainShellModuleLib) == "table" and type(MainShellModuleLib.applyReactiveTheme) == "function" then
	MainShellModuleLib.applyReactiveTheme({
		Main = Main,
		Topbar = Topbar,
		bindTheme = bindTheme
	})
else
	bindTheme(Main, "BackgroundColor3", "Background")
	bindTheme(Topbar, "BackgroundColor3", "Topbar")
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
	Elements = Elements,
	SettingsStoreModule = SettingsStoreModuleLib,
	SettingsPersistenceModule = SettingsPersistenceModuleLib,
	SettingsUIModule = SettingsUIModuleLib,
	SettingsShareCodeModule = SettingsShareCodeModuleLib
})

-- Initialize Configuration Module
local ConfigStorageAdapter = nil
if type(ConfigStorageAdapterModuleLib) == "table" and type(ConfigStorageAdapterModuleLib.create) == "function" then
	local okStorageAdapter, adapterOrErr = pcall(ConfigStorageAdapterModuleLib.create, {
		callSafely = callSafely
	})
	if okStorageAdapter and type(adapterOrErr) == "table" then
		ConfigStorageAdapter = adapterOrErr
	end
end
local ConfigSystem = ConfigModuleLib.init({
	HttpService = HttpService,
	TweenService = TweenService,
	Animation = Animation,
	RayfieldLibrary = RayfieldLibrary,
	callSafely = callSafely,
	StorageAdapter = ConfigStorageAdapter,
	StorageAdapterModule = ConfigStorageAdapterModuleLib,
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
function ChangeTheme(Theme)
	ThemeSystem.ChangeTheme(Theme)
	SelectedTheme = ThemeSystem.SelectedTheme
end

function getIcon(name)
	return ThemeSystem.getIcon(name)
end

-- Settings wrapper functions
function getSetting(category, name)
	return SettingsSystem.getSetting(category, name)
end

function overrideSetting(category, name, value)
	return SettingsSystem.overrideSetting(category, name, value)
end

function saveSettings()
	return SettingsSystem.saveSettings()
end

function updateSetting(category, setting, value)
	return SettingsSystem.updateSetting(category, setting, value)
end

function setSettingValue(category, setting, value, persist)
	if SettingsSystem and type(SettingsSystem.setSettingValue) == "function" then
		return SettingsSystem.setSettingValue(category, setting, value, persist)
	end
	return false, "Settings system unavailable."
end

function loadSettings()
	return SettingsSystem.loadSettings()
end

function createSettings(window)
	return SettingsSystem.createSettings(window)
end

-- Local settings references
settingsTable = SettingsSystem.settingsTable
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

local DefaultUIStringRegistry = UIStringRegistryLib.create()
local LocalizationService = LocalizationServiceLib.create({
	HttpService = HttpService,
	getSetting = getSetting,
	setSettingValue = setSettingValue,
	getElementsSystem = function()
		return ElementsSystem
	end,
	rayfieldFolder = RayfieldFolder,
	getHubSlug = function()
		if type(CFileName) == "string" and CFileName ~= "" then
			return CFileName
		end
		local activeWorkspace = getSetting("Workspaces", "active")
		if type(activeWorkspace) == "string" and activeWorkspace ~= "" then
			return activeWorkspace
		end
		return "default"
	end,
	getStringFallbacks = function()
		return DefaultUIStringRegistry.getDefaults()
	end
})
local UIStringRegistry = UIStringRegistryLib.create({
	getOverride = function(stringKey)
		if LocalizationService and type(LocalizationService.getSystemLabel) == "function" then
			return LocalizationService.getSystemLabel(stringKey)
		end
		return nil
	end
})
function localizeString(key, fallback)
	return UIStringRegistry.resolve(key, fallback)
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
function makeElementDetachable(guiObject, elementName, elementType)
	if detachPathEnabled == false then
		return nil
	end
	return DragSystem.makeElementDetachable(guiObject, elementName, elementType)
end

local openSettingsTabFromTopbar = nil
local commandPaletteQueryProvider = nil
local commandPaletteSelector = nil
local toggleAudioFeedbackFromUi = nil
local togglePinBadgesFromUi = nil
local toggleVisibilityFromUi = nil
local getPinBadgesVisibleFromUi = nil
local togglePerformanceHUDFromUi = nil
local openPerformanceHUDFromUi = nil
local closePerformanceHUDFromUi = nil
local resetPerformanceHUDFromUi = nil
local refreshMainResizeHandleVisibility = function() end
local setVisibility = nil
local commandPaletteConfirmationState = {
	key = "",
	expiresAt = 0
}

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
	localize = localizeString,
	UserInputService = UserInputService,
	useMobileSizing = useMobileSizing,
	useMobilePrompt = useMobilePrompt,
	onOpenSettingsTab = function()
		if type(openSettingsTabFromTopbar) == "function" then
			return openSettingsTabFromTopbar()
		end
		return false, "Settings handler unavailable."
	end,
	onCommandPaletteQuery = function(query)
		if type(commandPaletteQueryProvider) == "function" then
			return commandPaletteQueryProvider(query)
		end
		return {}
	end,
	onCommandPaletteSelect = function(item, mode, options)
		if type(commandPaletteSelector) == "function" then
			return commandPaletteSelector(item, mode, options)
		end
		return false, "Command handler unavailable."
	end,
	onToggleAudioFeedback = function()
		if type(toggleAudioFeedbackFromUi) == "function" then
			return toggleAudioFeedbackFromUi()
		end
		return false, "Audio handler unavailable."
	end,
	onTogglePinBadges = function()
		if type(togglePinBadgesFromUi) == "function" then
			return togglePinBadgesFromUi()
		end
		return false, "Pin badge handler unavailable."
	end,
	onToggleVisibility = function()
		if type(toggleVisibilityFromUi) == "function" then
			return toggleVisibilityFromUi()
		end
		return false, "Visibility handler unavailable."
	end,
	onTogglePerformanceHUD = function()
		if type(togglePerformanceHUDFromUi) == "function" then
			return togglePerformanceHUDFromUi()
		end
		return false, "Performance HUD handler unavailable."
	end,
	onOpenPerformanceHUD = function()
		if type(openPerformanceHUDFromUi) == "function" then
			return openPerformanceHUDFromUi()
		end
		return false, "Performance HUD handler unavailable."
	end,
	onClosePerformanceHUD = function()
		if type(closePerformanceHUDFromUi) == "function" then
			return closePerformanceHUDFromUi()
		end
		return false, "Performance HUD handler unavailable."
	end,
	onResetPerformanceHUD = function()
		if type(resetPerformanceHUDFromUi) == "function" then
			return resetPerformanceHUDFromUi()
		end
		return false, "Performance HUD reset handler unavailable."
	end,
	getAudioFeedbackEnabled = function()
		return ExperienceState and ExperienceState.audioState and ExperienceState.audioState.enabled == true
	end,
	getPinBadgesVisible = function()
		if type(getPinBadgesVisibleFromUi) == "function" then
			return getPinBadgesVisibleFromUi()
		end
		return nil
	end,
	setElementInspectorEnabled = function(enabled)
		if type(setElementInspectorEnabledInternal) == "function" then
			local okSet, setResult = pcall(setElementInspectorEnabledInternal, enabled == true)
			if okSet and setResult ~= false then
				if type(isElementInspectorEnabledInternal) == "function" then
					local okValue, value = pcall(isElementInspectorEnabledInternal)
					if okValue then
						return value == true
					end
				end
				return enabled == true
			end
		end
		return false
	end,
	getElementInspectorEnabled = function()
		if type(isElementInspectorEnabledInternal) == "function" then
			local okValue, value = pcall(isElementInspectorEnabledInternal)
			if okValue then
				return value == true
			end
		end
		return false
	end,
	inspectElementAtPointer = function(anchor)
		if type(inspectElementAtPointerInternal) == "function" then
			return inspectElementAtPointerInternal(anchor)
		end
		return false, "Element inspector unavailable."
	end,
	NotificationManagerModule = UIStateNotificationManagerLib,
	SearchEngineModule = UIStateSearchEngineLib,
	WindowManagerModule = UIStateWindowManagerLib
})

local TabSplitSystem = nil

-- Wrapper functions for UI State
function openSearch()
	UIStateSystem.openSearch()
	searchOpen = UIStateSystem.getSearchOpen()
end

function closeSearch()
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

function Hide(notify)
	VisibilityController.Hide(notify)
	if type(refreshMainResizeHandleVisibility) == "function" then
		refreshMainResizeHandleVisibility()
	end
end

function Unhide()
	VisibilityController.Unhide()
	if type(refreshMainResizeHandleVisibility) == "function" then
		refreshMainResizeHandleVisibility()
	end
end

function Maximise()
	VisibilityController.Maximise()
	if type(refreshMainResizeHandleVisibility) == "function" then
		refreshMainResizeHandleVisibility()
	end
end

function Minimise()
	VisibilityController.Minimise()
	if type(refreshMainResizeHandleVisibility) == "function" then
		refreshMainResizeHandleVisibility()
	end
end

-- Converts ID to asset URI. Returns rbxassetid://0 if ID is not a number
function getAssetUri(id)
	return UtilitiesSystem and UtilitiesSystem.getAssetUri(id, Icons) or ("rbxassetid://" .. (type(id) == "number" and id or 0))
end

function makeDraggable(object, dragObject, enableTaptic, tapticOffset)
	if UtilitiesSystem then
		UtilitiesSystem.makeDraggable(object, dragObject, enableTaptic, tapticOffset)
	else
		warn("Rayfield | UtilitiesSystem not initialized yet")
	end
end

-- Note: Old makeDraggable implementation moved to rayfield-utilities.lua module

-- Note: Drag/Detach system code has been moved to rayfield-drag.lua module

-- Configuration wrapper functions
function PackColor(Color)
	return ConfigSystem.PackColor(Color)
end

function UnpackColor(Color)
	return ConfigSystem.UnpackColor(Color)
end

function LoadConfiguration(Configuration)
	return ConfigSystem.LoadConfiguration(Configuration)
end

function SaveConfiguration()
	return ConfigSystem.SaveConfiguration()
end

function buildGeneratedAtStamp()
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

local ShareCodeSystem = nil
if type(ShareCodeServiceLib) == "table" and type(ShareCodeServiceLib.create) == "function" then
	local okShareCreate, shareOrErr = pcall(ShareCodeServiceLib.create, {
		HttpService = HttpService,
		ConfigSystem = ConfigSystem,
		SettingsSystem = SettingsSystem,
		UIStateSystem = UIStateSystem,
		LocalizationService = LocalizationService,
		InterfaceBuild = InterfaceBuild,
		Release = Release,
		SHARE_CODE_PREFIX = "RFSC1:",
		SHARE_PAYLOAD_VERSION = 1,
		SHARE_PAYLOAD_TYPE = "rayfield_share",
		buildGeneratedAtStamp = buildGeneratedAtStamp
	})
	if okShareCreate and type(shareOrErr) == "table" then
		ShareCodeSystem = shareOrErr
	else
		warn("Rayfield Mod: [W_SHARECODE_SERVICE] " .. tostring(shareOrErr))
	end
end

if type(ShareCodeSystem) ~= "table" then
	ShareCodeSystem = {
		importCode = function()
			return false, "Share code service unavailable."
		end,
		importSettings = function()
			return false, "Share code service unavailable."
		end,
		exportSettings = function()
			return nil, "Share code service unavailable."
		end,
		copyShareCode = function()
			return false, "Share code service unavailable."
		end,
		getActiveShareCode = function()
			return ""
		end,
		notifyStatus = function()
			return
		end
	}
end

local DiscordInviteSystem = nil
if type(EntryDiscordInviteServiceLib) == "table" and type(EntryDiscordInviteServiceLib.create) == "function" then
	local okDiscordInvite, discordInviteOrErr = pcall(EntryDiscordInviteServiceLib.create, {
		ensureFolder = ensureFolder,
		callSafely = callSafely,
		isfileFn = isfile,
		writefileFn = writefile,
		requestFunc = requestFunc,
		httpService = HttpService,
		rayfieldFolder = RayfieldFolder,
		configurationExtension = ConfigurationExtension,
		useStudio = useStudio
	})
	if okDiscordInvite and type(discordInviteOrErr) == "table" then
		DiscordInviteSystem = discordInviteOrErr
	else
		warn("Rayfield Mod: [W_DISCORD_INVITE_SERVICE] " .. tostring(discordInviteOrErr))
	end
end

if type(DiscordInviteSystem) ~= "table" then
	DiscordInviteSystem = {
		handle = function()
			return false, "Discord invite service unavailable."
		end
	}
end

local KeySystemRuntime = nil
if type(EntryKeySystemServiceLib) == "table" and type(EntryKeySystemServiceLib.create) == "function" then
	local okKeySystem, keySystemOrErr = pcall(EntryKeySystemServiceLib.create, {
		ensureFolder = ensureFolder,
		callSafely = callSafely,
		isfileFn = isfile,
		readfileFn = readfile,
		writefileFn = writefile,
		rayfieldFolder = RayfieldFolder,
		configurationExtension = ConfigurationExtension,
		requestHttpGet = function(url)
			return game:HttpGet(url)
		end,
		requestObjects = function(assetId)
			return game:GetObjects(assetId)
		end,
		players = Players,
		coreGui = CoreGui,
		gameRef = game,
		animation = Animation,
		tweenInfo = TweenInfo,
		enumTable = Enum,
		taskLib = task,
		print = print,
		warn = warn,
		useStudio = useStudio
	})
	if okKeySystem and type(keySystemOrErr) == "table" then
		KeySystemRuntime = keySystemOrErr
	else
		warn("Rayfield Mod: [W_KEY_SYSTEM_SERVICE] " .. tostring(keySystemOrErr))
	end
end

if type(KeySystemRuntime) ~= "table" then
	KeySystemRuntime = {
		handle = function(_, runtimeOptions)
			if type(runtimeOptions) == "table" and type(runtimeOptions.setPassthrough) == "function" then
				runtimeOptions.setPassthrough(true)
			end
			return {
				handled = false,
				abortWindowCreation = false
			}
		end
	}
end

function RayfieldLibrary:ImportCode(code)
	return ShareCodeSystem.importCode(code)
end

function RayfieldLibrary:ImportSettings(options)
	return ShareCodeSystem.importSettings(options)
end

function RayfieldLibrary:ExportSettings()
	return ShareCodeSystem.exportSettings()
end

function RayfieldLibrary:CopyShareCode(suppressNotify)
	return ShareCodeSystem.copyShareCode(suppressNotify)
end

if SettingsSystem and type(SettingsSystem.setShareCodeHandlers) == "function" then
	SettingsSystem.setShareCodeHandlers({
		importCode = function(code)
			return ShareCodeSystem.importCode(code)
		end,
		importSettings = function(options)
			return ShareCodeSystem.importSettings(options)
		end,
		exportSettings = function()
			return ShareCodeSystem.exportSettings()
		end,
		copyShareCode = function()
			return ShareCodeSystem.copyShareCode(true)
		end,
		getActiveShareCode = function()
			return ShareCodeSystem.getActiveShareCode()
		end,
		notify = function(success, message)
			if type(ShareCodeSystem.notifyStatus) == "function" then
				ShareCodeSystem.notifyStatus(success == true, message)
			end
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

function cloneValue(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, nested in pairs(value) do
		out[cloneValue(key)] = cloneValue(nested)
	end
	return out
end

function cloneArray(values)
	local out = {}
	if type(values) ~= "table" then
		return out
	end
	for index, value in ipairs(values) do
		out[index] = value
	end
	return out
end

function normalizePresetName(name)
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

function normalizeTransitionProfileName(name)
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

function color3ToPacked(color)
	if typeof(color) ~= "Color3" then
		return nil
	end
	return {
		R = math.floor(color.R * 255 + 0.5),
		G = math.floor(color.G * 255 + 0.5),
		B = math.floor(color.B * 255 + 0.5)
	}
end

function packedToColor3(packed)
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

function listThemeNames()
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

function normalizeAudioPackName(name)
	local normalized = string.lower(tostring(name or ""))
	return AUDIO_PACK_NAMES[normalized]
end

function sanitizeSoundId(value)
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

function cloneAudioPack(pack)
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

function ensureAudioSoundFolder()
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

function ensureAudioCueSound(cueName)
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

function syncAudioCueSounds()
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

function setAudioFeedbackVolumeInternal(volume, persist)
	local audioState = ExperienceState.audioState
	audioState.volume = math.clamp(tonumber(volume) or audioState.volume or 0.45, 0, 1)
	syncAudioCueSounds()
	if persist ~= false then
		setSettingValue("Audio", "volume", audioState.volume, true)
	end
	return true, "Audio volume updated."
end

function setAudioFeedbackEnabledInternal(enabled, persist)
	local audioState = ExperienceState.audioState
	audioState.enabled = enabled == true
	syncAudioCueSounds()
	if persist ~= false then
		setSettingValue("Audio", "enabled", audioState.enabled, true)
	end
	return true, audioState.enabled and "Audio feedback enabled." or "Audio feedback disabled."
end

function setAudioFeedbackPackInternal(name, packDefinition, persist)
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

function getAudioFeedbackStateSnapshot()
	local audioState = ExperienceState.audioState
	return {
		enabled = audioState.enabled == true,
		pack = audioState.pack,
		volume = tonumber(audioState.volume) or 0.45,
		customPack = cloneValue(audioState.customPack)
	}
end

function playUICueInternal(cueName, options)
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

function canUseCanvasGroup()
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

function cleanupGlassLayer()
	local glassState = ExperienceState.glassState
	if glassState.root and glassState.root.Parent then
		glassState.root:Destroy()
	end
	glassState.root = nil
	glassState.masks = nil
	glassState.highlight = nil
	glassState.resolvedMode = "off"
end

function resolveGlassMode(mode)
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

function ensureGlassLayerRoot(resolvedMode)
	local function resolveMainCornerRadius()
		if not Main then
			return nil
		end
		local mainCorner = Main:FindFirstChildOfClass("UICorner")
		if mainCorner and mainCorner.CornerRadius then
			return mainCorner.CornerRadius
		end
		return nil
	end

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
	root.ClipsDescendants = true
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

	local corner = Instance.new("UICorner")
	corner.Name = "GlassCorner"
	corner.CornerRadius = resolveMainCornerRadius() or UDim.new(0, 8)
	corner.Parent = root

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

	local corner = root:FindFirstChild("GlassCorner")
	if corner and corner:IsA("UICorner") and Main then
		local mainCorner = Main:FindFirstChildOfClass("UICorner")
		if mainCorner and mainCorner.CornerRadius then
			corner.CornerRadius = mainCorner.CornerRadius
		end
	end

	if root:IsA("CanvasGroup") then
		root.GroupTransparency = 0.2 - (intensity * 0.12)
	end

	glassState.resolvedMode = resolvedMode
	return true, "Glass applied (" .. tostring(resolvedMode) .. ")."
end

function setGlassModeInternal(mode, persist)
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

function setGlassIntensityInternal(value, persist)
	ExperienceState.glassState.intensity = math.clamp(tonumber(value) or ExperienceState.glassState.intensity or 0.32, 0, 1)
	local okApply, applyMessage = applyGlassLayer()
	if persist ~= false then
		setSettingValue("Glass", "intensity", ExperienceState.glassState.intensity, true)
	end
	return okApply, applyMessage
end

function getMainScale()
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
function capturePresetLayoutBaseline()
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

function applyPresetLayoutInternal(presetName)
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

function setTransitionProfileInternal(name, persist)
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

function setUIPresetInternal(name, persist)
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

function buildThemeStudioTheme(baseThemeName, packedOverrides)
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

function getThemeStudioColor(themeKey)
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

function applyThemeStudioState(persist)
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

function setThemeStudioBaseTheme(name, persist)
	local themeName = tostring(name or "")
	if not ThemeModule.Themes[themeName] then
		return false, "Theme not found."
	end
	ExperienceState.themeStudioState.baseTheme = themeName
	return applyThemeStudioState(persist ~= false)
end

function setThemeStudioUseCustom(value, persist)
	ExperienceState.themeStudioState.useCustom = value == true
	return applyThemeStudioState(persist ~= false)
end

function setThemeStudioColor(themeKey, color)
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

function resetThemeStudioState(persist)
	ExperienceState.themeStudioState.useCustom = false
	ExperienceState.themeStudioState.customThemePacked = {}
	return applyThemeStudioState(persist ~= false)
end

function refreshFavoritesSettingsPersistence()
	if ElementsSystem and type(ElementsSystem.getPinnedIds) == "function" then
		local pinnedIds = ElementsSystem.getPinnedIds(true)
		setSettingValue("Favorites", "pinnedIds", cloneArray(pinnedIds), true)
	end
end

function highlightFavoriteControl(record)
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

function renderFavoritesTab()
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

function ensureFavoritesTab(windowRef)
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

function openFavoritesTab(windowRef)
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

local listWorkspacesInternal = nil
local saveWorkspaceInternal = nil
local loadWorkspaceInternal = nil
local deleteWorkspaceInternal = nil
local listProfilesInternal = nil
local saveProfileInternal = nil
local loadProfileInternal = nil
local deleteProfileInternal = nil
local copyWorkspaceToProfileInternal = nil
local copyProfileToWorkspaceInternal = nil
local setCommandPaletteExecutionModeInternal = nil
local getCommandPaletteExecutionModeInternal = nil
local setCommandPalettePolicyInternal = nil
local runCommandPaletteItemInternal = nil
local openPerformanceHUDInternal = nil
local closePerformanceHUDInternal = nil
local togglePerformanceHUDInternal = nil
local resetPerformanceHUDInternal = nil
local configurePerformanceHUDInternal = nil
local getPerformanceHUDStateInternal = nil
local registerHUDMetricProviderInternal = nil
local unregisterHUDMetricProviderInternal = nil
local setControlDisplayLabelInternal = nil
local getControlDisplayLabelInternal = nil
local resetControlDisplayLabelInternal = nil
local setSystemDisplayLabelInternal = nil
local getSystemDisplayLabelInternal = nil
local resetDisplayLanguageInternal = nil
local getLocalizationStateInternal = nil
local setLocalizationLanguageTagInternal = nil
local exportLocalizationInternal = nil
local importLocalizationInternal = nil
local localizeStringInternal = nil
local getUsageAnalyticsInternal = nil
local clearUsageAnalyticsInternal = nil
local startMacroRecordingInternal = nil
local stopMacroRecordingInternal = nil
local cancelMacroRecordingInternal = nil
local isMacroRecordingInternal = nil
local isMacroExecutingInternal = nil
local listMacrosInternal = nil
local deleteMacroInternal = nil
local executeMacroInternal = nil
local bindMacroInternal = nil
local triggerMacroByKeybindInternal = nil
local registerHubMetadataInternal = nil
local getHubMetadataInternal = nil
local setElementInspectorEnabledInternal = nil
local isElementInspectorEnabledInternal = nil
local inspectElementAtPointerInternal = nil
local openLiveThemeEditorInternal = nil
local setLiveThemeValueInternal = nil
local applyLiveThemeDraftInternal = nil
local exportLiveThemeLuaInternal = nil
local registerDiscoveryProviderInternal = nil
local unregisterDiscoveryProviderInternal = nil
local queryDiscoveryInternal = nil
local executePromptCommandInternal = nil
local askAssistantInternal = nil
local getAssistantHistoryInternal = nil
local sendGlobalSignalInternal = nil
local sendInternalChatInternal = nil
local pollBridgeMessagesInternal = nil
local startBridgePollingInternal = nil
local stopBridgePollingInternal = nil
local getBridgeMessagesInternal = nil
local scheduleMacroInternal = nil
local scheduleAutomationActionInternal = nil
local cancelScheduledActionInternal = nil
local listScheduledActionsInternal = nil
local clearScheduledActionsInternal = nil
local addAutomationRuleInternal = nil
local removeAutomationRuleInternal = nil
local listAutomationRulesInternal = nil
local setAutomationRuleEnabledInternal = nil
local evaluateAutomationRulesInternal = nil

local UsageAnalyticsService = UsageAnalyticsServiceLib.create({
	getSetting = getSetting,
	cloneValue = cloneValue
})

local MacroRecorderService = MacroRecorderServiceLib.create({
	getSetting = getSetting,
	setSettingValue = setSettingValue,
	cloneValue = cloneValue,
	onPersist = function()
		if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
			pcall(SettingsSystem.saveSettings)
		end
	end,
	onMacroExecuted = function(name, completedSteps)
		if UsageAnalyticsService and type(UsageAnalyticsService.trackMacroUsage) == "function" then
			pcall(UsageAnalyticsService.trackMacroUsage, {
				name = name,
				steps = completedSteps
			})
		end
	end
})

local DevExperienceService = DevExperienceServiceLib.create({
	cloneValue = cloneValue,
	getElementsSystem = function()
		return ElementsSystem
	end,
	applyThemeStudioTheme = function(themeTable)
		return RayfieldLibrary:ApplyThemeStudioTheme(themeTable)
	end,
	getThemeStudioState = function()
		return RayfieldLibrary:GetThemeStudioState()
	end,
	getThemeStudioColor = function(themeKey)
		return getThemeStudioColor(themeKey)
	end,
	getThemeStudioKeys = function()
		return cloneArray(THEME_STUDIO_KEYS)
	end,
	packedToColor3 = packedToColor3
})

local bridgeNotifyEnabled = not (type(_G) == "table" and _G.__RAYFIELD_MULTI_BRIDGE_NOTIFY == false)
local MultiInstanceBridgeService = MultiInstanceBridgeServiceLib.create({
	HttpService = HttpService,
	cloneValue = cloneValue,
	notify = function(data)
		if bridgeNotifyEnabled and type(RayfieldLibrary.Notify) == "function" then
			RayfieldLibrary:Notify(data)
		end
	end,
	onMessage = function(envelope)
		if type(envelope) ~= "table" then
			return
		end
		local kind = tostring(envelope.kind or "")
		local payload = type(envelope.payload) == "table" and envelope.payload or {}

		if kind == "chat" then
			if bridgeNotifyEnabled and type(RayfieldLibrary.Notify) == "function" then
				RayfieldLibrary:Notify({
					Title = "Bridge Chat",
					Content = string.format("%s: %s", tostring(envelope.from or "peer"), tostring(payload.text or "")),
					Duration = 4
				})
			end
		elseif kind == "signal" then
			local command = tostring(payload.command or "")
			if command == "toggle_ui" then
				RayfieldLibrary:SetVisibility(not RayfieldLibrary:IsVisible())
			elseif command == "open_action_center" then
				RayfieldLibrary:OpenActionCenter()
			elseif command == "open_settings" and type(openSettingsTabFromTopbar) == "function" then
				pcall(openSettingsTabFromTopbar)
			elseif command == "run_macro" and type(executeMacroInternal) == "function" then
				local data = type(payload.data) == "table" and payload.data or payload
				local macroName = tostring(data.name or data.macro or "")
				if macroName ~= "" then
					pcall(executeMacroInternal, macroName, {
						respectDelay = false
					})
				end
			end
		end

		if type(_G) == "table" and type(_G.__RAYFIELD_GLOBAL_SIGNAL_HANDLER) == "function" then
			pcall(_G.__RAYFIELD_GLOBAL_SIGNAL_HANDLER, cloneValue(envelope))
		end
	end
})

sendGlobalSignalInternal = function(command, payload, options)
	return MultiInstanceBridgeService.sendSignal(command, payload, options)
end

sendInternalChatInternal = function(message, options)
	return MultiInstanceBridgeService.sendChat(message, options)
end

pollBridgeMessagesInternal = function(limit, options)
	return MultiInstanceBridgeService.poll(limit, options)
end

startBridgePollingInternal = function()
	return MultiInstanceBridgeService.startPolling()
end

stopBridgePollingInternal = function()
	return MultiInstanceBridgeService.stopPolling()
end

getBridgeMessagesInternal = function(limit, kind)
	return MultiInstanceBridgeService.listMessages(limit, kind)
end

if type(_G) == "table" and _G.__RAYFIELD_MULTI_BRIDGE_AUTO_POLL == true then
	pcall(startBridgePollingInternal)
end

function normalizeDiscoveryEntries(rawItems, providerName, queryLower)
	local out = {}
	for _, raw in ipairs(type(rawItems) == "table" and rawItems or {}) do
		local entry = nil
		if type(raw) == "string" then
			entry = {
				id = string.format("%s:%s", tostring(providerName), tostring(raw)),
				name = tostring(raw),
				type = tostring(providerName)
			}
		elseif type(raw) == "table" then
			entry = {
				id = tostring(raw.id or raw.key or raw.name or ""),
				name = tostring(raw.name or raw.label or raw.title or raw.id or "result"),
				type = tostring(raw.type or providerName),
				tabId = tostring(raw.tabId or ""),
				controlId = tostring(raw.controlId or ""),
				matchScore = tonumber(raw.matchScore),
				searchText = tostring(raw.searchText or raw.alias or raw.name or raw.id or "")
			}
			if entry.id == "" then
				entry.id = string.format("%s:%s", tostring(providerName), tostring(entry.name))
			end
		end
		if entry then
			entry.searchText = tostring(entry.searchText or entry.name or "")
			local searchLower = string.lower(entry.searchText)
			if queryLower == "" or string.find(searchLower, queryLower, 1, true) ~= nil then
				table.insert(out, entry)
			end
		end
	end
	return out
end

function buildDefaultDiscoveryProviders()
	return {
		game_api = function(queryText, queryLower)
			local globalApi = type(_G) == "table" and _G.__RAYFIELD_GAME_DISCOVERY_API or nil
			local out = {}
			local function appendEntries(rawItems, providerName)
				local normalized = normalizeDiscoveryEntries(rawItems, providerName, queryLower)
				for _, item in ipairs(normalized) do
					table.insert(out, item)
				end
			end

			if type(globalApi) == "function" then
				local okCall, items = pcall(globalApi, queryText, queryLower)
				if okCall then
					appendEntries(items, "game")
				end
			elseif type(globalApi) == "table" then
				if type(globalApi.search) == "function" then
					local okSearch, items = pcall(globalApi.search, queryText, queryLower)
					if okSearch then
						appendEntries(items, "game")
					end
				end
				if type(globalApi.searchItems) == "function" then
					local okItems, items = pcall(globalApi.searchItems, queryText, queryLower)
					if okItems then
						appendEntries(items, "item")
					end
				end
				if type(globalApi.searchLocations) == "function" then
					local okLocations, items = pcall(globalApi.searchLocations, queryText, queryLower)
					if okLocations then
						appendEntries(items, "location")
					end
				end
			end
			return out
		end
	}
end

local SmartSearchService = SmartSearchServiceLib.create({
	cloneValue = cloneValue,
	HttpService = HttpService,
	requestFn = requestFunc,
	notify = function(data)
		if type(RayfieldLibrary.Notify) == "function" then
			RayfieldLibrary:Notify(data)
		end
	end,
	applyThemeColor = function(accentColor)
		return RayfieldLibrary:ApplyThemeStudioTheme({
			SliderBackground = accentColor,
			SliderProgress = accentColor,
			SliderStroke = accentColor,
			ToggleEnabled = accentColor,
			ToggleEnabledStroke = accentColor,
			ToggleEnabledOuterStroke = accentColor,
			TabBackgroundSelected = accentColor
		})
	end,
	toggleVisibility = function()
		if type(toggleVisibilityFromUi) == "function" then
			return toggleVisibilityFromUi()
		end
		RayfieldLibrary:SetVisibility(not RayfieldLibrary:IsVisible())
		return true, "Interface visibility toggled."
	end,
	openSettings = function()
		if type(openSettingsTabFromTopbar) == "function" then
			return openSettingsTabFromTopbar()
		end
		return false, "Settings tab unavailable."
	end,
	openFavorites = function()
		return openFavoritesTab(ExperienceState.favoritesTabWindow)
	end,
	openActionCenter = function()
		return RayfieldLibrary:OpenActionCenter()
	end,
	sendGlobalSignal = function(command, payload, options)
		if type(sendGlobalSignalInternal) == "function" then
			return sendGlobalSignalInternal(command, payload, options)
		end
		return false, "Global signal bridge unavailable."
	end,
	sendInternalChat = function(text, options)
		if type(sendInternalChatInternal) == "function" then
			return sendInternalChatInternal(text, options)
		end
		return false, "Internal chat bridge unavailable."
	end,
	scheduleMacro = function(name, delaySeconds, options)
		if type(scheduleMacroInternal) == "function" then
			return scheduleMacroInternal(name, delaySeconds, options)
		end
		return false, "Automation scheduler unavailable."
	end,
	registerDiscoveryProvider = buildDefaultDiscoveryProviders
})

registerDiscoveryProviderInternal = function(id, provider)
	return SmartSearchService.registerProvider(id, provider)
end

unregisterDiscoveryProviderInternal = function(id)
	return SmartSearchService.unregisterProvider(id)
end

queryDiscoveryInternal = function(query)
	return SmartSearchService.queryDiscovery(query)
end

executePromptCommandInternal = function(rawText)
	return SmartSearchService.executePromptCommand(rawText)
end

askAssistantInternal = function(prompt, options)
	return SmartSearchService.askAssistant(prompt, options)
end

getAssistantHistoryInternal = function()
	return SmartSearchService.getAiHistory()
end

getUsageAnalyticsInternal = function(limit)
	return UsageAnalyticsService.getSnapshot(limit)
end

clearUsageAnalyticsInternal = function()
	return UsageAnalyticsService.clear()
end

startMacroRecordingInternal = function(name)
	return MacroRecorderService.startRecording(name)
end

stopMacroRecordingInternal = function(saveResult)
	return MacroRecorderService.stopRecording(saveResult ~= false)
end

cancelMacroRecordingInternal = function()
	return MacroRecorderService.cancelRecording()
end

isMacroRecordingInternal = function()
	return MacroRecorderService.isRecording()
end

isMacroExecutingInternal = function()
	if type(MacroRecorderService.isExecuting) == "function" then
		return MacroRecorderService.isExecuting()
	end
	return false
end

listMacrosInternal = function()
	return MacroRecorderService.listMacros()
end

deleteMacroInternal = function(name)
	return MacroRecorderService.deleteMacro(name)
end

executeMacroInternal = function(name, options)
	return MacroRecorderService.executeMacro(name, {
		executeStep = function(step)
			if type(step) ~= "table" then
				return true
			end
			local action = tostring(step.action or "")
			if action == "control" then
				local controlId = tostring(step.controlId or "")
				if controlId == "" then
					return false, "Macro step missing controlId."
				end
				if ElementsSystem and type(ElementsSystem.getControlRecordById) == "function" then
					local record = ElementsSystem.getControlRecordById(controlId)
					if record then
						if ElementsSystem and type(ElementsSystem.activateTabByPersistenceId) == "function" then
							ElementsSystem.activateTabByPersistenceId(record.TabPersistenceId, true, "macro")
						end
						local elementObject = record.ElementObject
						if type(elementObject) == "table" and type(elementObject.Set) == "function" and step.value ~= nil then
							elementObject:Set(step.value)
						end
						local interaction = tostring(step.interaction or "")
						if interaction == "click" or interaction == "touch" then
							local guiObject = record.GuiObject
							local interactButton = guiObject and guiObject:FindFirstChild("Interact")
							if interactButton and interactButton:IsA("GuiButton") then
								pcall(function()
									interactButton:Activate()
								end)
							end
						end
						return true
					end
				end
				return false, "Control not found for macro step."
			elseif action == "toggle_visibility" then
				RayfieldLibrary:SetVisibility(not RayfieldLibrary:IsVisible())
				return true
			elseif action == "open_action_center" then
				return RayfieldLibrary:OpenActionCenter()
			elseif action == "open_settings" then
				if type(openSettingsTabFromTopbar) == "function" then
					return openSettingsTabFromTopbar()
				end
				return false, "Settings tab unavailable."
			end
			return true
		end
	}, options)
end

bindMacroInternal = function(name, keybind)
	return MacroRecorderService.bindMacro(name, keybind)
end

triggerMacroByKeybindInternal = function(keybind, options)
	return MacroRecorderService.triggerByKeybind(keybind, {
		executeStep = function(step)
			if type(step) ~= "table" then
				return true
			end
			local action = tostring(step.action or "")
			if action == "control" then
				local controlId = tostring(step.controlId or "")
				if controlId == "" then
					return false, "Macro step missing controlId."
				end
				if ElementsSystem and type(ElementsSystem.getControlRecordById) == "function" then
					local record = ElementsSystem.getControlRecordById(controlId)
					if record then
						if ElementsSystem and type(ElementsSystem.activateTabByPersistenceId) == "function" then
							ElementsSystem.activateTabByPersistenceId(record.TabPersistenceId, true, "macro")
						end
						local elementObject = record.ElementObject
						if type(elementObject) == "table" and type(elementObject.Set) == "function" and step.value ~= nil then
							elementObject:Set(step.value)
						end
						local interaction = tostring(step.interaction or "")
						if interaction == "click" or interaction == "touch" then
							local guiObject = record.GuiObject
							local interactButton = guiObject and guiObject:FindFirstChild("Interact")
							if interactButton and interactButton:IsA("GuiButton") then
								pcall(function()
									interactButton:Activate()
								end)
							end
						end
						return true
					end
				end
				return false, "Control not found for macro step."
			end
			return true
		end
	}, options)
end

registerHubMetadataInternal = function(metadata)
	return DevExperienceService.registerHubMetadata(metadata)
end

getHubMetadataInternal = function()
	return DevExperienceService.getHubMetadata()
end

setElementInspectorEnabledInternal = function(enabled)
	return DevExperienceService.setInspectorEnabled(enabled == true)
end

isElementInspectorEnabledInternal = function()
	return DevExperienceService.isInspectorEnabled()
end

inspectElementAtPointerInternal = function(anchor)
	return DevExperienceService.inspectAtPointer(anchor)
end

openLiveThemeEditorInternal = function(seedDraft)
	return DevExperienceService.openLiveThemeEditor(seedDraft)
end

setLiveThemeValueInternal = function(themeKey, color)
	return DevExperienceService.setLiveThemeValue(themeKey, color)
end

applyLiveThemeDraftInternal = function()
	return DevExperienceService.applyLiveThemeDraft()
end

exportLiveThemeLuaInternal = function()
	return DevExperienceService.exportLiveThemeDraftLua()
end

local AutomationEngineService = AutomationEngineServiceLib.create({
	getSetting = getSetting,
	setSettingValue = setSettingValue,
	cloneValue = cloneValue,
	executeMacro = function(name, options)
		if type(executeMacroInternal) ~= "function" then
			return false, "Macro executor unavailable."
		end
		return executeMacroInternal(name, options)
	end,
	executeCommand = function(actionName, payload, options)
		local action = tostring(actionName or "")
		if action == "" then
			return false, "Command action is required."
		end
		if type(commandPaletteSelector) == "function" then
			local item = type(payload) == "table" and cloneValue(payload) or {}
			item.action = action
			item.name = tostring(item.name or action)
			local forcedMode = type(options) == "table" and options.mode or nil
			return commandPaletteSelector(item, forcedMode, options)
		end
		if action == "toggle_visibility" then
			RayfieldLibrary:SetVisibility(not RayfieldLibrary:IsVisible())
			return true, "Interface visibility toggled."
		end
		if action == "open_action_center" then
			return RayfieldLibrary:OpenActionCenter()
		end
		if action == "open_settings" and type(openSettingsTabFromTopbar) == "function" then
			return openSettingsTabFromTopbar()
		end
		return false, "Command executor unavailable for action: " .. action
	end,
	notify = function(data)
		if type(RayfieldLibrary.Notify) == "function" then
			RayfieldLibrary:Notify(data)
		end
	end,
	onEvent = function(kind, payload)
		if kind == "macro" and UsageAnalyticsService and type(UsageAnalyticsService.trackMacroUsage) == "function" then
			pcall(UsageAnalyticsService.trackMacroUsage, {
				name = tostring(payload and payload.name or "automation"),
				steps = 0
			})
		elseif kind == "command" and UsageAnalyticsService and type(UsageAnalyticsService.trackCommandUsage) == "function" then
			pcall(UsageAnalyticsService.trackCommandUsage, {
				action = tostring(payload and payload.action or "automation"),
				name = tostring(payload and payload.action or "automation")
			})
		end
	end,
	onPersist = function()
		if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
			pcall(SettingsSystem.saveSettings)
		end
	end
})

scheduleMacroInternal = function(name, delaySeconds, options)
	return AutomationEngineService.scheduleMacro(name, delaySeconds, options)
end

scheduleAutomationActionInternal = function(actionSpec, delaySeconds, options)
	return AutomationEngineService.scheduleAction(actionSpec, delaySeconds, options)
end

cancelScheduledActionInternal = function(taskId)
	return AutomationEngineService.cancelScheduled(taskId)
end

listScheduledActionsInternal = function()
	return AutomationEngineService.listScheduled()
end

clearScheduledActionsInternal = function()
	return AutomationEngineService.clearScheduled()
end

addAutomationRuleInternal = function(rule)
	return AutomationEngineService.addRule(rule)
end

removeAutomationRuleInternal = function(ruleId)
	return AutomationEngineService.removeRule(ruleId)
end

listAutomationRulesInternal = function()
	return AutomationEngineService.listRules()
end

setAutomationRuleEnabledInternal = function(ruleId, enabled)
	return AutomationEngineService.setRuleEnabled(ruleId, enabled)
end

evaluateAutomationRulesInternal = function(eventPayload)
	return AutomationEngineService.evaluateRules(eventPayload)
end

local WorkspaceService = WorkspaceServiceLib.create({
	getSetting = getSetting,
	setSettingValue = setSettingValue,
	settingsSystem = SettingsSystem,
	buildGeneratedAtStamp = buildGeneratedAtStamp,
	cloneValue = cloneValue,
	localize = localizeString,
	onRestoreAfterLoad = function()
		if ExperienceBindings and type(ExperienceBindings.restoreFromSettings) == "function" then
			pcall(ExperienceBindings.restoreFromSettings, ExperienceState.favoritesTabWindow)
		end
		if type(renderFavoritesTab) == "function" then
			renderFavoritesTab()
		end
	end,
	onPersist = function()
		if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
			pcall(SettingsSystem.saveSettings)
		end
	end
})

listWorkspacesInternal = function()
	return WorkspaceService.listWorkspaces()
end

saveWorkspaceInternal = function(name)
	return WorkspaceService.saveWorkspace(name)
end

loadWorkspaceInternal = function(name)
	return WorkspaceService.loadWorkspace(name)
end

deleteWorkspaceInternal = function(name)
	return WorkspaceService.deleteWorkspace(name)
end

listProfilesInternal = function()
	return WorkspaceService.listProfiles()
end

saveProfileInternal = function(name)
	return WorkspaceService.saveProfile(name)
end

loadProfileInternal = function(name)
	return WorkspaceService.loadProfile(name)
end

deleteProfileInternal = function(name)
	return WorkspaceService.deleteProfile(name)
end

copyWorkspaceToProfileInternal = function(workspaceName, profileName)
	return WorkspaceService.copyWorkspaceToProfile(workspaceName, profileName)
end

copyProfileToWorkspaceInternal = function(profileName, workspaceName)
	return WorkspaceService.copyProfileToWorkspace(profileName, workspaceName)
end

local PerformanceHUDService = PerformanceHUDServiceLib.create({
	Main = Main,
	Topbar = Topbar,
	RunService = RunService,
	UserInputService = UserInputService,
	bindTheme = bindTheme,
	getSelectedTheme = function()
		return SelectedTheme
	end,
	localize = localizeString,
	getRuntimeDiagnostics = function()
		if type(RayfieldLibrary.GetRuntimeDiagnostics) == "function" then
			local okDiag, diagnostics = pcall(RayfieldLibrary.GetRuntimeDiagnostics, RayfieldLibrary)
			if okDiag and type(diagnostics) == "table" then
				return diagnostics
			end
		end
		return {}
	end,
	getVisibilityState = function()
		return {
			hidden = Hidden == true,
			minimized = Minimised == true
		}
	end,
	getMacroState = function()
		return {
			recording = type(isMacroRecordingInternal) == "function" and isMacroRecordingInternal() == true or false,
			executing = type(isMacroExecutingInternal) == "function" and isMacroExecutingInternal() == true or false
		}
	end,
	getAutomationSummary = function()
		local scheduled = type(listScheduledActionsInternal) == "function" and listScheduledActionsInternal() or {}
		local rules = type(listAutomationRulesInternal) == "function" and listAutomationRulesInternal() or {}
		return {
			scheduled = type(scheduled) == "table" and #scheduled or 0,
			rules = type(rules) == "table" and #rules or 0
		}
	end,
	loadState = function()
		local saved = getSetting("UIExperience", "performanceHudConfig")
		if type(saved) == "table" then
			return saved
		end
		return nil
	end,
	saveState = function(nextState)
		if type(nextState) == "table" then
			setSettingValue("UIExperience", "performanceHudConfig", nextState, true)
		end
	end
})

openPerformanceHUDInternal = function()
	return PerformanceHUDService.open()
end

closePerformanceHUDInternal = function()
	return PerformanceHUDService.close()
end

togglePerformanceHUDInternal = function()
	return PerformanceHUDService.toggle()
end

resetPerformanceHUDInternal = function(anchor)
	if type(PerformanceHUDService.resetPosition) == "function" then
		return PerformanceHUDService.resetPosition(anchor)
	end
	return false, "Performance HUD reset unavailable."
end

configurePerformanceHUDInternal = function(options)
	return PerformanceHUDService.configure(options)
end

getPerformanceHUDStateInternal = function()
	return PerformanceHUDService.getState()
end

registerHUDMetricProviderInternal = function(id, provider, options)
	return PerformanceHUDService.registerProvider(id, provider, options)
end

unregisterHUDMetricProviderInternal = function(id)
	return PerformanceHUDService.unregisterProvider(id)
end

local CommandPaletteService = CommandPaletteServiceLib.create({
	getElementsSystem = function()
		return ElementsSystem
	end,
	localize = localizeString,
	usageAnalytics = UsageAnalyticsService,
	searchAlgorithms = CommandPaletteSearchAlgorithmsLib,
	queryDiscovery = function(query)
		if type(queryDiscoveryInternal) == "function" then
			return queryDiscoveryInternal(query)
		end
		return {}
	end,
	parsePromptCommand = function(rawText)
		if SmartSearchService and type(SmartSearchService.parsePromptCommand) == "function" then
			return SmartSearchService.parsePromptCommand(rawText)
		end
		return nil
	end,
	executePromptCommand = function(rawText, parsedCommand)
		if SmartSearchService and type(SmartSearchService.executePromptCommand) == "function" then
			return SmartSearchService.executePromptCommand(rawText, parsedCommand)
		end
		return false, "Prompt command service unavailable."
	end,
	selectDiscoveryItem = function(item)
		if type(item) ~= "table" then
			return false, "Discovery item is invalid."
		end
		if type(item.onSelect) == "function" then
			return item.onSelect(item)
		end
		if tostring(item.controlId or "") ~= "" and ElementsSystem and type(ElementsSystem.getControlRecordById) == "function" then
			local record = ElementsSystem.getControlRecordById(tostring(item.controlId))
			if record then
				if type(ElementsSystem.activateTabByPersistenceId) == "function" then
					ElementsSystem.activateTabByPersistenceId(record.TabPersistenceId, true, "discovery")
				end
				if type(highlightFavoriteControl) == "function" then
					highlightFavoriteControl(record)
				end
				return true, "Opened discovery control: " .. tostring(item.name or item.controlId)
			end
		end
		if type(RayfieldLibrary.Notify) == "function" then
			RayfieldLibrary:Notify({
				Title = "Discovery",
				Content = tostring(item.name or item.id or "Selected discovery entry."),
				Duration = 3
			})
		end
		return true, "Discovery entry selected."
	end,
	getExperienceState = function()
		return ExperienceState
	end,
	getSetting = getSetting,
	setSettingValue = setSettingValue,
	setAudioFeedbackEnabled = setAudioFeedbackEnabledInternal,
	setVisibility = function(visibility, notify)
		if VisibilityController and type(VisibilityController.SetVisibility) == "function" then
			return VisibilityController.SetVisibility(visibility, notify)
		end
		return false, "Visibility handler unavailable."
	end,
	getHidden = function()
		return Hidden == true
	end,
	getUseMobileSizing = function()
		return useMobileSizing == true
	end,
	openFavoritesTab = openFavoritesTab,
	getFavoritesTabWindow = function()
		return ExperienceState.favoritesTabWindow
	end,
	highlightFavoriteControl = highlightFavoriteControl,
	getSettingsPage = function()
		return Elements and Elements:FindFirstChild("Rayfield Settings")
	end,
	jumpToSettingsPage = function(page)
		Elements.UIPageLayout:JumpTo(page)
	end,
	notify = function(data)
		RayfieldLibrary:Notify(data)
	end,
	openActionCenter = function()
		return RayfieldLibrary:OpenActionCenter()
	end,
	openPerformanceHUD = function()
		return openPerformanceHUDInternal()
	end,
	closePerformanceHUD = function()
		return closePerformanceHUDInternal()
	end,
	togglePerformanceHUD = function()
		return togglePerformanceHUDInternal()
	end,
	resetPerformanceHUDPosition = function(anchor)
		return resetPerformanceHUDInternal(anchor or "top_left")
	end,
	confirmCommandPaletteItem = function(item)
		local key = tostring(type(item) == "table" and (item.id or item.action or item.name) or "")
		local nowTime = os.clock()
		if key ~= "" and commandPaletteConfirmationState.key == key and nowTime <= commandPaletteConfirmationState.expiresAt then
			commandPaletteConfirmationState.key = ""
			commandPaletteConfirmationState.expiresAt = 0
			return true
		end
		commandPaletteConfirmationState.key = key
		commandPaletteConfirmationState.expiresAt = nowTime + 4
		if type(RayfieldLibrary.Notify) == "function" then
			RayfieldLibrary:Notify({
				Title = "Command Palette Confirmation",
				Content = "Repeat Alt+Enter within 4 seconds to confirm, or use Shift+Enter to execute now.",
				Duration = 4
			})
		end
		return false, "Confirmation pending."
	end,
	exportSettings = function()
		return RayfieldLibrary:ExportSettings()
	end,
	importSettings = function()
		return RayfieldLibrary:ImportSettings()
	end,
	recordMacroStep = function(step)
		if MacroRecorderService and type(MacroRecorderService.isRecording) == "function" and MacroRecorderService.isRecording() then
			pcall(MacroRecorderService.recordStep, step)
		end
	end,
	listMacros = function()
		if MacroRecorderService and type(MacroRecorderService.listMacros) == "function" then
			return MacroRecorderService.listMacros()
		end
		return {}
	end,
	startMacroRecording = function(name)
		return startMacroRecordingInternal(name)
	end,
	stopMacroRecording = function(saveResult)
		return stopMacroRecordingInternal(saveResult ~= false)
	end,
	executeMacro = function(name)
		return executeMacroInternal(name)
	end,
	sendGlobalSignal = function(command, payload, options)
		return sendGlobalSignalInternal(command, payload, options)
	end,
	sendInternalChat = function(message, options)
		return sendInternalChatInternal(message, options)
	end,
	startBridgePolling = function()
		return startBridgePollingInternal()
	end,
	stopBridgePolling = function()
		return stopBridgePollingInternal()
	end,
	listBridgeMessages = function(limit, kind)
		return getBridgeMessagesInternal(limit, kind)
	end,
	scheduleMacro = function(name, delaySeconds, options)
		return scheduleMacroInternal(name, delaySeconds, options)
	end,
	listScheduledActions = function()
		return listScheduledActionsInternal()
	end,
	listAutomationRules = function()
		return listAutomationRulesInternal()
	end,
	toggleElementInspector = function()
		if UIStateSystem and type(UIStateSystem.ToggleElementInspector) == "function" then
			return UIStateSystem.ToggleElementInspector()
		end
		return false, "Element inspector unavailable."
	end,
	openLiveThemeEditor = function()
		local okOpen, status = openLiveThemeEditorInternal()
		if okOpen and type(RayfieldLibrary.Notify) == "function" then
			RayfieldLibrary:Notify({
				Title = "Live Theme Editor",
				Content = "Draft session started. Use API to tune colors, then export Lua.",
				Duration = 4
			})
		end
		return okOpen, status
	end,
	exportLiveThemeLua = function()
		local okExport, luaOrErr = exportLiveThemeLuaInternal()
		if okExport and type(setclipboard) == "function" then
			pcall(setclipboard, luaOrErr)
			return true, "Theme Lua copied to clipboard."
		end
		if okExport and type(toclipboard) == "function" then
			pcall(toclipboard, luaOrErr)
			return true, "Theme Lua copied to clipboard."
		end
		return okExport, okExport and "Theme Lua generated." or luaOrErr
	end,
	showHubMetadata = function()
		local meta = getHubMetadataInternal()
		if type(meta) ~= "table" then
			return false, "Hub metadata is not registered."
		end
		if type(RayfieldLibrary.Notify) == "function" then
			RayfieldLibrary:Notify({
				Title = tostring(meta.Name ~= "" and meta.Name or "Hub Metadata"),
				Content = string.format("Author: %s | Version: %s", tostring(meta.Author), tostring(meta.Version)),
				Duration = 6
			})
		end
		return true, "Hub metadata displayed."
	end,
	setShareCodeInputValue = function(code)
		if SettingsSystem and type(SettingsSystem.setShareCodeInputValue) == "function" then
			return SettingsSystem.setShareCodeInputValue(code)
		end
		return false
	end
})

openSettingsTabFromTopbar = function()
	return CommandPaletteService.openSettingsTab()
end

toggleAudioFeedbackFromUi = function()
	return CommandPaletteService.toggleAudioFeedback()
end

getPinBadgesVisibleFromUi = function()
	return CommandPaletteService.getPinBadgesVisible()
end

togglePinBadgesFromUi = function()
	return CommandPaletteService.togglePinBadges()
end

toggleVisibilityFromUi = function()
	return CommandPaletteService.toggleVisibility()
end

togglePerformanceHUDFromUi = function()
	return togglePerformanceHUDInternal()
end

openPerformanceHUDFromUi = function()
	return openPerformanceHUDInternal()
end

closePerformanceHUDFromUi = function()
	return closePerformanceHUDInternal()
end

resetPerformanceHUDFromUi = function()
	return resetPerformanceHUDInternal("top_left")
end

commandPaletteQueryProvider = function(query)
	return CommandPaletteService.query(query)
end

commandPaletteSelector = function(item, mode, options)
	return CommandPaletteService.select(item, mode, options)
end

setCommandPaletteExecutionModeInternal = function(mode)
	return CommandPaletteService.setExecutionMode(mode)
end

getCommandPaletteExecutionModeInternal = function()
	return CommandPaletteService.getExecutionMode()
end

setCommandPalettePolicyInternal = function(callback)
	return CommandPaletteService.setPolicy(callback)
end

runCommandPaletteItemInternal = function(item, mode)
	return CommandPaletteService.runItem(item, mode)
end

setControlDisplayLabelInternal = function(idOrFlag, label, options)
	options = type(options) == "table" and options or {}
	local controlKey = trimString(idOrFlag)
	if controlKey == "" then
		return false, "Control key is required."
	end
	local shouldPersist = options.persist ~= false

	if not shouldPersist and ElementsSystem and type(ElementsSystem.setControlDisplayLabel) == "function" then
		return ElementsSystem.setControlDisplayLabel(controlKey, label, {
			persist = false,
			source = "experience_binding_temporary"
		})
	end

	if shouldPersist and LocalizationService and type(LocalizationService.setControlLabel) == "function" then
		local okCall, okSet, resultMessage = pcall(LocalizationService.setControlLabel, controlKey, label)
		if not okCall then
			return false, tostring(okSet)
		end
		if okSet ~= true then
			return false, tostring(resultMessage or "Failed to set control display label.")
		end
		if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
			pcall(SettingsSystem.saveSettings)
		end
		return true, "Control display label updated."
	end

	if ElementsSystem and type(ElementsSystem.setControlDisplayLabel) == "function" then
		return ElementsSystem.setControlDisplayLabel(controlKey, label, {
			persist = true,
			source = "experience_binding"
		})
	end
	return false, "Control localization handler unavailable."
end

getControlDisplayLabelInternal = function(idOrFlag)
	local controlKey = trimString(idOrFlag)
	if controlKey == "" then
		return nil
	end

	if LocalizationService and type(LocalizationService.getControlLabel) == "function" then
		local okCall, value = pcall(LocalizationService.getControlLabel, controlKey)
		if okCall and type(value) == "string" and value ~= "" then
			return value
		end
	end

	if ElementsSystem and type(ElementsSystem.getControlDisplayLabel) == "function" then
		local okCall, value = pcall(ElementsSystem.getControlDisplayLabel, controlKey)
		if okCall and type(value) == "string" and value ~= "" then
			return value
		end
	end

	if ElementsSystem and type(ElementsSystem.getControlRecordByIdOrFlag) == "function" then
		local okRecord, record = pcall(ElementsSystem.getControlRecordByIdOrFlag, controlKey)
		if okRecord and type(record) == "table" then
			return tostring(record.DisplayName or record.Name or "")
		end
	end
	return nil
end

resetControlDisplayLabelInternal = function(idOrFlag, options)
	options = type(options) == "table" and options or {}
	local controlKey = trimString(idOrFlag)
	if controlKey == "" then
		return false, "Control key is required."
	end
	local shouldPersist = options.persist ~= false

	if not shouldPersist and ElementsSystem and type(ElementsSystem.resetControlDisplayLabel) == "function" then
		return ElementsSystem.resetControlDisplayLabel(controlKey, {
			persist = false,
			source = "experience_binding_temporary"
		})
	end

	if shouldPersist and LocalizationService and type(LocalizationService.resetControlLabel) == "function" then
		local okCall, okReset, resultMessage = pcall(LocalizationService.resetControlLabel, controlKey)
		if not okCall then
			return false, tostring(okReset)
		end
		if okReset ~= true then
			return false, tostring(resultMessage or "Failed to reset control display label.")
		end
		if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
			pcall(SettingsSystem.saveSettings)
		end
		return true, "Control display label reset."
	end

	if ElementsSystem and type(ElementsSystem.resetControlDisplayLabel) == "function" then
		return ElementsSystem.resetControlDisplayLabel(controlKey, {
			persist = true,
			source = "experience_binding"
		})
	end
	return false, "Control localization handler unavailable."
end

setSystemDisplayLabelInternal = function(key, label)
	local stringKey = trimString(key)
	if stringKey == "" then
		return false, "System localization key is required."
	end
	if not (LocalizationService and type(LocalizationService.setSystemLabel) == "function") then
		return false, "System localization handler unavailable."
	end

	local okCall, okSet, resultMessage = pcall(LocalizationService.setSystemLabel, stringKey, label)
	if not okCall then
		return false, tostring(okSet)
	end
	if okSet ~= true then
		return false, tostring(resultMessage or "Failed to set system display label.")
	end
	if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
		pcall(SettingsSystem.saveSettings)
	end
	return true, "System display label updated."
end

getSystemDisplayLabelInternal = function(key)
	local stringKey = trimString(key)
	if stringKey == "" then
		return nil
	end
	if LocalizationService and type(LocalizationService.getSystemLabel) == "function" then
		local okCall, value = pcall(LocalizationService.getSystemLabel, stringKey)
		if okCall and type(value) == "string" and value ~= "" then
			return value
		end
	end
	return localizeString(stringKey, stringKey)
end

resetDisplayLanguageInternal = function(options)
	options = type(options) == "table" and options or {}
	if not (LocalizationService and type(LocalizationService.resetAllToEnglish) == "function") then
		return false, "Localization reset handler unavailable."
	end

	local okCall, okReset, message = pcall(LocalizationService.resetAllToEnglish)
	if not okCall then
		return false, tostring(okReset)
	end
	if okReset ~= true then
		return false, tostring(message or "Failed to reset localization.")
	end

	local nextLanguageTag = trimString(options.languageTag)
	if nextLanguageTag ~= "" and nextLanguageTag ~= "en" and type(LocalizationService.setLanguageTag) == "function" then
		pcall(LocalizationService.setLanguageTag, nextLanguageTag)
	end
	if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
		pcall(SettingsSystem.saveSettings)
	end
	return true, tostring(message or "Localization reset to English.")
end

getLocalizationStateInternal = function()
	if LocalizationService and type(LocalizationService.getState) == "function" then
		local okCall, state = pcall(LocalizationService.getState)
		if okCall and type(state) == "table" then
			return state
		end
	end
	return {
		scopeMode = "unavailable",
		scopeKey = "",
		scopePath = "",
		meta = {
			languageTag = "en"
		},
		controlLabelCount = 0,
		systemLabelCount = 0
	}
end

setLocalizationLanguageTagInternal = function(languageTag)
	if not (LocalizationService and type(LocalizationService.setLanguageTag) == "function") then
		return false, "Localization language handler unavailable."
	end
	local okCall, okSet, resolved = pcall(LocalizationService.setLanguageTag, languageTag)
	if not okCall then
		return false, tostring(okSet)
	end
	if okSet ~= true then
		return false, tostring(resolved or "Failed to set language tag.")
	end
	if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
		pcall(SettingsSystem.saveSettings)
	end
	return true, tostring(resolved or "en")
end

exportLocalizationInternal = function(options)
	if not (LocalizationService and type(LocalizationService.exportScopePack) == "function") then
		return false, "Localization export handler unavailable."
	end
	local okCall, okExport, payloadOrErr = pcall(LocalizationService.exportScopePack, options)
	if not okCall then
		return false, tostring(okExport)
	end
	if okExport ~= true then
		return false, tostring(payloadOrErr or "Failed to export localization pack.")
	end
	return true, payloadOrErr
end

importLocalizationInternal = function(payload, options)
	if not (LocalizationService and type(LocalizationService.importScopePack) == "function") then
		return false, "Localization import handler unavailable."
	end
	local okCall, okImport, message = pcall(LocalizationService.importScopePack, payload, options)
	if not okCall then
		return false, tostring(okImport)
	end
	if okImport ~= true then
		return false, tostring(message or "Failed to import localization pack.")
	end
	if SettingsSystem and type(SettingsSystem.saveSettings) == "function" then
		pcall(SettingsSystem.saveSettings)
	end
	return true, tostring(message or "Localization imported.")
end

localizeStringInternal = function(key, fallback)
	return localizeString(key, fallback)
end

function ensureOnboardingOverlay()
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

ExperienceBindings = ExperienceBindingsLib.bind({
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
	openFavoritesTab = openFavoritesTab,
	saveWorkspaceInternal = saveWorkspaceInternal,
	loadWorkspaceInternal = loadWorkspaceInternal,
	listWorkspacesInternal = listWorkspacesInternal,
	deleteWorkspaceInternal = deleteWorkspaceInternal,
	saveProfileInternal = saveProfileInternal,
	loadProfileInternal = loadProfileInternal,
	listProfilesInternal = listProfilesInternal,
	deleteProfileInternal = deleteProfileInternal,
	copyWorkspaceToProfileInternal = copyWorkspaceToProfileInternal,
	copyProfileToWorkspaceInternal = copyProfileToWorkspaceInternal,
	setCommandPaletteExecutionModeInternal = setCommandPaletteExecutionModeInternal,
	getCommandPaletteExecutionModeInternal = getCommandPaletteExecutionModeInternal,
	setCommandPalettePolicyInternal = setCommandPalettePolicyInternal,
	runCommandPaletteItemInternal = runCommandPaletteItemInternal,
	openPerformanceHUDInternal = openPerformanceHUDInternal,
	closePerformanceHUDInternal = closePerformanceHUDInternal,
	togglePerformanceHUDInternal = togglePerformanceHUDInternal,
	resetPerformanceHUDInternal = resetPerformanceHUDInternal,
	configurePerformanceHUDInternal = configurePerformanceHUDInternal,
	getPerformanceHUDStateInternal = getPerformanceHUDStateInternal,
	registerHUDMetricProviderInternal = registerHUDMetricProviderInternal,
	unregisterHUDMetricProviderInternal = unregisterHUDMetricProviderInternal,
	setControlDisplayLabelInternal = setControlDisplayLabelInternal,
	getControlDisplayLabelInternal = getControlDisplayLabelInternal,
	resetControlDisplayLabelInternal = resetControlDisplayLabelInternal,
	setSystemDisplayLabelInternal = setSystemDisplayLabelInternal,
	getSystemDisplayLabelInternal = getSystemDisplayLabelInternal,
	resetDisplayLanguageInternal = resetDisplayLanguageInternal,
	getLocalizationStateInternal = getLocalizationStateInternal,
	setLocalizationLanguageTagInternal = setLocalizationLanguageTagInternal,
	exportLocalizationInternal = exportLocalizationInternal,
	importLocalizationInternal = importLocalizationInternal,
	localizeStringInternal = localizeStringInternal,
	getUsageAnalyticsInternal = getUsageAnalyticsInternal,
	clearUsageAnalyticsInternal = clearUsageAnalyticsInternal,
	startMacroRecordingInternal = startMacroRecordingInternal,
	stopMacroRecordingInternal = stopMacroRecordingInternal,
	cancelMacroRecordingInternal = cancelMacroRecordingInternal,
	isMacroRecordingInternal = isMacroRecordingInternal,
	isMacroExecutingInternal = isMacroExecutingInternal,
	listMacrosInternal = listMacrosInternal,
	deleteMacroInternal = deleteMacroInternal,
	executeMacroInternal = executeMacroInternal,
	bindMacroInternal = bindMacroInternal,
	registerDiscoveryProviderInternal = registerDiscoveryProviderInternal,
	unregisterDiscoveryProviderInternal = unregisterDiscoveryProviderInternal,
	queryDiscoveryInternal = queryDiscoveryInternal,
	executePromptCommandInternal = executePromptCommandInternal,
	askAssistantInternal = askAssistantInternal,
	getAssistantHistoryInternal = getAssistantHistoryInternal,
	sendGlobalSignalInternal = sendGlobalSignalInternal,
	sendInternalChatInternal = sendInternalChatInternal,
	pollBridgeMessagesInternal = pollBridgeMessagesInternal,
	startBridgePollingInternal = startBridgePollingInternal,
	stopBridgePollingInternal = stopBridgePollingInternal,
	getBridgeMessagesInternal = getBridgeMessagesInternal,
	scheduleMacroInternal = scheduleMacroInternal,
	scheduleAutomationActionInternal = scheduleAutomationActionInternal,
	cancelScheduledActionInternal = cancelScheduledActionInternal,
	listScheduledActionsInternal = listScheduledActionsInternal,
	clearScheduledActionsInternal = clearScheduledActionsInternal,
	addAutomationRuleInternal = addAutomationRuleInternal,
	removeAutomationRuleInternal = removeAutomationRuleInternal,
	listAutomationRulesInternal = listAutomationRulesInternal,
	setAutomationRuleEnabledInternal = setAutomationRuleEnabledInternal,
	evaluateAutomationRulesInternal = evaluateAutomationRulesInternal,
	registerHubMetadataInternal = registerHubMetadataInternal,
	getHubMetadataInternal = getHubMetadataInternal,
	setElementInspectorEnabledInternal = setElementInspectorEnabledInternal,
	isElementInspectorEnabledInternal = isElementInspectorEnabledInternal,
	inspectElementAtPointerInternal = inspectElementAtPointerInternal,
	openLiveThemeEditorInternal = openLiveThemeEditorInternal,
	closeLiveThemeEditorInternal = function()
		return DevExperienceService.closeLiveThemeEditor()
	end,
	setLiveThemeValueInternal = setLiveThemeValueInternal,
	getLiveThemeDraftInternal = function()
		return DevExperienceService.getLiveThemeDraft()
	end,
	applyLiveThemeDraftInternal = applyLiveThemeDraftInternal,
	exportLiveThemeLuaInternal = exportLiveThemeLuaInternal,
	uiEventModules = {
		RuntimeBindingsUXLib,
		RuntimeBindingsThemeLib,
		RuntimeBindingsFavoritesLib,
		RuntimeBindingsDiscoveryLib,
		RuntimeBindingsDiagnosticsLib,
		RuntimeBindingsLocalizationLib
	},
	movementEventModules = {
		RuntimeBindingsAudioLib,
		RuntimeBindingsPersistenceLib
	},
	combatEventModules = {
		RuntimeBindingsAutomationLib,
		RuntimeBindingsAIAssistantLib,
		RuntimeBindingsCommunicationLib
	},
	bindingModules = {
		RuntimeBindingsUIEventsLib,
		RuntimeBindingsMovementEventsLib,
		RuntimeBindingsCombatEventsLib
	},
	openSettingsTabInternal = function()
		return openSettingsTabFromTopbar()
	end
})

if type(RayfieldLibrary.SetOnboardingSuppressed) ~= "function" then
	function RayfieldLibrary:SetOnboardingSuppressed(value)
		ExperienceState.onboardingSuppressed = value == true
		setSettingValue("Onboarding", "suppressed", ExperienceState.onboardingSuppressed, true)
		return true, ExperienceState.onboardingSuppressed and "Onboarding suppressed." or "Onboarding enabled."
	end
end

if type(RayfieldLibrary.IsOnboardingSuppressed) ~= "function" then
	function RayfieldLibrary:IsOnboardingSuppressed()
		return ExperienceState.onboardingSuppressed == true
	end
end

if type(RayfieldLibrary.ShowOnboarding) ~= "function" then
	function RayfieldLibrary:ShowOnboarding(force)
		if ExperienceState.onboardingSuppressed and force ~= true then
			return false, "Onboarding is suppressed."
		end
		local overlayRef = ensureOnboardingOverlay()
		if not overlayRef or not overlayRef.Root then
			return false, "Onboarding UI unavailable."
		end
		overlayRef.State.step = 1
		overlayRef.State.dontShowAgain = false
		overlayRef.Render()
		overlayRef.Root.Visible = true
		ExperienceState.onboardingRendered = true
		return true, "Onboarding shown."
	end
end

function restoreExperienceStateFromSettings(windowRef)
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

function ensureOwnershipSystem()
	if not OwnershipSystem then
		return false, "Ownership tracker is unavailable."
	end
	return true
end

function sanitizeScopeName(rawName)
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

function shallowArrayCopy(input)
	local out = {}
	if type(input) ~= "table" then
		return out
	end
	for index, value in ipairs(input) do
		out[index] = value
	end
	return out
end

function normalizeProfileMode(mode)
	if type(mode) ~= "string" then
		return "auto"
	end
	local normalized = string.lower(mode)
	if normalized == "auto" or normalized == "potato" or normalized == "mobile" or normalized == "normal" then
		return normalized
	end
	return "auto"
end

function mergeTable(target, source)
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

function applyPresetFillNil(target, preset, appliedFields, pathPrefix)
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

function buildLowSpecPreset(resolvedMode, aggressive, profileSettings)
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

function resolvePerformanceProfile(Settings, runtimeCtx)
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
	local performanceModeEnabled = type(Settings) == "table" and Settings.PerformanceMode == true
	if performanceModeEnabled then
		if type(profile) ~= "table" then
			profile = {}
		end
		if profile.Enabled == nil then
			profile.Enabled = true
		end
		if profile.Mode == nil then
			profile.Mode = "potato"
		end
		if profile.Aggressive == nil then
			profile.Aggressive = true
		end
		if profile.DisableDetach == nil then
			profile.DisableDetach = true
		end
		if profile.DisableTabSplit == nil then
			profile.DisableTabSplit = true
		end
		if profile.DisableAnimations == nil then
			profile.DisableAnimations = true
		end
		if type(profile.ViewportVirtualization) ~= "table" then
			profile.ViewportVirtualization = {}
		end
		if profile.ViewportVirtualization.Enabled == nil then
			profile.ViewportVirtualization.Enabled = true
		end
		if profile.ViewportVirtualization.AlwaysOn == nil then
			profile.ViewportVirtualization.AlwaysOn = true
		end
		if profile.ViewportVirtualization.FullSuspend == nil then
			profile.ViewportVirtualization.FullSuspend = true
		end
		if profile.ViewportVirtualization.FadeOnScroll == nil then
			profile.ViewportVirtualization.FadeOnScroll = false
		end
		if profile.ViewportVirtualization.DisableFadeDuringResize == nil then
			profile.ViewportVirtualization.DisableFadeDuringResize = true
		end
		if profile.ViewportVirtualization.OverscanPx == nil then
			profile.ViewportVirtualization.OverscanPx = 80
		end
		if profile.ViewportVirtualization.UpdateHz == nil then
			profile.ViewportVirtualization.UpdateHz = 16
		end
		if profile.ViewportVirtualization.ResizeDebounceMs == nil then
			profile.ViewportVirtualization.ResizeDebounceMs = 140
		end
		Settings.PerformanceProfile = profile
	end
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

function applySystemOverridesForProfile(profile)
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
	if Settings.PerformanceMode == true then
		if Settings.FastLoad == nil then
			Settings.FastLoad = true
		end
		if Settings.DisableRayfieldPrompts == nil then
			Settings.DisableRayfieldPrompts = true
		end
		if Settings.DisableBuildWarnings == nil then
			Settings.DisableBuildWarnings = true
		end
	end
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

	local function setupMainResizeHandle()
		if not (Main and UserInputService) then
			return
		end

		local handle = Main:FindFirstChild("ResizeHandle")
		local handleStroke = nil
		local handleIndicator = nil
		if not handle then
			handle = Instance.new("TextButton")
			handle.Name = "ResizeHandle"
			handle.AnchorPoint = Vector2.new(1, 1)
			handle.Position = UDim2.new(1, -8, 1, -8)
			handle.Size = UDim2.fromOffset(18, 18)
			handle.BorderSizePixel = 0
			handle.AutoButtonColor = false
			handle.Text = ""
			handle.ZIndex = 25
			handle.Parent = Main

			local handleCorner = Instance.new("UICorner")
			handleCorner.CornerRadius = UDim.new(0, 5)
			handleCorner.Parent = handle

			handleStroke = Instance.new("UIStroke")
			handleStroke.Name = "Stroke"
			handleStroke.Thickness = 1
			handleStroke.Transparency = 0.18
			handleStroke.Parent = handle

			handleIndicator = Instance.new("TextLabel")
			handleIndicator.Name = "Indicator"
			handleIndicator.BackgroundTransparency = 1
			handleIndicator.Size = UDim2.new(1, -2, 1, -2)
			handleIndicator.Position = UDim2.fromOffset(1, 1)
			handleIndicator.Font = Enum.Font.Code
			handleIndicator.TextSize = 11
			handleIndicator.Text = "//"
			handleIndicator.TextXAlignment = Enum.TextXAlignment.Center
			handleIndicator.TextYAlignment = Enum.TextYAlignment.Center
			handleIndicator.ZIndex = 26
			handleIndicator.Parent = handle
		else
			handleStroke = handle:FindFirstChild("Stroke")
			handleIndicator = handle:FindFirstChild("Indicator")
		end

		if bindTheme and type(bindTheme) == "function" then
			pcall(bindTheme, handle, "BackgroundColor3", "SecondaryElementBackground")
			if handleStroke then
				pcall(bindTheme, handleStroke, "Color", "ElementStroke")
			end
			if handleIndicator then
				pcall(bindTheme, handleIndicator, "TextColor3", "TextColor")
			end
		else
			handle.BackgroundColor3 = Color3.fromRGB(44, 52, 66)
			if handleStroke then
				handleStroke.Color = Color3.fromRGB(140, 150, 170)
			end
			if handleIndicator then
				handleIndicator.TextColor3 = Color3.fromRGB(230, 235, 245)
			end
		end

		local function clampResizeTarget(width, height)
			local minWidth = 320
			local minHeight = useMobileSizing and 170 or 220
			local clampedWidth = math.max(minWidth, math.floor(tonumber(width) or minWidth))
			local clampedHeight = math.max(minHeight, math.floor(tonumber(height) or minHeight))
			local parentGui = Main.Parent
			if parentGui and parentGui.AbsoluteSize then
				local viewport = parentGui.AbsoluteSize
				if viewport.X > 0 then
					clampedWidth = math.min(clampedWidth, math.max(minWidth, viewport.X - 24))
				end
				if viewport.Y > 0 then
					clampedHeight = math.min(clampedHeight, math.max(minHeight, viewport.Y - 24))
				end
			end
			return clampedWidth, clampedHeight
		end

		local function applyResizeTarget(width, height)
			local nextWidth, nextHeight = clampResizeTarget(width, height)
			Main.Size = UDim2.fromOffset(nextWidth, nextHeight)
			if Topbar then
				Topbar.Size = UDim2.fromOffset(nextWidth, 45)
			end
			if UIStateSystem and type(UIStateSystem.setExpandedSize) == "function" then
				pcall(UIStateSystem.setExpandedSize, {
					width = nextWidth,
					height = nextHeight
				})
			end
			markLayoutDirty("main", "resize_drag")
		end

		local function canResizeNow()
			if Hidden == true or Minimised == true then
				return false
			end
			if Main.Visible ~= true then
				return false
			end
			if UIStateSystem and type(UIStateSystem.getDebounce) == "function" and UIStateSystem.getDebounce() then
				return false
			end
			return true
		end

		refreshMainResizeHandleVisibility = function()
			if handle and handle.Parent then
				handle.Visible = canResizeNow()
			end
		end
		refreshMainResizeHandleVisibility()

		local resizing = false
		local resizeStartPointer = nil
		local resizeStartSize = nil

		handle.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			if not canResizeNow() then
				return
			end
			local okPointer, pointer = pcall(UserInputService.GetMouseLocation, UserInputService)
			if not okPointer or not pointer then
				return
			end
			resizing = true
			resizeStartPointer = Vector2.new(pointer.X, pointer.Y)
			resizeStartSize = Main.AbsoluteSize
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not resizing then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local okPointer, pointer = pcall(UserInputService.GetMouseLocation, UserInputService)
			if not okPointer or not pointer or not resizeStartPointer or not resizeStartSize then
				return
			end
			local deltaX = pointer.X - resizeStartPointer.X
			local deltaY = pointer.Y - resizeStartPointer.Y
			applyResizeTarget(resizeStartSize.X + deltaX, resizeStartSize.Y + deltaY)
		end)

		UserInputService.InputEnded:Connect(function(input)
			if not resizing then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = false
				resizeStartPointer = nil
				resizeStartSize = nil
				markLayoutDirty("main", "resize_commit")
				refreshMainResizeHandleVisibility()
			end
		end)
	end

	setupMainResizeHandle()

	for _, TabButton in ipairs(TabList:GetChildren()) do
		if TabButton.ClassName == "Frame" and TabButton.Name ~= "Placeholder" then
			TabButton.BackgroundTransparency = 1
			TabButton.Title.TextTransparency = 1
			TabButton.Image.ImageTransparency = 1
			TabButton.UIStroke.Transparency = 1
		end
	end

	if type(DiscordInviteSystem) == "table" and type(DiscordInviteSystem.handle) == "function" then
		local okDiscordInvite, discordInviteErr = pcall(DiscordInviteSystem.handle, Settings, {
			useStudio = useStudio
		})
		if not okDiscordInvite then
			warn("Rayfield Mod: [W_DISCORD_INVITE_RUNTIME] " .. tostring(discordInviteErr))
		end
	end

	if Settings.KeySystem then
		local okKeyRuntime, keyRuntimeOrErr = pcall(KeySystemRuntime.handle, Settings, {
			useStudio = useStudio,
			scriptRef = script,
			compatibility = Compatibility,
			rayfield = Rayfield,
			rayfieldLibrary = RayfieldLibrary,
			setPassthrough = function(value)
				Passthrough = value == true
			end
		})
		if not okKeyRuntime then
			warn("Rayfield Mod: [W_KEY_SYSTEM_RUNTIME] " .. tostring(keyRuntimeOrErr))
			Passthrough = true
		elseif type(keyRuntimeOrErr) == "table" and keyRuntimeOrErr.abortWindowCreation == true then
			return
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
		VirtualizationEngineModule = VirtualizationEngineModuleLib,
		VirtualHostManagerModule = VirtualHostManagerModuleLib,
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
		trackElementInteraction = function(payload)
			if UsageAnalyticsService and type(UsageAnalyticsService.trackControlUsage) == "function" then
				pcall(UsageAnalyticsService.trackControlUsage, payload)
			end
			if MacroRecorderService and type(MacroRecorderService.isRecording) == "function" and MacroRecorderService.isRecording() then
				local actionName = tostring(payload and payload.action or "")
				local shouldRecord = actionName == "set" or actionName == "click" or actionName == "touch"
				if not shouldRecord then
					return
				end
				pcall(MacroRecorderService.recordStep, {
					action = "control",
					interaction = tostring(payload and payload.action or "set"),
					controlId = tostring(payload and payload.id or ""),
					tabId = tostring(payload and payload.tabId or ""),
					name = tostring(payload and payload.name or ""),
					value = cloneValue(payload and payload.value)
				})
			end
			if AutomationEngineService and type(AutomationEngineService.evaluateRules) == "function" then
				pcall(AutomationEngineService.evaluateRules, {
					action = tostring(payload and payload.action or ""),
					controlId = tostring(payload and payload.id or ""),
					id = tostring(payload and payload.id or ""),
					tabId = tostring(payload and payload.tabId or ""),
					interaction = tostring(payload and payload.action or ""),
					value = cloneValue(payload and payload.value),
					name = tostring(payload and payload.name or "")
				})
			end
		end,
		trackTabActivation = function(payload)
			if UsageAnalyticsService and type(UsageAnalyticsService.trackTabOpen) == "function" then
				pcall(UsageAnalyticsService.trackTabOpen, payload)
			end
		end,
		resolveControlDisplayLabel = function(record)
			if LocalizationService and type(LocalizationService.resolveControlLabel) == "function" then
				return LocalizationService.resolveControlLabel(record)
			end
			return nil
		end,
		persistControlDisplayLabel = function(record, label)
			if LocalizationService and type(LocalizationService.setControlLabel) == "function" then
				return LocalizationService.setControlLabel(record, label)
			end
			return false, "Localization persistence unavailable."
		end,
		resetControlDisplayLabel = function(record)
			if LocalizationService and type(LocalizationService.resetControlLabel) == "function" then
				return LocalizationService.resetControlLabel(record)
			end
			return false, "Localization reset unavailable."
		end,
		localizeSystemString = localizeString,
		DataGridFactoryModule = getLoadedRuntimeModule("elementsDataGridFactory"),
		ResolveDataGridFactory = resolveDataGridFactoryModule,
		ChartFactoryModule = getLoadedRuntimeModule("elementsChartFactory"),
		ResolveChartFactory = resolveChartFactoryModule,
		GridBuilderModule = getLoadedRuntimeModule("elementsGridBuilder"),
		ResolveGridBuilderModule = resolveGridBuilderModule,
		ChartBuilderModule = getLoadedRuntimeModule("elementsChartBuilder"),
		ResolveChartBuilderModule = resolveChartBuilderModule,
		RangeBarsFactoryModule = getLoadedRuntimeModule("elementsRangeBarsFactory"),
		ResolveRangeBarsFactoryModule = resolveRangeBarsFactoryModule,
		FeedbackWidgetsFactoryModule = getLoadedRuntimeModule("elementsFeedbackWidgetsFactory"),
		ResolveFeedbackWidgetsFactoryModule = resolveFeedbackWidgetsFactoryModule,
		ButtonFactoryModule = getLoadedRuntimeModule("elementsButtonFactory"),
		ResolveButtonFactory = resolveButtonFactoryModule,
		InputFactoryModule = getLoadedRuntimeModule("elementsInputFactory"),
		ResolveInputFactory = resolveInputFactoryModule,
		DropdownFactoryModule = getLoadedRuntimeModule("elementsDropdownFactory"),
		ResolveDropdownFactory = resolveDropdownFactoryModule,
		KeybindFactoryModule = getLoadedRuntimeModule("elementsKeybindFactory"),
		ResolveKeybindFactory = resolveKeybindFactoryModule,
		ToggleFactoryModule = getLoadedRuntimeModule("elementsToggleFactory"),
		ResolveToggleFactory = resolveToggleFactoryModule,
		SliderFactoryModule = getLoadedRuntimeModule("elementsSliderFactory"),
		ResolveSliderFactory = resolveSliderFactoryModule,
		TabManagerModule = getLoadedRuntimeModule("elementsTabManager"),
		ResolveTabManagerModule = resolveTabManagerModule,
		HoverProviderModule = getLoadedRuntimeModule("elementsHoverProvider"),
		ResolveHoverProviderModule = resolveHoverProviderModule,
		TooltipEngineModule = getLoadedRuntimeModule("elementsTooltipEngine"),
		ResolveTooltipEngineModule = resolveTooltipEngineModule,
		TooltipProviderModule = getLoadedRuntimeModule("elementsTooltipProvider"),
		ResolveTooltipProviderModule = resolveTooltipProviderModule,
		LoggingProviderModule = getLoadedRuntimeModule("elementsLoggingProvider"),
		ResolveLoggingProviderModule = resolveLoggingProviderModule,
		WidgetAPIInjectorModule = getLoadedRuntimeModule("elementsWidgetAPIInjector"),
		ResolveWidgetAPIInjectorModule = resolveWidgetAPIInjectorModule,
		MathUtilsModule = getLoadedRuntimeModule("elementsMathUtils"),
		ResolveMathUtilsModule = resolveMathUtilsModule,
		ResourceGuardModule = getLoadedRuntimeModule("elementsResourceGuard"),
		ResolveResourceGuardModule = resolveResourceGuardModule,
		SectionFactoryModule = getLoadedRuntimeModule("elementsSectionFactory"),
		ResolveSectionFactoryModule = resolveSectionFactoryModule,
		ControlRegistryModule = getLoadedRuntimeModule("elementsControlRegistry"),
		ResolveControlRegistryModule = resolveControlRegistryModule,
		ComponentWidgetsFactoryModule = getLoadedRuntimeModule("elementsComponentWidgetsFactory"),
		ResolveComponentWidgetsFactoryModule = resolveComponentWidgetsFactoryModule,
		showContextMenu = function(items, anchor)
			if UIStateSystem and type(UIStateSystem.ShowContextMenu) == "function" then
				return UIStateSystem.ShowContextMenu(items, anchor)
			end
			return false, "Context menu unavailable."
		end,
		hideContextMenu = function()
			if UIStateSystem and type(UIStateSystem.HideContextMenu) == "function" then
				return UIStateSystem.HideContextMenu()
			end
			return false, "Context menu unavailable."
		end,
		useMobileSizing = useMobileSizing,
		ElementSync = ElementSyncSystem,
		ViewportVirtualization = ViewportVirtualizationSystem,
		ResourceOwnership = OwnershipSystem,
		Settings = Settings
	})
	if LocalizationService and type(LocalizationService.applyControlLabelsToUi) == "function" then
		pcall(LocalizationService.applyControlLabelsToUi)
	end
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

setVisibility = function(visibility, notify)
	VisibilityController.SetVisibility(visibility, notify)
end

local hideHotkeyConnection -- Has to be initialized here since the connection is made later in the script
function destroyRuntime()
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
	if PerformanceHUDService and type(PerformanceHUDService.destroy) == "function" then
		pcall(PerformanceHUDService.destroy)
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

function isRuntimeDestroyed()
	if rayfieldDestroyed then
		return true
	end
	local ok, parent = pcall(function()
		return Rayfield.Parent
	end)
	return (not ok) or parent == nil
end

function configureRuntimeInternal(optionsTable)
	if type(ApiClient) ~= "table" or type(ApiClient.configureRuntime) ~= "function" then
		return false, "Runtime config client is unavailable."
	end
	local okConfigure, configureResult = pcall(ApiClient.configureRuntime, optionsTable)
	if not okConfigure then
		return false, tostring(configureResult)
	end
	if configureResult == false then
		return false, "Runtime config update rejected."
	end

	if type(ApiClient.getRuntimeConfig) == "function" then
		local okSnapshot, snapshot = pcall(ApiClient.getRuntimeConfig)
		if okSnapshot and type(snapshot) == "table" then
			LegacyRuntimeConfig = snapshot
			if type(snapshot.runtimeRootUrl) == "string" and snapshot.runtimeRootUrl ~= "" then
				MODULE_ROOT_URL = snapshot.runtimeRootUrl
				if type(_G) == "table" then
					_G.__RAYFIELD_RUNTIME_ROOT_URL = snapshot.runtimeRootUrl
				end
			end
		end
	end
	return true
end

function getRuntimeConfigInternal()
	if type(ApiClient) == "table" and type(ApiClient.getRuntimeConfig) == "function" then
		local okSnapshot, snapshot = pcall(ApiClient.getRuntimeConfig)
		if okSnapshot and type(snapshot) == "table" then
			return snapshot
		end
	end
	return cloneValue(LegacyRuntimeConfig)
end

RuntimeApiLib.bind({
	RayfieldLibrary = RayfieldLibrary,
	setVisibility = setVisibility,
	getHidden = function()
		return Hidden
	end,
	destroyRuntime = destroyRuntime,
	isDestroyed = isRuntimeDestroyed,
	configureRuntime = configureRuntimeInternal,
	getRuntimeConfig = getRuntimeConfigInternal
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
	if type(refreshMainResizeHandleVisibility) == "function" then
		refreshMainResizeHandleVisibility()
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
		task.spawn(openSettingsTabFromTopbar)
	end)

end


Topbar.Hide.MouseButton1Click:Connect(function()
	setVisibility(Hidden, not useMobileSizing)
end)

function buildCanonicalMacroKeybind(input)
	if not input or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return nil
	end
	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.LeftControl
		or keyCode == Enum.KeyCode.RightControl
		or keyCode == Enum.KeyCode.LeftShift
		or keyCode == Enum.KeyCode.RightShift
		or keyCode == Enum.KeyCode.LeftAlt
		or keyCode == Enum.KeyCode.RightAlt then
		return nil
	end

	local tokens = {}
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
		table.insert(tokens, "LeftControl")
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		table.insert(tokens, "LeftShift")
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
		table.insert(tokens, "LeftAlt")
	end
	table.insert(tokens, tostring(keyCode.Name))
	return table.concat(tokens, "+")
end

hideHotkeyConnection = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	local macroBinding = buildCanonicalMacroKeybind(input)
	if macroBinding and type(triggerMacroByKeybindInternal) == "function" then
		local okMacro = select(1, triggerMacroByKeybindInternal(macroBinding, {
			respectDelay = false
		}))
		if okMacro == true then
			return
		end
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

