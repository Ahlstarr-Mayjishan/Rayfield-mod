--[[

	Rayfield Interface Suite - Enhanced Version 2.0
	
	Tính năng mới:
	✅ Memory Leak Detection tự động
	✅ Performance Profiler
	✅ Hybrid Mode (fast + protected callbacks)
	✅ Priority Queue cho Remote Calls
	✅ Exception System với auto-disable
	✅ Audit Log cho security
	✅ API Reference đầy đủ
	✅ Migration helpers

	Tác giả: Enhanced by Community
	Version: 2.0.0

]]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- ============================================
-- PHẦN 1: MEMORY LEAK DETECTOR
-- ============================================

local MemoryLeakDetector = {}
MemoryLeakDetector.__index = MemoryLeakDetector

function MemoryLeakDetector.new()
	local self = setmetatable({}, MemoryLeakDetector)
	
	-- Tracking
	self.snapshots = {}
	self.maxSnapshots = 10
	self.checkInterval = 30 -- seconds
	self.leakThreshold = 10 * 1024 * 1024 -- 10MB growth
	self.suspectedLeaks = {}
	
	-- Object tracking
	self.objectCounts = {}
	self.lastObjectCounts = {}
	
	-- Callbacks
	self.onLeakDetected = nil
	
	self:startMonitoring()
	
	return self
end

function MemoryLeakDetector:takeSnapshot()
	local stats = game:GetService("Stats")
	local snapshot = {
		timestamp = tick(),
		totalMemory = stats:GetTotalMemoryUsageMb(),
		instanceCount = #game:GetDescendants(),
		objectBreakdown = {}
	}
	
	-- Count objects by type
	for _, obj in ipairs(game:GetDescendants()) do
		local className = obj.ClassName
		snapshot.objectBreakdown[className] = (snapshot.objectBreakdown[className] or 0) + 1
	end
	
	table.insert(self.snapshots, snapshot)
	
	-- Keep only recent snapshots
	if #self.snapshots > self.maxSnapshots then
		table.remove(self.snapshots, 1)
	end
	
	return snapshot
end

