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

local function resolveCompatibility()
	if type(_G) == "table" and type(_G.__RayfieldCompatibility) == "table" then
		return _G.__RayfieldCompatibility
	end
	return nil
end

local function getService(name)
	local compatibility = resolveCompatibility()
	if compatibility and type(compatibility.getService) == "function" then
		local service = compatibility.getService(name)
		if service then
			return service
		end
	end
	return game:GetService(name)
end

local function safeGetChildren(instance)
	local ok, children = pcall(function()
		return instance:GetChildren()
	end)
	if ok and type(children) == "table" then
		return children
	end
	return {}
end

local function safeGetDescendants(instance)
	local ok, descendants = pcall(function()
		return instance:GetDescendants()
	end)
	if ok and type(descendants) == "table" then
		return descendants
	end
	return {}
end

local UI_HEAVY_CLASSES = {
	Frame = true,
	TextLabel = true,
	ImageLabel = true,
	UIStroke = true,
	UICorner = true,
	ScrollingFrame = true,
	TextButton = true,
	ImageButton = true,
}

local function clamp(value, minValue, maxValue)
	value = tonumber(value) or 0
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

function MemoryLeakDetector.new()
	local self = setmetatable({}, MemoryLeakDetector)
	
	-- Tracking
	self.snapshots = {}
	self.maxSnapshots = 10
	self.checkInterval = 120 -- seconds (increased from 30 for performance)
	self.leakThreshold = 10 * 1024 * 1024 -- 10MB growth
	self.suspectedLeaks = {}
	self.enabled = true -- Toggle to disable in production
	
	-- Object tracking
	self.objectCounts = {}
	self.lastObjectCounts = {}
	
	-- Scan behavior
	self.scanMode = "ui" -- "ui", "mixed", "game"
	self.scanTargets = {"Workspace", "Players"} -- legacy targets for "game" mode
	self.customScanRoots = nil
	self.maxScanDescendants = 50000
	self.scanBudgetWarning = 20000
	self.lastScanMeta = nil
	
	-- Callbacks
	self.onLeakDetected = nil
	self.onUnknownCause = nil
	self.running = false
	self.monitorThread = nil

	self.runtimeDiagnosticsProvider = nil
	self.attributionPolicy = {
		mode = "weighted",
		triggerScore = 70,
		confirmCycles = 2,
		unknownNotifyOncePerSession = true
	}
	self.attributionState = {
		lastScore = 0,
		lastClassification = "unknown",
		confirmStreak = 0,
		lastEvidence = {},
		unknownNotified = false
	}
	
	self:startMonitoring()
	
	return self
end

function MemoryLeakDetector:setRuntimeDiagnosticsProvider(provider)
	if provider ~= nil and type(provider) ~= "function" then
		warn("[Memory Leak Detector] setRuntimeDiagnosticsProvider expects function or nil")
		return false
	end
	self.runtimeDiagnosticsProvider = provider
	return true
end

function MemoryLeakDetector:setAttributionPolicy(policy)
	if type(policy) ~= "table" then
		warn("[Memory Leak Detector] setAttributionPolicy expects table")
		return false
	end

	local updated = {
		mode = tostring(policy.mode or self.attributionPolicy.mode):lower(),
		triggerScore = tonumber(policy.triggerScore) or self.attributionPolicy.triggerScore,
		confirmCycles = tonumber(policy.confirmCycles) or self.attributionPolicy.confirmCycles,
		unknownNotifyOncePerSession = policy.unknownNotifyOncePerSession
	}

	if updated.mode ~= "weighted" then
		warn("[Memory Leak Detector] Unsupported attribution mode: " .. tostring(updated.mode))
		return false
	end

	if updated.unknownNotifyOncePerSession == nil then
		updated.unknownNotifyOncePerSession = self.attributionPolicy.unknownNotifyOncePerSession
	end

	self.attributionPolicy = {
		mode = updated.mode,
		triggerScore = clamp(updated.triggerScore, 1, 100),
		confirmCycles = math.max(1, math.floor(updated.confirmCycles)),
		unknownNotifyOncePerSession = updated.unknownNotifyOncePerSession == true
	}

	return true
end

function MemoryLeakDetector:getAttributionReport()
	return {
		lastScore = self.attributionState.lastScore,
		lastClassification = self.attributionState.lastClassification,
		confirmStreak = self.attributionState.confirmStreak,
		lastEvidence = self.attributionState.lastEvidence
	}
end

