local ExperienceBindings = {}

local function fallbackCloneArray(values)
	if type(values) ~= "table" then
		return {}
	end
	local output = {}
	for _, value in ipairs(values) do
		table.insert(output, value)
	end
	return output
end

function ExperienceBindings.bind(context)
	if type(context) ~= "table" then
		error("ExperienceBindings.bind expected context table")
	end

	local RayfieldLibrary = context.RayfieldLibrary
	if type(RayfieldLibrary) ~= "table" then
		error("ExperienceBindings.bind missing RayfieldLibrary")
	end

	local getExperienceState = context.getExperienceState
	if type(getExperienceState) ~= "function" then
		error("ExperienceBindings.bind missing getExperienceState")
	end

	local getElementsSystem = context.getElementsSystem or function()
		return nil
	end
	local getUIStateSystem = context.getUIStateSystem or function()
		return nil
	end

	local setTransitionProfileInternal = context.setTransitionProfileInternal
	local setUIPresetInternal = context.setUIPresetInternal
	local setAudioFeedbackEnabledInternal = context.setAudioFeedbackEnabledInternal
	local setAudioFeedbackPackInternal = context.setAudioFeedbackPackInternal
	local getAudioFeedbackStateSnapshot = context.getAudioFeedbackStateSnapshot
	local playUICueInternal = context.playUICueInternal
	local setGlassModeInternal = context.setGlassModeInternal
	local setGlassIntensityInternal = context.setGlassIntensityInternal
	local setSettingValue = context.setSettingValue
	local ensureOnboardingOverlay = context.ensureOnboardingOverlay
	local setThemeStudioBaseTheme = context.setThemeStudioBaseTheme
	local applyThemeStudioState = context.applyThemeStudioState
	local resetThemeStudioState = context.resetThemeStudioState
	local cloneValue = context.cloneValue or function(value)
		return value
	end
	local cloneArray = context.cloneArray or fallbackCloneArray
	local color3ToPacked = context.color3ToPacked
	local packedToColor3 = context.packedToColor3
	local normalizeAudioPackName = context.normalizeAudioPackName
	local cloneAudioPack = context.cloneAudioPack or function(value)
		return value
	end
	local syncAudioCueSounds = context.syncAudioCueSounds or function() end
	local setAudioFeedbackVolumeInternal = context.setAudioFeedbackVolumeInternal
	local getThemeStudioColor = context.getThemeStudioColor
	local setThemeStudioUseCustom = context.setThemeStudioUseCustom
	local setThemeStudioColor = context.setThemeStudioColor
	local listThemeNames = context.listThemeNames
	local getSetting = context.getSetting
	local HttpService = context.HttpService
	local ThemeModule = context.ThemeModule or {}
	local THEME_STUDIO_KEYS = context.themeStudioKeys or {}
	local refreshFavoritesSettingsPersistence = context.refreshFavoritesSettingsPersistence
	local ensureFavoritesTab = context.ensureFavoritesTab
	local renderFavoritesTab = context.renderFavoritesTab
	local openFavoritesTab = context.openFavoritesTab
	local SettingsSystem = context.SettingsSystem
	local saveWorkspaceInternal = context.saveWorkspaceInternal
	local loadWorkspaceInternal = context.loadWorkspaceInternal
	local listWorkspacesInternal = context.listWorkspacesInternal
	local deleteWorkspaceInternal = context.deleteWorkspaceInternal
	local saveProfileInternal = context.saveProfileInternal
	local loadProfileInternal = context.loadProfileInternal
	local listProfilesInternal = context.listProfilesInternal
	local deleteProfileInternal = context.deleteProfileInternal
	local copyWorkspaceToProfileInternal = context.copyWorkspaceToProfileInternal
	local copyProfileToWorkspaceInternal = context.copyProfileToWorkspaceInternal
	local setCommandPaletteExecutionModeInternal = context.setCommandPaletteExecutionModeInternal
	local getCommandPaletteExecutionModeInternal = context.getCommandPaletteExecutionModeInternal
	local setCommandPalettePolicyInternal = context.setCommandPalettePolicyInternal
	local runCommandPaletteItemInternal = context.runCommandPaletteItemInternal
	local openPerformanceHUDInternal = context.openPerformanceHUDInternal
	local closePerformanceHUDInternal = context.closePerformanceHUDInternal
	local togglePerformanceHUDInternal = context.togglePerformanceHUDInternal
	local resetPerformanceHUDInternal = context.resetPerformanceHUDInternal
	local configurePerformanceHUDInternal = context.configurePerformanceHUDInternal
	local getPerformanceHUDStateInternal = context.getPerformanceHUDStateInternal
	local registerHUDMetricProviderInternal = context.registerHUDMetricProviderInternal
	local unregisterHUDMetricProviderInternal = context.unregisterHUDMetricProviderInternal
	local setControlDisplayLabelInternal = context.setControlDisplayLabelInternal
	local getControlDisplayLabelInternal = context.getControlDisplayLabelInternal
	local resetControlDisplayLabelInternal = context.resetControlDisplayLabelInternal
	local setSystemDisplayLabelInternal = context.setSystemDisplayLabelInternal
	local getSystemDisplayLabelInternal = context.getSystemDisplayLabelInternal
	local resetDisplayLanguageInternal = context.resetDisplayLanguageInternal
	local getLocalizationStateInternal = context.getLocalizationStateInternal
	local setLocalizationLanguageTagInternal = context.setLocalizationLanguageTagInternal
	local exportLocalizationInternal = context.exportLocalizationInternal
	local importLocalizationInternal = context.importLocalizationInternal
	local localizeStringInternal = context.localizeStringInternal
	local openSettingsTabInternal = context.openSettingsTabInternal
	local getUsageAnalyticsInternal = context.getUsageAnalyticsInternal
	local clearUsageAnalyticsInternal = context.clearUsageAnalyticsInternal
	local startMacroRecordingInternal = context.startMacroRecordingInternal
	local stopMacroRecordingInternal = context.stopMacroRecordingInternal
	local cancelMacroRecordingInternal = context.cancelMacroRecordingInternal
	local isMacroRecordingInternal = context.isMacroRecordingInternal
	local isMacroExecutingInternal = context.isMacroExecutingInternal
	local listMacrosInternal = context.listMacrosInternal
	local deleteMacroInternal = context.deleteMacroInternal
	local executeMacroInternal = context.executeMacroInternal
	local bindMacroInternal = context.bindMacroInternal
	local registerDiscoveryProviderInternal = context.registerDiscoveryProviderInternal
	local unregisterDiscoveryProviderInternal = context.unregisterDiscoveryProviderInternal
	local queryDiscoveryInternal = context.queryDiscoveryInternal
	local executePromptCommandInternal = context.executePromptCommandInternal
	local askAssistantInternal = context.askAssistantInternal
	local getAssistantHistoryInternal = context.getAssistantHistoryInternal
	local sendGlobalSignalInternal = context.sendGlobalSignalInternal
	local sendInternalChatInternal = context.sendInternalChatInternal
	local pollBridgeMessagesInternal = context.pollBridgeMessagesInternal
	local startBridgePollingInternal = context.startBridgePollingInternal
	local stopBridgePollingInternal = context.stopBridgePollingInternal
	local getBridgeMessagesInternal = context.getBridgeMessagesInternal
	local scheduleMacroInternal = context.scheduleMacroInternal
	local scheduleAutomationActionInternal = context.scheduleAutomationActionInternal
	local cancelScheduledActionInternal = context.cancelScheduledActionInternal
	local listScheduledActionsInternal = context.listScheduledActionsInternal
	local clearScheduledActionsInternal = context.clearScheduledActionsInternal
	local addAutomationRuleInternal = context.addAutomationRuleInternal
	local removeAutomationRuleInternal = context.removeAutomationRuleInternal
	local listAutomationRulesInternal = context.listAutomationRulesInternal
	local setAutomationRuleEnabledInternal = context.setAutomationRuleEnabledInternal
	local evaluateAutomationRulesInternal = context.evaluateAutomationRulesInternal
	local registerHubMetadataInternal = context.registerHubMetadataInternal
	local getHubMetadataInternal = context.getHubMetadataInternal
	local setElementInspectorEnabledInternal = context.setElementInspectorEnabledInternal
	local isElementInspectorEnabledInternal = context.isElementInspectorEnabledInternal
	local inspectElementAtPointerInternal = context.inspectElementAtPointerInternal
	local openLiveThemeEditorInternal = context.openLiveThemeEditorInternal
	local closeLiveThemeEditorInternal = context.closeLiveThemeEditorInternal
	local setLiveThemeValueInternal = context.setLiveThemeValueInternal
	local getLiveThemeDraftInternal = context.getLiveThemeDraftInternal
	local applyLiveThemeDraftInternal = context.applyLiveThemeDraftInternal
	local exportLiveThemeLuaInternal = context.exportLiveThemeLuaInternal
	local bindingModules = type(context.bindingModules) == "table" and context.bindingModules or {}
	local uiEventModules = type(context.uiEventModules) == "table" and context.uiEventModules or {}
	local movementEventModules = type(context.movementEventModules) == "table" and context.movementEventModules or {}
	local combatEventModules = type(context.combatEventModules) == "table" and context.combatEventModules or {}

	local function experienceState()
		return getExperienceState()
	end

	local function clamp(value, minValue, maxValue)
		local numeric = tonumber(value) or minValue
		if numeric < minValue then
			return minValue
		end
		if numeric > maxValue then
			return maxValue
		end
		return numeric
	end

	local function getThemeNamesSafe()
		if type(listThemeNames) == "function" then
			return listThemeNames()
		end
		local names = {}
		if type(ThemeModule.Themes) == "table" then
			for name in pairs(ThemeModule.Themes) do
				table.insert(names, tostring(name))
			end
			return names
		end
		return names
	end

	local api = {}
	local settingsHandlers = {}

	local function withUIStateMethod(methodName, ...)
		local uiStateSystem = getUIStateSystem()
		if not uiStateSystem then
			return false, "UI state unavailable."
		end
		local method = uiStateSystem[methodName]
		if type(method) ~= "function" then
			return false, "UI state method unavailable: " .. tostring(methodName)
		end
		return method(...)
	end

	function api.restoreFromSettings(windowRef)
		if type(getSetting) ~= "function" then
			return false, "Settings getter unavailable."
		end

		local state = experienceState()
		local transition = getSetting("Appearance", "transitionProfile") or state.transitionProfile
		if type(setTransitionProfileInternal) == "function" then
			setTransitionProfileInternal(transition, false)
		end

		local preset = getSetting("Appearance", "uiPreset") or state.uiPreset
		if type(setUIPresetInternal) == "function" then
			setUIPresetInternal(preset, false)
		end

		local baseTheme = getSetting("ThemeStudio", "baseTheme")
		if type(baseTheme) == "string" and type(ThemeModule.Themes) == "table" and ThemeModule.Themes[baseTheme] then
			state.themeStudioState.baseTheme = baseTheme
		end
		state.themeStudioState.useCustom = getSetting("ThemeStudio", "useCustom") == true

		local packedTheme = getSetting("ThemeStudio", "customThemePacked")
		if type(packedTheme) == "table" then
			state.themeStudioState.customThemePacked = cloneValue(packedTheme)
		end
		if type(applyThemeStudioState) == "function" then
			applyThemeStudioState(false)
		end

		local elementsSystem = getElementsSystem()
		if elementsSystem and type(elementsSystem.setPinBadgesVisible) == "function" then
			local showBadges = getSetting("Favorites", "showPinBadges")
			elementsSystem.setPinBadgesVisible(showBadges ~= false)
		end
		if elementsSystem and type(elementsSystem.setPinnedIds) == "function" then
			local pinnedIds = getSetting("Favorites", "pinnedIds")
			if type(pinnedIds) == "table" then
				elementsSystem.setPinnedIds(cloneArray(pinnedIds))
			end
		end

		local pinnedControls = elementsSystem and elementsSystem.getPinnedIds and elementsSystem.getPinnedIds(true) or {}
		if type(pinnedControls) == "table" and #pinnedControls > 0 then
			if type(ensureFavoritesTab) == "function" then
				ensureFavoritesTab(windowRef)
			end
			if type(renderFavoritesTab) == "function" then
				renderFavoritesTab()
			end
		end

		local paletteMode = getSetting("UIExperience", "commandPaletteMode")
		if type(setCommandPaletteExecutionModeInternal) == "function" and type(paletteMode) == "string" and paletteMode ~= "" then
			pcall(setCommandPaletteExecutionModeInternal, paletteMode)
		end
		local performanceHudEnabled = getSetting("UIExperience", "performanceHudEnabled")
		if type(openPerformanceHUDInternal) == "function" and type(closePerformanceHUDInternal) == "function" then
			if performanceHudEnabled == false then
				pcall(closePerformanceHUDInternal)
			else
				pcall(openPerformanceHUDInternal)
			end
		end

		state.onboardingSuppressed = getSetting("Onboarding", "suppressed") == true

		local audioEnabled = getSetting("Audio", "enabled")
		local audioPack = getSetting("Audio", "pack")
		local audioVolume = getSetting("Audio", "volume")
		local audioCustomPack = getSetting("Audio", "customPack")

		if type(audioCustomPack) == "table" then
			state.audioState.customPack = cloneAudioPack(audioCustomPack)
		end
		if type(audioPack) == "string" and type(normalizeAudioPackName) == "function" then
			local normalizedPack = normalizeAudioPackName(audioPack)
			if normalizedPack then
				state.audioState.pack = normalizedPack
			end
		end
		if audioVolume ~= nil and type(setAudioFeedbackVolumeInternal) == "function" then
			setAudioFeedbackVolumeInternal(audioVolume, false)
		end
		if type(setAudioFeedbackEnabledInternal) == "function" then
			setAudioFeedbackEnabledInternal(audioEnabled == true, false)
		end
		syncAudioCueSounds()

		local glassMode = getSetting("Glass", "mode")
		local glassIntensity = getSetting("Glass", "intensity")
		if type(glassMode) == "string" then
			local normalizedMode = string.lower(glassMode)
			if normalizedMode == "auto" or normalizedMode == "off" or normalizedMode == "canvas" or normalizedMode == "fallback" then
				state.glassState.mode = normalizedMode
			end
		end
		if glassIntensity ~= nil then
			state.glassState.intensity = clamp(tonumber(glassIntensity) or state.glassState.intensity, 0, 1)
		end
		if type(context.applyGlassLayer) == "function" then
			context.applyGlassLayer()
		end

		return true
	end

	local function setHandler(name, fn)
		if type(name) ~= "string" or name == "" or type(fn) ~= "function" then
			return
		end
		settingsHandlers[name] = fn
	end

	local moduleContext = {
		RayfieldLibrary = RayfieldLibrary,
		setHandler = setHandler,
		experienceState = experienceState,
		withUIStateMethod = withUIStateMethod,
		getElementsSystem = getElementsSystem,
		getUIStateSystem = getUIStateSystem,
		getThemeNamesSafe = getThemeNamesSafe,
		setSettingValue = setSettingValue,
		getSetting = getSetting,
		refreshFavoritesSettingsPersistence = refreshFavoritesSettingsPersistence,
		ensureFavoritesTab = ensureFavoritesTab,
		renderFavoritesTab = renderFavoritesTab,
		openFavoritesTab = openFavoritesTab,
		cloneValue = cloneValue,
		cloneArray = cloneArray,
		cloneAudioPack = cloneAudioPack,
		color3ToPacked = color3ToPacked,
		packedToColor3 = packedToColor3,
		THEME_STUDIO_KEYS = THEME_STUDIO_KEYS,
		HttpService = HttpService,
		setTransitionProfileInternal = setTransitionProfileInternal,
		setUIPresetInternal = setUIPresetInternal,
		setAudioFeedbackEnabledInternal = setAudioFeedbackEnabledInternal,
		setAudioFeedbackPackInternal = setAudioFeedbackPackInternal,
		getAudioFeedbackStateSnapshot = getAudioFeedbackStateSnapshot,
		playUICueInternal = playUICueInternal,
		setGlassModeInternal = setGlassModeInternal,
		setGlassIntensityInternal = setGlassIntensityInternal,
		ensureOnboardingOverlay = ensureOnboardingOverlay,
		setThemeStudioBaseTheme = setThemeStudioBaseTheme,
		applyThemeStudioState = applyThemeStudioState,
		resetThemeStudioState = resetThemeStudioState,
		getThemeStudioColor = getThemeStudioColor,
		setThemeStudioUseCustom = setThemeStudioUseCustom,
		setThemeStudioColor = setThemeStudioColor,
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
		closeLiveThemeEditorInternal = closeLiveThemeEditorInternal,
		setLiveThemeValueInternal = setLiveThemeValueInternal,
		getLiveThemeDraftInternal = getLiveThemeDraftInternal,
		applyLiveThemeDraftInternal = applyLiveThemeDraftInternal,
		exportLiveThemeLuaInternal = exportLiveThemeLuaInternal,
		uiEventModules = uiEventModules,
		movementEventModules = movementEventModules,
		combatEventModules = combatEventModules
	}

	for _, moduleValue in ipairs(bindingModules) do
		if type(moduleValue) == "table" and type(moduleValue.attach) == "function" then
			moduleValue.attach(moduleContext)
		end
	end

	local function notifyExperienceStatus(success, message)
		local uiStateSystem = getUIStateSystem()
		if uiStateSystem and type(uiStateSystem.Notify) == "function" then
			pcall(uiStateSystem.Notify, {
				Title = "Rayfield Experience",
				Content = tostring(message or ""),
				Image = success and 4483362458 or 4384402990
			})
		elseif success ~= true then
			warn("Rayfield | " .. tostring(message or "UI experience operation failed."))
		end
	end

	setHandler("openSettingsTab", function()
		if type(openSettingsTabInternal) == "function" then
			return openSettingsTabInternal()
		end
		return false, "Settings tab unavailable."
	end)
	setHandler("notify", function(success, message)
		notifyExperienceStatus(success == true, message)
	end)

	if SettingsSystem and type(SettingsSystem.setExperienceHandlers) == "function" then
		SettingsSystem.setExperienceHandlers(settingsHandlers)
	end

	return api
end

return ExperienceBindings