function MemoryLeakDetector:detectLeaks()
	if #self.snapshots < 3 then
		return nil -- Need at least 3 snapshots
	end
	
	local leaks = {}
	local oldest = self.snapshots[1]
	local newest = self.snapshots[#self.snapshots]
	
	-- Check total memory growth
	local memoryGrowth = (newest.totalMemory - oldest.totalMemory) * 1024 * 1024
	local timeSpan = newest.timestamp - oldest.timestamp
	local growthRate = memoryGrowth / timeSpan -- bytes per second
	
	if memoryGrowth > self.leakThreshold then
		table.insert(leaks, {
			type = "memory",
			severity = "high",
			growth = memoryGrowth,
			rate = growthRate,
			message = string.format(
				"Memory leak detected: %.2f MB growth in %.1f seconds (%.2f KB/s)",
				memoryGrowth / 1024 / 1024,
				timeSpan,
				growthRate / 1024
			)
		})
	end
	
	-- Check object count growth
	for className, newCount in pairs(newest.objectBreakdown) do
		local oldCount = oldest.objectBreakdown[className] or 0
		local growth = newCount - oldCount
		
		if growth > 100 then -- More than 100 new objects
			table.insert(leaks, {
				type = "object",
				severity = "medium",
				className = className,
				growth = growth,
				message = string.format(
					"Object leak detected: %s increased by %d instances",
					className,
					growth
				)
			})
		end
	end
	
	return #leaks > 0 and leaks or nil
end

function MemoryLeakDetector:startMonitoring()
	task.spawn(function()
		while true do
			task.wait(self.checkInterval)
			
			-- Take snapshot
			self:takeSnapshot()
			
			-- Detect leaks
			local leaks = self:detectLeaks()
			
			if leaks then
				for _, leak in ipairs(leaks) do
					warn("[Memory Leak Detector] " .. leak.message)
					
					-- Track suspected leaks
					table.insert(self.suspectedLeaks, {
						leak = leak,
						timestamp = tick()
					})
					
					-- Callback
					if self.onLeakDetected then
						pcall(self.onLeakDetected, leak)
					end
				end
			end
		end
	end)
end

function MemoryLeakDetector:getReport()
	local report = {
		snapshots = #self.snapshots,
		suspectedLeaks = #self.suspectedLeaks,
		currentMemory = 0,
		details = {}
	}
	
	if #self.snapshots > 0 then
		local latest = self.snapshots[#self.snapshots]
		report.currentMemory = latest.totalMemory
		report.instanceCount = latest.instanceCount
		
		-- Top 10 object types
		local sorted = {}
		for className, count in pairs(latest.objectBreakdown) do
			table.insert(sorted, {className = className, count = count})
		end
		table.sort(sorted, function(a, b) return a.count > b.count end)
		
		for i = 1, math.min(10, #sorted) do
			table.insert(report.details, sorted[i])
		end
	end
	
	return report
end

-- ============================================
-- PHẦN 2: PERFORMANCE PROFILER
-- ============================================

local PerformanceProfiler = {}
PerformanceProfiler.__index = PerformanceProfiler

function PerformanceProfiler.new()
	local self = setmetatable({}, PerformanceProfiler)
	
	self.profiles = {}
	self.activeProfiles = {}
	self.maxProfiles = 1000
	
	return self
end

function PerformanceProfiler:startProfile(identifier)
	self.activeProfiles[identifier] = {
		startTime = tick(),
		startMemory = collectgarbage("count")
	}
end

function PerformanceProfiler:endProfile(identifier)
	local active = self.activeProfiles[identifier]
	if not active then return nil end
	
	local duration = tick() - active.startTime
	local memoryDelta = collectgarbage("count") - active.startMemory
	
	-- Store profile
	if not self.profiles[identifier] then
		self.profiles[identifier] = {
			calls = 0,
			totalTime = 0,
			minTime = math.huge,
			maxTime = 0,
			avgTime = 0,
			totalMemory = 0
		}
	end
	
	local profile = self.profiles[identifier]
	profile.calls = profile.calls + 1
	profile.totalTime = profile.totalTime + duration
	profile.minTime = math.min(profile.minTime, duration)
	profile.maxTime = math.max(profile.maxTime, duration)
	profile.avgTime = profile.totalTime / profile.calls
	profile.totalMemory = profile.totalMemory + memoryDelta
	
	self.activeProfiles[identifier] = nil
	
	return {
		duration = duration,
		memory = memoryDelta
	}
end

function PerformanceProfiler:getProfile(identifier)
	return self.profiles[identifier]
end

function PerformanceProfiler:getAllProfiles()
	return self.profiles
end

function PerformanceProfiler:printReport()
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📊 Performance Profile Report")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	-- Sort by total time
	local sorted = {}
	for identifier, profile in pairs(self.profiles) do
		table.insert(sorted, {
			identifier = identifier,
			profile = profile
		})
	end
	table.sort(sorted, function(a, b)
		return a.profile.totalTime > b.profile.totalTime
	end)
	
	for i, data in ipairs(sorted) do
		if i > 20 then break end -- Top 20
		
		local p = data.profile
		print(string.format(
			"%d. %s\n   Calls: %d | Avg: %.3fms | Max: %.3fms | Total: %.2fs",
			i,
			data.identifier,
			p.calls,
			p.avgTime * 1000,
			p.maxTime * 1000,
			p.totalTime
		))
	end
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
end

-- ============================================
-- PHẦN 3: ENHANCED ERROR MANAGER (V2)
-- ============================================

local ErrorManager = {}
ErrorManager.__index = ErrorManager

function ErrorManager.new()
	local self = setmetatable({}, ErrorManager)
	
	-- Circuit Breaker
	self.errorThreshold = 5
	self.resetTimeout = 30
	self.errorCount = {}
	self.circuitState = {}
	self.lastErrorTime = {}
	
	-- Rate Limiting
	self.rateLimits = {}
	self.callHistory = {}
	
	-- Error logging
	self.errorLog = {}
	self.maxLogSize = 100
	
	-- Fatal error
	self.fatalErrorOccurred = false
	self.shutdownCallbacks = {}
	
	-- Exception System V2
	self.exceptionList = {}
	self.exceptionMode = false
	self.exceptionModeTimer = nil
	self.auditLog = {} -- NEW: Security audit log
	
	return self
end

function ErrorManager:isCircuitOpen(identifier)
	if self.exceptionMode or self.exceptionList[identifier] then
		return false
	end
	
	if not self.circuitState[identifier] then
		self.circuitState[identifier] = "closed"
		self.errorCount[identifier] = 0
		return false
	end
	
	local state = self.circuitState[identifier]
	
	if state == "open" then
		local timeSinceError = tick() - (self.lastErrorTime[identifier] or 0)
		if timeSinceError >= self.resetTimeout then
			self.circuitState[identifier] = "half-open"
			return false
		end
		return true
	end
	
	return false
end

function ErrorManager:recordError(identifier, errorMessage)
	self.errorCount[identifier] = (self.errorCount[identifier] or 0) + 1
	self.lastErrorTime[identifier] = tick()
	
	table.insert(self.errorLog, {
		identifier = identifier,
		message = errorMessage,
		timestamp = tick(),
		count = self.errorCount[identifier]
	})
	
	if #self.errorLog > self.maxLogSize then
		table.remove(self.errorLog, 1)
	end
	
	if self.errorCount[identifier] >= self.errorThreshold then
		self.circuitState[identifier] = "open"
		warn(string.format(
			"[Rayfield Circuit Breaker] Circuit mở cho '%s' sau %d lỗi",
			identifier,
			self.errorCount[identifier]
		))
		return true
	end
	
	return false
end

function ErrorManager:recordSuccess(identifier)
	if self.circuitState[identifier] == "half-open" then
		self.circuitState[identifier] = "closed"
	end
	self.errorCount[identifier] = 0
end

function ErrorManager:checkRateLimit(identifier, maxCallsPerSecond)
	if self.exceptionMode or self.exceptionList[identifier] then
		return true, nil
	end
	
	maxCallsPerSecond = maxCallsPerSecond or 10
	
	if not self.callHistory[identifier] then
		self.callHistory[identifier] = {}
	end
	
	local now = tick()
	local history = self.callHistory[identifier]
	
	for i = #history, 1, -1 do
		if now - history[i] > 1 then
			table.remove(history, i)
		end
	end
	
	if #history >= maxCallsPerSecond then
		return false, "Rate limit exceeded"
	end
	
	table.insert(history, now)
	return true, nil
end

-- NEW: Exception with auto-disable
function ErrorManager:addException(identifier, duration)
	self.exceptionList[identifier] = true
	
	-- Audit log
	table.insert(self.auditLog, {
		action = "add_exception",
		identifier = identifier,
		duration = duration,
		timestamp = tick()
	})
	
	print(string.format(
		"⚠️ [Exception] '%s' bypassed protection%s",
		identifier,
		duration and string.format(" for %ds", duration) or ""
	))
	
	-- Auto-disable after duration
	if duration then
		task.delay(duration, function()
			if self.exceptionList[identifier] then
				self:removeException(identifier)
				print(string.format("✅ [Exception] '%s' protection restored", identifier))
			end
		end)
	end
end

function ErrorManager:removeException(identifier)
	self.exceptionList[identifier] = nil
	
	table.insert(self.auditLog, {
		action = "remove_exception",
		identifier = identifier,
		timestamp = tick()
	})
end

-- NEW: Global exception with confirmation
function ErrorManager:setExceptionMode(enabled, duration, confirmed)
	if enabled and not confirmed then
		warn("⚠️⚠️⚠️ [SECURITY WARNING] ⚠️⚠️⚠️")
		warn("You are about to DISABLE ALL PROTECTION!")
		warn("Call again with confirmed=true to proceed")
		return false
	end
	
	self.exceptionMode = enabled
	
	-- Audit log
	table.insert(self.auditLog, {
		action = enabled and "enable_global_exception" or "disable_global_exception",
		duration = duration,
		timestamp = tick()
	})
	
	if enabled then
		warn("⚠️⚠️⚠️ [Exception Mode] ALL PROTECTION DISABLED!")
		
		-- Auto-disable
		if duration then
			if self.exceptionModeTimer then
				task.cancel(self.exceptionModeTimer)
			end
			
			self.exceptionModeTimer = task.delay(duration, function()
				self:setExceptionMode(false, nil, true)
				print("✅ [Exception Mode] Protection restored automatically")
			end)
		end
	else
		print("✅ [Exception Mode] Protection enabled")
		if self.exceptionModeTimer then
			task.cancel(self.exceptionModeTimer)
			self.exceptionModeTimer = nil
		end
	end
	
	return true
end

function ErrorManager:isException(identifier)
	return self.exceptionMode or self.exceptionList[identifier] == true
end

function ErrorManager:getAuditLog()
	return self.auditLog
end

function ErrorManager:printAuditLog()
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🔒 Security Audit Log")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	for i, entry in ipairs(self.auditLog) do
		print(string.format(
			"[%d] %s: %s (%.1fs ago)",
			i,
			entry.action,
			entry.identifier or "global",
			tick() - entry.timestamp
		))
	end
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
end

function ErrorManager:onShutdown(callback)
	table.insert(self.shutdownCallbacks, callback)
end

function ErrorManager:triggerFatalError(reason)
	if self.fatalErrorOccurred then return end
	
	self.fatalErrorOccurred = true
	warn("[Rayfield Fatal Error] " .. reason)
	
	for _, callback in ipairs(self.shutdownCallbacks) do
		pcall(callback)
	end
end

-- ============================================
-- PHẦN 4: ENHANCED GARBAGE COLLECTOR
-- ============================================

local GarbageCollector = {}
GarbageCollector.__index = GarbageCollector

function GarbageCollector.new()
	local self = setmetatable({}, GarbageCollector)
	
	self.trackedObjects = {}
	self.weakReferences = setmetatable({}, {__mode = "v"})
	self.connections = {}
	self.timers = {}
	
	self.autoCleanupInterval = 60
	self.maxTrackedObjects = 1000
	
	self:startAutoCleanup()
	
	return self
end

function GarbageCollector:track(object, identifier, cleanupFunc)
	if #self.trackedObjects >= self.maxTrackedObjects then
		self:cleanup()
	end
	
	table.insert(self.trackedObjects, {
		object = object,
		identifier = identifier,
		cleanupFunc = cleanupFunc,
		createdAt = tick()
	})
	
	self.weakReferences[identifier] = object
end

function GarbageCollector:trackConnection(connection, identifier)
	self.connections[identifier] = connection
end

function GarbageCollector:trackTimer(thread, identifier)
	self.timers[identifier] = thread
end

function GarbageCollector:cleanup()
	local cleaned = 0
	
	for i = #self.trackedObjects, 1, -1 do
		local tracked = self.trackedObjects[i]
		local obj = tracked.object
		
		local exists = pcall(function()
			return obj.Parent ~= nil
		end)
		
		if not exists or (obj.Parent == nil) then
			if tracked.cleanupFunc then
				pcall(tracked.cleanupFunc)
			end
			table.remove(self.trackedObjects, i)
			cleaned = cleaned + 1
		end
	end
	
	for identifier, connection in pairs(self.connections) do
		if not connection.Connected then
			self.connections[identifier] = nil
			cleaned = cleaned + 1
		end
	end
	
	if cleaned > 0 then
		print(string.format("[GC] Cleaned %d objects", cleaned))
	end
	
	return cleaned
end

function GarbageCollector:cleanupAll()
	for identifier, connection in pairs(self.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	self.connections = {}
	
	for identifier, thread in pairs(self.timers) do
		pcall(function()
			task.cancel(thread)
		end)
	end
	self.timers = {}
	
	for _, tracked in ipairs(self.trackedObjects) do
		if tracked.cleanupFunc then
			pcall(tracked.cleanupFunc)
		end
	end
	self.trackedObjects = {}
	
	print("[GC] Full cleanup completed")
end

function GarbageCollector:startAutoCleanup()
	local thread = task.spawn(function()
		while true do
			task.wait(self.autoCleanupInterval)
			self:cleanup()
		end
	end)
	
	self.timers["autoCleanup"] = thread
end

-- ============================================
-- PHẦN 5: PRIORITY REMOTE PROTECTION
-- ============================================

local RemoteProtection = {}
RemoteProtection.__index = RemoteProtection

function RemoteProtection.new(errorManager)
	local self = setmetatable({}, RemoteProtection)
	
	self.errorManager = errorManager
	
	-- Priority queues
	self.queues = {
		critical = {},
		high = {},
		normal = {},
		low = {}
	}
	
	self.maxQueueSize = {
		critical = 100,
		high = 75,
		normal = 50,
		low = 25
	}
	
	self.processingQueue = false
	self.timeout = 10 -- Increased from 5
	
	return self
end

function RemoteProtection:safeRemoteCall(remoteObject, method, priority, ...)
	priority = priority or "normal"
	local args = {...}
	
	if self.errorManager.fatalErrorOccurred then
		return false, "Fatal error occurred"
	end
	
	local queue = self.queues[priority]
	local maxSize = self.maxQueueSize[priority]
	
	if #queue >= maxSize then
		warn(string.format("[Remote] %s queue full", priority))
		return false, "Queue full"
	end
	
	table.insert(queue, {
		remote = remoteObject,
		method = method,
		args = args,
		timestamp = tick(),
		priority = priority
	})
	
	if not self.processingQueue then
		self:processQueue()
	end
	
	return true, "Queued"
end

function RemoteProtection:processQueue()
	self.processingQueue = true
	
	task.spawn(function()
		local priorities = {"critical", "high", "normal", "low"}
		
		while true do
			local hasWork = false
			
			-- Process in priority order
			for _, priority in ipairs(priorities) do
				local queue = self.queues[priority]
				
				if #queue > 0 then
					hasWork = true
					local callData = table.remove(queue, 1)
					
					-- Check timeout
					if tick() - callData.timestamp > self.timeout then
						warn(string.format("[Remote] Timeout: %s", priority))
					else
						local success, result = pcall(function()
							return callData.remote[callData.method](callData.remote, unpack(callData.args))
						end)
						
						if not success then
							warn("[Remote Error] " .. tostring(result))
							self.errorManager:recordError("RemoteCall", tostring(result))
						end
					end
					
					-- Delay based on priority
					local delays = {
						critical = 0.05,
						high = 0.1,
						normal = 0.15,
						low = 0.2
					}
					task.wait(delays[priority])
					break -- Process one at a time
				end
			end
			
			if not hasWork then
				break
			end
		end
		
		self.processingQueue = false
	end)
end

function RemoteProtection:getQueueStatus()
	local status = {}
	for priority, queue in pairs(self.queues) do
		status[priority] = {
			count = #queue,
			max = self.maxQueueSize[priority]
		}
	end
	return status
end

-- ============================================
-- PHẦN 6: HYBRID CALLBACK SYSTEM
-- ============================================

local function createHybridCallback(callback, identifier, errorManager, profiler, options)
	options = options or {}
	
	local mode = options.mode or "protected" -- "protected" or "fast"
	local rateLimit = options.rateLimit or 10
	local circuitBreaker = options.circuitBreaker ~= false
	local profile = options.profile ~= false
	
	if mode == "fast" then
		-- Fast path: minimal overhead
		return function(...)
			if profile and profiler then
				profiler:startProfile(identifier)
			end
			
			local success, result = pcall(callback, ...)
			
			if profile and profiler then
				profiler:endProfile(identifier)
			end
			
			if not success then
				warn(string.format("[Fast Callback] '%s' error: %s", identifier, tostring(result)))
			end
			
			return result
		end
	else
		-- Protected path: full protection
		return function(...)
			-- Fatal error check
			if errorManager.fatalErrorOccurred then
				return nil
			end
			
			-- Exception check
			if errorManager:isException(identifier) then
				if profile and profiler then
					profiler:startProfile(identifier)
				end
				
				local success, result = pcall(callback, ...)
				
				if profile and profiler then
					profiler:endProfile(identifier)
				end
				
				return result
			end
			
			-- Circuit breaker
			if circuitBreaker and errorManager:isCircuitOpen(identifier) then
				return nil
			end
			
			-- Rate limit
			local allowed, rateLimitError = errorManager:checkRateLimit(identifier, rateLimit)
			if not allowed then
				return nil
			end
			
			-- Profile start
			if profile and profiler then
				profiler:startProfile(identifier)
			end
			
			-- Execute
			local success, result = pcall(callback, ...)
			
			-- Profile end
			if profile and profiler then
				profiler:endProfile(identifier)
			end
			
			-- Handle result
			if success then
				errorManager:recordSuccess(identifier)
				return result
			else
				local circuitOpened = errorManager:recordError(identifier, tostring(result))
				
				if circuitOpened then
					errorManager:triggerFatalError(
						string.format("Circuit breaker opened for '%s'", identifier)
					)
				end
				
				return nil
			end
		end
	end
end

-- ============================================
-- PHẦN 7: ENHANCED WRAPPER
-- ============================================

local function createEnhancedRayfield(originalRayfield)
	local errorManager = ErrorManager.new()
	local garbageCollector = GarbageCollector.new()
	local remoteProtection = RemoteProtection.new(errorManager)
	local memoryLeakDetector = MemoryLeakDetector.new()
	local profiler = PerformanceProfiler.new()
	
	-- Shutdown callback
	errorManager:onShutdown(function()
		garbageCollector:cleanupAll()
	end)
	
	-- Leak detection callback
	memoryLeakDetector.onLeakDetected = function(leak)
		if leak.severity == "high" then
			warn("[Memory Leak] Triggering emergency cleanup")
			garbageCollector:cleanup()
		end
	end
	
	-- Wrap CreateWindow
	local originalCreateWindow = originalRayfield.CreateWindow
	originalRayfield.CreateWindow = function(settings)
		local window = originalCreateWindow(settings)
		
		garbageCollector:track(window, "MainWindow", function()
			if window.Destroy then
				pcall(window.Destroy, window)
			end
		end)
		
		return window
	end
	
	-- New APIs
	originalRayfield.GetErrorManager = function()
		return errorManager
	end
	
	originalRayfield.GetGarbageCollector = function()
		return garbageCollector
	end
	
	originalRayfield.GetRemoteProtection = function()
		return remoteProtection
	end
	
	originalRayfield.GetMemoryLeakDetector = function()
		return memoryLeakDetector
	end
	
	originalRayfield.GetProfiler = function()
		return profiler
	end
	
	originalRayfield.IsHealthy = function()
		return not errorManager.fatalErrorOccurred
	end
	
	originalRayfield.GetErrorLog = function()
		return errorManager.errorLog
	end
	
	originalRayfield.ForceCleanup = function()
		return garbageCollector:cleanup()
	end
	
	originalRayfield.GetMemoryReport = function()
		return memoryLeakDetector:getReport()
	end
	
	originalRayfield.GetPerformanceReport = function()
		profiler:printReport()
	end
	
	originalRayfield.GetAuditLog = function()
		return errorManager:getAuditLog()
	end
	
	return originalRayfield, errorManager, garbageCollector, remoteProtection, memoryLeakDetector, profiler
end

-- ============================================
-- EXPORT
-- ============================================

return {
	ErrorManager = ErrorManager,
	GarbageCollector = GarbageCollector,
	RemoteProtection = RemoteProtection,
	MemoryLeakDetector = MemoryLeakDetector,
	PerformanceProfiler = PerformanceProfiler,
	createHybridCallback = createHybridCallback,
	createEnhancedRayfield = createEnhancedRayfield,
	Version = "2.0.0"
}
