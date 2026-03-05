--[[
	Rayfield UI Experience regression
	Validates Theme Studio + Presets + Favorites + Transition Profiles + Onboarding APIs.

	Usage:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-ui-experience-pack.lua"))()
]]

local BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local function assertTrue(condition, message)
	if not condition then
		error(message or "assertTrue failed")
	end
end

local function assertEquals(actual, expected, message)
	if actual ~= expected then
		error(message or ("Expected " .. tostring(expected) .. ", got " .. tostring(actual)))
	end
end

local function compileChunk(source)
	local compileString = loadstring or load
	if not compileString then
		error("No Lua compiler function available (loadstring/load)")
	end
	local fn, err = compileString(source)
	if not fn then
		error("compile failed: " .. tostring(err))
	end
	return fn
end

local function loadRemote(url)
	local source = game:HttpGet(url)
	if type(source) ~= "string" or #source == 0 then
		error("Empty source: " .. tostring(url))
	end
	source = source:gsub("^\239\187\191", "")
	source = source:gsub("^\0+", "")
	return compileChunk(source)()
end

if type(_G.__RayfieldApiModuleCache) == "table" then
	table.clear(_G.__RayfieldApiModuleCache)
end
if type(_G.RayfieldCache) == "table" then
	table.clear(_G.RayfieldCache)
end
_G.Rayfield = nil
_G.RayfieldUI = nil
_G.RayfieldAllInOneLoaded = nil
_G.__RAYFIELD_MULTI_BRIDGE_MODE = "none"
_G.__RAYFIELD_AI_BRIDGE_ASK = function(prompt)
	return "stub-answer:" .. tostring(prompt or "")
end

local Rayfield = loadRemote(BASE_URL .. "Main%20loader/rayfield-modified.lua")
assertTrue(type(Rayfield) == "table", "Rayfield load failed")