function MemoryLeakDetector:_collectRuntimeDiagnostics()
	local diagnostics = {
		activeTweens = 0,
		activeTextHandles = 0,
		themeBindings = {
			objectsBound = 0,
			propertiesBound = 0
		},
		gcTrackedObjects = 0,
		rayfieldVisible = false,
		rayfieldMinimized = false,
		rayfieldDestroyed = false
	}

	if type(self.runtimeDiagnosticsProvider) == "function" then
		local ok, provided = pcall(self.runtimeDiagnosticsProvider)
		if ok and type(provided) == "table" then
			diagnostics.activeTweens = tonumber(provided.activeTweens) or diagnostics.activeTweens
			diagnostics.activeTextHandles = tonumber(provided.activeTextHandles) or diagnostics.activeTextHandles
			diagnostics.gcTrackedObjects = tonumber(provided.gcTrackedObjects) or diagnostics.gcTrackedObjects
			diagnostics.rayfieldVisible = provided.rayfieldVisible == true
			diagnostics.rayfieldMinimized = provided.rayfieldMinimized == true
			diagnostics.rayfieldDestroyed = provided.rayfieldDestroyed == true
			if type(provided.themeBindings) == "table" then
				diagnostics.themeBindings = {
					objectsBound = tonumber(provided.themeBindings.objectsBound) or 0,
					propertiesBound = tonumber(provided.themeBindings.propertiesBound) or 0
				}
			end
		end
	end

	return diagnostics
end

function MemoryLeakDetector:setScanMode(mode)
	local normalized = tostring(mode or ""):lower()
	if normalized ~= "ui" and normalized ~= "mixed" and normalized ~= "game" then
		warn("[Memory Leak Detector] Invalid scan mode: " .. tostring(mode) .. " (use 'ui', 'mixed', or 'game')")
		return false
	end
	self.scanMode = normalized
	return true
end

function MemoryLeakDetector:setScanRoots(roots)
	if roots == nil then
		self.customScanRoots = nil
		return true
	end
	if type(roots) ~= "table" then
		warn("[Memory Leak Detector] setScanRoots expects table or nil")
		return false
	end

	local sanitized = {}
	local seen = {}
	for _, root in ipairs(roots) do
		if typeof(root) == "Instance" and not seen[root] then
			seen[root] = true
			table.insert(sanitized, root)
		end
	end
	self.customScanRoots = sanitized
	return true
end

function MemoryLeakDetector:_resolveUiRoots()
	if type(self.customScanRoots) == "table" and #self.customScanRoots > 0 then
		return self.customScanRoots
	end

	local roots = {}
	local seen = {}
	local function addRoot(root)
		if typeof(root) ~= "Instance" then
			return
		end
		if seen[root] then
			return
		end
		seen[root] = true
		table.insert(roots, root)
	end

	local compatibility = resolveCompatibility()
	local coreGui = getService("CoreGui")
	local players = getService("Players")
	local localPlayer = players and players.LocalPlayer or nil

	if type(_G) == "table" then
		addRoot(_G.Rayfield)
		local rayfieldUi = _G.RayfieldUI
		if type(rayfieldUi) == "table" and typeof(rayfieldUi.ScreenGui) == "Instance" then
			addRoot(rayfieldUi.ScreenGui)
		end
	end

	if compatibility and type(compatibility.tryGetHui) == "function" then
		local hui = compatibility.tryGetHui()
		if hui then
			for _, child in ipairs(safeGetChildren(hui)) do
				if child.Name == "Rayfield" or child.Name == "Key" then
					addRoot(child)
				end
			end
		end
	end

	if coreGui then
		for _, child in ipairs(safeGetChildren(coreGui)) do
			if child.Name == "Rayfield" or child.Name == "Key" then
				addRoot(child)
			end
		end
	end

	local playerGui = nil
	if localPlayer then
		playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	end
	if playerGui then
		for _, child in ipairs(safeGetChildren(playerGui)) do
			if child.Name == "Rayfield" or child.Name == "Key" then
				addRoot(child)
			end
		end
	end

	return roots
end

function MemoryLeakDetector:_resolveGameRoots()
	local roots = {}
	for _, targetName in ipairs(self.scanTargets) do
		local target = game:FindFirstChild(targetName)
		if target then
			table.insert(roots, target)
		end
	end
	return roots
end

function MemoryLeakDetector:_resolveScanRoots()
	if self.scanMode == "game" then
		return self:_resolveGameRoots()
	end
	return self:_resolveUiRoots()
end

