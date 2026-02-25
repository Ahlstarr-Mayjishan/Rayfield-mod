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
