--[[
	Exception System - Complete Example
	
	Demonstrates all exception system features:
	- Per-callback exceptions
	- Global exception mode
	- Dynamic exception management
	- Error logging with exceptions
]]

-- Load modules
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/your-repo/rayfield-modified.lua'))()
local Enhancement = loadstring(game:HttpGet('https://raw.githubusercontent.com/your-repo/rayfield-enhanced.lua'))()

-- Initialize
local EnhancedRayfield, ErrorMgr, GC, RemoteProt = Enhancement.createEnhancedRayfield(Rayfield)

-- Create window
local Window = EnhancedRayfield:CreateWindow({
	Name = "Exception System Demo",
	LoadingTitle = "Loading Exception Demo",
	LoadingSubtitle = "by Your Name",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "ExceptionDemo",
		FileName = "config"
	}
})

-- ============================================
-- TAB 1: NORMAL VS EXCEPTION
-- ============================================

local CompareTab = Window:CreateTab("🔄 Compare")

-- Normal callback (with protection)
local normalCallback = Enhancement.createSafeCallback(function()
	print("✅ Normal callback executed")
	-- Simulate some work
	task.wait(0.1)
end, "NormalCallback", ErrorMgr, {
	rateLimit = 5, -- Max 5 calls/second
	circuitBreaker = true
})

-- Exception callback (no protection)
local exceptionCallback = Enhancement.createSafeCallback(function()
	print("⚡ Exception callback executed (NO LIMITS)")
	task.wait(0.1)
end, "ExceptionCallback", ErrorMgr, {
	rateLimit = 5,
	circuitBreaker = true
})

-- Add to exception list
ErrorMgr:addException("ExceptionCallback")

CompareTab:CreateButton({
	Name = "Normal Button (Max 5/sec)",
	Callback = normalCallback
})

CompareTab:CreateButton({
	Name = "Exception Button (Unlimited)",
	Callback = exceptionCallback
})

