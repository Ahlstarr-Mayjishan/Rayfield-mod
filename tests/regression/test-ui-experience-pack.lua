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
assertTrue(type(Rayfield.GetThemeStudioState) == "function", "GetThemeStudioState missing")
assertTrue(type(Rayfield.ApplyThemeStudioTheme) == "function", "ApplyThemeStudioTheme missing")
assertTrue(type(Rayfield.ResetThemeStudio) == "function", "ResetThemeStudio missing")

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

local setTransitionOk, setTransitionMsg = Rayfield:SetTransitionProfile("Snappy")
assertTrue(setTransitionOk == true, "SetTransitionProfile failed: " .. tostring(setTransitionMsg))
assertEquals(Rayfield:GetTransitionProfile(), "Snappy", "Transition profile mismatch")

local setPresetOk, setPresetMsg = Rayfield:SetUIPreset("Focus")
assertTrue(setPresetOk == true, "SetUIPreset failed: " .. tostring(setPresetMsg))
assertEquals(Rayfield:GetUIPreset(), "Focus", "UI preset mismatch")

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

print("UI Experience regression: PASS")

return {
	status = "PASS",
	favoriteId = favId,
	pinnedCount = #pinnedList
}
