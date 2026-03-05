local RuntimeModuleRegistryLoader = {}

local MODULE_SPECS = {
	{ field = "ThemeModule", module = "theme", mode = "required" },
	{ field = "ThemePresetsModuleLib", module = "themePresets", mode = "required" },
	{ field = "ThemeDefaultThemesModuleLib", module = "themeDefaultThemes", mode = "required" },
	{ field = "UtilitiesModuleLib", module = "utilities", mode = "required" },
	{ field = "SettingsModuleLib", module = "settings", mode = "required" },
	{ field = "SettingsStoreModuleLib", module = "settingsStore", mode = "required" },
	{ field = "SettingsPersistenceModuleLib", module = "settingsPersistence", mode = "required" },
	{ field = "SettingsUIModuleLib", module = "settingsUI", mode = "required" },
	{ field = "SettingsShareCodeModuleLib", module = "settingsShareCode", mode = "required" },
	{
		field = "OwnershipTrackerModuleLib",
		module = "ownershipTracker",
		mode = "optional",
		fallback = "FallbackOwnershipTrackerModule",
		hint = "Scoped ownership cleanup will run in compatibility mode."
	},
	{
		field = "ElementSyncModuleLib",
		module = "elementSync",
		mode = "optional",
		fallback = "FallbackElementSyncModule",
		hint = "Element state sync will run in compatibility mode."
	},
	{ field = "KeybindSequenceLib", module = "keybindSequence", mode = "required" },
	{
		field = "DragModuleLib",
		module = "drag",
		mode = "optional",
		fallback = "FallbackDragModule",
		hint = "Detach/reorder advanced drag features are disabled for this session."
	},
	{ field = "UIStateModuleLib", module = "uiState", mode = "required" },
	{ field = "UIStateNotificationManagerLib", module = "uiStateNotificationManager", mode = "required" },
	{ field = "UIStateSearchEngineLib", module = "uiStateSearchEngine", mode = "required" },
	{ field = "UIStateWindowManagerLib", module = "uiStateWindowManager", mode = "required" },
	{ field = "ElementsModuleLib", module = "elements", mode = "required" },
	{ field = "ConfigModuleLib", module = "config", mode = "required" },
	{ field = "ConfigStorageAdapterModuleLib", module = "configStorageAdapter", mode = "required" },
	{
		field = "LayoutPersistenceModuleLib",
		module = "layoutPersistence",
		mode = "optional",
		fallback = "FallbackLayoutPersistenceModule",
		hint = "Layout persistence is disabled for this session."
	},
	{
		field = "ViewportVirtualizationModuleLib",
		module = "viewportVirtualization",
		mode = "optional",
		fallback = "FallbackViewportVirtualizationModule",
		hint = "Viewport virtualization is disabled for this session."
	},
	{ field = "VirtualizationEngineModuleLib", module = "virtualizationEngine", mode = "required" },
	{ field = "VirtualHostManagerModuleLib", module = "virtualHostManager", mode = "required" },
	{
		field = "TabSplitModuleLib",
		module = "tabSplit",
		mode = "optional",
		fallback = "FallbackTabSplitModule",
		hint = "Tab split features are disabled for this session."
	},
	{ field = "AnimationEngineLib", module = "animationEngine", mode = "required" },
	{ field = "AnimationPublicLib", module = "animationPublic", mode = "required" },
	{ field = "AnimationSequenceLib", module = "animationSequence", mode = "required" },
	{ field = "AnimationUILib", module = "animationUI", mode = "required" },
	{ field = "AnimationTextLib", module = "animationText", mode = "required" },
	{ field = "AnimationCleanupLib", module = "animationCleanup", mode = "required" },
	{ field = "AnimationConstantsLib", module = "animationConstants", mode = "required" },
	{ field = "AnimationSchedulerLib", module = "animationScheduler", mode = "required" },
	{ field = "MainShellModuleLib", module = "uiShellMainShell", mode = "required" },
	{ field = "VisibilityControllerLib", module = "runtimeVisibilityController", mode = "required" },
	{ field = "ExperienceBindingsLib", module = "runtimeExperienceBindings", mode = "required" },
	{ field = "RuntimeBindingsUXLib", module = "runtimeBindingsUX", mode = "required" },
	{ field = "RuntimeBindingsAudioLib", module = "runtimeBindingsAudio", mode = "required" },
	{ field = "RuntimeBindingsThemeLib", module = "runtimeBindingsTheme", mode = "required" },
	{ field = "RuntimeBindingsFavoritesLib", module = "runtimeBindingsFavorites", mode = "required" },
	{ field = "RuntimeBindingsPersistenceLib", module = "runtimeBindingsPersistence", mode = "required" },
	{ field = "RuntimeBindingsDiagnosticsLib", module = "runtimeBindingsDiagnostics", mode = "required" },
	{ field = "RuntimeBindingsAutomationLib", module = "runtimeBindingsAutomation", mode = "required" },
	{ field = "RuntimeBindingsDiscoveryLib", module = "runtimeBindingsDiscovery", mode = "required" },
	{ field = "RuntimeBindingsAIAssistantLib", module = "runtimeBindingsAIAssistant", mode = "required" },
	{ field = "RuntimeBindingsCommunicationLib", module = "runtimeBindingsCommunication", mode = "required" },
	{ field = "RuntimeBindingsLocalizationLib", module = "runtimeBindingsLocalization", mode = "required" },
	{ field = "RuntimeBindingsUIEventsLib", module = "runtimeBindingsUIEvents", mode = "required" },
	{ field = "RuntimeBindingsMovementEventsLib", module = "runtimeBindingsMovementEvents", mode = "required" },
	{ field = "RuntimeBindingsCombatEventsLib", module = "runtimeBindingsCombatEvents", mode = "required" },
	{ field = "WorkspaceServiceLib", module = "runtimeWorkspaceService", mode = "required" },
	{ field = "CommandPaletteServiceLib", module = "runtimeCommandPaletteService", mode = "required" },
	{ field = "CommandPaletteSearchAlgorithmsLib", module = "runtimeCommandPaletteSearchAlgorithms", mode = "required" },
	{ field = "SmartSearchServiceLib", module = "runtimeSmartSearchService", mode = "required" },
	{ field = "MultiInstanceBridgeServiceLib", module = "runtimeMultiInstanceBridgeService", mode = "required" },
	{ field = "AutomationEngineServiceLib", module = "runtimeAutomationEngineService", mode = "required" },
	{ field = "UsageAnalyticsServiceLib", module = "runtimeUsageAnalyticsService", mode = "required" },
	{ field = "MacroRecorderServiceLib", module = "runtimeMacroRecorderService", mode = "required" },
	{ field = "DevExperienceServiceLib", module = "runtimeDevExperienceService", mode = "required" },
	{ field = "LocalizationServiceLib", module = "runtimeLocalizationService", mode = "required" },
	{ field = "UIStringRegistryLib", module = "runtimeUIStringRegistry", mode = "required" },
	{ field = "ShareCodeServiceLib", module = "runtimeShareCodeService", mode = "required" },
	{ field = "EntryDiscordInviteServiceLib", module = "entryDiscordInviteService", mode = "required" },
	{ field = "EntryKeySystemServiceLib", module = "entryKeySystemService", mode = "required" },
	{ field = "RuntimeModuleLoaderLib", module = "runtimeModuleLoader", mode = "required" },
	{ field = "PerformanceHUDServiceLib", module = "runtimePerformanceHUDService", mode = "required" },
	{ field = "RuntimeApiLib", module = "runtimeApi", mode = "required" }
}