CompareTab:CreateButton({
	Name = "Spam Test (Click 20 times fast)",
	Callback = function()
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🧪 Spam Test Started")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		
		-- Test normal callback
		print("\n1️⃣ Testing Normal Callback (should hit rate limit):")
		for i = 1, 20 do
			normalCallback()
		end
		
		task.wait(1)
		
		-- Test exception callback
		print("\n2️⃣ Testing Exception Callback (should work all 20 times):")
		for i = 1, 20 do
			exceptionCallback()
		end
		
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("✅ Spam Test Completed")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

-- ============================================
-- TAB 2: AUTO FARM EXAMPLE
-- ============================================

local FarmTab = Window:CreateTab("🌾 Auto Farm")

_G.AutoFarm = false
_G.FastMode = false

-- Auto farm callback
local farmCallback = Enhancement.createSafeCallback(function()
	-- Simulate farming
	print("🌾 Farming...")
	game:GetService("ReplicatedStorage"):WaitForChild("FarmEvent"):FireServer()
end, "AutoFarm", ErrorMgr, {
	rateLimit = 10,
	circuitBreaker = true
})

FarmTab:CreateToggle({
	Name = "Auto Farm",
	Default = false,
	Callback = function(value)
		_G.AutoFarm = value
		
		if value then
			print("🌾 Auto Farm: ON")
			task.spawn(function()
				while _G.AutoFarm do
					farmCallback()
					task.wait(_G.FastMode and 0.01 or 0.1)
				end
			end)
		else
			print("🌾 Auto Farm: OFF")
		end
	end
})

FarmTab:CreateToggle({
	Name = "Fast Mode (Bypass Rate Limit)",
	Default = false,
	Callback = function(value)
		_G.FastMode = value
		
		if value then
			ErrorMgr:addException("AutoFarm")
			print("⚡ Fast Mode: ON - Rate limit bypassed")
		else
			ErrorMgr:removeException("AutoFarm")
			print("🛡️ Fast Mode: OFF - Rate limit active")
		end
	end
})

FarmTab:CreateLabel("Fast Mode: 100 calls/sec | Normal: 10 calls/sec")

-- ============================================
-- TAB 3: GLOBAL EXCEPTION MODE
-- ============================================

local GlobalTab = Window:CreateTab("🌐 Global Mode")

GlobalTab:CreateToggle({
	Name = "⚠️ Global Exception Mode",
	Default = false,
	Callback = function(value)
		ErrorMgr:setExceptionMode(value)
	end
})

GlobalTab:CreateLabel("⚠️ WARNING: Disables ALL protection!")
GlobalTab:CreateLabel("Use only for testing or performance-critical scenarios")

-- Test callbacks
local testCallback1 = Enhancement.createSafeCallback(function()
	print("Test 1 executed")
end, "Test1", ErrorMgr, {rateLimit = 2})

local testCallback2 = Enhancement.createSafeCallback(function()
	print("Test 2 executed")
end, "Test2", ErrorMgr, {rateLimit = 2})

local testCallback3 = Enhancement.createSafeCallback(function()
	print("Test 3 executed")
end, "Test3", ErrorMgr, {rateLimit = 2})

GlobalTab:CreateButton({
	Name = "Test All Callbacks (Spam 10x)",
	Callback = function()
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("Testing with Global Exception Mode:", ErrorMgr.exceptionMode)
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
		
		for i = 1, 10 do
			testCallback1()
			testCallback2()
			testCallback3()
		end
		
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("If exception mode OFF: Only 2 calls each")
		print("If exception mode ON: All 10 calls each")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

-- ============================================
-- TAB 4: EXCEPTION MANAGEMENT
-- ============================================

local ManageTab = Window:CreateTab("⚙️ Manage")

-- List of all callbacks
local allCallbacks = {
	"NormalCallback",
	"ExceptionCallback",
	"AutoFarm",
	"Test1",
	"Test2",
	"Test3"
}

ManageTab:CreateLabel("Individual Exception Controls:")

for _, callbackName in ipairs(allCallbacks) do
	ManageTab:CreateToggle({
		Name = callbackName,
		Default = ErrorMgr:isException(callbackName),
		Callback = function(value)
			if value then
				ErrorMgr:addException(callbackName)
			else
				ErrorMgr:removeException(callbackName)
			end
		end
	})
end

ManageTab:CreateButton({
	Name = "Show Exception Status",
	Callback = function()
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🚨 Exception System Status")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("Global Exception Mode:", ErrorMgr.exceptionMode and "ON ⚠️" or "OFF ✅")
		print("\nException List:")
		
		local count = 0
		for identifier, _ in pairs(ErrorMgr.exceptionList) do
			print("  ⚡", identifier)
			count = count + 1
		end
		
		if count == 0 then
			print("  (None)")
		end
		
		print("\nTotal Exceptions:", count)
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

ManageTab:CreateButton({
	Name = "Clear All Exceptions",
	Callback = function()
		for identifier, _ in pairs(ErrorMgr.exceptionList) do
			ErrorMgr:removeException(identifier)
		end
		print("✅ All exceptions cleared")
	end
})

-- ============================================
-- TAB 5: ERROR TESTING
-- ============================================

local ErrorTab = Window:CreateTab("🐛 Error Test")

-- Callback that always errors
local errorCallback = Enhancement.createSafeCallback(function()
	error("Intentional test error!")
end, "ErrorTest", ErrorMgr, {
	circuitBreaker = true
})

ErrorTab:CreateButton({
	Name = "Trigger Error (Protected)",
	Callback = errorCallback
})

ErrorTab:CreateLabel("Click 5 times to open circuit breaker")

ErrorTab:CreateToggle({
	Name = "Bypass Circuit Breaker",
	Default = false,
	Callback = function(value)
		if value then
			ErrorMgr:addException("ErrorTest")
			print("⚠️ Circuit breaker bypassed - errors will keep happening")
		else
			ErrorMgr:removeException("ErrorTest")
			print("✅ Circuit breaker active - will stop after 5 errors")
		end
	end
})

ErrorTab:CreateButton({
	Name = "View Error Log",
	Callback = function()
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("📋 Error Log (Last " .. #ErrorMgr.errorLog .. " errors)")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		
		if #ErrorMgr.errorLog == 0 then
			print("No errors logged")
		else
			for i, log in ipairs(ErrorMgr.errorLog) do
				print(string.format(
					"[%d] %s: %s (Count: %d, Time: %.1fs ago)",
					i,
					log.identifier,
					log.message,
					log.count,
					tick() - log.timestamp
				))
			end
		end
		
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	end
})

ErrorTab:CreateButton({
	Name = "Clear Error Log",
	Callback = function()
		ErrorMgr.errorLog = {}
		print("✅ Error log cleared")
	end
})

-- ============================================
-- TAB 6: PERFORMANCE COMPARISON
-- ============================================

local PerfTab = Window:CreateTab("⚡ Performance")

PerfTab:CreateLabel("Compare performance with/without protection")

local function benchmarkCallback(name, callback, iterations)
	local startTime = tick()
	
	for i = 1, iterations do
		callback()
	end
	
	local endTime = tick()
	local duration = endTime - startTime
	local callsPerSecond = iterations / duration
	
	print(string.format(
		"%s: %.3fs for %d calls (%.0f calls/sec)",
		name,
		duration,
		iterations,
		callsPerSecond
	))
	
	return duration, callsPerSecond
end

PerfTab:CreateButton({
	Name = "Run Benchmark",
	Callback = function()
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("⚡ Performance Benchmark")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
		
		local iterations = 1000
		
		-- Benchmark with protection
		local protectedCb = Enhancement.createSafeCallback(function()
			-- Empty callback
		end, "BenchProtected", ErrorMgr, {
			rateLimit = 9999,
			circuitBreaker = true
		})
		
		local time1, cps1 = benchmarkCallback("With Protection", protectedCb, iterations)
		
		-- Benchmark without protection (exception)
		ErrorMgr:addException("BenchException")
		local exceptionCb = Enhancement.createSafeCallback(function()
			-- Empty callback
		end, "BenchException", ErrorMgr, {
			rateLimit = 9999,
			circuitBreaker = true
		})
		
		local time2, cps2 = benchmarkCallback("With Exception", exceptionCb, iterations)
		
		-- Calculate difference
		local speedup = cps2 / cps1
		local overhead = ((time1 - time2) / time1) * 100
		
		print(string.format("\n📊 Results:"))
		print(string.format("  Speedup: %.2fx faster", speedup))
		print(string.format("  Overhead: %.1f%%", overhead))
		
		print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
		
		-- Cleanup
		ErrorMgr:removeException("BenchException")
	end
})

PerfTab:CreateLabel("Higher calls/sec = better performance")

-- ============================================
-- FINAL NOTES
-- ============================================

print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🚨 Exception System Demo Loaded")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("Explore all tabs to see exception features!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

