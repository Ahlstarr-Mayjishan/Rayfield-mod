local function entry(canonical, legacy, studio)
	return {
		canonical = canonical,
		legacy = legacy or canonical,
		studio = studio
	}
end

return {
	theme = entry("src/services/theme.lua", "feature/rayfield-theme.lua", "rayfield-theme"),
	settings = entry("src/services/settings.lua", "feature/rayfield-settings.lua", "rayfield-settings"),
	compatibility = entry("src/services/compatibility.lua", nil, "compatibility"),
	ownershipTracker = entry("src/services/ownership-tracker.lua", nil, "ownership-tracker"),
	elementSync = entry("src/services/element-sync.lua", nil, "element-sync"),
	keybindSequence = entry("src/services/keybind-sequence.lua", nil, "keybind-sequence"),
	layoutPersistence = entry("src/services/layout-persistence.lua", nil, "layout-persistence"),
	viewportVirtualization = entry("src/services/viewport-virtualization.lua", nil, "viewport-virtualization"),
	drag = entry("src/feature/drag/init.lua", "feature/rayfield-drag.lua", "rayfield-drag"),
	uiState = entry("src/core/ui-state.lua", "feature/rayfield-ui-state.lua", "rayfield-ui-state"),
	elements = entry("src/ui/elements/factory/init.lua", "feature/rayfield-elements.lua", "rayfield-elements"),
	elementsExtracted = entry("src/ui/elements/widgets/index.lua", "feature/rayfield-elements-extracted.lua", "rayfield-elements-extracted"),
	widgetsBootstrap = entry("src/ui/elements/widgets/bootstrap.lua", nil, "widgets-bootstrap"),
	config = entry("src/services/config.lua", "feature/rayfield-config.lua", "rayfield-config"),
	utilities = entry("src/services/utilities.lua", "feature/rayfield-utilities.lua", "rayfield-utilities"),
	tabSplit = entry("src/feature/tabsplit/init.lua", "feature/rayfield-tab-split.lua", "rayfield-tab-split"),
	miniWindow = entry("src/feature/mini-window/init.lua", "feature/mini-window-system.lua", "mini-window-system"),
	enhanced = entry("src/feature/enhanced/init.lua", "feature/rayfield-enhanced.lua", "rayfield-enhanced"),
	advanced = entry("src/feature/enhanced/advanced.lua", "feature/rayfield-advanced-features.lua", "rayfield-advanced-features"),
	animationEngine = entry("src/core/animation/engine.lua", nil, "animation-engine"),
	animationPublic = entry("src/core/animation/public.lua", nil, "animation-public"),
	animationSequence = entry("src/core/animation/sequence.lua", nil, "animation-sequence"),
	animationUI = entry("src/core/animation/ui.lua", nil, "animation-ui"),
	animationText = entry("src/core/animation/text.lua", nil, "animation-text"),
	animationEasing = entry("src/core/animation/easing.lua", nil, "animation-easing"),
	animationCleanup = entry("src/core/animation/cleanup.lua", nil, "animation-cleanup"),
	allInOne = entry("src/entry/rayfield-all-in-one.entry.lua", "Main%20loader/rayfield-all-in-one.lua", "rayfield-all-in-one"),
	modifiedEntry = entry("src/entry/rayfield-modified.entry.lua", "Main%20loader/rayfield-modified.lua", "rayfield-modified")
}
