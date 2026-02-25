--[[
	Rayfield element sync regression
	Validates unified state/visual/callback/persist commit path for core stateful elements.

	Usage:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-element-sync-consistency.lua"))()
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

local Window = Rayfield:CreateWindow({
	Name = "Element Sync Regression",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false }
})
assertTrue(type(Window) == "table", "CreateWindow failed")

local Tab = Window:CreateTab("Sync", 4483362458)
assertTrue(type(Tab) == "table", "CreateTab failed")

local callbackHits = {
	dropdown = 0,
	toggle = 0,
	input = 0,
	slider = 0,
	track = 0,
	status = 0
}

local dropdown = Tab:CreateDropdown({
	Name = "Dropdown Sync",
	Options = {"Alpha", "Beta", "Gamma"},
	CurrentOption = {},
	DefaultSelection = {"Beta"},
	ClearBehavior = "default",
	Callback = function(selection)
		callbackHits.dropdown = callbackHits.dropdown + 1
		assertTrue(type(selection) == "table", "Dropdown callback shape mismatch")
	end
})
assertTrue(type(dropdown) == "table", "Dropdown create failed")

dropdown:Clear()
assertTrue(type(dropdown.CurrentOption) == "table", "Dropdown current option should be table")
assertEquals(dropdown.CurrentOption[1], "Beta", "Dropdown clear fallback mismatch")
assertTrue(callbackHits.dropdown >= 1, "Dropdown fallback must emit callback")

dropdown:Refresh({"Beta", "Gamma"})
assertEquals(dropdown.CurrentOption[1], "Beta", "Dropdown refresh normalize mismatch")
dropdown:Set({"Gamma"})
assertEquals(dropdown.CurrentOption[1], "Gamma", "Dropdown Set mismatch")

local toggle = Tab:CreateToggle({
	Name = "Toggle Sync",
	CurrentValue = false,
	Callback = function(value)
		callbackHits.toggle = callbackHits.toggle + 1
		assertTrue(type(value) == "boolean", "Toggle callback value type mismatch")
	end
})
toggle:Set(true)
toggle:Set(false)
assertEquals(toggle:Get(), false, "Toggle final state mismatch")
assertTrue(callbackHits.toggle >= 2, "Toggle callback should be emitted on Set")

local input = Tab:CreateInput({
	Name = "Input Sync",
	CurrentValue = "",
	PlaceholderText = "Type",
	RemoveTextAfterFocusLost = false,
	Callback = function(value)
		callbackHits.input = callbackHits.input + 1
		assertTrue(type(value) == "string", "Input callback value type mismatch")
	end
})
input:Set("hello-sync")
assertEquals(input.CurrentValue, "hello-sync", "Input state mismatch")
assertTrue(callbackHits.input >= 1, "Input callback should be emitted on Set")

local slider = Tab:CreateSlider({
	Name = "Slider Sync",
	Range = {0, 100},
	Increment = 1,
	CurrentValue = 10,
	Callback = function(value)
		callbackHits.slider = callbackHits.slider + 1
		assertTrue(type(value) == "number", "Slider callback value type mismatch")
	end
})
slider:Set(42)
assertEquals(slider.CurrentValue, 42, "Slider state mismatch")
assertTrue(callbackHits.slider >= 1, "Slider callback should be emitted on Set")

local track = Tab:CreateTrackBar({
	Name = "Track Sync",
	Range = {0, 100},
	Increment = 1,
	CurrentValue = 15,
	Callback = function(value)
		callbackHits.track = callbackHits.track + 1
		assertTrue(type(value) == "number", "TrackBar callback value type mismatch")
	end
})
track:Set(73)
assertEquals(track:Get(), 73, "TrackBar state mismatch")
assertTrue(callbackHits.track >= 1, "TrackBar callback should be emitted on Set")

local status = Tab:CreateStatusBar({
	Name = "Status Sync",
	Range = {0, 250},
	Increment = 5,
	CurrentValue = 100,
	Callback = function(value)
		callbackHits.status = callbackHits.status + 1
		assertTrue(type(value) == "number", "StatusBar callback value type mismatch")
	end
})
status:Set(145)
assertEquals(status:Get(), 145, "StatusBar state mismatch")
assertTrue(callbackHits.status >= 1, "StatusBar callback should be emitted on Set")

Tab:Clear()
local remaining = Tab.GetElements and Tab:GetElements() or {}
assertEquals(#remaining, 0, "Tab:Clear should remove all elements")

print("Element sync regression: PASS")

return {
	status = "PASS",
	callbackHits = callbackHits
}
