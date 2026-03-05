local function row(canonical, legacy, extraLegacy)
	local output = {
		canonical,
		legacy or canonical
	}
	if extraLegacy and extraLegacy ~= "" then
		table.insert(output, extraLegacy)
	end
	return output
end

return {
	theme = row("src/services/theme.lua", "feature/rayfield-theme.lua"),
	settings = row("src/services/settings.lua", "feature/rayfield-settings.lua"),
	compatibility = row("src/services/compatibility.lua"),
	ownershipTracker = row("src/services/ownership-tracker.lua"),
	elementSync = row("src/services/element-sync.lua"),
	keybindSequence = row("src/services/keybind-sequence.lua"),
	layoutPersistence = row("src/services/layout-persistence.lua"),
	viewportVirtualization = row("src/services/viewport-virtualization.lua"),
	config = row("src/services/config.lua", "feature/rayfield-config.lua"),
	utilities = row("src/services/utilities.lua", "feature/rayfield-utilities.lua"),
	uiState = row("src/core/ui-state.lua", "feature/rayfield-ui-state.lua"),
	elements = row("src/ui/elements/factory/init.lua", "feature/rayfield-elements.lua"),
	elementsExtracted = row("src/ui/elements/widgets/index.lua", "feature/rayfield-elements-extracted.lua"),
	widgetsBootstrap = row("src/ui/elements/widgets/bootstrap.lua"),
	drag = row("src/feature/drag/init.lua", "feature/rayfield-drag.lua"),
	tabSplit = row("src/feature/tabsplit/init.lua", "feature/rayfield-tab-split.lua"),
	miniWindow = row("src/feature/mini-window/init.lua", "feature/mini-window-system.lua"),
	enhanced = row("src/feature/enhanced/init.lua", "feature/rayfield-enhanced.lua"),
	advanced = row("src/feature/enhanced/advanced.lua", "feature/rayfield-advanced-features.lua"),
	animationEngine = row("src/core/animation/engine.lua"),
	animationPublic = row("src/core/animation/public.lua"),
	animationSequence = row("src/core/animation/sequence.lua"),
	animationUI = row("src/core/animation/ui.lua"),
	animationText = row("src/core/animation/text.lua"),
	animationEasing = row("src/core/animation/easing.lua"),
	animationCleanup = row("src/core/animation/cleanup.lua"),
	runtimeVisibilityController = row("src/core/runtime/visibility-controller.lua"),
	runtimeExperienceBindings = row("src/core/runtime/experience-bindings.lua"),
	runtimeWorkspaceService = row("src/core/runtime/workspace-service.lua"),
	runtimeCommandPaletteService = row("src/core/runtime/command-palette-service.lua"),
	runtimeSmartSearchService = row("src/core/runtime/smart-search-service.lua"),
	runtimeMultiInstanceBridgeService = row("src/core/runtime/multi-instance-bridge-service.lua"),
	runtimeAutomationEngineService = row("src/core/runtime/automation-engine-service.lua"),
	runtimeUsageAnalyticsService = row("src/core/runtime/usage-analytics-service.lua"),
	runtimeMacroRecorderService = row("src/core/runtime/macro-recorder-service.lua"),
	runtimeDevExperienceService = row("src/core/runtime/dev-experience-service.lua"),
	runtimePerformanceHUDService = row("src/core/runtime/performance-hud-service.lua"),
	runtimeApi = row("src/core/runtime/runtime-api.lua"),
	elementsDataGridFactory = row("src/ui/elements/factory/data-grid.lua"),
	elementsChartFactory = row("src/ui/elements/factory/chart.lua"),
	allInOne = row("src/entry/rayfield-all-in-one.entry.lua", "Main%20loader/rayfield-all-in-one.lua", "feature/rayfield-all-in-one.lua"),
	modifiedEntry = row("src/entry/rayfield-modified.entry.lua", "Main%20loader/rayfield-modified.lua")
}