-- Tiered module groups for parallel loading.
-- Within each tier, modules are independent and can load concurrently.
-- Each tier waits for all previous tiers to complete before starting.
local MODULE_TIERS = {
	-- Tier 0: Core foundations (needed by everything)
	{
		{ field = "ThemeModule", module = "theme", mode = "required" },
		{ field = "ThemePresetsModuleLib", module = "themePresets", mode = "required" },
		{ field = "ThemeDefaultThemesModuleLib", module = "themeDefaultThemes", mode = "required" },
		{ field = "UtilitiesModuleLib", module = "utilities", mode = "required" },
		{ field = "KeybindSequenceLib", module = "keybindSequence", mode = "required" },
	},
	-- Tier 1: Animation core (no deps on settings/config)
	{
		{ field = "AnimationEngineLib", module = "animationEngine", mode = "required" },
		{ field = "AnimationCleanupLib", module = "animationCleanup", mode = "required" },
		{ field = "AnimationConstantsLib", module = "animationConstants", mode = "required" },
		{ field = "AnimationSchedulerLib", module = "animationScheduler", mode = "required" },
	},
	-- Tier 2: Animation API (needs Tier 1)
	{
		{ field = "AnimationPublicLib", module = "animationPublic", mode = "required" },
		{ field = "AnimationSequenceLib", module = "animationSequence", mode = "required" },
		{ field = "AnimationUILib", module = "animationUI", mode = "required" },
		{ field = "AnimationTextLib", module = "animationText", mode = "required" },
	},
	-- Tier 3: Settings + Config (independent of animation)
	{
		{ field = "SettingsModuleLib", module = "settings", mode = "required" },
		{ field = "SettingsStoreModuleLib", module = "settingsStore", mode = "required" },
		{ field = "SettingsPersistenceModuleLib", module = "settingsPersistence", mode = "required" },
		{ field = "SettingsUIModuleLib", module = "settingsUI", mode = "required" },
		{ field = "SettingsShareCodeModuleLib", module = "settingsShareCode", mode = "required" },
		{ field = "ConfigModuleLib", module = "config", mode = "required" },
		{ field = "ConfigStorageAdapterModuleLib", module = "configStorageAdapter", mode = "required" },
	},
	-- Tier 4: UI Infrastructure (needs theme + utils from Tier 0)
	{
		{ field = "UIStateModuleLib", module = "uiState", mode = "required" },
		{ field = "UIStateNotificationManagerLib", module = "uiStateNotificationManager", mode = "required" },
		{ field = "UIStateSearchEngineLib", module = "uiStateSearchEngine", mode = "required" },
		{ field = "UIStateWindowManagerLib", module = "uiStateWindowManager", mode = "required" },
		{ field = "ElementsModuleLib", module = "elements", mode = "required" },
		{ field = "MainShellModuleLib", module = "uiShellMainShell", mode = "required" },
		{ field = "VirtualizationEngineModuleLib", module = "virtualizationEngine", mode = "required" },
		{ field = "VirtualHostManagerModuleLib", module = "virtualHostManager", mode = "required" },
	},
	-- Tier 5: Features + Optional modules (fully independent)
	{
		{ field = "OwnershipTrackerModuleLib", module = "ownershipTracker", mode = "optional", fallback = "FallbackOwnershipTrackerModule", hint = "Scoped ownership cleanup will run in compatibility mode." },
		{ field = "ElementSyncModuleLib", module = "elementSync", mode = "optional", fallback = "FallbackElementSyncModule", hint = "Element state sync will run in compatibility mode." },
		{ field = "DragModuleLib", module = "drag", mode = "optional", fallback = "FallbackDragModule", hint = "Detach/reorder advanced drag features are disabled for this session." },
		{ field = "LayoutPersistenceModuleLib", module = "layoutPersistence", mode = "optional", fallback = "FallbackLayoutPersistenceModule", hint = "Layout persistence is disabled for this session." },
		{ field = "ViewportVirtualizationModuleLib", module = "viewportVirtualization", mode = "optional", fallback = "FallbackViewportVirtualizationModule", hint = "Viewport virtualization is disabled for this session." },
		{ field = "TabSplitModuleLib", module = "tabSplit", mode = "optional", fallback = "FallbackTabSplitModule", hint = "Tab split features are disabled for this session." },
		{ field = "VisibilityControllerLib", module = "runtimeVisibilityController", mode = "required" },
		{ field = "ExperienceBindingsLib", module = "runtimeExperienceBindings", mode = "required" },
	},
	-- Tier 6: Runtime bindings + services (fully independent)
	{
		{ field = "RuntimeBindingsUXLib", module = "runtimeBindingsUX", mode = "required" },
		{ field = "RuntimeBindingsAudioLib", module = "runtimeBindingsAudio", mode = "required" },
		{ field = "RuntimeBindingsThemeLib", module = "runtimeBindingsTheme", mode = "required" },
		{ field = "RuntimeBindingsFavoritesLib", module = "runtimeBindingsFavorites", mode = "required" },
		{ field = "RuntimeBindingsPersistenceLib", module = "runtimeBindingsPersistence", mode = "required" },
		{ field = "RuntimeBindingsDiagnosticsLib", module = "runtimeBindingsDiagnostics", mode = "required" },
		{ field = "RuntimeBindingsAutomationLib", module = "runtimeBindingsAutomation", mode = "required" },
		{ field = "RuntimeBindingsDiscoveryLib", module = "runtimeBindingsDiscovery", mode = "required" },
		{ field = "RuntimeBindingsAIAssistantLib", module = "runtimeBindingsAIAssistant", mode = "required" },
		{ field = "RuntimeBindingsCommunicationLib", module = "runtimeBindingsCommunication", mode = "required" },
		{ field = "RuntimeBindingsLocalizationLib", module = "runtimeBindingsLocalization", mode = "required" },
		{ field = "RuntimeBindingsUIEventsLib", module = "runtimeBindingsUIEvents", mode = "required" },
		{ field = "RuntimeBindingsMovementEventsLib", module = "runtimeBindingsMovementEvents", mode = "required" },
		{ field = "RuntimeBindingsCombatEventsLib", module = "runtimeBindingsCombatEvents", mode = "required" },
		{ field = "WorkspaceServiceLib", module = "runtimeWorkspaceService", mode = "required" },
		{ field = "CommandPaletteServiceLib", module = "runtimeCommandPaletteService", mode = "required" },
		{ field = "CommandPaletteSearchAlgorithmsLib", module = "runtimeCommandPaletteSearchAlgorithms", mode = "required" },
		{ field = "SmartSearchServiceLib", module = "runtimeSmartSearchService", mode = "required" },
		{ field = "MultiInstanceBridgeServiceLib", module = "runtimeMultiInstanceBridgeService", mode = "required" },
		{ field = "AutomationEngineServiceLib", module = "runtimeAutomationEngineService", mode = "required" },
		{ field = "UsageAnalyticsServiceLib", module = "runtimeUsageAnalyticsService", mode = "required" },
		{ field = "MacroRecorderServiceLib", module = "runtimeMacroRecorderService", mode = "required" },
		{ field = "DevExperienceServiceLib", module = "runtimeDevExperienceService", mode = "required" },
		{ field = "LocalizationServiceLib", module = "runtimeLocalizationService", mode = "required" },
		{ field = "UIStringRegistryLib", module = "runtimeUIStringRegistry", mode = "required" },
		{ field = "ShareCodeServiceLib", module = "runtimeShareCodeService", mode = "required" },
		{ field = "EntryDiscordInviteServiceLib", module = "entryDiscordInviteService", mode = "required" },
		{ field = "EntryKeySystemServiceLib", module = "entryKeySystemService", mode = "required" },
		{ field = "RuntimeModuleLoaderLib", module = "runtimeModuleLoader", mode = "required" },
		{ field = "PerformanceHUDServiceLib", module = "runtimePerformanceHUDService", mode = "required" },
		{ field = "RuntimeApiLib", module = "runtimeApi", mode = "required" },
	},
}