assertTrue(type(Rayfield.SetUIPreset) == "function", "SetUIPreset missing")
assertTrue(type(Rayfield.GetUIPreset) == "function", "GetUIPreset missing")
assertTrue(type(Rayfield.SetTransitionProfile) == "function", "SetTransitionProfile missing")
assertTrue(type(Rayfield.GetTransitionProfile) == "function", "GetTransitionProfile missing")
assertTrue(type(Rayfield.ListControls) == "function", "ListControls missing")
assertTrue(type(Rayfield.PinControl) == "function", "PinControl missing")
assertTrue(type(Rayfield.UnpinControl) == "function", "UnpinControl missing")
assertTrue(type(Rayfield.GetPinnedControls) == "function", "GetPinnedControls missing")
assertTrue(type(Rayfield.ShowOnboarding) == "function", "ShowOnboarding missing")
assertTrue(type(Rayfield.SetOnboardingSuppressed) == "function", "SetOnboardingSuppressed missing")
assertTrue(type(Rayfield.IsOnboardingSuppressed) == "function", "IsOnboardingSuppressed missing")
assertTrue(type(Rayfield.SetAudioFeedbackEnabled) == "function", "SetAudioFeedbackEnabled missing")
assertTrue(type(Rayfield.IsAudioFeedbackEnabled) == "function", "IsAudioFeedbackEnabled missing")
assertTrue(type(Rayfield.SetAudioFeedbackPack) == "function", "SetAudioFeedbackPack missing")
assertTrue(type(Rayfield.GetAudioFeedbackState) == "function", "GetAudioFeedbackState missing")
assertTrue(type(Rayfield.PlayUICue) == "function", "PlayUICue missing")
assertTrue(type(Rayfield.SetGlassMode) == "function", "SetGlassMode missing")
assertTrue(type(Rayfield.GetGlassMode) == "function", "GetGlassMode missing")
assertTrue(type(Rayfield.SetGlassIntensity) == "function", "SetGlassIntensity missing")
assertTrue(type(Rayfield.GetGlassIntensity) == "function", "GetGlassIntensity missing")
assertTrue(type(Rayfield.GetThemeStudioState) == "function", "GetThemeStudioState missing")
assertTrue(type(Rayfield.ApplyThemeStudioTheme) == "function", "ApplyThemeStudioTheme missing")
assertTrue(type(Rayfield.ResetThemeStudio) == "function", "ResetThemeStudio missing")
assertTrue(type(Rayfield.OpenCommandPalette) == "function", "OpenCommandPalette missing")
assertTrue(type(Rayfield.CloseCommandPalette) == "function", "CloseCommandPalette missing")
assertTrue(type(Rayfield.ToggleCommandPalette) == "function", "ToggleCommandPalette missing")
assertTrue(type(Rayfield.SetCommandPaletteExecutionMode) == "function", "SetCommandPaletteExecutionMode missing")
assertTrue(type(Rayfield.GetCommandPaletteExecutionMode) == "function", "GetCommandPaletteExecutionMode missing")
assertTrue(type(Rayfield.SetCommandPalettePolicy) == "function", "SetCommandPalettePolicy missing")
assertTrue(type(Rayfield.RunCommandPaletteItem) == "function", "RunCommandPaletteItem missing")
assertTrue(type(Rayfield.OpenActionCenter) == "function", "OpenActionCenter missing")
assertTrue(type(Rayfield.CloseActionCenter) == "function", "CloseActionCenter missing")
assertTrue(type(Rayfield.ToggleActionCenter) == "function", "ToggleActionCenter missing")
assertTrue(type(Rayfield.GetNotificationHistory) == "function", "GetNotificationHistory missing")
assertTrue(type(Rayfield.ClearNotificationHistory) == "function", "ClearNotificationHistory missing")
assertTrue(type(Rayfield.GetUnreadNotificationCount) == "function", "GetUnreadNotificationCount missing")
assertTrue(type(Rayfield.MarkAllNotificationsRead) == "function", "MarkAllNotificationsRead missing")
assertTrue(type(Rayfield.GetNotificationHistoryEx) == "function", "GetNotificationHistoryEx missing")
assertTrue(type(Rayfield.SaveWorkspace) == "function", "SaveWorkspace missing")
assertTrue(type(Rayfield.LoadWorkspace) == "function", "LoadWorkspace missing")
assertTrue(type(Rayfield.ListWorkspaces) == "function", "ListWorkspaces missing")
assertTrue(type(Rayfield.DeleteWorkspace) == "function", "DeleteWorkspace missing")
assertTrue(type(Rayfield.SaveProfile) == "function", "SaveProfile missing")
assertTrue(type(Rayfield.LoadProfile) == "function", "LoadProfile missing")
assertTrue(type(Rayfield.ListProfiles) == "function", "ListProfiles missing")
assertTrue(type(Rayfield.DeleteProfile) == "function", "DeleteProfile missing")
assertTrue(type(Rayfield.CopyWorkspaceToProfile) == "function", "CopyWorkspaceToProfile missing")
assertTrue(type(Rayfield.CopyProfileToWorkspace) == "function", "CopyProfileToWorkspace missing")
assertTrue(type(Rayfield.ShowContextMenu) == "function", "ShowContextMenu missing")
assertTrue(type(Rayfield.HideContextMenu) == "function", "HideContextMenu missing")
assertTrue(type(Rayfield.OpenPerformanceHUD) == "function", "OpenPerformanceHUD missing")
assertTrue(type(Rayfield.ClosePerformanceHUD) == "function", "ClosePerformanceHUD missing")
assertTrue(type(Rayfield.TogglePerformanceHUD) == "function", "TogglePerformanceHUD missing")
assertTrue(type(Rayfield.ConfigurePerformanceHUD) == "function", "ConfigurePerformanceHUD missing")
assertTrue(type(Rayfield.GetPerformanceHUDState) == "function", "GetPerformanceHUDState missing")
assertTrue(type(Rayfield.RegisterHUDMetricProvider) == "function", "RegisterHUDMetricProvider missing")
assertTrue(type(Rayfield.UnregisterHUDMetricProvider) == "function", "UnregisterHUDMetricProvider missing")
assertTrue(type(Rayfield.GetUsageAnalytics) == "function", "GetUsageAnalytics missing")
assertTrue(type(Rayfield.ClearUsageAnalytics) == "function", "ClearUsageAnalytics missing")
assertTrue(type(Rayfield.StartMacroRecording) == "function", "StartMacroRecording missing")
assertTrue(type(Rayfield.StopMacroRecording) == "function", "StopMacroRecording missing")
assertTrue(type(Rayfield.IsMacroExecuting) == "function", "IsMacroExecuting missing")
assertTrue(type(Rayfield.ListMacros) == "function", "ListMacros missing")
assertTrue(type(Rayfield.ExecuteMacro) == "function", "ExecuteMacro missing")
assertTrue(type(Rayfield.BindMacro) == "function", "BindMacro missing")
assertTrue(type(Rayfield.RegisterDiscoveryProvider) == "function", "RegisterDiscoveryProvider missing")
assertTrue(type(Rayfield.UnregisterDiscoveryProvider) == "function", "UnregisterDiscoveryProvider missing")
assertTrue(type(Rayfield.QueryDiscovery) == "function", "QueryDiscovery missing")
assertTrue(type(Rayfield.ExecutePromptCommand) == "function", "ExecutePromptCommand missing")
assertTrue(type(Rayfield.AskAssistant) == "function", "AskAssistant missing")
assertTrue(type(Rayfield.GetAssistantHistory) == "function", "GetAssistantHistory missing")
assertTrue(type(Rayfield.SendGlobalSignal) == "function", "SendGlobalSignal missing")
assertTrue(type(Rayfield.SendInternalChat) == "function", "SendInternalChat missing")
assertTrue(type(Rayfield.PollBridgeMessages) == "function", "PollBridgeMessages missing")
assertTrue(type(Rayfield.StartBridgePolling) == "function", "StartBridgePolling missing")
assertTrue(type(Rayfield.StopBridgePolling) == "function", "StopBridgePolling missing")
assertTrue(type(Rayfield.GetBridgeMessages) == "function", "GetBridgeMessages missing")
assertTrue(type(Rayfield.ScheduleMacro) == "function", "ScheduleMacro missing")
assertTrue(type(Rayfield.ScheduleAction) == "function", "ScheduleAction missing")
assertTrue(type(Rayfield.CancelScheduledAction) == "function", "CancelScheduledAction missing")
assertTrue(type(Rayfield.ListScheduledActions) == "function", "ListScheduledActions missing")
assertTrue(type(Rayfield.ClearScheduledActions) == "function", "ClearScheduledActions missing")
assertTrue(type(Rayfield.AddAutomationRule) == "function", "AddAutomationRule missing")
assertTrue(type(Rayfield.RemoveAutomationRule) == "function", "RemoveAutomationRule missing")
assertTrue(type(Rayfield.ListAutomationRules) == "function", "ListAutomationRules missing")
assertTrue(type(Rayfield.SetAutomationRuleEnabled) == "function", "SetAutomationRuleEnabled missing")
assertTrue(type(Rayfield.EvaluateAutomationRules) == "function", "EvaluateAutomationRules missing")
assertTrue(type(Rayfield.RegisterHubMetadata) == "function", "RegisterHubMetadata missing")
assertTrue(type(Rayfield.GetHubMetadata) == "function", "GetHubMetadata missing")
assertTrue(type(Rayfield.ToggleElementInspector) == "function", "ToggleElementInspector missing")
assertTrue(type(Rayfield.IsElementInspectorEnabled) == "function", "IsElementInspectorEnabled missing")
assertTrue(type(Rayfield.OpenLiveThemeEditor) == "function", "OpenLiveThemeEditor missing")
assertTrue(type(Rayfield.ExportLiveThemeDraftLua) == "function", "ExportLiveThemeDraftLua missing")

