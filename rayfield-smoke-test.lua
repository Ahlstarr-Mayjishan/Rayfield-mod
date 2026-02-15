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

-- Load Rayfield
print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🧪 Rayfield Smoke Test Suite")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

local Rayfield = loadstring(game:HttpGet(BASE_URL .. "Main%20loader/rayfield-modified.lua"))()
assertNotNil(Rayfield, "Failed to load Rayfield")

-- Test 1: Window Creation
test("Window Creation", function()
	local Window = Rayfield:CreateWindow({
		Name = "Smoke Test Window",
		LoadingTitle = "Testing...",
		LoadingSubtitle = "Smoke Test",
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

-- Test 6: Input Element
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

-- Test 7: Dropdown Element
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


-- Test 8: Label Element
test("Label Element Creation", function()
	local label = testTab:CreateLabel("Test Label")
	assertNotNil(label, "Label is nil")
end)

-- Test 9: Paragraph Element
test("Paragraph Element Creation", function()
	local paragraph = testTab:CreateParagraph({
		Title = "Test Paragraph",
		Content = "This is test content"
	})
	assertNotNil(paragraph, "Paragraph is nil")
end)

-- Test 10: Section Element
test("Section Element Creation", function()
	local section = testTab:CreateSection("Test Section")
	assertNotNil(section, "Section is nil")
end)

-- Test 11: Tab:Clear() Functionality
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
		local elements = tempTab:GetElements and tempTab:GetElements() or {}
		assertEquals(#elements, 0, "Tab not properly cleared")
	else
		error("Tab:Clear() method not found")
	end
end)

-- Test 12: Rayfield:Destroy() and Reload
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
		Rayfield = loadstring(game:HttpGet(BASE_URL .. "Main%20loader/rayfield-modified.lua"))()
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
