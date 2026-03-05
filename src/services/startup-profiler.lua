-- Rayfield Startup Profiler
-- Lightweight timing utility for measuring startup phase durations.
-- All output goes through warn() so it appears in the Roblox Output console.

local StartupProfiler = {}
StartupProfiler.__index = StartupProfiler

function StartupProfiler.new(options)
	options = type(options) == "table" and options or {}
	local self = setmetatable({}, StartupProfiler)
	self._marks = {}
	self._order = {}
	self._origin = os.clock()
	self._enabled = options.enabled ~= false
	self._prefix = type(options.prefix) == "string" and options.prefix or "[Rayfield-Profiler]"
	self._warnFn = type(options.warn) == "function" and options.warn or warn
	return self
end

function StartupProfiler:mark(name)
	if not self._enabled then
		return
	end
	local now = os.clock()
	self._marks[name] = now
	table.insert(self._order, { name = name, at = now })
end

function StartupProfiler:elapsed(startName, endName)
	local startMark = self._marks[startName]
	local endMark = self._marks[endName]
	if not startMark or not endMark then
		return nil
	end
	return endMark - startMark
end

function StartupProfiler:totalElapsed()
	return os.clock() - self._origin
end

function StartupProfiler:getReport()
	local report = {}
	for i, entry in ipairs(self._order) do
		local delta = entry.at - self._origin
		report[i] = {
			name = entry.name,
			absoluteMs = math.floor(delta * 1000 + 0.5),
			timestamp = entry.at
		}
	end

	-- Compute phase durations between consecutive marks
	for i = 2, #report do
		report[i].deltaMs = report[i].absoluteMs - report[i - 1].absoluteMs
	end

	report.totalMs = math.floor(self:totalElapsed() * 1000 + 0.5)
	return report
end

function StartupProfiler:report()
	if not self._enabled then
		return
	end

	local warnFn = self._warnFn
	local prefix = self._prefix
	local totalMs = math.floor(self:totalElapsed() * 1000 + 0.5)

	warnFn(prefix .. " ===== Startup Timing Report =====")

	local prev = self._origin
	for _, entry in ipairs(self._order) do
		local delta = entry.at - prev
		local deltaMs = math.floor(delta * 1000 + 0.5)
		local absoluteMs = math.floor((entry.at - self._origin) * 1000 + 0.5)
		warnFn(string.format(
			"%s  +%4dms  @%5dms  %s",
			prefix, deltaMs, absoluteMs, entry.name
		))
		prev = entry.at
	end

	warnFn(prefix .. " Total: " .. tostring(totalMs) .. "ms")
	warnFn(prefix .. " ===== End Report =====")
end

return StartupProfiler