local Window = Rayfield:CreateWindow({
	Name = "UI Experience Regression",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false }
})
assertTrue(type(Window) == "table", "CreateWindow failed")

local Tab = Window:CreateTab("Experience", 4483362458)
assertTrue(type(Tab) == "table", "CreateTab failed")

local toggle = Tab:CreateToggle({
	Name = "Pin Candidate",
	CurrentValue = false,
	Callback = function() end
})
assertTrue(type(toggle) == "table", "Toggle creation failed")
assertTrue(type(toggle.GetFavoriteId) == "function", "Element:GetFavoriteId missing")
assertTrue(type(toggle.Pin) == "function", "Element:Pin missing")
assertTrue(type(toggle.Unpin) == "function", "Element:Unpin missing")
assertTrue(type(toggle.IsPinned) == "function", "Element:IsPinned missing")

assertTrue(type(Tab.CreateDataGrid) == "function", "CreateDataGrid missing")
local dataGrid = Tab:CreateDataGrid({
	Name = "Regression Grid",
	Columns = {
		{ Key = "id", Title = "ID", Sortable = true },
		{ Key = "name", Title = "Name", Sortable = true },
		{ Key = "score", Title = "Score", Sortable = true }
	},
	Rows = {
		{ id = "a", name = "Alpha", score = 20 },
		{ id = "b", name = "Beta", score = 10 },
		{ id = "c", name = "Gamma", score = 30 }
	}
})
assertTrue(type(dataGrid) == "table", "CreateDataGrid failed")
assertTrue(type(dataGrid.SetRows) == "function", "DataGrid:SetRows missing")
assertTrue(type(dataGrid.GetRows) == "function", "DataGrid:GetRows missing")
assertTrue(type(dataGrid.SortBy) == "function", "DataGrid:SortBy missing")
assertTrue(type(dataGrid.SetFilter) == "function", "DataGrid:SetFilter missing")
assertTrue(type(dataGrid.GetFilter) == "function", "DataGrid:GetFilter missing")
assertTrue(type(dataGrid.GetSelectedRow) == "function", "DataGrid:GetSelectedRow missing")
assertTrue(type(dataGrid.ExportCSV) == "function", "DataGrid:ExportCSV missing")
assertTrue(type(dataGrid.ExportJSON) == "function", "DataGrid:ExportJSON missing")
assertTrue(select(1, dataGrid:SortBy("score", "asc")) == true, "DataGrid sort asc failed")
assertTrue(select(1, dataGrid:SetFilter("beta")) == true, "DataGrid filter failed")
assertEquals(dataGrid:GetFilter(), "beta", "DataGrid filter mismatch")
local exportCsvOk, exportCsvPayload = dataGrid:ExportCSV({
	writeFile = false,
	scope = "all"
})
assertTrue(exportCsvOk == true, "DataGrid:ExportCSV inline failed")
assertTrue(type(exportCsvPayload) == "string" and string.find(exportCsvPayload, "ID", 1, true) ~= nil, "DataGrid CSV payload malformed")
local exportJsonOk, exportJsonPayload = dataGrid:ExportJSON({
	writeFile = false,
	scope = "all"
})
assertTrue(exportJsonOk == true, "DataGrid:ExportJSON inline failed")
assertTrue(type(exportJsonPayload) == "string" and string.find(exportJsonPayload, "\"rows\"", 1, true) ~= nil, "DataGrid JSON payload malformed")

