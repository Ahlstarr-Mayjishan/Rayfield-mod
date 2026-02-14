--[[
	Rayfield Enhanced V2 - Complete Usage Example
	Demonstrates all new features
]]

-- ============================================
-- SETUP V2
-- ============================================

-- Load Rayfield modified
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/.../rayfield-modified.lua'))()

-- Load enhancement V2
local Enhancement = loadstring(game:HttpGet('https://raw.githubusercontent.com/.../rayfield-enhanced-v2.lua'))()

-- Wrap Rayfield
local EnhancedRayfield, ErrorMgr, GC, RemoteProt, LeakDetector, Profiler = 
	Enhancement.createEnhancedRayfield(Rayfield)

print("✅ Rayfield Enhanced V2 loaded!")
print("Version:", Enhancement.Version)

-- ============================================
-- CREATE WINDOW
-- ============================================

local Window = EnhancedRayfield:CreateWindow({
	Name = "Script Hub V2",
	LoadingTitle = "Loading Enhanced V2",
	LoadingSubtitle = "by Your Name",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "ScriptHubV2",
		FileName = "config"
	}
})

-- ============================================
-- TAB 1: HYBRID MODE DEMO
-- ============================================

local HybridTab = Window:CreateTab("⚡ Hybrid Mode")

HybridTab:CreateLabel("Fast Mode = No protection, max speed")
HybridTab:CreateLabel("Protected Mode = Full protection")

-- Fast callback (for performance-critical code)
local fastCallback = Enhancement.createHybridCallback(function()
	-- ESP update, aimbot, etc.
	print("⚡ Fast callback executed (no overhead)")
end, "FastCallback", ErrorMgr, Profiler, {
	mode = "fast",
	profile = true
})

-- Protected callback (for normal UI interactions)
local protectedCallback = Enhancement.createHybridCallback(function()
	-- Settings, toggles, etc.
	print("🛡️ Protected callback executed (full protection)")
end, "ProtectedCallback", ErrorMgr, Profiler, {
	mode = "protected",
	rateLimit = 5,
	circuitBreaker = true,
	profile = true
})

HybridTab:CreateButton({
	Name = "Fast Button (ESP/Aimbot)",
	Callback = fastCallback
})

HybridTab:CreateButton({
	Name = "Protected Button (Settings)",
	Callback = protectedCallback
})

