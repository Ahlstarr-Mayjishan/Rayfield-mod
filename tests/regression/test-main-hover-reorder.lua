--[[
	Rayfield Main Hover/Reorder Regression Script

	Purpose:
	1. Sanity-check detach/dock flow used by main reorder + floating logic
	2. Verify extended drag API is available on interactive elements
	3. Provide quick manual checklist for hover/reorder behavior

	Usage:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-main-hover-reorder.lua"))()
]]

local BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local testCount = 0
local passCount = 0
local failCount = 0
local results = {}

local function test(name, fn)
	testCount = testCount + 1
	local ok, err = pcall(fn)
	if ok then
		passCount = passCount + 1
		print("✅ PASS: " .. name)
		table.insert(results, { name = name, status = "PASS" })
	else
		failCount = failCount + 1
		print("❌ FAIL: " .. name)
		print("   Error: " .. tostring(err))
		table.insert(results, { name = name, status = "FAIL", error = tostring(err) })
	end
end

local function assertTrue(condition, message)
	if not condition then
		error(message or "Assertion failed")
	end
end

local function assertNotNil(value, message)
	if value == nil then
		error(message or "Value is nil")
	end
end

local function compileChunk(source)
	if type(source) == "string" then
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
	local source = game:HttpGet(url)
	if type(source) ~= "string" or #source == 0 then
		error("Empty source: " .. tostring(url))
	end
	local fn = compileChunk(source)
	return fn()
end

print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🧪 Main Hover/Reorder Regression")
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

local Window = Rayfield:CreateWindow({
	Name = "Main Hover/Reorder Regression",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false },
	EnableTabSplit = true
})

local TabA = Window:CreateTab("Main A", 4483362458)
local TabB = Window:CreateTab("Main B", 4483362458)

local button = TabA:CreateButton({
	Name = "Detach Button",
	Callback = function() end
})

local slider = TabA:CreateSlider({
	Name = "Detach Slider",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = 50,
	Callback = function() end
})

local statusBar = TabA:CreateStatusBar({
	Name = "Detach StatusBar",
	Range = { 0, 250 },
	Increment = 5,
	CurrentValue = 100,
	Callback = function() end
})

TabB:CreateParagraph({
	Title = "Manual Check",
	Content = "Switch tabs quickly and hover elements in Main A"
})

test("Extended drag API is exposed", function()
	assertTrue(type(button.Detach) == "function", "Button.Detach missing")
	assertTrue(type(button.Dock) == "function", "Button.Dock missing")
	assertTrue(type(slider.Detach) == "function", "Slider.Detach missing")
	assertTrue(type(statusBar.Detach) == "function", "StatusBar.Detach missing")
end)

test("Detach/Dock roundtrip (single element)", function()
	local outside = Vector2.new(4096, 4096)
	local okDetach = pcall(function()
		button:Detach(outside)
	end)
	assertTrue(okDetach, "Button detach failed")
	task.wait(0.25)
	local okDock = pcall(function()
		button:Dock()
	end)
	assertTrue(okDock, "Button dock failed")
end)

test("Detach/Dock roundtrip (multi element)", function()
	local outsideA = Vector2.new(3800, 3800)
	local outsideB = Vector2.new(3900, 3900)
	assertTrue(pcall(function() slider:Detach(outsideA) end), "Slider detach failed")
	assertTrue(pcall(function() statusBar:Detach(outsideB) end), "StatusBar detach failed")
	task.wait(0.3)
	assertTrue(pcall(function() slider:Dock() end), "Slider dock failed")
	assertTrue(pcall(function() statusBar:Dock() end), "StatusBar dock failed")
end)

print("\nManual checklist (runtime):")
print("1) Switch quickly between Main A and Main B while continuously hovering Button/Slider/StatusBar.")
print("2) Hold and drag an element inside Main A, then drop inside Main A to reorder in-place.")
print("3) Hold and drag an element outside Main, then drop to detach; drag it back into Main to dock.")

print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("📊 Regression Summary")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print(string.format("Total: %d", testCount))
print(string.format("✅ Passed: %d", passCount))
print(string.format("❌ Failed: %d", failCount))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

return {
	results = results,
	passed = passCount,
	failed = failCount,
	total = testCount
}
