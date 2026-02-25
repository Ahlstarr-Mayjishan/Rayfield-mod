--[[
	Rayfield Keybind Sequence Regression Test

	Purpose:
	- Validate canonical parse/normalize/format behavior
	- Validate dynamic sequence matcher flow (max steps + timeout)

	Usage:
		loadstring(game:HttpGet('https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-keybind-sequence.lua'))()
]]

local BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local results = {}
local testCount = 0
local passCount = 0
local failCount = 0

local function test(name, fn)
	testCount = testCount + 1
	local ok, err = pcall(fn)
	if ok then
		passCount = passCount + 1
		print("[PASS] " .. name)
		table.insert(results, {name = name, status = "PASS"})
	else
		failCount = failCount + 1
		print("[FAIL] " .. name)
		print("   Error: " .. tostring(err))
		table.insert(results, {name = name, status = "FAIL", error = tostring(err)})
	end
end

local function assertTrue(condition, message)
	if not condition then
		error(message or "Condition is false")
	end
end

local function assertEquals(actual, expected, message)
	if actual ~= expected then
		error(message or string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
	end
end

local function compileChunk(source)
	local loadFn = loadstring or load
	if type(loadFn) ~= "function" then
		error("No compiler found (loadstring/load)")
	end
	if type(source) == "string" then
		source = source:gsub("^\239\187\191", "")
		source = source:gsub("^\0+", "")
	end
	local fn, err = loadFn(source)
	if not fn then
		error("compile failed: " .. tostring(err))
	end
	return fn
end

local function loadRemoteChunk(url)
	local source = game:HttpGet(url)
	assertTrue(type(source) == "string" and #source > 0, "Empty source: " .. tostring(url))
	local fn = compileChunk(source)
	return fn()
end

local Sequence = loadRemoteChunk(BASE_URL .. "src/services/keybind-sequence.lua")
assertTrue(type(Sequence) == "table", "keybind-sequence module did not return a table")

print("\n--------------------------------")
print("Keybind Sequence Regression")
print("--------------------------------\n")

test("Parse canonical single key", function()
	local canonical, steps, err = Sequence.parseCanonical("Q")
	assertTrue(canonical ~= nil, "parseCanonical failed: " .. tostring(err))
	assertEquals(canonical, "Q")
	assertEquals(#steps, 1)
	assertEquals(steps[1].primary, "Q")
end)

test("Parse canonical multi-step", function()
	local canonical, steps, err = Sequence.parseCanonical("LeftControl+A>LeftShift+K")
	assertTrue(canonical ~= nil, "parseCanonical failed: " .. tostring(err))
	assertEquals(canonical, "LeftControl+A>LeftShift+K")
	assertEquals(#steps, 2)
	assertEquals(steps[1].primary, "A")
	assertEquals(steps[2].primary, "K")
end)

test("Reject invalid step without primary", function()
	local canonical, _, err = Sequence.parseCanonical("LeftControl+LeftShift")
	assertTrue(canonical == nil, "Expected parse to fail")
	assertTrue(type(err) == "string" and string.find(err, "missing_primary") ~= nil, "Unexpected error: " .. tostring(err))
end)

test("Display formatter default", function()
	local display = Sequence.formatDisplay("LeftControl+A>LeftShift+K")
	assertEquals(display, "Ctrl + A > Shift + K")
end)

test("Display formatter custom", function()
	local display = Sequence.formatDisplay("LeftControl+A>LeftShift+K", function(canonical)
		return "BIND:" .. canonical
	end)
	assertEquals(display, "BIND:LeftControl+A>LeftShift+K")
end)

test("Matcher success for two-step sequence", function()
	local matcher = Sequence.newMatcher({maxSteps = 4, stepTimeoutMs = 800})
	matcher:setBinding("LeftControl+A>LeftShift+K")

	local inputA = {UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.A}
	local inputK = {UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K}

	local stateA = {
		IsKeyDown = function(_, keyCode)
			return keyCode == Enum.KeyCode.LeftControl
		end
	}
	local stateK = {
		IsKeyDown = function(_, keyCode)
			return keyCode == Enum.KeyCode.LeftShift
		end
	}

	local hitFirst = matcher:consume(inputA, nil, stateA, false)
	assertEquals(hitFirst, false, "First step should not finalize sequence")
	local hitFinal = matcher:consume(inputK, nil, stateK, false)
	assertEquals(hitFinal, true, "Second step should finalize sequence")
end)

test("Matcher timeout resets sequence", function()
	local matcher = Sequence.newMatcher({maxSteps = 4, stepTimeoutMs = 800})
	matcher:setBinding("LeftControl+A>LeftShift+K")

	local inputA = {UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.A}
	local inputK = {UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K}

	local stateA = {
		IsKeyDown = function(_, keyCode)
			return keyCode == Enum.KeyCode.LeftControl
		end
	}
	local stateK = {
		IsKeyDown = function(_, keyCode)
			return keyCode == Enum.KeyCode.LeftShift
		end
	}

	local step1 = matcher:consume(inputA, nil, stateA, false)
	assertEquals(step1, false)
	task.wait(0.9)
	local step2 = matcher:consume(inputK, nil, stateK, false)
	assertEquals(step2, false, "Timed-out sequence should not complete")
end)

test("parseUserInput custom parser", function()
	local canonical = Sequence.parseUserInput("ctrl+a then shift+k", function(text)
		if text == "ctrl+a then shift+k" then
			return "LeftControl+A>LeftShift+K"
		end
		return nil, "unsupported"
	end)
	assertEquals(canonical, "LeftControl+A>LeftShift+K")
end)

print("\n--------------------------------")
print("Test Summary")
print("--------------------------------")
print(string.format("Total Tests: %d", testCount))
print(string.format("Passed: %d", passCount))
print(string.format("Failed: %d", failCount))
print(string.format("Success Rate: %.1f%%", (passCount / testCount) * 100))
print("--------------------------------\n")

return {
	results = results,
	total = testCount,
	passed = passCount,
	failed = failCount
}
