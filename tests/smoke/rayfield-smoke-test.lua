--[[
	Rayfield Smoke Test Script

	Purpose: Automated testing to verify basic functionality after code changes

	Usage:
		loadstring(game:HttpGet('https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/rayfield-smoke-test.lua'))()

	Or run directly in executor after loading Rayfield
]]

local testResults = {}
local testCount = 0
local passCount = 0
local failCount = 0
local BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

-- Runtime compatibility helpers for different executors
local function tryRequestApi(requestFn, url)
	if type(requestFn) ~= "function" then
		return nil
	end

	local ok, response = pcall(requestFn, {
		Url = url,
		Method = "GET"
	})
	if not ok then
		return nil
	end

	if type(response) == "table" then
		local status = response.StatusCode or response.Status
		local body = response.Body or response.body
		if (status == nil or status == 200) and type(body) == "string" and #body > 0 then
			return body
		end
	elseif type(response) == "string" and #response > 0 then
		return response
	end

	return nil
end

local function httpGet(url)
	if game and game.HttpGet then
		local ok, body = pcall(function()
			return game:HttpGet(url)
		end)
		if ok and type(body) == "string" and #body > 0 then
			return body
		end
	end

	local globalEnv = (getgenv and getgenv()) or _G
	local directHttpGet = globalEnv and (globalEnv.httpget or globalEnv.HttpGet)
	if type(directHttpGet) == "function" then
		local ok1, body1 = pcall(directHttpGet, url)
		if ok1 and type(body1) == "string" and #body1 > 0 then
			return body1
		end

		local ok2, body2 = pcall(directHttpGet, game, url)
		if ok2 and type(body2) == "string" and #body2 > 0 then
			return body2
		end
	end

	local requestCandidates = {}
	local function addRequestCandidate(candidate)
		if type(candidate) == "function" then
			table.insert(requestCandidates, candidate)
		end
	end

	addRequestCandidate(syn and syn.request)
	addRequestCandidate(fluxus and fluxus.request)
	addRequestCandidate(http and http.request)
	addRequestCandidate(http_request)
	addRequestCandidate(request)

	for _, requestFn in ipairs(requestCandidates) do
		local body = tryRequestApi(requestFn, url)
		if body then
			return body
		end
	end

	error("No compatible HTTP function found (game:HttpGet / request / http_request).")
end

local function compileChunk(source)
	if type(source) == "string" then
		-- Strip UTF-8 BOM (U+FEFF) and leading NUL bytes for strict loadstring parsers
		source = source:gsub("^\239\187\191", "")
		source = source:gsub("^\0+", "")
	end

	if type(loadstring) == "function" then
		local fn, err = loadstring(source)
		if not fn then
			error("loadstring failed: " .. tostring(err))
		end
		return fn
	end

	if type(load) == "function" then
		local fn, err = load(source)
		if not fn then
			error("load failed: " .. tostring(err))
		end
		return fn
	end

	error("No Lua compiler function available (loadstring/load).")
end

local function loadRemoteChunk(url)
	local source = httpGet(url)
	if type(source) ~= "string" or #source == 0 then
		error("Empty response while loading: " .. tostring(url))
	end

	local fn = compileChunk(source)
	return fn()
end

-- Test helper functions
local function test(name, fn)
	testCount = testCount + 1
	local success, err = pcall(fn)

	if success then
		passCount = passCount + 1
		print("✅ PASS: " .. name)
		table.insert(testResults, {name = name, status = "PASS"})
	else
		failCount = failCount + 1
		print("❌ FAIL: " .. name)
		print("   Error: " .. tostring(err))
		table.insert(testResults, {name = name, status = "FAIL", error = tostring(err)})
	end
end

