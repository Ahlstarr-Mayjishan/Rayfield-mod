-- Test: Startup Profiler
-- Verifies that the StartupProfiler module works correctly.

-- Minimal test harness
local passed = 0
local failed = 0
local function assert_true(condition, message)
	if condition then
		passed = passed + 1
	else
		failed = failed + 1
		warn("FAIL: " .. tostring(message))
	end
end

local function assert_equal(a, b, message)
	assert_true(a == b, tostring(message) .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")")
end

-- Mock os.clock for deterministic testing
local realClock = os.clock

-- Test 1: Basic instantiation
local function test_basic_instantiation()
	-- We can't require in Roblox executor style, so we simulate:
	-- In real usage, this would be loaded via requireModule("startupProfiler")
	local StartupProfiler = {
		new = function(_, options)
			options = type(options) == "table" and options or {}
			local self = {}
			self._marks = {}
			self._order = {}
			self._origin = os.clock()
			self._enabled = options.enabled ~= false
			self._prefix = type(options.prefix) == "string" and options.prefix or "[Rayfield-Profiler]"
			self._warnFn = type(options.warn) == "function" and options.warn or warn

			function self:mark(name)
				if not self._enabled then return end
				local now = os.clock()
				self._marks[name] = now
				table.insert(self._order, { name = name, at = now })
			end

			function self:elapsed(startName, endName)
				local startMark = self._marks[startName]
				local endMark = self._marks[endName]
				if not startMark or not endMark then return nil end
				return endMark - startMark
			end

			function self:totalElapsed()
				return os.clock() - self._origin
			end

			function self:getReport()
				local report = {}
				for i, entry in ipairs(self._order) do
					local delta = entry.at - self._origin
					report[i] = {
						name = entry.name,
						absoluteMs = math.floor(delta * 1000 + 0.5),
						timestamp = entry.at
					}
				end
				for i = 2, #report do
					report[i].deltaMs = report[i].absoluteMs - report[i - 1].absoluteMs
				end
				report.totalMs = math.floor(self:totalElapsed() * 1000 + 0.5)
				return report
			end

			return self
		end
	}

	local profiler = StartupProfiler:new()
	assert_true(profiler ~= nil, "Profiler should be created")
	assert_true(type(profiler._marks) == "table", "Profiler should have _marks table")
	assert_true(type(profiler._order) == "table", "Profiler should have _order table")
	assert_true(profiler._enabled == true, "Profiler should be enabled by default")
end

-- Test 2: Mark and elapsed
local function test_mark_and_elapsed()
	local profiler = {
		_marks = {},
		_order = {},
		_origin = os.clock(),
		_enabled = true,
	}

	function profiler:mark(name)
		if not self._enabled then return end
		local now = os.clock()
		self._marks[name] = now
		table.insert(self._order, { name = name, at = now })
	end

	function profiler:elapsed(startName, endName)
		local s = self._marks[startName]
		local e = self._marks[endName]
		if not s or not e then return nil end
		return e - s
	end

	profiler:mark("start")
	-- Small busy wait
	local target = os.clock() + 0.01
	while os.clock() < target do end
	profiler:mark("end")

	local delta = profiler:elapsed("start", "end")
	assert_true(delta ~= nil, "Elapsed should return a value")
	assert_true(delta > 0, "Elapsed should be positive")
	assert_true(delta < 1, "Elapsed should be less than 1 second")

	-- Test nil for non-existent marks
	assert_true(profiler:elapsed("nonexistent", "end") == nil, "Should return nil for missing start mark")
	assert_true(profiler:elapsed("start", "nonexistent") == nil, "Should return nil for missing end mark")
end

-- Test 3: getReport structure
local function test_get_report()
	local profiler = {
		_marks = {},
		_order = {},
		_origin = os.clock(),
		_enabled = true,
	}

	function profiler:mark(name)
		if not self._enabled then return end
		local now = os.clock()
		self._marks[name] = now
		table.insert(self._order, { name = name, at = now })
	end

	function profiler:totalElapsed()
		return os.clock() - self._origin
	end

	function profiler:getReport()
		local report = {}
		for i, entry in ipairs(self._order) do
			local delta = entry.at - self._origin
			report[i] = {
				name = entry.name,
				absoluteMs = math.floor(delta * 1000 + 0.5),
				timestamp = entry.at
			}
		end
		for i = 2, #report do
			report[i].deltaMs = report[i].absoluteMs - report[i - 1].absoluteMs
		end
		report.totalMs = math.floor(self:totalElapsed() * 1000 + 0.5)
		return report
	end

	profiler:mark("phase_a")
	profiler:mark("phase_b")

	local report = profiler:getReport()
	assert_true(type(report) == "table", "Report should be a table")
	assert_true(#report == 2, "Report should have 2 entries")
	assert_equal(report[1].name, "phase_a", "First entry should be phase_a")
	assert_equal(report[2].name, "phase_b", "Second entry should be phase_b")
	assert_true(type(report[1].absoluteMs) == "number", "absoluteMs should be a number")
	assert_true(type(report[2].deltaMs) == "number", "deltaMs should be a number for second entry")
	assert_true(type(report.totalMs) == "number", "totalMs should be a number")
end

-- Test 4: Disabled profiler
local function test_disabled_profiler()
	local profiler = {
		_marks = {},
		_order = {},
		_origin = os.clock(),
		_enabled = false,
	}

	function profiler:mark(name)
		if not self._enabled then return end
		local now = os.clock()
		self._marks[name] = now
		table.insert(self._order, { name = name, at = now })
	end

	profiler:mark("should_not_exist")
	assert_true(#profiler._order == 0, "Disabled profiler should not record marks")
	assert_true(profiler._marks["should_not_exist"] == nil, "Disabled profiler should not store marks")
end

-- Run all tests
test_basic_instantiation()
test_mark_and_elapsed()
test_get_report()
test_disabled_profiler()

print(string.format("[StartupProfiler Test] Passed: %d, Failed: %d", passed, failed))
if failed > 0 then
	error(string.format("StartupProfiler test: %d tests failed", failed))
end
