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
	local configurePerformanceHUDInternal = context.configurePerformanceHUDInternal
	local getPerformanceHUDStateInternal = context.getPerformanceHUDStateInternal
	local registerHUDMetricProviderInternal = context.registerHUDMetricProviderInternal
	local unregisterHUDMetricProviderInternal = context.unregisterHUDMetricProviderInternal
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

	local function experienceState()
		return getExperienceState()
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
			state.glassState.intensity = math.clamp(tonumber(glassIntensity) or state.glassState.intensity, 0, 1)
		end
		if type(context.applyGlassLayer) == "function" then
			context.applyGlassLayer()
		end

		return true
	end

	function RayfieldLibrary:SetTransitionProfile(name)
		return setTransitionProfileInternal(name, true)
	end

	function RayfieldLibrary:GetTransitionProfile()
		return experienceState().transitionProfile
	end

	function RayfieldLibrary:SetUIPreset(name)
		return setUIPresetInternal(name, true)
	end

	function RayfieldLibrary:GetUIPreset()
		return experienceState().uiPreset
	end

	function RayfieldLibrary:SetAudioFeedbackEnabled(value)
		return setAudioFeedbackEnabledInternal(value == true, true)
	end

	function RayfieldLibrary:IsAudioFeedbackEnabled()
		return experienceState().audioState.enabled == true
	end

	function RayfieldLibrary:SetAudioFeedbackPack(name, packDefinition)
		return setAudioFeedbackPackInternal(name, packDefinition, true)
	end

	function RayfieldLibrary:GetAudioFeedbackState()
		return getAudioFeedbackStateSnapshot()
	end

	function RayfieldLibrary:PlayUICue(cueName)
		return playUICueInternal(cueName)
	end

	function RayfieldLibrary:SetGlassMode(mode)
		return setGlassModeInternal(mode, true)
	end

	function RayfieldLibrary:GetGlassMode()
		return experienceState().glassState.mode
	end

	function RayfieldLibrary:SetGlassIntensity(value)
		return setGlassIntensityInternal(value, true)
	end

	function RayfieldLibrary:GetGlassIntensity()
		return tonumber(experienceState().glassState.intensity) or 0.32
	end

	function RayfieldLibrary:ListControls()
		local elementsSystem = getElementsSystem()
		if not elementsSystem or type(elementsSystem.listControlsForFavorites) ~= "function" then
			return {}
		end
		return elementsSystem.listControlsForFavorites(true)
	end

	function RayfieldLibrary:PinControl(idOrFlag)
		local elementsSystem = getElementsSystem()
		if not elementsSystem or type(elementsSystem.pinControl) ~= "function" then
			return false, "Control registry unavailable."
		end
		local ok, message = elementsSystem.pinControl(tostring(idOrFlag or ""))
		if ok then
			if type(refreshFavoritesSettingsPersistence) == "function" then
				refreshFavoritesSettingsPersistence()
			end
			if experienceState().favoritesTabWindow and type(ensureFavoritesTab) == "function" then
				ensureFavoritesTab(experienceState().favoritesTabWindow)
			end
			if type(renderFavoritesTab) == "function" then
				renderFavoritesTab()
			end
		end
		return ok, message
	end

	function RayfieldLibrary:UnpinControl(idOrFlag)
		local elementsSystem = getElementsSystem()
		if not elementsSystem or type(elementsSystem.unpinControl) ~= "function" then
			return false, "Control registry unavailable."
		end
		local ok, message = elementsSystem.unpinControl(tostring(idOrFlag or ""))
		if ok then
			if type(refreshFavoritesSettingsPersistence) == "function" then
				refreshFavoritesSettingsPersistence()
			end
			if type(renderFavoritesTab) == "function" then
				renderFavoritesTab()
			end
		end
		return ok, message
	end

	function RayfieldLibrary:GetPinnedControls()
		local elementsSystem = getElementsSystem()
		if not elementsSystem or type(elementsSystem.getPinnedIds) ~= "function" then
			return {}
		end
		return elementsSystem.getPinnedIds(true)
	end

	function RayfieldLibrary:SetOnboardingSuppressed(value)
		local state = experienceState()
		state.onboardingSuppressed = value == true
		setSettingValue("Onboarding", "suppressed", state.onboardingSuppressed, true)
		return true, state.onboardingSuppressed and "Onboarding suppressed." or "Onboarding enabled."
	end

	function RayfieldLibrary:IsOnboardingSuppressed()
		return experienceState().onboardingSuppressed == true
	end

	function RayfieldLibrary:ShowOnboarding(force)
		local state = experienceState()
		if state.onboardingSuppressed and force ~= true then
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
		state.onboardingRendered = true
		return true, "Onboarding shown."
	end

	function RayfieldLibrary:GetThemeStudioState()
		local state = experienceState()
		return {
			baseTheme = state.themeStudioState.baseTheme,
			useCustom = state.themeStudioState.useCustom == true,
			customThemePacked = cloneValue(state.themeStudioState.customThemePacked)
		}
	end

	function RayfieldLibrary:ApplyThemeStudioTheme(themeOrName)
		if type(themeOrName) == "string" then
			return setThemeStudioBaseTheme(themeOrName, true)
		end
		if type(themeOrName) ~= "table" then
			return false, "Theme input must be a theme name or table."
		end

		local nextPacked = {}
		for _, key in ipairs(THEME_STUDIO_KEYS) do
			local value = themeOrName[key]
			if typeof(value) == "Color3" then
				nextPacked[key] = color3ToPacked(value)
			elseif type(value) == "table" and type(packedToColor3) == "function" then
				local packedColor = packedToColor3(value)
				if packedColor then
					nextPacked[key] = color3ToPacked(packedColor)
				end
			end
		end
		local state = experienceState()
		state.themeStudioState.customThemePacked = nextPacked
		state.themeStudioState.useCustom = true
		return applyThemeStudioState(true)
	end

	function RayfieldLibrary:ResetThemeStudio()
		return resetThemeStudioState(true)
	end

	function RayfieldLibrary:OpenCommandPalette(seedText)
		return withUIStateMethod("OpenCommandPalette", seedText)
	end

	function RayfieldLibrary:CloseCommandPalette()
		return withUIStateMethod("CloseCommandPalette")
	end

	function RayfieldLibrary:ToggleCommandPalette(seedText)
		return withUIStateMethod("ToggleCommandPalette", seedText)
	end

	function RayfieldLibrary:SetCommandPaletteExecutionMode(mode)
		if type(setCommandPaletteExecutionModeInternal) ~= "function" then
			return false, "Command palette execution mode handler unavailable."
		end
		local okSet, message = setCommandPaletteExecutionModeInternal(mode)
		if okSet and type(setSettingValue) == "function" then
			setSettingValue("UIExperience", "commandPaletteMode", tostring(mode or "auto"), true)
		end
		return okSet, message
	end

	function RayfieldLibrary:GetCommandPaletteExecutionMode()
		if type(getCommandPaletteExecutionModeInternal) == "function" then
			local value = getCommandPaletteExecutionModeInternal()
			return tostring(value or "auto")
		end
		if type(_G) == "table" and type(_G.__RAYFIELD_COMMAND_PALETTE_EXEC_MODE) == "string" then
			return tostring(_G.__RAYFIELD_COMMAND_PALETTE_EXEC_MODE)
		end
		return "auto"
	end

	function RayfieldLibrary:SetCommandPalettePolicy(callback)
		if type(setCommandPalettePolicyInternal) ~= "function" then
			return false, "Command palette policy handler unavailable."
		end
		return setCommandPalettePolicyInternal(callback)
	end

	function RayfieldLibrary:RunCommandPaletteItem(item, mode)
		if type(runCommandPaletteItemInternal) ~= "function" then
			return false, "Command palette executor unavailable."
		end
		return runCommandPaletteItemInternal(item, mode)
	end

	function RayfieldLibrary:OpenActionCenter()
		return withUIStateMethod("OpenActionCenter")
	end

	function RayfieldLibrary:CloseActionCenter()
		return withUIStateMethod("CloseActionCenter")
	end

	function RayfieldLibrary:ToggleActionCenter()
		return withUIStateMethod("ToggleActionCenter")
	end

	function RayfieldLibrary:GetNotificationHistory(limit)
		local okHistory, historyOrErr = withUIStateMethod("GetNotificationHistory", limit)
		if okHistory == false and type(historyOrErr) == "string" then
			return {}
		end
		if type(okHistory) == "table" then
			return okHistory
		end
		if type(historyOrErr) == "table" then
			return historyOrErr
		end
		return {}
	end

	function RayfieldLibrary:ClearNotificationHistory()
		return withUIStateMethod("ClearNotificationHistory")
	end

	function RayfieldLibrary:GetUnreadNotificationCount()
		local okCall, result = withUIStateMethod("GetUnreadNotificationCount")
		if type(okCall) == "number" then
			return okCall
		end
		if okCall == false and type(result) == "string" then
			return 0
		end
		return tonumber(result) or 0
	end

	function RayfieldLibrary:MarkAllNotificationsRead()
		return withUIStateMethod("MarkAllNotificationsRead")
	end

	function RayfieldLibrary:GetNotificationHistoryEx(options)
		local okCall, result = withUIStateMethod("GetNotificationHistoryEx", options)
		if type(okCall) == "table" then
			return okCall
		end
		if okCall == false and type(result) == "string" then
			return {}
		end
		return type(result) == "table" and result or {}
	end

	function RayfieldLibrary:ShowContextMenu(items, anchor)
		return withUIStateMethod("ShowContextMenu", items, anchor)
	end

	function RayfieldLibrary:HideContextMenu()
		return withUIStateMethod("HideContextMenu")
	end

	function RayfieldLibrary:SaveWorkspace(name)
		if type(saveWorkspaceInternal) ~= "function" then
			return false, "Workspace save unavailable."
		end
		return saveWorkspaceInternal(name)
	end

	function RayfieldLibrary:LoadWorkspace(name)
		if type(loadWorkspaceInternal) ~= "function" then
			return false, "Workspace load unavailable."
		end
		return loadWorkspaceInternal(name)
	end

	function RayfieldLibrary:ListWorkspaces()
		if type(listWorkspacesInternal) ~= "function" then
			return {}
		end
		local list = listWorkspacesInternal()
		if type(list) ~= "table" then
			return {}
		end
		return list
	end

	function RayfieldLibrary:DeleteWorkspace(name)
		if type(deleteWorkspaceInternal) ~= "function" then
			return false, "Workspace delete unavailable."
		end
		return deleteWorkspaceInternal(name)
	end

	function RayfieldLibrary:SaveProfile(name)
		if type(saveProfileInternal) ~= "function" then
			return false, "Profile save unavailable."
		end
		return saveProfileInternal(name)
	end

	function RayfieldLibrary:LoadProfile(name)
		if type(loadProfileInternal) ~= "function" then
			return false, "Profile load unavailable."
		end
		return loadProfileInternal(name)
	end

	function RayfieldLibrary:ListProfiles()
		if type(listProfilesInternal) ~= "function" then
			return {}
		end
		local list = listProfilesInternal()
		return type(list) == "table" and list or {}
	end

	function RayfieldLibrary:DeleteProfile(name)
		if type(deleteProfileInternal) ~= "function" then
			return false, "Profile delete unavailable."
		end
		return deleteProfileInternal(name)
	end

	function RayfieldLibrary:CopyWorkspaceToProfile(workspaceName, profileName)
		if type(copyWorkspaceToProfileInternal) ~= "function" then
			return false, "Workspace/profile copy unavailable."
		end
		return copyWorkspaceToProfileInternal(workspaceName, profileName)
	end

	function RayfieldLibrary:CopyProfileToWorkspace(profileName, workspaceName)
		if type(copyProfileToWorkspaceInternal) ~= "function" then
			return false, "Workspace/profile copy unavailable."
		end
		return copyProfileToWorkspaceInternal(profileName, workspaceName)
	end

	function RayfieldLibrary:OpenPerformanceHUD()
		if type(openPerformanceHUDInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		local okOpen, message = openPerformanceHUDInternal()
		if okOpen and type(setSettingValue) == "function" then
			setSettingValue("UIExperience", "performanceHudEnabled", true, true)
		end
		return okOpen, message
	end

	function RayfieldLibrary:ClosePerformanceHUD()
		if type(closePerformanceHUDInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		local okClose, message = closePerformanceHUDInternal()
		if okClose and type(setSettingValue) == "function" then
			setSettingValue("UIExperience", "performanceHudEnabled", false, true)
		end
		return okClose, message
	end

	function RayfieldLibrary:TogglePerformanceHUD()
		if type(togglePerformanceHUDInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		local okToggle, message = togglePerformanceHUDInternal()
		if okToggle and type(setSettingValue) == "function" then
			local hudState = RayfieldLibrary:GetPerformanceHUDState()
			setSettingValue("UIExperience", "performanceHudEnabled", hudState.visible == true, true)
		end
		return okToggle, message
	end

	function RayfieldLibrary:ConfigurePerformanceHUD(options)
		if type(configurePerformanceHUDInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		return configurePerformanceHUDInternal(options)
	end

	function RayfieldLibrary:GetPerformanceHUDState()
		if type(getPerformanceHUDStateInternal) ~= "function" then
			return {}
		end
		local state = getPerformanceHUDStateInternal()
		return type(state) == "table" and state or {}
	end

	function RayfieldLibrary:RegisterHUDMetricProvider(id, provider, options)
		if type(registerHUDMetricProviderInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		return registerHUDMetricProviderInternal(id, provider, options)
	end

	function RayfieldLibrary:UnregisterHUDMetricProvider(id)
		if type(unregisterHUDMetricProviderInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		return unregisterHUDMetricProviderInternal(id)
	end

	function RayfieldLibrary:GetUsageAnalytics(limit)
		if type(getUsageAnalyticsInternal) ~= "function" then
			return {}
		end
		local snapshot = getUsageAnalyticsInternal(limit)
		if type(snapshot) ~= "table" then
			return {}
		end
		return snapshot
	end

	function RayfieldLibrary:ClearUsageAnalytics()
		if type(clearUsageAnalyticsInternal) ~= "function" then
			return false, "Usage analytics unavailable."
		end
		return clearUsageAnalyticsInternal()
	end

	function RayfieldLibrary:StartMacroRecording(name)
		if type(startMacroRecordingInternal) ~= "function" then
			return false, "Macro recorder unavailable."
		end
		return startMacroRecordingInternal(name)
	end

	function RayfieldLibrary:StopMacroRecording(saveResult)
		if type(stopMacroRecordingInternal) ~= "function" then
			return false, "Macro recorder unavailable."
		end
		return stopMacroRecordingInternal(saveResult ~= false)
	end

	function RayfieldLibrary:CancelMacroRecording()
		if type(cancelMacroRecordingInternal) ~= "function" then
			return false, "Macro recorder unavailable."
		end
		return cancelMacroRecordingInternal()
	end

	function RayfieldLibrary:IsMacroRecording()
		if type(isMacroRecordingInternal) ~= "function" then
			return false
		end
		return isMacroRecordingInternal() == true
	end

	function RayfieldLibrary:IsMacroExecuting()
		if type(isMacroExecutingInternal) ~= "function" then
			return false
		end
		return isMacroExecutingInternal() == true
	end

	function RayfieldLibrary:ListMacros()
		if type(listMacrosInternal) ~= "function" then
			return {}
		end
		local list = listMacrosInternal()
		return type(list) == "table" and list or {}
	end

	function RayfieldLibrary:DeleteMacro(name)
		if type(deleteMacroInternal) ~= "function" then
			return false, "Macro recorder unavailable."
		end
		return deleteMacroInternal(name)
	end

	function RayfieldLibrary:ExecuteMacro(name, options)
		if type(executeMacroInternal) ~= "function" then
			return false, "Macro executor unavailable."
		end
		return executeMacroInternal(name, options)
	end

	function RayfieldLibrary:BindMacro(name, keybind)
		if type(bindMacroInternal) ~= "function" then
			return false, "Macro binder unavailable."
		end
		return bindMacroInternal(name, keybind)
	end

	function RayfieldLibrary:RegisterDiscoveryProvider(id, provider)
		if type(registerDiscoveryProviderInternal) ~= "function" then
			return false, "Discovery registry unavailable."
		end
		return registerDiscoveryProviderInternal(id, provider)
	end

	function RayfieldLibrary:UnregisterDiscoveryProvider(id)
		if type(unregisterDiscoveryProviderInternal) ~= "function" then
			return false, "Discovery registry unavailable."
		end
		return unregisterDiscoveryProviderInternal(id)
	end

	function RayfieldLibrary:QueryDiscovery(query)
		if type(queryDiscoveryInternal) ~= "function" then
			return {}
		end
		local results = queryDiscoveryInternal(query)
		return type(results) == "table" and results or {}
	end

	function RayfieldLibrary:ExecutePromptCommand(rawText)
		if type(executePromptCommandInternal) ~= "function" then
			return false, "Prompt command service unavailable."
		end
		return executePromptCommandInternal(rawText)
	end

	function RayfieldLibrary:AskAssistant(prompt, options)
		if type(askAssistantInternal) ~= "function" then
			return false, "Assistant bridge unavailable."
		end
		return askAssistantInternal(prompt, options)
	end

	function RayfieldLibrary:GetAssistantHistory()
		if type(getAssistantHistoryInternal) ~= "function" then
			return {}
		end
		local history = getAssistantHistoryInternal()
		return type(history) == "table" and history or {}
	end

	function RayfieldLibrary:SendGlobalSignal(command, payload, options)
		if type(sendGlobalSignalInternal) ~= "function" then
			return false, "Global signal bridge unavailable."
		end
		return sendGlobalSignalInternal(command, payload, options)
	end

	function RayfieldLibrary:SendInternalChat(message, options)
		if type(sendInternalChatInternal) ~= "function" then
			return false, "Internal chat bridge unavailable."
		end
		return sendInternalChatInternal(message, options)
	end

	function RayfieldLibrary:PollBridgeMessages(limit, options)
		if type(pollBridgeMessagesInternal) ~= "function" then
			return false, "Bridge polling unavailable.", {}
		end
		return pollBridgeMessagesInternal(limit, options)
	end

	function RayfieldLibrary:StartBridgePolling()
		if type(startBridgePollingInternal) ~= "function" then
			return false, "Bridge polling unavailable."
		end
		return startBridgePollingInternal()
	end

	function RayfieldLibrary:StopBridgePolling()
		if type(stopBridgePollingInternal) ~= "function" then
			return false, "Bridge polling unavailable."
		end
		return stopBridgePollingInternal()
	end

	function RayfieldLibrary:GetBridgeMessages(limit, kind)
		if type(getBridgeMessagesInternal) ~= "function" then
			return {}
		end
		local list = getBridgeMessagesInternal(limit, kind)
		return type(list) == "table" and list or {}
	end

	function RayfieldLibrary:ScheduleMacro(name, delaySeconds, options)
		if type(scheduleMacroInternal) ~= "function" then
			return false, "Automation scheduler unavailable."
		end
		return scheduleMacroInternal(name, delaySeconds, options)
	end

	function RayfieldLibrary:ScheduleAction(actionSpec, delaySeconds, options)
		if type(scheduleAutomationActionInternal) ~= "function" then
			return false, "Automation scheduler unavailable."
		end
		return scheduleAutomationActionInternal(actionSpec, delaySeconds, options)
	end

	function RayfieldLibrary:CancelScheduledAction(taskId)
		if type(cancelScheduledActionInternal) ~= "function" then
			return false, "Automation scheduler unavailable."
		end
		return cancelScheduledActionInternal(taskId)
	end

	function RayfieldLibrary:ListScheduledActions()
		if type(listScheduledActionsInternal) ~= "function" then
			return {}
		end
		local list = listScheduledActionsInternal()
		return type(list) == "table" and list or {}
	end

	function RayfieldLibrary:ClearScheduledActions()
		if type(clearScheduledActionsInternal) ~= "function" then
			return false, "Automation scheduler unavailable."
		end
		return clearScheduledActionsInternal()
	end

	function RayfieldLibrary:AddAutomationRule(rule)
		if type(addAutomationRuleInternal) ~= "function" then
			return false, "Automation rule engine unavailable."
		end
		return addAutomationRuleInternal(rule)
	end

	function RayfieldLibrary:RemoveAutomationRule(ruleId)
		if type(removeAutomationRuleInternal) ~= "function" then
			return false, "Automation rule engine unavailable."
		end
		return removeAutomationRuleInternal(ruleId)
	end

	function RayfieldLibrary:ListAutomationRules()
		if type(listAutomationRulesInternal) ~= "function" then
			return {}
		end
		local list = listAutomationRulesInternal()
		return type(list) == "table" and list or {}
	end

	function RayfieldLibrary:SetAutomationRuleEnabled(ruleId, enabled)
		if type(setAutomationRuleEnabledInternal) ~= "function" then
			return false, "Automation rule engine unavailable."
		end
		return setAutomationRuleEnabledInternal(ruleId, enabled == true)
	end

	function RayfieldLibrary:EvaluateAutomationRules(eventPayload)
		if type(evaluateAutomationRulesInternal) ~= "function" then
			return false, "Automation rule engine unavailable.", 0
		end
		return evaluateAutomationRulesInternal(eventPayload)
	end

	function RayfieldLibrary:RegisterHubMetadata(metadata)
		if type(registerHubMetadataInternal) ~= "function" then
			return false, "Hub metadata bridge unavailable."
		end
		return registerHubMetadataInternal(metadata)
	end

	function RayfieldLibrary:GetHubMetadata()
		if type(getHubMetadataInternal) ~= "function" then
			return nil
		end
		return getHubMetadataInternal()
	end

	function RayfieldLibrary:SetElementInspectorEnabled(enabled)
		if type(setElementInspectorEnabledInternal) == "function" then
			return setElementInspectorEnabledInternal(enabled == true)
		end
		return withUIStateMethod("SetElementInspectorEnabled", enabled == true)
	end

	function RayfieldLibrary:ToggleElementInspector()
		return withUIStateMethod("ToggleElementInspector")
	end

	function RayfieldLibrary:IsElementInspectorEnabled()
		if type(isElementInspectorEnabledInternal) == "function" then
			return isElementInspectorEnabledInternal() == true
		end
		local okValue, value = withUIStateMethod("IsElementInspectorEnabled")
		if okValue == false and type(value) == "string" then
			return false
		end
		return okValue == true or value == true
	end

	function RayfieldLibrary:InspectElementAtPointer(anchor)
		if type(inspectElementAtPointerInternal) ~= "function" then
			return false, "Inspector unavailable."
		end
		return inspectElementAtPointerInternal(anchor)
	end

	function RayfieldLibrary:OpenLiveThemeEditor(seedDraft)
		if type(openLiveThemeEditorInternal) ~= "function" then
			return false, "Live Theme Editor unavailable."
		end
		return openLiveThemeEditorInternal(seedDraft)
	end

	function RayfieldLibrary:CloseLiveThemeEditor()
		if type(closeLiveThemeEditorInternal) ~= "function" then
			return false, "Live Theme Editor unavailable."
		end
		return closeLiveThemeEditorInternal()
	end

	function RayfieldLibrary:SetLiveThemeValue(themeKey, color)
		if type(setLiveThemeValueInternal) ~= "function" then
			return false, "Live Theme Editor unavailable."
		end
		return setLiveThemeValueInternal(themeKey, color)
	end

	function RayfieldLibrary:GetLiveThemeDraft()
		if type(getLiveThemeDraftInternal) ~= "function" then
			return {}
		end
		local draft = getLiveThemeDraftInternal()
		return type(draft) == "table" and draft or {}
	end

	function RayfieldLibrary:ApplyLiveThemeDraft()
		if type(applyLiveThemeDraftInternal) ~= "function" then
			return false, "Live Theme Editor unavailable."
		end
		return applyLiveThemeDraftInternal()
	end

	function RayfieldLibrary:ExportLiveThemeDraftLua()
		if type(exportLiveThemeLuaInternal) ~= "function" then
			return false, "Live Theme Editor unavailable."
		end
		return exportLiveThemeLuaInternal()
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

	if SettingsSystem and type(SettingsSystem.setExperienceHandlers) == "function" then
		SettingsSystem.setExperienceHandlers({
			setUIPreset = function(name)
				return RayfieldLibrary:SetUIPreset(name)
			end,
			setTransitionProfile = function(name)
				return RayfieldLibrary:SetTransitionProfile(name)
			end,
			setAudioEnabled = function(enabled)
				return RayfieldLibrary:SetAudioFeedbackEnabled(enabled == true)
			end,
			setAudioPack = function(name)
				return RayfieldLibrary:SetAudioFeedbackPack(name)
			end,
			setAudioPackJson = function(rawJson)
				local decoded = nil
				local okDecode, decodeErr = pcall(function()
					decoded = HttpService:JSONDecode(tostring(rawJson or ""))
				end)
				if not okDecode then
					return false, "Invalid JSON: " .. tostring(decodeErr)
				end
				if type(decoded) ~= "table" then
					return false, "Audio pack JSON must decode to a table."
				end
				local normalizedPack = cloneAudioPack(decoded)
				local okSet, message = RayfieldLibrary:SetAudioFeedbackPack("Custom", normalizedPack)
				if not okSet then
					return false, message
				end
				return true, message, normalizedPack
			end,
			setGlassMode = function(mode)
				return RayfieldLibrary:SetGlassMode(mode)
			end,
			setGlassIntensity = function(value)
				return RayfieldLibrary:SetGlassIntensity(value)
			end,
			listControls = function(pruneMissing)
				local elementsSystem = getElementsSystem()
				if elementsSystem and type(elementsSystem.listControlsForFavorites) == "function" then
					return elementsSystem.listControlsForFavorites(pruneMissing == true)
				end
				return {}
			end,
			pinControl = function(id)
				return RayfieldLibrary:PinControl(id)
			end,
			unpinControl = function(id)
				return RayfieldLibrary:UnpinControl(id)
			end,
			setPinBadgesVisible = function(visible)
				local elementsSystem = getElementsSystem()
				if elementsSystem and type(elementsSystem.setPinBadgesVisible) == "function" then
					elementsSystem.setPinBadgesVisible(visible ~= false)
					setSettingValue("Favorites", "showPinBadges", visible ~= false, true)
					return true, "Pin badge visibility updated."
				end
				return false, "Pin badge controller unavailable."
			end,
			openFavoritesTab = function()
				if type(openFavoritesTab) == "function" then
					return openFavoritesTab(experienceState().favoritesTabWindow)
				end
				return false, "Favorites tab unavailable."
			end,
			saveWorkspace = function(name)
				return RayfieldLibrary:SaveWorkspace(name)
			end,
			loadWorkspace = function(name)
				return RayfieldLibrary:LoadWorkspace(name)
			end,
			listWorkspaces = function()
				return RayfieldLibrary:ListWorkspaces()
			end,
			deleteWorkspace = function(name)
				return RayfieldLibrary:DeleteWorkspace(name)
			end,
			saveProfile = function(name)
				return RayfieldLibrary:SaveProfile(name)
			end,
			loadProfile = function(name)
				return RayfieldLibrary:LoadProfile(name)
			end,
			listProfiles = function()
				return RayfieldLibrary:ListProfiles()
			end,
			deleteProfile = function(name)
				return RayfieldLibrary:DeleteProfile(name)
			end,
			copyWorkspaceToProfile = function(workspaceName, profileName)
				return RayfieldLibrary:CopyWorkspaceToProfile(workspaceName, profileName)
			end,
			copyProfileToWorkspace = function(profileName, workspaceName)
				return RayfieldLibrary:CopyProfileToWorkspace(profileName, workspaceName)
			end,
			setCommandPaletteExecutionMode = function(mode)
				return RayfieldLibrary:SetCommandPaletteExecutionMode(mode)
			end,
			getCommandPaletteExecutionMode = function()
				return RayfieldLibrary:GetCommandPaletteExecutionMode()
			end,
			setCommandPalettePolicy = function(callback)
				return RayfieldLibrary:SetCommandPalettePolicy(callback)
			end,
			runCommandPaletteItem = function(item, mode)
				return RayfieldLibrary:RunCommandPaletteItem(item, mode)
			end,
			getUnreadNotificationCount = function()
				return RayfieldLibrary:GetUnreadNotificationCount()
			end,
			markAllNotificationsRead = function()
				return RayfieldLibrary:MarkAllNotificationsRead()
			end,
			getNotificationHistoryEx = function(options)
				return RayfieldLibrary:GetNotificationHistoryEx(options)
			end,
			openPerformanceHUD = function()
				return RayfieldLibrary:OpenPerformanceHUD()
			end,
			closePerformanceHUD = function()
				return RayfieldLibrary:ClosePerformanceHUD()
			end,
			togglePerformanceHUD = function()
				return RayfieldLibrary:TogglePerformanceHUD()
			end,
			configurePerformanceHUD = function(options)
				return RayfieldLibrary:ConfigurePerformanceHUD(options)
			end,
			getPerformanceHUDState = function()
				return RayfieldLibrary:GetPerformanceHUDState()
			end,
			registerHUDMetricProvider = function(id, provider, options)
				return RayfieldLibrary:RegisterHUDMetricProvider(id, provider, options)
			end,
			unregisterHUDMetricProvider = function(id)
				return RayfieldLibrary:UnregisterHUDMetricProvider(id)
			end,
			getUsageAnalytics = function(limit)
				return RayfieldLibrary:GetUsageAnalytics(limit)
			end,
			clearUsageAnalytics = function()
				return RayfieldLibrary:ClearUsageAnalytics()
			end,
			startMacroRecording = function(name)
				return RayfieldLibrary:StartMacroRecording(name)
			end,
			stopMacroRecording = function(saveResult)
				return RayfieldLibrary:StopMacroRecording(saveResult ~= false)
			end,
			cancelMacroRecording = function()
				return RayfieldLibrary:CancelMacroRecording()
			end,
			listMacros = function()
				return RayfieldLibrary:ListMacros()
			end,
			executeMacro = function(name, options)
				return RayfieldLibrary:ExecuteMacro(name, options)
			end,
			bindMacro = function(name, keybind)
				return RayfieldLibrary:BindMacro(name, keybind)
			end,
			registerDiscoveryProvider = function(id, provider)
				return RayfieldLibrary:RegisterDiscoveryProvider(id, provider)
			end,
			unregisterDiscoveryProvider = function(id)
				return RayfieldLibrary:UnregisterDiscoveryProvider(id)
			end,
			queryDiscovery = function(query)
				return RayfieldLibrary:QueryDiscovery(query)
			end,
			executePromptCommand = function(text)
				return RayfieldLibrary:ExecutePromptCommand(text)
			end,
			askAssistant = function(prompt, options)
				return RayfieldLibrary:AskAssistant(prompt, options)
			end,
			getAssistantHistory = function()
				return RayfieldLibrary:GetAssistantHistory()
			end,
			sendGlobalSignal = function(command, payload, options)
				return RayfieldLibrary:SendGlobalSignal(command, payload, options)
			end,
			sendInternalChat = function(message, options)
				return RayfieldLibrary:SendInternalChat(message, options)
			end,
			pollBridgeMessages = function(limit, options)
				return RayfieldLibrary:PollBridgeMessages(limit, options)
			end,
			startBridgePolling = function()
				return RayfieldLibrary:StartBridgePolling()
			end,
			stopBridgePolling = function()
				return RayfieldLibrary:StopBridgePolling()
			end,
			getBridgeMessages = function(limit, kind)
				return RayfieldLibrary:GetBridgeMessages(limit, kind)
			end,
			scheduleMacro = function(name, delaySeconds, options)
				return RayfieldLibrary:ScheduleMacro(name, delaySeconds, options)
			end,
			scheduleAction = function(actionSpec, delaySeconds, options)
				return RayfieldLibrary:ScheduleAction(actionSpec, delaySeconds, options)
			end,
			cancelScheduledAction = function(taskId)
				return RayfieldLibrary:CancelScheduledAction(taskId)
			end,
			listScheduledActions = function()
				return RayfieldLibrary:ListScheduledActions()
			end,
			clearScheduledActions = function()
				return RayfieldLibrary:ClearScheduledActions()
			end,
			addAutomationRule = function(rule)
				return RayfieldLibrary:AddAutomationRule(rule)
			end,
			removeAutomationRule = function(ruleId)
				return RayfieldLibrary:RemoveAutomationRule(ruleId)
			end,
			listAutomationRules = function()
				return RayfieldLibrary:ListAutomationRules()
			end,
			setAutomationRuleEnabled = function(ruleId, enabled)
				return RayfieldLibrary:SetAutomationRuleEnabled(ruleId, enabled == true)
			end,
			evaluateAutomationRules = function(eventPayload)
				return RayfieldLibrary:EvaluateAutomationRules(eventPayload)
			end,
			registerHubMetadata = function(metadata)
				return RayfieldLibrary:RegisterHubMetadata(metadata)
			end,
			getHubMetadata = function()
				return RayfieldLibrary:GetHubMetadata()
			end,
			setElementInspectorEnabled = function(enabled)
				return RayfieldLibrary:SetElementInspectorEnabled(enabled == true)
			end,
			toggleElementInspector = function()
				return RayfieldLibrary:ToggleElementInspector()
			end,
			openLiveThemeEditor = function(seedDraft)
				return RayfieldLibrary:OpenLiveThemeEditor(seedDraft)
			end,
			closeLiveThemeEditor = function()
				return RayfieldLibrary:CloseLiveThemeEditor()
			end,
			setLiveThemeValue = function(themeKey, color)
				return RayfieldLibrary:SetLiveThemeValue(themeKey, color)
			end,
			getLiveThemeDraft = function()
				return RayfieldLibrary:GetLiveThemeDraft()
			end,
			applyLiveThemeDraft = function()
				return RayfieldLibrary:ApplyLiveThemeDraft()
			end,
			exportLiveThemeDraftLua = function()
				return RayfieldLibrary:ExportLiveThemeDraftLua()
			end,
			openActionCenter = function()
				return RayfieldLibrary:OpenActionCenter()
			end,
			openCommandPalette = function(seed)
				return RayfieldLibrary:OpenCommandPalette(seed)
			end,
			openSettingsTab = function()
				if type(openSettingsTabInternal) == "function" then
					return openSettingsTabInternal()
				end
				return false, "Settings tab unavailable."
			end,
			showOnboarding = function(force)
				return RayfieldLibrary:ShowOnboarding(force == true)
			end,
			getThemeNames = function()
				return getThemeNamesSafe()
			end,
			getThemeStudioKeys = function()
				return cloneArray(THEME_STUDIO_KEYS)
			end,
			getThemeStudioColor = function(themeKey)
				return getThemeStudioColor(themeKey)
			end,
			setThemeStudioBaseTheme = function(themeName)
				local ok, message = setThemeStudioBaseTheme(themeName, true)
				if ok then
					setSettingValue("ThemeStudio", "baseTheme", experienceState().themeStudioState.baseTheme, true)
				end
				return ok, message
			end,
			setThemeStudioUseCustom = function(value)
				local ok, message = setThemeStudioUseCustom(value == true, true)
				if ok then
					setSettingValue("ThemeStudio", "useCustom", experienceState().themeStudioState.useCustom == true, true)
				end
				return ok, message
			end,
			setThemeStudioColor = function(themeKey, color)
				local ok, message = setThemeStudioColor(themeKey, color)
				if ok then
					setSettingValue("ThemeStudio", "customThemePacked", cloneValue(experienceState().themeStudioState.customThemePacked), false)
					setSettingValue("ThemeStudio", "useCustom", true, true)
				end
				return ok, message
			end,
			applyThemeStudioDraft = function()
				local ok, message = applyThemeStudioState(true)
				if ok then
					setSettingValue("ThemeStudio", "baseTheme", experienceState().themeStudioState.baseTheme, false)
					setSettingValue("ThemeStudio", "useCustom", experienceState().themeStudioState.useCustom == true, false)
					setSettingValue("ThemeStudio", "customThemePacked", cloneValue(experienceState().themeStudioState.customThemePacked), true)
				end
				return ok, message
			end,
			resetThemeStudio = function()
				local ok, message = resetThemeStudioState(true)
				if ok then
					setSettingValue("ThemeStudio", "useCustom", false, false)
					setSettingValue("ThemeStudio", "customThemePacked", {}, true)
				end
				return ok, message
			end,
			notify = function(success, message)
				notifyExperienceStatus(success == true, message)
			end
		})
	end

	return api
end

return ExperienceBindings