local function assertEquals(actual, expected, message)
	if actual ~= expected then
		error(message or string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
	end
end

local function assertNotNil(value, message)
	if value == nil then
		error(message or "Value is nil")
	end
end

local function assertTrue(condition, message)
	if not condition then
		error(message or "Condition is false")
	end
end

-- Load Rayfield
print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🧪 Rayfield Smoke Test Suite")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

if type(_G.__RayfieldApiModuleCache) == "table" then
	table.clear(_G.__RayfieldApiModuleCache)
end
if type(_G.RayfieldCache) == "table" then
	table.clear(_G.RayfieldCache)
end
_G.Rayfield = nil
_G.RayfieldUI = nil
_G.RayfieldAllInOneLoaded = nil

local Rayfield = loadRemoteChunk(BASE_URL .. "Main%20loader/rayfield-modified.lua")
assertNotNil(Rayfield, "Failed to load Rayfield")

test("Share Code API Surface", function()
	assertTrue(type(Rayfield.ImportCode) == "function", "Rayfield:ImportCode missing")
	assertTrue(type(Rayfield.ImportSettings) == "function", "Rayfield:ImportSettings missing")
	assertTrue(type(Rayfield.ExportSettings) == "function", "Rayfield:ExportSettings missing")
	assertTrue(type(Rayfield.CopyShareCode) == "function", "Rayfield:CopyShareCode missing")
end)

test("UI Experience API Surface", function()
	assertTrue(type(Rayfield.SetUIPreset) == "function", "Rayfield:SetUIPreset missing")
	assertTrue(type(Rayfield.GetUIPreset) == "function", "Rayfield:GetUIPreset missing")
	assertTrue(type(Rayfield.SetTransitionProfile) == "function", "Rayfield:SetTransitionProfile missing")
	assertTrue(type(Rayfield.GetTransitionProfile) == "function", "Rayfield:GetTransitionProfile missing")
	assertTrue(type(Rayfield.ListControls) == "function", "Rayfield:ListControls missing")
	assertTrue(type(Rayfield.PinControl) == "function", "Rayfield:PinControl missing")
	assertTrue(type(Rayfield.UnpinControl) == "function", "Rayfield:UnpinControl missing")
	assertTrue(type(Rayfield.GetPinnedControls) == "function", "Rayfield:GetPinnedControls missing")
	assertTrue(type(Rayfield.ShowOnboarding) == "function", "Rayfield:ShowOnboarding missing")
	assertTrue(type(Rayfield.SetOnboardingSuppressed) == "function", "Rayfield:SetOnboardingSuppressed missing")
	assertTrue(type(Rayfield.IsOnboardingSuppressed) == "function", "Rayfield:IsOnboardingSuppressed missing")
	assertTrue(type(Rayfield.SetAudioFeedbackEnabled) == "function", "Rayfield:SetAudioFeedbackEnabled missing")
	assertTrue(type(Rayfield.IsAudioFeedbackEnabled) == "function", "Rayfield:IsAudioFeedbackEnabled missing")
	assertTrue(type(Rayfield.SetAudioFeedbackPack) == "function", "Rayfield:SetAudioFeedbackPack missing")
	assertTrue(type(Rayfield.GetAudioFeedbackState) == "function", "Rayfield:GetAudioFeedbackState missing")
	assertTrue(type(Rayfield.PlayUICue) == "function", "Rayfield:PlayUICue missing")
	assertTrue(type(Rayfield.SetGlassMode) == "function", "Rayfield:SetGlassMode missing")
	assertTrue(type(Rayfield.GetGlassMode) == "function", "Rayfield:GetGlassMode missing")
	assertTrue(type(Rayfield.SetGlassIntensity) == "function", "Rayfield:SetGlassIntensity missing")
	assertTrue(type(Rayfield.GetGlassIntensity) == "function", "Rayfield:GetGlassIntensity missing")
	assertTrue(type(Rayfield.GetThemeStudioState) == "function", "Rayfield:GetThemeStudioState missing")
	assertTrue(type(Rayfield.ApplyThemeStudioTheme) == "function", "Rayfield:ApplyThemeStudioTheme missing")
	assertTrue(type(Rayfield.ResetThemeStudio) == "function", "Rayfield:ResetThemeStudio missing")
	assertTrue(type(Rayfield.CreateFeatureScope) == "function", "Rayfield:CreateFeatureScope missing")
	assertTrue(type(Rayfield.TrackFeatureConnection) == "function", "Rayfield:TrackFeatureConnection missing")
	assertTrue(type(Rayfield.TrackFeatureTask) == "function", "Rayfield:TrackFeatureTask missing")
	assertTrue(type(Rayfield.TrackFeatureInstance) == "function", "Rayfield:TrackFeatureInstance missing")
	assertTrue(type(Rayfield.TrackFeatureCleanup) == "function", "Rayfield:TrackFeatureCleanup missing")
	assertTrue(type(Rayfield.CleanupFeatureScope) == "function", "Rayfield:CleanupFeatureScope missing")
	assertTrue(type(Rayfield.GetFeatureCleanupStats) == "function", "Rayfield:GetFeatureCleanupStats missing")
end)

-- Test 1: Window Creation
test("Window Creation", function()
	local Window = Rayfield:CreateWindow({
		Name = "Smoke Test Window",
		LoadingTitle = "Testing...",
		LoadingSubtitle = "Smoke Test",
		ToggleUIKeybind = "LeftControl+K>LeftShift+M",
		ConfigurationSaving = {
			Enabled = false
		},
		DisableRayfieldPrompts = true,
		DisableBuildWarnings = true
	})
	assertNotNil(Window, "Window is nil")
	assertNotNil(Window.CreateTab, "Window.CreateTab method missing")
end)

-- Test 2: Tab Creation
local testTab
test("Tab Creation", function()
	local Window = Rayfield:CreateWindow({
		Name = "Test Window",
		DisableRayfieldPrompts = true,
		DisableBuildWarnings = true,
		ConfigurationSaving = {Enabled = false}
	})
	testTab = Window:CreateTab("Test Tab", 4483362458)
	assertNotNil(testTab, "Tab is nil")
	assertNotNil(testTab.CreateButton, "Tab.CreateButton method missing")
end)

test("Element Expansion Tab API Surface", function()
	assertNotNil(testTab.CreateChart, "Tab.CreateChart missing")
	assertNotNil(testTab.CreateLogConsole, "Tab.CreateLogConsole missing")
	assertNotNil(testTab.CreateNumberStepper, "Tab.CreateNumberStepper missing")
	assertNotNil(testTab.CreateConfirmButton, "Tab.CreateConfirmButton missing")
	assertNotNil(testTab.CreateCollapsibleSection, "Tab.CreateCollapsibleSection missing")
	assertNotNil(testTab.CreateGallery, "Tab.CreateGallery missing")
	assertNotNil(testTab.CreateImage, "Tab.CreateImage missing")
end)

-- Test 2.1: Performance Profile Opt-in
test("PerformanceProfile Opt-in", function()
	local window = Rayfield:CreateWindow({
		Name = "LowSpec Profile Test",
		DisableRayfieldPrompts = true,
		DisableBuildWarnings = true,
		ConfigurationSaving = { Enabled = false },
		PerformanceProfile = {
			Enabled = true,
			Mode = "auto",
			Aggressive = true
		}
	})
	assertNotNil(window, "Window is nil with PerformanceProfile")
	assertNotNil(window.CreateTab, "Window.CreateTab missing with PerformanceProfile")

	local diagnostics = _G and _G.__RAYFIELD_LOADER_DIAGNOSTICS
	assertNotNil(diagnostics, "Loader diagnostics missing")
	assertNotNil(diagnostics.performanceProfile, "Performance profile diagnostics missing")
	assertTrue(diagnostics.performanceProfile.enabled == true, "Performance profile should be enabled in diagnostics")

	local lowSpecTab = window:CreateTab("LowSpec", 4483362458)
	local lowSpecButton = lowSpecTab:CreateButton({
		Name = "LowSpec Button",
		Callback = function() end
	})
	assertNotNil(lowSpecButton, "LowSpec button is nil")
	assertTrue(type(lowSpecButton.Detach) ~= "function", "Detach should be disabled by aggressive low-spec profile")

	-- Reset profile state for subsequent tests (detach/split behavior should return to normal)
	local resetWindow = Rayfield:CreateWindow({
		Name = "Profile Reset Window",
		DisableRayfieldPrompts = true,
		DisableBuildWarnings = true,
		ConfigurationSaving = { Enabled = false }
	})
	assertNotNil(resetWindow, "Failed to reset profile state")
end)

-- Test 3: Button Element
test("Button Element Creation", function()
	local button = testTab:CreateButton({
		Name = "Test Button",
		Callback = function()
			-- no-op for smoke test
		end
	})
	assertNotNil(button, "Button is nil")
end)

-- Test 4: Toggle Element
test("Toggle Element Creation", function()
	local toggleValue = false
	local toggle = testTab:CreateToggle({
		Name = "Test Toggle",
		CurrentValue = false,
		Callback = function(value)
			toggleValue = value
		end
	})
	assertNotNil(toggle, "Toggle is nil")
end)

test("Favorites Element API", function()
	local toggle = testTab:CreateToggle({
		Name = "Favorites Toggle",
		CurrentValue = false,
		Callback = function() end
	})
	assertNotNil(toggle, "Favorites toggle is nil")
	assertTrue(type(toggle.GetFavoriteId) == "function", "GetFavoriteId missing")
	assertTrue(type(toggle.Pin) == "function", "Pin missing")
	assertTrue(type(toggle.Unpin) == "function", "Unpin missing")
	assertTrue(type(toggle.IsPinned) == "function", "IsPinned missing")

	local pinOk = select(1, toggle:Pin())
	assertTrue(pinOk == true, "Element:Pin should return true")
	local favoriteId = toggle:GetFavoriteId()
	assertTrue(type(favoriteId) == "string" and favoriteId ~= "", "Favorite ID should be valid")
	assertTrue(toggle:IsPinned() == true, "Toggle should be pinned")

	local unpinOk = select(1, Rayfield:UnpinControl(favoriteId))
	assertTrue(unpinOk == true, "UnpinControl should return true")
	assertTrue(toggle:IsPinned() == false, "Toggle should be unpinned")
end)

-- Test 4.1: Keybind Sequence Element
test("Keybind Sequence Creation + Set", function()
	local changedKeybind = nil
	local keybind = testTab:CreateKeybind({
		Name = "Test Sequence Keybind",
		CurrentKeybind = "LeftControl+K>LeftShift+M",
		CallOnChange = true,
		Callback = function(newBinding)
			changedKeybind = newBinding
		end
	})

	assertNotNil(keybind, "Sequence keybind is nil")
	assertEquals(keybind.CurrentKeybind, "LeftControl+K>LeftShift+M", "Initial sequence keybind mismatch")

	keybind:Set("LeftControl+A>LeftShift+K")
	assertEquals(keybind.CurrentKeybind, "LeftControl+A>LeftShift+K", "Sequence keybind Set mismatch")
	assertEquals(changedKeybind, "LeftControl+A>LeftShift+K", "Sequence keybind callback mismatch")
	keybind:Destroy()
end)

-- Test 4.2: Toggle with Keybind Frame
test("Toggle Keybind Integration", function()
	local toggle = testTab:CreateToggle({
		Name = "Test Toggle Keybind",
		CurrentValue = false,
		Keybind = {
			Enabled = true,
			CurrentKeybind = "LeftControl+T"
		},
		Callback = function()
			-- no-op
		end
	})

	assertNotNil(toggle, "Toggle with keybind is nil")
	assertTrue(type(toggle.SetKeybind) == "function", "Toggle.SetKeybind missing")
	assertTrue(type(toggle.GetKeybind) == "function", "Toggle.GetKeybind missing")
	assertEquals(toggle:GetKeybind(), "LeftControl+T", "Toggle initial keybind mismatch")

	local setOk = toggle:SetKeybind("LeftControl+Y>LeftShift+H")
	assertTrue(setOk, "Toggle:SetKeybind should return true for valid sequence")
	assertEquals(toggle:GetKeybind(), "LeftControl+Y>LeftShift+H", "Toggle keybind Set mismatch")

	toggle:Set(true)
	assertTrue(toggle:Get() == true, "Toggle:Get should return true after Set(true)")
	toggle:Set(false)
	assertTrue(toggle:Get() == false, "Toggle:Get should return false after Set(false)")
	toggle:Destroy()
end)

-- Test 4.3: Toggle Wrapper Methods
test("Toggle Wrapper Methods", function()
	local a = testTab:CreateToggleBind({
		Name = "Wrapper ToggleBind",
		CurrentValue = false,
		Keybind = {
			CurrentKeybind = "LeftControl+1"
		},
		Callback = function() end
	})
	local b = testTab:CreateHotToggle({
		Name = "Wrapper HotToggle",
		CurrentValue = false,
		Keybind = {
			CurrentKeybind = "LeftControl+2"
		},
		Callback = function() end
	})

	assertNotNil(a, "CreateToggleBind failed")
	assertNotNil(b, "CreateHotToggle failed")
	assertTrue(type(a.GetKeybind) == "function", "CreateToggleBind missing keybind API")
	assertTrue(type(b.GetKeybind) == "function", "CreateHotToggle missing keybind API")
	a:Destroy()
	b:Destroy()
end)

-- Test 5: Slider Element
test("Slider Element Creation", function()
	local sliderValue = 0
	local slider = testTab:CreateSlider({
		Name = "Test Slider",
		Range = {0, 100},
		Increment = 1,
		CurrentValue = 50,
		Callback = function(value)
			sliderValue = value
		end
	})
	assertNotNil(slider, "Slider is nil")
end)

-- Test 6: TrackBar Element
test("TrackBar Element Creation + Set/Get/Destroy", function()
	local trackValue = 0
	local track = testTab:CreateTrackBar({
		Name = "Test TrackBar",
		Range = {0, 100},
		Increment = 1,
		CurrentValue = 15,
		Callback = function(value)
			trackValue = value
		end
	})

	assertNotNil(track, "TrackBar is nil")
	assertEquals(track:Get(), 15, "TrackBar initial value mismatch")
	track:Set(42)
	assertEquals(track:Get(), 42, "TrackBar Set/Get mismatch")
	assertEquals(trackValue, 42, "TrackBar callback mismatch")
	track:Destroy()
end)

-- Test 7: StatusBar Element
test("StatusBar Element Creation + Defaults + Formatter", function()
	local statusValue = 0
	local status = testTab:CreateStatusBar({
		Name = "Test StatusBar",
		Range = {0, 250},
		Increment = 5,
		CurrentValue = 100,
		TextFormatter = function(current, max, percent)
			return string.format("%d/%d (%.0f%%)", current, max, percent)
		end,
		Callback = function(value)
			statusValue = value
		end
	})

	assertNotNil(status, "StatusBar is nil")
	assertEquals(status.Draggable, false, "StatusBar default Draggable should be false")
	assertEquals(status:Get(), 100, "StatusBar initial value mismatch")
	status:Set(130)
	assertEquals(status:Get(), 130, "StatusBar Set/Get mismatch")
	assertEquals(statusValue, 130, "StatusBar callback mismatch")
	status:Destroy()
end)

-- Test 8: TrackBar Alias Methods
test("TrackBar Alias Methods", function()
	local a = testTab:CreateDragBar({
		Name = "Alias DragBar",
		Range = {0, 10},
		Increment = 1,
		CurrentValue = 2,
		Callback = function() end
	})
	local b = testTab:CreateSliderLite({
		Name = "Alias SliderLite",
		Range = {0, 10},
		Increment = 1,
		CurrentValue = 3,
		Callback = function() end
	})
	assertNotNil(a, "CreateDragBar alias failed")
	assertNotNil(b, "CreateSliderLite alias failed")
	a:Destroy()
	b:Destroy()
end)

-- Test 9: StatusBar Alias Methods
test("StatusBar Alias Methods", function()
	local a = testTab:CreateInfoBar({
		Name = "Alias InfoBar",
		Range = {0, 10},
		Increment = 1,
		CurrentValue = 4,
		Callback = function() end
	})
	local b = testTab:CreateSliderDisplay({
		Name = "Alias SliderDisplay",
		Range = {0, 10},
		Increment = 1,
		CurrentValue = 5,
		Callback = function() end
	})
	assertNotNil(a, "CreateInfoBar alias failed")
	assertNotNil(b, "CreateSliderDisplay alias failed")
	a:Destroy()
	b:Destroy()
end)

-- Test 10: Input Element
test("Input Element Creation", function()
	local input = testTab:CreateInput({
		Name = "Test Input",
		CurrentValue = "",
		PlaceholderText = "Enter text",
		RemoveTextAfterFocusLost = false,
		Callback = function(text)
			-- Input callback
		end
	})
	assertNotNil(input, "Input is nil")
end)

-- Test 11: Dropdown Element
test("Dropdown Element Creation", function()
	local dropdown = testTab:CreateDropdown({
		Name = "Test Dropdown",
		Options = {"Option 1", "Option 2", "Option 3"},
		CurrentOption = "Option 1",
		Callback = function(option)
			-- Dropdown callback
		end
	})
	assertNotNil(dropdown, "Dropdown is nil")
end)

test("Dropdown Clear Fallback (default -> selection)", function()
	local callbackSelection = nil
	local dropdown = testTab:CreateDropdown({
		Name = "Fallback Dropdown",
		Options = {"A", "B", "C"},
		CurrentOption = "A",
		DefaultSelection = "B",
		Callback = function(optionTable)
			if type(optionTable) == "table" then
				callbackSelection = optionTable[1]
			end
		end
	})

	assertNotNil(dropdown, "Fallback dropdown is nil")
	dropdown:Clear()
	assertTrue(type(dropdown.CurrentOption) == "table", "CurrentOption should stay table")
	assertEquals(dropdown.CurrentOption[1], "B", "Clear should fallback to DefaultSelection")
	assertEquals(callbackSelection, "B", "Callback should receive fallback selection")
end)

test("Dropdown Clear Fallback (none -> empty)", function()
	local callbackCount = 0
	local dropdown = testTab:CreateDropdown({
		Name = "No Fallback Dropdown",
		Options = {"A", "B", "C"},
		CurrentOption = "A",
		DefaultSelection = "B",
		ClearBehavior = "none",
		Callback = function()
			callbackCount = callbackCount + 1
		end
	})

	assertNotNil(dropdown, "No-fallback dropdown is nil")
	dropdown:Clear()
	assertTrue(type(dropdown.CurrentOption) == "table", "CurrentOption should stay table")
	assertEquals(#dropdown.CurrentOption, 0, "ClearBehavior=none should clear to empty")
	assertTrue(callbackCount > 0, "Callback should still fire on clear")
end)


-- Test 12: Label Element
test("Label Element Creation", function()
	local label = testTab:CreateLabel("Test Label")
	assertNotNil(label, "Label is nil")
end)

-- Test 13: Paragraph Element
test("Paragraph Element Creation", function()
	local paragraph = testTab:CreateParagraph({
		Title = "Test Paragraph",
		Content = "This is test content"
	})
	assertNotNil(paragraph, "Paragraph is nil")
end)

-- Test 14: Section Element
test("Section Element Creation", function()
	local section = testTab:CreateSection("Test Section")
	assertNotNil(section, "Section is nil")
end)

-- Test 15: Tab:Clear() Functionality
test("Tab Clear Functionality", function()
	local tempTab = Rayfield:CreateWindow({
		Name = "Clear Test",
		DisableRayfieldPrompts = true,
		DisableBuildWarnings = true,
		ConfigurationSaving = {Enabled = false}
	}):CreateTab("Clear Tab", 4483362458)

	tempTab:CreateButton({Name = "Button 1", Callback = function() end})
	tempTab:CreateButton({Name = "Button 2", Callback = function() end})

	if tempTab.Clear then
		tempTab:Clear()
		-- Verify elements are cleared
		local elements = tempTab.GetElements and tempTab:GetElements() or {}
		assertEquals(#elements, 0, "Tab not properly cleared")
	else
		error("Tab:Clear() method not found")
	end
end)

-- Test 16: Element Detach/Dock API
test("Element Detach/Dock API", function()
	local detachable = testTab:CreateButton({
		Name = "Detach Smoke",
		Callback = function() end
	})
	assertNotNil(detachable, "Detachable button is nil")
	assertTrue(type(detachable.Detach) == "function", "Detach method missing")
	assertTrue(type(detachable.Dock) == "function", "Dock method missing")

	local outside = Vector2.new(4096, 4096)
	local okDetach = pcall(function()
		detachable:Detach(outside)
	end)
	assertTrue(okDetach, "Detach call failed")

	task.wait(0.2)

	local okDock = pcall(function()
		detachable:Dock()
	end)
	assertTrue(okDock, "Dock call failed")
end)

-- Test 17: Rayfield:Destroy() and Reload
test("Rayfield Destroy and Reload", function()
	-- Create a temporary window
	local tempWindow = Rayfield:CreateWindow({
		Name = "Destroy Test",
		DisableRayfieldPrompts = true,
		DisableBuildWarnings = true,
		ConfigurationSaving = {Enabled = false}
	})

	-- Destroy Rayfield
	if Rayfield.Destroy then
		Rayfield:Destroy()
		task.wait(0.5)

		-- Reload Rayfield
		Rayfield = loadRemoteChunk(BASE_URL .. "Main%20loader/rayfield-modified.lua")
		assertNotNil(Rayfield, "Failed to reload Rayfield after destroy")
	else
		error("Rayfield:Destroy() method not found")
	end
end)

-- Print Summary
print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("📊 Test Summary")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print(string.format("Total Tests: %d", testCount))
print(string.format("✅ Passed: %d", passCount))
print(string.format("❌ Failed: %d", failCount))
print(string.format("Success Rate: %.1f%%", (passCount / testCount) * 100))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

if failCount > 0 then
	print("⚠️  Some tests failed. Review the errors above.")
else
	print("🎉 All tests passed! Rayfield is working correctly.")
end

return {
	results = testResults,
	passed = passCount,
	failed = failCount,
	total = testCount
}
