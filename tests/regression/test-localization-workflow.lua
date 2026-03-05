--[[
	Rayfield localization workflow regression
	Validates user-driven control/system labels, scoped export/import, UTF-8 safety.

	Usage:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-localization-workflow.lua"))()
]]

local BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local UTF8_CONTROL_LABEL = "\229\138\160\233\128\159"
local UTF8_SYSTEM_LABEL = "\232\170\173\229\174\154"

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

local Rayfield = loadRemote(BASE_URL .. "Main%20loader/rayfield-modified.lua")
assertTrue(type(Rayfield) == "table", "Rayfield load failed")

assertTrue(type(Rayfield.ListControls) == "function", "ListControls missing")
assertTrue(type(Rayfield.SetControlDisplayLabel) == "function", "SetControlDisplayLabel missing")
assertTrue(type(Rayfield.GetControlDisplayLabel) == "function", "GetControlDisplayLabel missing")
assertTrue(type(Rayfield.ResetControlDisplayLabel) == "function", "ResetControlDisplayLabel missing")
assertTrue(type(Rayfield.SetSystemDisplayLabel) == "function", "SetSystemDisplayLabel missing")
assertTrue(type(Rayfield.GetSystemDisplayLabel) == "function", "GetSystemDisplayLabel missing")
assertTrue(type(Rayfield.LocalizeString) == "function", "LocalizeString missing")
assertTrue(type(Rayfield.SetLocalizationLanguageTag) == "function", "SetLocalizationLanguageTag missing")
assertTrue(type(Rayfield.GetLocalizationState) == "function", "GetLocalizationState missing")
assertTrue(type(Rayfield.ExportLocalization) == "function", "ExportLocalization missing")
assertTrue(type(Rayfield.ImportLocalization) == "function", "ImportLocalization missing")
assertTrue(type(Rayfield.ResetDisplayLanguage) == "function", "ResetDisplayLanguage missing")

local window = Rayfield:CreateWindow({
	Name = "Localization Regression",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false }
})
assertTrue(type(window) == "table", "CreateWindow failed")

local tab = window:CreateTab("Localization", 4483362458)
assertTrue(type(tab) == "table", "CreateTab failed")

local toggle = tab:CreateToggle({
	Name = "Localized Toggle",
	Flag = "loc_toggle_flag",
	CurrentValue = false,
	Callback = function() end
})
assertTrue(type(toggle) == "table", "CreateToggle failed")

Rayfield.Flags = Rayfield.Flags or {}
Rayfield.Flags.loc_toggle_flag = toggle

local function findControlByFlag(controlList, flagName)
	for _, control in ipairs(type(controlList) == "table" and controlList or {}) do
		if type(control) == "table" and tostring(control.flag or "") == tostring(flagName) then
			return control
		end
	end
	return nil
end

local controlsBefore = Rayfield:ListControls()
local toggleControl = findControlByFlag(controlsBefore, "loc_toggle_flag")
assertTrue(type(toggleControl) == "table", "ListControls should include flagged toggle")
assertEquals(tostring(toggleControl.internalName), "Localized Toggle", "internalName mismatch before rename")
assertEquals(tostring(toggleControl.displayName), "Localized Toggle", "displayName mismatch before rename")
assertTrue(type(toggleControl.localizationKey) == "string" and toggleControl.localizationKey ~= "", "localizationKey missing")

local setDisplayOk, setDisplayMsg = Rayfield:SetControlDisplayLabel("loc_toggle_flag", UTF8_CONTROL_LABEL)
assertTrue(setDisplayOk == true, "SetControlDisplayLabel failed: " .. tostring(setDisplayMsg))
assertEquals(Rayfield:GetControlDisplayLabel("loc_toggle_flag"), UTF8_CONTROL_LABEL, "Display label should use UTF-8 value")

local setSystemOk, setSystemMsg = Rayfield:SetSystemDisplayLabel("settings.section.localization", UTF8_SYSTEM_LABEL)
assertTrue(setSystemOk == true, "SetSystemDisplayLabel failed: " .. tostring(setSystemMsg))
assertEquals(Rayfield:GetSystemDisplayLabel("settings.section.localization"), UTF8_SYSTEM_LABEL, "GetSystemDisplayLabel mismatch")
assertEquals(Rayfield:LocalizeString("settings.section.localization", "Localization"), UTF8_SYSTEM_LABEL, "LocalizeString should return custom system label")

local setLanguageOk, languageTag = Rayfield:SetLocalizationLanguageTag("vi")
assertTrue(setLanguageOk == true, "SetLocalizationLanguageTag failed")
assertEquals(tostring(languageTag), "vi", "Language tag mismatch")

local stateBeforeExport = Rayfield:GetLocalizationState()
assertTrue(type(stateBeforeExport) == "table", "GetLocalizationState should return table")
assertTrue(type(stateBeforeExport.scopeKey) == "string" and stateBeforeExport.scopeKey ~= "", "scopeKey should be non-empty")
assertTrue((tonumber(stateBeforeExport.controlLabelCount) or 0) >= 1, "controlLabelCount should be >= 1")
assertTrue((tonumber(stateBeforeExport.systemLabelCount) or 0) >= 1, "systemLabelCount should be >= 1")

local exportOk, exportJson = Rayfield:ExportLocalization({ asJson = true })
assertTrue(exportOk == true, "ExportLocalization should succeed")
assertTrue(type(exportJson) == "string" and exportJson ~= "", "ExportLocalization JSON should be non-empty")
assertTrue(string.find(exportJson, UTF8_CONTROL_LABEL, 1, true) ~= nil, "Export JSON should preserve UTF-8 control label")
assertTrue(string.find(exportJson, UTF8_SYSTEM_LABEL, 1, true) ~= nil, "Export JSON should preserve UTF-8 system label")

local resetOk, resetMsg = Rayfield:ResetDisplayLanguage({ languageTag = "en" })
assertTrue(resetOk == true, "ResetDisplayLanguage failed: " .. tostring(resetMsg))
assertEquals(Rayfield:GetControlDisplayLabel("loc_toggle_flag"), "Localized Toggle", "Control label should reset to English/internal name")

local importOk, importMsg = Rayfield:ImportLocalization(exportJson, { merge = false })
assertTrue(importOk == true, "ImportLocalization failed: " .. tostring(importMsg))
assertEquals(Rayfield:GetControlDisplayLabel("loc_toggle_flag"), UTF8_CONTROL_LABEL, "Control label should restore after import")
assertEquals(Rayfield:LocalizeString("settings.section.localization", "Localization"), UTF8_SYSTEM_LABEL, "System label should restore after import")

local finalResetOk = select(1, Rayfield:ResetDisplayLanguage({ languageTag = "en" }))
assertTrue(finalResetOk == true, "Final ResetDisplayLanguage should succeed")

print("Localization workflow regression: PASS")

return {
	status = "PASS",
	scope = stateBeforeExport.scopeKey,
	controlLabel = Rayfield:GetControlDisplayLabel("loc_toggle_flag")
}