local setTransitionOk, setTransitionMsg = Rayfield:SetTransitionProfile("Snappy")
assertTrue(setTransitionOk == true, "SetTransitionProfile failed: " .. tostring(setTransitionMsg))
assertEquals(Rayfield:GetTransitionProfile(), "Snappy", "Transition profile mismatch")

local setPresetOk, setPresetMsg = Rayfield:SetUIPreset("Focus")
assertTrue(setPresetOk == true, "SetUIPreset failed: " .. tostring(setPresetMsg))
assertEquals(Rayfield:GetUIPreset(), "Focus", "UI preset mismatch")

local setCripwareOk, setCripwareMsg = Rayfield:SetUIPreset("Cripware")
assertTrue(setCripwareOk == true, "SetUIPreset(Cripware) failed: " .. tostring(setCripwareMsg))
assertEquals(Rayfield:GetUIPreset(), "Cripware", "UI preset Cripware mismatch")

local controlsBeforePin = Rayfield:ListControls()
assertTrue(type(controlsBeforePin) == "table" and #controlsBeforePin > 0, "ListControls should contain created controls")

local favId = toggle:GetFavoriteId()
assertTrue(type(favId) == "string" and favId ~= "", "Favorite ID should be a non-empty string")

local pinElementOk = select(1, toggle:Pin())
assertTrue(pinElementOk == true, "Element:Pin should return true")
assertTrue(toggle:IsPinned() == true, "Element should be pinned after Element:Pin")

local unpinApiOk = select(1, Rayfield:UnpinControl(favId))
assertTrue(unpinApiOk == true, "UnpinControl should succeed with favorite ID")
assertTrue(toggle:IsPinned() == false, "Element should be unpinned after UnpinControl")

local pinApiOk = select(1, Rayfield:PinControl(favId))
assertTrue(pinApiOk == true, "PinControl should succeed with favorite ID")
local pinnedList = Rayfield:GetPinnedControls()
assertTrue(type(pinnedList) == "table" and #pinnedList >= 1, "GetPinnedControls should include pinned control")

local themeStateBefore = Rayfield:GetThemeStudioState()
assertTrue(type(themeStateBefore) == "table", "GetThemeStudioState should return table")

local applyThemeOk = select(1, Rayfield:ApplyThemeStudioTheme({
	TextColor = Color3.fromRGB(240, 240, 240),
	Background = Color3.fromRGB(15, 20, 30),
	Topbar = Color3.fromRGB(20, 30, 45)
}))
assertTrue(applyThemeOk == true, "ApplyThemeStudioTheme(table) should succeed")

local resetThemeOk = select(1, Rayfield:ResetThemeStudio())
assertTrue(resetThemeOk == true, "ResetThemeStudio should succeed")

local suppressOnboardingOk = select(1, Rayfield:SetOnboardingSuppressed(true))
assertTrue(suppressOnboardingOk == true, "SetOnboardingSuppressed(true) failed")
assertTrue(Rayfield:IsOnboardingSuppressed() == true, "Onboarding should be suppressed")

local showForcedOk = select(1, Rayfield:ShowOnboarding(true))
assertTrue(showForcedOk == true, "ShowOnboarding(true) should bypass suppression")

assertTrue(Rayfield:IsAudioFeedbackEnabled() == false, "Audio should be disabled by default")
local audioEnableOk = select(1, Rayfield:SetAudioFeedbackEnabled(true))
assertTrue(audioEnableOk == true, "SetAudioFeedbackEnabled(true) should succeed")
assertTrue(Rayfield:IsAudioFeedbackEnabled() == true, "Audio should be enabled")

local setCustomPackOk = select(1, Rayfield:SetAudioFeedbackPack("Custom", {
	click = "rbxassetid://0",
	hover = "rbxassetid://0",
	success = "rbxassetid://0",
	error = "rbxassetid://0"
}))
assertTrue(setCustomPackOk == true, "SetAudioFeedbackPack(Custom) should succeed")

local audioState = Rayfield:GetAudioFeedbackState()
assertTrue(type(audioState) == "table" and audioState.pack == "Custom", "Audio state should reflect Custom pack")

local audioDisableOk = select(1, Rayfield:SetAudioFeedbackEnabled(false))
assertTrue(audioDisableOk == true and Rayfield:IsAudioFeedbackEnabled() == false, "SetAudioFeedbackEnabled(false) should disable audio")

local paletteOpenOk = select(1, Rayfield:OpenCommandPalette("open set"))
assertTrue(paletteOpenOk == true, "OpenCommandPalette failed")
assertTrue(select(1, Rayfield:CloseCommandPalette()) == true, "CloseCommandPalette failed")
assertTrue(select(1, Rayfield:SetCommandPaletteExecutionMode("auto")) == true, "SetCommandPaletteExecutionMode(auto) failed")
assertEquals(Rayfield:GetCommandPaletteExecutionMode(), "auto", "GetCommandPaletteExecutionMode mismatch")
assertTrue(select(1, Rayfield:SetCommandPalettePolicy(nil)) == true, "SetCommandPalettePolicy(nil) failed")
assertTrue(type(select(1, Rayfield:RunCommandPaletteItem({
	id = "test-open-action-center",
	action = "open_action_center",
	type = "command",
	name = "Open Action Center"
}, "execute"))) == "boolean", "RunCommandPaletteItem should return boolean status")
assertTrue(select(1, Rayfield:OpenActionCenter()) == true, "OpenActionCenter failed")
assertTrue(select(1, Rayfield:CloseActionCenter()) == true, "CloseActionCenter failed")
assertTrue(select(1, Rayfield:ExecutePromptCommand("/set color blue")) == true, "ExecutePromptCommand(/set color blue) failed")
local askOk, askResult = Rayfield:AskAssistant("where is spawn?")
assertTrue(askOk == true and type(askResult) == "string", "AskAssistant failed")
local assistantHistory = Rayfield:GetAssistantHistory()
assertTrue(type(assistantHistory) == "table", "GetAssistantHistory should return table")

Rayfield:Notify({
	Title = "Regression Notification",
	Content = "History check"
})
local history = Rayfield:GetNotificationHistory(5)
assertTrue(type(history) == "table", "GetNotificationHistory should return table")
assertTrue(type(Rayfield:GetUnreadNotificationCount()) == "number", "GetUnreadNotificationCount should return number")
assertTrue(type(Rayfield:GetNotificationHistoryEx({ level = "info", query = "history" })) == "table", "GetNotificationHistoryEx should return table")
assertTrue(select(1, Rayfield:MarkAllNotificationsRead()) == true, "MarkAllNotificationsRead failed")
assertTrue(select(1, Rayfield:ClearNotificationHistory()) == true, "ClearNotificationHistory failed")

local workspaceSaveOk = select(1, Rayfield:SaveWorkspace("regression-workspace"))
assertTrue(workspaceSaveOk == true, "SaveWorkspace failed")
local workspaceList = Rayfield:ListWorkspaces()
assertTrue(type(workspaceList) == "table", "ListWorkspaces should return table")
assertTrue(select(1, Rayfield:LoadWorkspace("regression-workspace")) == true, "LoadWorkspace failed")
assertTrue(select(1, Rayfield:CopyWorkspaceToProfile("regression-workspace", "regression-profile")) == true, "CopyWorkspaceToProfile failed")
assertTrue(type(Rayfield:ListProfiles()) == "table", "ListProfiles should return table")
assertTrue(select(1, Rayfield:LoadProfile("regression-profile")) == true, "LoadProfile failed")
assertTrue(select(1, Rayfield:CopyProfileToWorkspace("regression-profile", "regression-workspace")) == true, "CopyProfileToWorkspace failed")
assertTrue(select(1, Rayfield:DeleteProfile("regression-profile")) == true, "DeleteProfile failed")
assertTrue(select(1, Rayfield:DeleteWorkspace("regression-workspace")) == true, "DeleteWorkspace failed")
assertTrue(select(1, Rayfield:OpenPerformanceHUD()) == true, "OpenPerformanceHUD failed")
assertTrue(select(1, Rayfield:ConfigurePerformanceHUD({ updateHz = 3, opacity = 0.7 })) == true, "ConfigurePerformanceHUD failed")
local hudState = Rayfield:GetPerformanceHUDState()
assertTrue(type(hudState) == "table", "GetPerformanceHUDState should return table")
assertTrue(select(1, Rayfield:RegisterHUDMetricProvider("regression-metric", function()
	return "ok"
end)) == true, "RegisterHUDMetricProvider failed")
assertTrue(select(1, Rayfield:UnregisterHUDMetricProvider("regression-metric")) == true, "UnregisterHUDMetricProvider failed")
assertTrue(select(1, Rayfield:TogglePerformanceHUD()) == true, "TogglePerformanceHUD failed")
assertTrue(select(1, Rayfield:ClosePerformanceHUD()) == true, "ClosePerformanceHUD failed")
assertTrue(select(1, Rayfield:RegisterDiscoveryProvider("regression-provider", function(queryText, queryLower)
	if queryLower == "alpha" then
		return {
			{ id = "disc-alpha", name = "Alpha Landmark", type = "location", searchText = "alpha landmark" }
		}
	end
	return {}
end)) == true, "RegisterDiscoveryProvider failed")
local discoveryResults = Rayfield:QueryDiscovery("alpha")
assertTrue(type(discoveryResults) == "table", "QueryDiscovery should return table")
assertTrue(select(1, Rayfield:UnregisterDiscoveryProvider("regression-provider")) == true, "UnregisterDiscoveryProvider failed")
local bridgeSignalOk = select(1, Rayfield:SendGlobalSignal("ping", { test = true }))
assertTrue(type(bridgeSignalOk) == "boolean", "SendGlobalSignal should return boolean status")
local bridgeChatOk = select(1, Rayfield:SendInternalChat("regression message"))
assertTrue(type(bridgeChatOk) == "boolean", "SendInternalChat should return boolean status")
assertTrue(type(select(1, Rayfield:StartBridgePolling())) == "boolean", "StartBridgePolling should return boolean status")
assertTrue(type(select(1, Rayfield:StopBridgePolling())) == "boolean", "StopBridgePolling should return boolean status")
assertTrue(type(Rayfield:GetBridgeMessages(10)) == "table", "GetBridgeMessages should return table")
assertTrue(type(select(1, Rayfield:PollBridgeMessages(20))) == "boolean", "PollBridgeMessages should return boolean status")

assertTrue(select(1, Rayfield:StartMacroRecording("regression-macro")) == true, "StartMacroRecording failed")
assertTrue(Rayfield:IsMacroExecuting() == false, "Macro should not be executing during recording")
toggle:Set(true)
assertTrue(select(1, Rayfield:StopMacroRecording(true)) == true, "StopMacroRecording failed")
local macroList = Rayfield:ListMacros()
assertTrue(type(macroList) == "table", "ListMacros should return table")
assertTrue(select(1, Rayfield:BindMacro("regression-macro", "LeftControl+M")) == true, "BindMacro failed")
assertTrue(select(1, Rayfield:ExecuteMacro("regression-macro", {respectDelay = false})) == true, "ExecuteMacro failed")
assertTrue(Rayfield:IsMacroExecuting() == false, "Macro should be idle after ExecuteMacro")
local scheduleMacroOk = select(1, Rayfield:ScheduleMacro("regression-macro", 0))
assertTrue(type(scheduleMacroOk) == "boolean", "ScheduleMacro should return boolean status")
local scheduleActionOk, _, scheduleActionData = Rayfield:ScheduleAction({
	type = "command",
	action = "open_action_center"
}, 0)
assertTrue(type(scheduleActionOk) == "boolean", "ScheduleAction should return boolean status")
local scheduledActions = Rayfield:ListScheduledActions()
assertTrue(type(scheduledActions) == "table", "ListScheduledActions should return table")
if type(scheduleActionData) == "table" and type(scheduleActionData.id) == "string" and scheduleActionData.id ~= "" then
	assertTrue(type(select(1, Rayfield:CancelScheduledAction(scheduleActionData.id))) == "boolean", "CancelScheduledAction should return boolean status")
end
assertTrue(select(1, Rayfield:ClearScheduledActions()) == true, "ClearScheduledActions failed")
assertTrue(select(1, Rayfield:AddAutomationRule({
	id = "regression-rule",
	name = "Regression Rule",
	when = {
		action = "set",
		controlId = favId,
		valueEquals = true
	},
	["then"] = {
		type = "command",
		action = "open_action_center"
	}
})) == true, "AddAutomationRule failed")
local automationRules = Rayfield:ListAutomationRules()
assertTrue(type(automationRules) == "table", "ListAutomationRules should return table")
assertTrue(select(1, Rayfield:SetAutomationRuleEnabled("regression-rule", true)) == true, "SetAutomationRuleEnabled failed")
assertTrue(type(select(1, Rayfield:EvaluateAutomationRules({
	action = "set",
	controlId = favId,
	id = favId,
	value = true
}))) == "boolean", "EvaluateAutomationRules should return boolean status")
assertTrue(select(1, Rayfield:RemoveAutomationRule("regression-rule")) == true, "RemoveAutomationRule failed")
assertTrue(select(1, Rayfield:DeleteMacro("regression-macro")) == true, "DeleteMacro failed")

assertTrue(select(1, Rayfield:RegisterHubMetadata({
	Name = "Regression Hub",
	Author = "Rayfield QA",
	Version = "1.0.0",
	UpdateLog = "Regression bridge check",
	Discord = "discord.gg/example"
})) == true, "RegisterHubMetadata failed")
local hubMeta = Rayfield:GetHubMetadata()
assertTrue(type(hubMeta) == "table", "GetHubMetadata should return table")

assertTrue(select(1, Rayfield:ToggleElementInspector()) == true, "ToggleElementInspector failed")
assertTrue(type(Rayfield:IsElementInspectorEnabled()) == "boolean", "IsElementInspectorEnabled should return boolean")
assertTrue(select(1, Rayfield:OpenLiveThemeEditor()) == true, "OpenLiveThemeEditor failed")
assertTrue(select(1, Rayfield:SetLiveThemeValue("SliderProgress", Color3.fromRGB(100, 200, 255))) == true, "SetLiveThemeValue failed")
assertTrue(select(1, Rayfield:ApplyLiveThemeDraft()) == true, "ApplyLiveThemeDraft failed")
local exportThemeOk, exportThemeLua = Rayfield:ExportLiveThemeDraftLua()
assertTrue(exportThemeOk == true and type(exportThemeLua) == "string", "ExportLiveThemeDraftLua failed")

local usageSnapshot = Rayfield:GetUsageAnalytics(10)
assertTrue(type(usageSnapshot) == "table", "GetUsageAnalytics should return table")
assertTrue(select(1, Rayfield:ClearUsageAnalytics()) == true, "ClearUsageAnalytics failed")

print("UI Experience regression: PASS")

return {
	status = "PASS",
	favoriteId = favId,
	pinnedCount = #pinnedList
}