HybridTab:CreateButton({
	Name = "Benchmark (1000 calls each)",
	Callback = function()
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("⚡ Hybrid Mode Benchmark")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
		
		-- Benchmark fast mode
		local startTime = tick()
		for i = 1, 1000 do
			fastCallback()
		end
		local fastTime = tick() - startTime
		
		-- Benchmark protected mode
		startTime = tick()
		for i = 1, 1000 do
			protectedCallback()
		end
		local protectedTime = tick() - startTime
		
		print(string.format("Fast Mode: %.3fs (%.0f calls/sec)", fastTime, 1000/fastTime))
		print(string.format("Protected Mode: %.3fs (%.0f calls/sec)", protectedTime, 1000/protectedTime))
		print(string.format("Speedup: %.2fx faster", protectedTime/fastTime))
		
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

-- ============================================
-- TAB 2: MEMORY LEAK DETECTION
-- ============================================

local MemoryTab = Window:CreateTab("🧠 Memory")

MemoryTab:CreateLabel("Automatic leak detection every 30s")

MemoryTab:CreateButton({
	Name = "Get Memory Report",
	Callback = function()
		local report = EnhancedRayfield:GetMemoryReport()
		
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🧠 Memory Report")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print(string.format("Current Memory: %.2f MB", report.currentMemory))
		print(string.format("Instance Count: %d", report.instanceCount or 0))
		print(string.format("Snapshots: %d", report.snapshots))
		print(string.format("Suspected Leaks: %d", report.suspectedLeaks))
		
		if #report.details > 0 then
			print("\nTop 10 Object Types:")
			for i, obj in ipairs(report.details) do
				print(string.format("  %d. %s: %d instances", i, obj.className, obj.count))
			end
		end
		
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

MemoryTab:CreateButton({
	Name = "Simulate Memory Leak",
	Callback = function()
		print("🧪 Creating 1000 parts to simulate leak...")
		
		local folder = Instance.new("Folder")
		folder.Name = "LeakTest"
		folder.Parent = workspace
		
		for i = 1, 1000 do
			local part = Instance.new("Part")
			part.Name = "LeakPart_" .. i
			part.Parent = folder
		end
		
		print("✅ Leak simulated. Check report in 30s")
		
		-- Cleanup after 60s
		task.delay(60, function()
			folder:Destroy()
			print("🗑️ Leak cleaned up")
		end)
	end
})

MemoryTab:CreateButton({
	Name = "Force Garbage Collection",
	Callback = function()
		local cleaned = EnhancedRayfield:ForceCleanup()
		print(string.format("🗑️ Cleaned %d objects", cleaned))
	end
})

-- ============================================
-- TAB 3: PERFORMANCE PROFILER
-- ============================================

local PerfTab = Window:CreateTab("📊 Performance")

PerfTab:CreateLabel("All callbacks are automatically profiled")

PerfTab:CreateButton({
	Name = "View Performance Report",
	Callback = function()
		EnhancedRayfield:GetPerformanceReport()
	end
})

PerfTab:CreateButton({
	Name = "Test Slow Callback",
	Callback = Enhancement.createHybridCallback(function()
		print("⏳ Simulating slow operation...")
		task.wait(0.5) -- Simulate slow work
		print("✅ Slow operation completed")
	end, "SlowCallback", ErrorMgr, Profiler, {
		mode = "protected",
		profile = true
	})
})

PerfTab:CreateButton({
	Name = "Get Specific Profile",
	Callback = function()
		local profile = Profiler:getProfile("SlowCallback")
		
		if profile then
			print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			print("📊 SlowCallback Profile")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			print(string.format("Calls: %d", profile.calls))
			print(string.format("Avg Time: %.3fms", profile.avgTime * 1000))
			print(string.format("Min Time: %.3fms", profile.minTime * 1000))
			print(string.format("Max Time: %.3fms", profile.maxTime * 1000))
			print(string.format("Total Time: %.2fs", profile.totalTime))
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
		else
			print("❌ No profile data yet. Run 'Test Slow Callback' first.")
		end
	end
})

-- ============================================
-- TAB 4: PRIORITY REMOTE CALLS
-- ============================================

local RemoteTab = Window:CreateTab("📡 Remote Calls")

RemoteTab:CreateLabel("Priority: critical > high > normal > low")

-- Simulate remote events
local mockRemote = {
	FireServer = function(self, ...)
		print("🔥 Remote fired:", ...)
	end
}

RemoteTab:CreateButton({
	Name = "Critical Priority Call",
	Callback = function()
		local success, msg = RemoteProt:safeRemoteCall(
			mockRemote,
			"FireServer",
			"critical",
			"Critical data"
		)
		print(string.format("Critical: %s - %s", success, msg))
	end
})

RemoteTab:CreateButton({
	Name = "High Priority Call",
	Callback = function()
		local success, msg = RemoteProt:safeRemoteCall(
			mockRemote,
			"FireServer",
			"high",
			"High data"
		)
		print(string.format("High: %s - %s", success, msg))
	end
})

RemoteTab:CreateButton({
	Name = "Normal Priority Call",
	Callback = function()
		local success, msg = RemoteProt:safeRemoteCall(
			mockRemote,
			"FireServer",
			"normal",
			"Normal data"
		)
		print(string.format("Normal: %s - %s", success, msg))
	end
})

RemoteTab:CreateButton({
	Name = "Low Priority Call",
	Callback = function()
		local success, msg = RemoteProt:safeRemoteCall(
			mockRemote,
			"FireServer",
			"low",
			"Low data"
		)
		print(string.format("Low: %s - %s", success, msg))
	end
})

RemoteTab:CreateButton({
	Name = "Queue Status",
	Callback = function()
		local status = RemoteProt:getQueueStatus()
		
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("📡 Remote Queue Status")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		
		for priority, data in pairs(status) do
			print(string.format(
				"%s: %d/%d (%.0f%% full)",
				priority,
				data.count,
				data.max,
				(data.count / data.max) * 100
			))
		end
		
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

-- ============================================
-- TAB 5: EXCEPTION SYSTEM V2
-- ============================================

local ExceptionTab = Window:CreateTab("⚠️ Exceptions")

ExceptionTab:CreateLabel("⚠️ Use with caution!")

-- Test callback
local testCallback = Enhancement.createHybridCallback(function()
	print("Test callback executed")
end, "TestCallback", ErrorMgr, Profiler, {
	mode = "protected",
	rateLimit = 2
})

ExceptionTab:CreateButton({
	Name = "Test Callback (Rate Limited)",
	Callback = testCallback
})

ExceptionTab:CreateButton({
	Name = "Add Exception (10 seconds)",
	Callback = function()
		ErrorMgr:addException("TestCallback", 10)
		print("⚠️ Exception added for 10 seconds")
	end
})

ExceptionTab:CreateButton({
	Name = "Add Exception (Permanent)",
	Callback = function()
		ErrorMgr:addException("TestCallback")
		print("⚠️ Permanent exception added")
	end
})

ExceptionTab:CreateButton({
	Name = "Remove Exception",
	Callback = function()
		ErrorMgr:removeException("TestCallback")
		print("✅ Exception removed")
	end
})

ExceptionTab:CreateToggle({
	Name = "⚠️ Global Exception Mode",
	Default = false,
	Callback = function(value)
		if value then
			-- First call: warning
			local success = ErrorMgr:setExceptionMode(true, nil, false)
			
			if not success then
				print("⚠️ Call again to confirm")
				task.wait(0.1)
				-- Second call: confirmed
				ErrorMgr:setExceptionMode(true, 60, true) -- Auto-disable after 60s
			end
		else
			ErrorMgr:setExceptionMode(false, nil, true)
		end
	end
})

ExceptionTab:CreateButton({
	Name = "View Audit Log",
	Callback = function()
		ErrorMgr:printAuditLog()
	end
})

-- ============================================
-- TAB 6: MONITORING DASHBOARD
-- ============================================

local MonitorTab = Window:CreateTab("📈 Monitor")

MonitorTab:CreateButton({
	Name = "Full System Report",
	Callback = function()
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("📈 Rayfield Enhanced V2 - System Report")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		
		-- Health
		print(string.format("System Health: %s", 
			EnhancedRayfield:IsHealthy() and "✅ Healthy" or "❌ Unhealthy"))
		
		-- Memory
		local memReport = EnhancedRayfield:GetMemoryReport()
		print(string.format("Memory: %.2f MB", memReport.currentMemory))
		print(string.format("Suspected Leaks: %d", memReport.suspectedLeaks))
		
		-- Errors
		local errors = EnhancedRayfield:GetErrorLog()
		print(string.format("Error Log: %d entries", #errors))
		
		-- Remote queues
		local queueStatus = RemoteProt:getQueueStatus()
		local totalQueued = 0
		for _, data in pairs(queueStatus) do
			totalQueued = totalQueued + data.count
		end
		print(string.format("Remote Queue: %d pending", totalQueued))
		
		-- Audit log
		local auditLog = EnhancedRayfield:GetAuditLog()
		print(string.format("Audit Log: %d entries", #auditLog))
		
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

MonitorTab:CreateButton({
	Name = "View Error Log",
	Callback = function()
		local errors = EnhancedRayfield:GetErrorLog()
		
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("📋 Error Log (Last " .. math.min(10, #errors) .. " errors)")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		
		if #errors == 0 then
			print("No errors logged")
		else
			for i = math.max(1, #errors - 9), #errors do
				local err = errors[i]
				print(string.format(
					"[%d] %s: %s (%.1fs ago)",
					i,
					err.identifier,
					err.message,
					tick() - err.timestamp
				))
			end
		end
		
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

MonitorTab:CreateButton({
	Name = "Circuit Breaker Status",
	Callback = function()
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🔌 Circuit Breaker Status")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		
		local hasCircuits = false
		for identifier, state in pairs(ErrorMgr.circuitState) do
			hasCircuits = true
			local errorCount = ErrorMgr.errorCount[identifier] or 0
			print(string.format(
				"%s: %s (Errors: %d/%d)",
				identifier,
				state,
				errorCount,
				ErrorMgr.errorThreshold
			))
		end
		
		if not hasCircuits then
			print("No circuits registered")
		end
		
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

-- ============================================
-- SHUTDOWN HANDLER
-- ============================================

ErrorMgr:onShutdown(function()
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🛑 Rayfield Enhanced V2 Shutting Down")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	-- Final reports
	print("\n📊 Final Performance Report:")
	EnhancedRayfield:GetPerformanceReport()
	
	print("\n🧠 Final Memory Report:")
	local report = EnhancedRayfield:GetMemoryReport()
	print(string.format("Final Memory: %.2f MB", report.currentMemory))
	print(string.format("Total Leaks Detected: %d", report.suspectedLeaks))
	
	print("\n🔒 Final Audit Log:")
	ErrorMgr:printAuditLog()
	
	-- Cleanup
	GC:cleanupAll()
	
	print("\n✅ Shutdown Complete")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
end)

-- ============================================
-- FINAL NOTIFICATION
-- ============================================

EnhancedRayfield:Notify({
	Title = "Rayfield Enhanced V2",
	Content = "All features loaded successfully!",
	Duration = 5,
})

print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ Rayfield Enhanced V2 Ready!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("New Features:")
print("  ✅ Memory Leak Detection")
print("  ✅ Performance Profiler")
print("  ✅ Hybrid Mode (fast/protected)")
print("  ✅ Priority Remote Queues")
print("  ✅ Exception System V2")
print("  ✅ Security Audit Log")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
