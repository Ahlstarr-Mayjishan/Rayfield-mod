local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local experienceState = ctx.experienceState
	local cloneValue = ctx.cloneValue
	local color3ToPacked = ctx.color3ToPacked
	local packedToColor3 = ctx.packedToColor3
	local THEME_STUDIO_KEYS = ctx.THEME_STUDIO_KEYS
	local setSettingValue = ctx.setSettingValue
	local getThemeNamesSafe = ctx.getThemeNamesSafe
	local getThemeStudioColor = ctx.getThemeStudioColor
	local setThemeStudioBaseTheme = ctx.setThemeStudioBaseTheme
	local setThemeStudioUseCustom = ctx.setThemeStudioUseCustom
	local setThemeStudioColor = ctx.setThemeStudioColor
	local applyThemeStudioState = ctx.applyThemeStudioState
	local resetThemeStudioState = ctx.resetThemeStudioState
	local setElementInspectorEnabledInternal = ctx.setElementInspectorEnabledInternal
	local isElementInspectorEnabledInternal = ctx.isElementInspectorEnabledInternal
	local inspectElementAtPointerInternal = ctx.inspectElementAtPointerInternal
	local openLiveThemeEditorInternal = ctx.openLiveThemeEditorInternal
	local closeLiveThemeEditorInternal = ctx.closeLiveThemeEditorInternal
	local setLiveThemeValueInternal = ctx.setLiveThemeValueInternal
	local getLiveThemeDraftInternal = ctx.getLiveThemeDraftInternal
	local applyLiveThemeDraftInternal = ctx.applyLiveThemeDraftInternal
	local exportLiveThemeLuaInternal = ctx.exportLiveThemeLuaInternal
	local withUIStateMethod = ctx.withUIStateMethod

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

	setHandler("setElementInspectorEnabled", function(enabled)
		return RayfieldLibrary:SetElementInspectorEnabled(enabled == true)
	end)
	setHandler("toggleElementInspector", function()
		return RayfieldLibrary:ToggleElementInspector()
	end)
	setHandler("openLiveThemeEditor", function(seedDraft)
		return RayfieldLibrary:OpenLiveThemeEditor(seedDraft)
	end)
	setHandler("closeLiveThemeEditor", function()
		return RayfieldLibrary:CloseLiveThemeEditor()
	end)
	setHandler("setLiveThemeValue", function(themeKey, color)
		return RayfieldLibrary:SetLiveThemeValue(themeKey, color)
	end)
	setHandler("getLiveThemeDraft", function()
		return RayfieldLibrary:GetLiveThemeDraft()
	end)
	setHandler("applyLiveThemeDraft", function()
		return RayfieldLibrary:ApplyLiveThemeDraft()
	end)
	setHandler("exportLiveThemeDraftLua", function()
		return RayfieldLibrary:ExportLiveThemeDraftLua()
	end)

	setHandler("getThemeNames", function()
		return getThemeNamesSafe()
	end)
	setHandler("getThemeStudioKeys", function()
		return ctx.cloneArray(THEME_STUDIO_KEYS)
	end)
	setHandler("getThemeStudioColor", function(themeKey)
		return getThemeStudioColor(themeKey)
	end)
	setHandler("setThemeStudioBaseTheme", function(themeName)
		local ok, message = setThemeStudioBaseTheme(themeName, true)
		if ok then
			setSettingValue("ThemeStudio", "baseTheme", experienceState().themeStudioState.baseTheme, true)
		end
		return ok, message
	end)
	setHandler("setThemeStudioUseCustom", function(value)
		local ok, message = setThemeStudioUseCustom(value == true, true)
		if ok then
			setSettingValue("ThemeStudio", "useCustom", experienceState().themeStudioState.useCustom == true, true)
		end
		return ok, message
	end)
	setHandler("setThemeStudioColor", function(themeKey, color)
		local ok, message = setThemeStudioColor(themeKey, color)
		if ok then
			setSettingValue("ThemeStudio", "customThemePacked", cloneValue(experienceState().themeStudioState.customThemePacked), false)
			setSettingValue("ThemeStudio", "useCustom", true, true)
		end
		return ok, message
	end)
	setHandler("applyThemeStudioDraft", function()
		local ok, message = applyThemeStudioState(true)
		if ok then
			setSettingValue("ThemeStudio", "baseTheme", experienceState().themeStudioState.baseTheme, false)
			setSettingValue("ThemeStudio", "useCustom", experienceState().themeStudioState.useCustom == true, false)
			setSettingValue("ThemeStudio", "customThemePacked", cloneValue(experienceState().themeStudioState.customThemePacked), true)
		end
		return ok, message
	end)
	setHandler("resetThemeStudio", function()
		local ok, message = resetThemeStudioState(true)
		if ok then
			setSettingValue("ThemeStudio", "useCustom", false, false)
			setSettingValue("ThemeStudio", "customThemePacked", {}, true)
		end
		return ok, message
	end)
end

return module
