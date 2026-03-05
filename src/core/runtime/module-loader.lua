local RuntimeModuleLoader = {}

local function createResolver(optionalModuleWithContract, state, key, validatorFn, hint)
	return function()
		local current = state[key]
		if validatorFn(current) then
			return current
		end
		state[key] = optionalModuleWithContract(key, validatorFn, hint)
		return state[key]
	end
end

function RuntimeModuleLoader.create(options)
	options = type(options) == "table" and options or {}
	local optionalModuleWithContract = type(options.optionalModuleWithContract) == "function" and options.optionalModuleWithContract or function()
		return nil
	end

	local state = {}
	local api = {}

	api.resolveDataGridFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsDataGridFactory",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"DataGrid elements will be unavailable."
	)

	api.resolveChartFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsChartFactory",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Chart elements will be unavailable."
	)

	api.resolveButtonFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsButtonFactory",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Button elements will use built-in fallback."
	)

	api.resolveInputFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsInputFactory",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Input elements will use built-in fallback."
	)

	api.resolveDropdownFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsDropdownFactory",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Dropdown elements will use built-in fallback."
	)

	api.resolveKeybindFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsKeybindFactory",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Keybind elements will use built-in fallback."
	)

	api.resolveToggleFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsToggleFactory",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Toggle elements will use built-in fallback."
	)

	api.resolveSliderFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsSliderFactory",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Slider elements will use built-in fallback."
	)

	api.resolveTabManagerModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsTabManager",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Tab manager will use built-in fallback."
	)

	api.resolveHoverProviderModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsHoverProvider",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Hover provider will use built-in fallback."
	)

	api.resolveTooltipEngineModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsTooltipEngine",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Tooltip engine will use built-in fallback."
	)

	api.resolveWidgetAPIInjectorModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsWidgetAPIInjector",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.inject) == "function"
		end,
		"Widget injector will use built-in fallback."
	)

	api.resolveMathUtilsModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsMathUtils",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.clampNumber) == "function"
		end,
		"Math utility helpers will use built-in fallback."
	)

	api.resolveResourceGuardModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsResourceGuard",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Resource guard will use built-in fallback."
	)

	api.resolveSectionFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsSectionFactory",
		function(moduleValue)
			return type(moduleValue) == "table"
				and type(moduleValue.createSection) == "function"
				and type(moduleValue.createCollapsibleSection) == "function"
		end,
		"Section factory will use built-in fallback."
	)

	api.resolveControlRegistryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsControlRegistry",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Control registry will use built-in fallback."
	)

	api.resolveLoggingProviderModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsLoggingProvider",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Element logging provider will use built-in fallback."
	)

	api.resolveTooltipProviderModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsTooltipProvider",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Tooltip provider will use built-in fallback."
	)

	api.resolveGridBuilderModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsGridBuilder",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Grid builder will use direct factory fallback."
	)

	api.resolveChartBuilderModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsChartBuilder",
		function(moduleValue)
			return type(moduleValue) == "table" and type(moduleValue.create) == "function"
		end,
		"Chart builder will use direct factory fallback."
	)

	api.resolveRangeBarsFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsRangeBarsFactory",
		function(moduleValue)
			return type(moduleValue) == "table"
				and type(moduleValue.createTrackBar) == "function"
				and type(moduleValue.createStatusBar) == "function"
		end,
		"Range bar widgets will be unavailable."
	)

	api.resolveFeedbackWidgetsFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsFeedbackWidgetsFactory",
		function(moduleValue)
			return type(moduleValue) == "table"
				and type(moduleValue.createLogConsole) == "function"
				and type(moduleValue.createLoadingSpinner) == "function"
				and type(moduleValue.createLoadingBar) == "function"
		end,
		"Feedback widgets will be unavailable."
	)

	api.resolveComponentWidgetsFactoryModule = createResolver(
		optionalModuleWithContract,
		state,
		"elementsComponentWidgetsFactory",
		function(moduleValue)
			return type(moduleValue) == "table"
				and type(moduleValue.createColorPicker) == "function"
				and type(moduleValue.createNumberStepper) == "function"
				and type(moduleValue.createConfirmButton) == "function"
				and type(moduleValue.createImage) == "function"
				and type(moduleValue.createGallery) == "function"
				and type(moduleValue.createDivider) == "function"
				and type(moduleValue.createLabel) == "function"
				and type(moduleValue.createParagraph) == "function"
		end,
		"Component widgets will use built-in fallback."
	)

	function api.getLoaded(key)
		return state[tostring(key or "")]
	end

	return api
end

return RuntimeModuleLoader