function MemoryLeakDetector:_scanRoots(collectBreakdown)
	local objectBreakdown = collectBreakdown and {} or nil
	local totalCount = 0
	local totalDescendantsVisited = 0
	local truncated = false
	local roots = self:_resolveScanRoots()

	for _, root in ipairs(roots) do
		local descendants = safeGetDescendants(root)
		totalDescendantsVisited += #descendants
		local allowed = #descendants
		local remainingBudget = self.maxScanDescendants - totalCount
		if remainingBudget <= 0 then
			truncated = true
			break
		end
		if allowed > remainingBudget then
			allowed = remainingBudget
			truncated = true
		end

		for index = 1, allowed do
			local obj = descendants[index]
			totalCount += 1
			if objectBreakdown then
				local className = obj.ClassName
				objectBreakdown[className] = (objectBreakdown[className] or 0) + 1
			end
		end
	end

	if totalDescendantsVisited > self.scanBudgetWarning then
		warn(string.format(
			"[Memory Leak Detector] Scan budget warning: visited=%d mode=%s roots=%d",
			totalDescendantsVisited,
			tostring(self.scanMode),
			#roots
		))
	end

	self.lastScanMeta = {
		mode = self.scanMode,
		rootCount = #roots,
		visited = totalDescendantsVisited,
		counted = totalCount,
		truncated = truncated
	}

	return totalCount, objectBreakdown
end

function MemoryLeakDetector:getTargetedInstanceCount()
	local count = self:_scanRoots(false)
	return count
end

function MemoryLeakDetector:_getMixedLightweightStats()
	local workspace = getService("Workspace")
	local players = getService("Players")
	local stats = {
		workspaceChildren = workspace and #safeGetChildren(workspace) or 0,
		playersChildren = players and #safeGetChildren(players) or 0
	}
	return stats
end

function MemoryLeakDetector:takeSnapshot()
	local statsService = getService("Stats")
	local instanceCount, objectBreakdown = self:_scanRoots(true)
	local runtimeDiagnostics = self:_collectRuntimeDiagnostics()
	local snapshot = {
		timestamp = tick(),
		totalMemory = statsService and statsService:GetTotalMemoryUsageMb() or 0,
		instanceCount = instanceCount,
		objectBreakdown = objectBreakdown or {},
		scanMode = self.scanMode,
		runtimeDiagnostics = runtimeDiagnostics
	}
	
	if self.scanMode == "mixed" then
		snapshot.mixedStats = self:_getMixedLightweightStats()
	end
	if self.lastScanMeta then
		snapshot.scanMeta = self.lastScanMeta
	end
	
	table.insert(self.snapshots, snapshot)
	
	-- Keep only recent snapshots
	if #self.snapshots > self.maxSnapshots then
		table.remove(self.snapshots, 1)
	end
	
	return snapshot
end