function RuntimeModuleRegistryLoader.load(options)
	options = type(options) == "table" and options or {}
	local requireModule = type(options.requireModule) == "function" and options.requireModule or nil
	local optionalModule = type(options.optionalModule) == "function" and options.optionalModule or nil
	local fallbacks = type(options.fallbacks) == "table" and options.fallbacks or {}

	if not requireModule then
		error("RuntimeModuleRegistryLoader.load requires requireModule")
	end
	if not optionalModule then
		error("RuntimeModuleRegistryLoader.load requires optionalModule")
	end

	local modules = {}
	for _, spec in ipairs(MODULE_SPECS) do
		if spec.mode == "required" then
			modules[spec.field] = requireModule(spec.module)
		else
			modules[spec.field] = optionalModule(spec.module, fallbacks[spec.fallback], spec.hint)
		end
	end
	return modules
end

function RuntimeModuleRegistryLoader.loadParallel(options)
	options = type(options) == "table" and options or {}
	local requireModule = type(options.requireModule) == "function" and options.requireModule or nil
	local optionalModule = type(options.optionalModule) == "function" and options.optionalModule or nil
	local fallbacks = type(options.fallbacks) == "table" and options.fallbacks or {}
	local taskLib = type(options.taskLib) == "table" and options.taskLib or (type(task) == "table" and task or nil)

	if not requireModule then
		error("RuntimeModuleRegistryLoader.loadParallel requires requireModule")
	end
	if not optionalModule then
		error("RuntimeModuleRegistryLoader.loadParallel requires optionalModule")
	end

	-- Fallback to serial if task.spawn is not available
	if not taskLib or type(taskLib.spawn) ~= "function" then
		return RuntimeModuleRegistryLoader.load(options)
	end

	local waitFn = taskLib.wait or function() end
	local modules = {}

	for _, tier in ipairs(MODULE_TIERS) do
		local pending = #tier
		for _, spec in ipairs(tier) do
			taskLib.spawn(function()
				if spec.mode == "required" then
					modules[spec.field] = requireModule(spec.module)
				else
					modules[spec.field] = optionalModule(spec.module, fallbacks[spec.fallback], spec.hint)
				end
				pending = pending - 1
			end)
		end
		-- Wait for entire tier to complete before proceeding to next
		while pending > 0 do
			waitFn()
		end
	end

	return modules
end

return RuntimeModuleRegistryLoader
