--[[
	Rayfield Premium UX regression
	Validates Audio Feedback + Guided Tour + Glass runtime APIs.

	Usage:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-premium-ux-pack.lua"))()
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

assertTrue(type(Rayfield.SetAudioFeedbackEnabled) == "function", "SetAudioFeedbackEnabled missing")
assertTrue(type(Rayfield.IsAudioFeedbackEnabled) == "function", "IsAudioFeedbackEnabled missing")
assertTrue(type(Rayfield.SetAudioFeedbackPack) == "function", "SetAudioFeedbackPack missing")
assertTrue(type(Rayfield.GetAudioFeedbackState) == "function", "GetAudioFeedbackState missing")
assertTrue(type(Rayfield.PlayUICue) == "function", "PlayUICue missing")
assertTrue(type(Rayfield.SetGlassMode) == "function", "SetGlassMode missing")
assertTrue(type(Rayfield.GetGlassMode) == "function", "GetGlassMode missing")
assertTrue(type(Rayfield.SetGlassIntensity) == "function", "SetGlassIntensity missing")
assertTrue(type(Rayfield.GetGlassIntensity) == "function", "GetGlassIntensity missing")
assertTrue(type(Rayfield.ShowOnboarding) == "function", "ShowOnboarding missing")
assertTrue(type(Rayfield.SetOnboardingSuppressed) == "function", "SetOnboardingSuppressed missing")
assertTrue(type(Rayfield.GetRuntimeDiagnostics) == "function", "GetRuntimeDiagnostics missing")

local Window = Rayfield:CreateWindow({
	Name = "Premium UX Regression",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false }
})
assertTrue(type(Window) == "table", "CreateWindow failed")

local diagnostics = Rayfield:GetRuntimeDiagnostics()
assertTrue(type(diagnostics) == "table", "Diagnostics should return table")

local initialAudio = Rayfield:GetAudioFeedbackState()
assertTrue(type(initialAudio) == "table", "Audio state should be table")
assertTrue(initialAudio.enabled == false, "Audio default should be disabled")
assertEquals(initialAudio.pack, "Mute", "Audio default pack should be Mute")

local okEnableAudio = select(1, Rayfield:SetAudioFeedbackEnabled(true))
assertTrue(okEnableAudio == true, "SetAudioFeedbackEnabled(true) should succeed")
assertTrue(Rayfield:IsAudioFeedbackEnabled() == true, "Audio should be enabled")

local okInvalidPack = select(1, Rayfield:SetAudioFeedbackPack("Custom", "invalid"))
assertTrue(okInvalidPack == false, "Custom pack should reject non-table payload")

local okCustomPack = select(1, Rayfield:SetAudioFeedbackPack("Custom", {
	click = "rbxassetid://0",
	hover = "rbxassetid://0",
	success = "rbxassetid://0",
	error = "rbxassetid://0"
}))
assertTrue(okCustomPack == true, "SetAudioFeedbackPack(Custom, table) should succeed")

local audioState = Rayfield:GetAudioFeedbackState()
assertTrue(type(audioState.customPack) == "table", "Audio customPack should be table")
assertEquals(audioState.pack, "Custom", "Audio pack should be Custom")

local cueResult = select(1, Rayfield:PlayUICue("click"))
assertTrue(type(cueResult) == "boolean", "PlayUICue should return boolean status")

local okDisableAudio = select(1, Rayfield:SetAudioFeedbackEnabled(false))
assertTrue(okDisableAudio == true, "SetAudioFeedbackEnabled(false) should succeed")
assertTrue(Rayfield:IsAudioFeedbackEnabled() == false, "Audio should be disabled")

local okSuppress = select(1, Rayfield:SetOnboardingSuppressed(true))
assertTrue(okSuppress == true, "SetOnboardingSuppressed(true) should succeed")
local okShowSuppressed = select(1, Rayfield:ShowOnboarding(false))
assertTrue(okShowSuppressed == false, "ShowOnboarding(false) should respect suppression")
local okShowForced = select(1, Rayfield:ShowOnboarding(true))
assertTrue(okShowForced == true, "ShowOnboarding(true) should bypass suppression")
local okShowReplay = select(1, Rayfield:ShowOnboarding(true))
assertTrue(okShowReplay == true, "ShowOnboarding replay should succeed")

local okGlassAuto = select(1, Rayfield:SetGlassMode("auto"))
assertTrue(okGlassAuto == true, "SetGlassMode(auto) should succeed")
assertEquals(Rayfield:GetGlassMode(), "auto", "Glass mode should persist requested mode")

local okGlassFallback = select(1, Rayfield:SetGlassMode("fallback"))
assertTrue(okGlassFallback == true, "SetGlassMode(fallback) should succeed")
assertEquals(Rayfield:GetGlassMode(), "fallback", "Glass mode fallback mismatch")

local okGlassCanvas = select(1, Rayfield:SetGlassMode("canvas"))
assertTrue(okGlassCanvas == true, "SetGlassMode(canvas) should succeed with fallback handling")
assertEquals(Rayfield:GetGlassMode(), "canvas", "Glass mode should retain requested canvas mode")

local okIntensity = select(1, Rayfield:SetGlassIntensity(0.63))
assertTrue(okIntensity == true, "SetGlassIntensity should succeed")
local currentIntensity = Rayfield:GetGlassIntensity()
assertTrue(type(currentIntensity) == "number", "Glass intensity should be numeric")
assertTrue(currentIntensity >= 0 and currentIntensity <= 1, "Glass intensity should stay clamped")

local diagnosticsAfter = Rayfield:GetRuntimeDiagnostics()
assertTrue(type(diagnosticsAfter.experience) == "table", "Diagnostics should expose experience block")
assertTrue(
	diagnosticsAfter.experience.glassResolvedMode == "canvas"
		or diagnosticsAfter.experience.glassResolvedMode == "fallback"
		or diagnosticsAfter.experience.glassResolvedMode == "off",
	"Resolved glass mode should be canvas/fallback/off"
)

print("Premium UX regression: PASS")

return {
	status = "PASS",
	audioPack = audioState.pack,
	glassMode = Rayfield:GetGlassMode(),
	glassResolvedMode = diagnosticsAfter.experience.glassResolvedMode
}