function MemoryLeakDetector:_evaluateAttribution()
	local snapshots = self.snapshots
	local newest = snapshots[#snapshots]
	local previous = snapshots[#snapshots - 1]
	if not newest or not previous then
		self.attributionState.lastScore = 0
		self.attributionState.lastClassification = "unknown"
		self.attributionState.confirmStreak = 0
		self.attributionState.lastEvidence = {
			reason = "insufficient_snapshots"
		}
		return {
			score = 0,
			classification = "unknown",
			confirmed = false,
			evidence = self.attributionState.lastEvidence
		}
	end

	local latestDiag = newest.runtimeDiagnostics or {}
	local prevDiag = previous.runtimeDiagnostics or {}
	local latestTheme = latestDiag.themeBindings or {}
	local prevTheme = prevDiag.themeBindings or {}

	local uiInstanceGrowth = math.max(0, (newest.instanceCount or 0) - (previous.instanceCount or 0))
	local uiClassGrowth = 0
	for className in pairs(UI_HEAVY_CLASSES) do
		local newestCount = tonumber(newest.objectBreakdown and newest.objectBreakdown[className]) or 0
		local previousCount = tonumber(previous.objectBreakdown and previous.objectBreakdown[className]) or 0
		uiClassGrowth += math.max(0, newestCount - previousCount)
	end

	local tweenGrowth = math.max(0, (tonumber(latestDiag.activeTweens) or 0) - (tonumber(prevDiag.activeTweens) or 0))
	local textHandleGrowth = math.max(0, (tonumber(latestDiag.activeTextHandles) or 0) - (tonumber(prevDiag.activeTextHandles) or 0))
	local themeBindingGrowth = math.max(0, (tonumber(latestTheme.propertiesBound) or 0) - (tonumber(prevTheme.propertiesBound) or 0))
	local gcTrackedGrowth = math.max(0, (tonumber(latestDiag.gcTrackedObjects) or 0) - (tonumber(prevDiag.gcTrackedObjects) or 0))

	local subsystemGrowth = tweenGrowth + textHandleGrowth + themeBindingGrowth + gcTrackedGrowth
	local rayfieldGuiAlive = false
	if type(_G) == "table" and typeof(_G.Rayfield) == "Instance" then
		local ok, parent = pcall(function()
			return _G.Rayfield.Parent
		end)
		rayfieldGuiAlive = ok and parent ~= nil
	end

	local scoreS1 = clamp((uiInstanceGrowth / 300) * 40, 0, 40)
	local scoreS2 = clamp((uiClassGrowth / 160) * 20, 0, 20)
	local scoreS3 = clamp((subsystemGrowth / 60) * 30, 0, 30)
	local scoreS4 = rayfieldGuiAlive and 10 or 0
	local totalScore = clamp(scoreS1 + scoreS2 + scoreS3 + scoreS4, 0, 100)

	local classification = totalScore >= self.attributionPolicy.triggerScore and "rayfield_ui" or "unknown"
	if classification == "rayfield_ui" then
		self.attributionState.confirmStreak = self.attributionState.confirmStreak + 1
	else
		self.attributionState.confirmStreak = 0
	end

	local evidence = {
		uiInstanceGrowth = uiInstanceGrowth,
		uiClassGrowth = uiClassGrowth,
		subsystemGrowth = subsystemGrowth,
		tweenGrowth = tweenGrowth,
		textHandleGrowth = textHandleGrowth,
		themeBindingGrowth = themeBindingGrowth,
		gcTrackedGrowth = gcTrackedGrowth,
		rayfieldGuiAlive = rayfieldGuiAlive,
		scoreBreakdown = {
			S1 = scoreS1,
			S2 = scoreS2,
			S3 = scoreS3,
			S4 = scoreS4
		}
	}

	self.attributionState.lastScore = totalScore
	self.attributionState.lastClassification = classification
	self.attributionState.lastEvidence = evidence

	return {
		score = totalScore,
		classification = classification,
		confirmed = classification == "rayfield_ui" and self.attributionState.confirmStreak >= self.attributionPolicy.confirmCycles,
		evidence = evidence
	}
end

function MemoryLeakDetector:_shouldNotifyUnknownCause()
	if not self.attributionPolicy.unknownNotifyOncePerSession then
		return true
	end
	if self.attributionState.unknownNotified then
		return false
	end
	self.attributionState.unknownNotified = true
	return true
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

function MemoryLeakDetector:setEnabled(enabled)
	self.enabled = enabled
	if enabled then
		print("[Memory Leak Detector] Enabled")
	else
		print("[Memory Leak Detector] Disabled")
	end
end

function MemoryLeakDetector:startMonitoring()
	if self.monitorThread then
		return
	end
	self.running = true
	self.monitorThread = task.spawn(function()
		while self.running do
			task.wait(self.checkInterval)
			if not self.running then
				break
			end
			
			if not self.enabled then continue end
			
			-- Take snapshot
			self:takeSnapshot()
			local attribution = self:_evaluateAttribution()
			
			-- Detect leaks
			local leaks = self:detectLeaks()
			
			if leaks then
				local unknownNotificationSent = false
				for _, leak in ipairs(leaks) do
					leak.sourceClassification = attribution.classification
					leak.attributionScore = attribution.score
					leak.attributionEvidence = attribution.evidence
					leak.attributionConfirmed = attribution.confirmed
					
					-- Track suspected leaks
					table.insert(self.suspectedLeaks, {
						leak = leak,
						timestamp = tick()
					})
					
					if leak.sourceClassification == "rayfield_ui" then
						warn("[Memory Leak Detector] " .. leak.message)
						if self.onLeakDetected then
							pcall(self.onLeakDetected, leak)
						end
					elseif not unknownNotificationSent and self:_shouldNotifyUnknownCause() then
						unknownNotificationSent = true
						if self.onUnknownCause then
							pcall(self.onUnknownCause, {
								message = leak.message,
								attributionScore = attribution.score,
								attributionEvidence = attribution.evidence
							})
						end
					end
				end
			end
		end
		self.monitorThread = nil
	end)
end

function MemoryLeakDetector:stopMonitoring()
	self.running = false
	if self.monitorThread then
		pcall(task.cancel, self.monitorThread)
		self.monitorThread = nil
	end
end

function MemoryLeakDetector:destroy()
	self:setEnabled(false)
	self:stopMonitoring()
	self.onLeakDetected = nil
	self.onUnknownCause = nil
end

function MemoryLeakDetector:getReport()
	local report = {
		snapshots = #self.snapshots,
		suspectedLeaks = #self.suspectedLeaks,
		currentMemory = 0,
		details = {},
		scanMode = self.scanMode,
		attribution = self:getAttributionReport()
	}
	
	if #self.snapshots > 0 then
		local latest = self.snapshots[#self.snapshots]
		report.currentMemory = latest.totalMemory
		report.instanceCount = latest.instanceCount
		report.scanMeta = latest.scanMeta
		if latest.mixedStats then
			report.mixedStats = latest.mixedStats
		end
		
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

function ErrorManager:formatError(identifier, errorMessage)
	local id = tostring(identifier or "Unknown")
	local detail = tostring(errorMessage or "Unknown error")
	local lowerId = string.lower(id)
	local component = id

	if string.find(lowerId, "split") then
		component = "Tab Splitter"
	elseif string.find(lowerId, "drag") or string.find(lowerId, "dock") then
		component = "Drag & Dock"
	elseif string.find(lowerId, "remote") then
		component = "Remote Protection"
	elseif string.find(lowerId, "config") then
		component = "Configuration"
	elseif string.find(lowerId, "theme") then
		component = "Theme"
	end

	return string.format("Rayfield Mod: %s | %s", component, detail)
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
	local formatted = self:formatError(identifier, errorMessage)
	
	table.insert(self.errorLog, {
		identifier = identifier,
		message = formatted,
		timestamp = tick(),
		count = self.errorCount[identifier]
	})
	
	if #self.errorLog > self.maxLogSize then
		table.remove(self.errorLog, 1)
	end
	
	if self.errorCount[identifier] >= self.errorThreshold then
		self.circuitState[identifier] = "open"
		warn(string.format(
			"Rayfield Mod: Circuit breaker opened for '%s' after %d errors",
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
				warn(errorManager:formatError(identifier, tostring(result)))
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
						errorManager:formatError(identifier, "Circuit breaker opened")
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

	memoryLeakDetector:setRuntimeDiagnosticsProvider(function()
		local diagnostics = {}
		if type(originalRayfield.GetRuntimeDiagnostics) == "function" then
			local ok, value = pcall(function()
				return originalRayfield:GetRuntimeDiagnostics()
			end)
			if ok and type(value) == "table" then
				diagnostics = value
			end
		end

		diagnostics.gcTrackedObjects = type(garbageCollector.trackedObjects) == "table" and #garbageCollector.trackedObjects or 0
		return diagnostics
	end)
	
	-- Shutdown callback
	errorManager:onShutdown(function()
		memoryLeakDetector:destroy()
		garbageCollector:cleanupAll()
	end)
	
	-- Leak detection callback
	memoryLeakDetector.onLeakDetected = function(leak)
		if leak.severity == "high" and leak.sourceClassification == "rayfield_ui" and leak.attributionConfirmed == true then
			warn("[Memory Leak] Triggering emergency cleanup")
			garbageCollector:cleanup()
		end
	end

	memoryLeakDetector.onUnknownCause = function()
		if type(originalRayfield.Notify) == "function" then
			pcall(function()
				originalRayfield:Notify({
					Title = "Memory Monitor",
					Content = "RAM tăng cao nhưng chưa đủ bằng chứng do Rayfield; chưa kích hoạt emergency.",
					Duration = 8
				})
			end)
		end
	end
	
	-- Wrap CreateWindow
	local originalCreateWindow = originalRayfield.CreateWindow
	originalRayfield.CreateWindow = function(selfOrSettings, maybeSettings)
		-- Support both call styles:
		-- 1) Rayfield:CreateWindow(settings)  -> selfOrSettings = Rayfield, maybeSettings = settings
		-- 2) Rayfield.CreateWindow(settings)  -> selfOrSettings = settings, maybeSettings = nil
		local self = originalRayfield
		local settings = maybeSettings

		if selfOrSettings == originalRayfield then
			self = selfOrSettings
		elseif maybeSettings == nil then
			settings = selfOrSettings
		end

		if type(settings) ~= "table" then
			settings = {}
		end

		local window = originalCreateWindow(self, settings)
		
		garbageCollector:track(window, "MainWindow", function()
			if window.Destroy then
				pcall(window.Destroy, window)
			end
		end)
		
		return window
	end

	-- Ensure background workers are stopped on explicit destroy
	local originalDestroy = originalRayfield.Destroy
	if type(originalDestroy) == "function" then
		originalRayfield.Destroy = function(self, ...)
			memoryLeakDetector:destroy()
			garbageCollector:cleanupAll()
			return originalDestroy(self, ...)
		end
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

	originalRayfield.GetAttributionReport = function()
		return memoryLeakDetector:getAttributionReport()
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
