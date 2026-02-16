--[[
	Rayfield Animation API Test Script
	
	Kiểm tra:
	1. Tween đồng thời trên nhiều objects cùng tên không bị cancel nhầm
	2. Destroy object trong lúc tween không gây lỗi/memory leak
	
	Usage:
		loadstring(game:HttpGet('https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/test-animation-api.lua'))()
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Test results tracking
local testResults = {}
local testCount = 0
local passCount = 0
local failCount = 0

-- Source pinning to avoid stale/cached remote artifact issues
local REPO = "Ahlstarr-Mayjishan/Rayfield-mod"
local PINNED_COMMIT = "main"
local MODULE_PATH = "feature/rayfield-advanced-features.lua"
local MODULE_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s", REPO, PINNED_COMMIT, MODULE_PATH)

-- Helper functions
local function test(name, fn)
	testCount = testCount + 1
	print("\n🔍 Running: " .. name)
	
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

local function waitUntil(predicate, timeoutSec, stepSec)
	timeoutSec = timeoutSec or 1
	stepSec = stepSec or 0.03

	local deadline = tick() + timeoutSec
	while tick() < deadline do
		local ok, result = pcall(predicate)
		if ok and result then
			return true
		end
		task.wait(stepSec)
	end

	return false
end

-- Load Rayfield Advanced Features module
print("📦 Loading Rayfield Advanced Features module...")
print("📦 Source Repo:", REPO)
print("📌 Pinned Commit:", PINNED_COMMIT)
print("🔗 Module URL:", MODULE_URL)
local RayfieldAdvanced
local success, err = pcall(function()
	local source = game:HttpGet(MODULE_URL)
	local loadFn = loadstring or load
	RayfieldAdvanced = loadFn(source)()
end)

if not success then
	error("Failed to load Rayfield Advanced Features: " .. tostring(err))
end

assertNotNil(RayfieldAdvanced, "stale artifact / wrong commit: module table is nil")
assertNotNil(RayfieldAdvanced.AnimationAPI, "stale artifact / wrong commit: AnimationAPI is nil")
assertTrue(type(RayfieldAdvanced.AnimationAPI.new) == "function",
	"stale artifact / wrong commit: AnimationAPI.new is missing")

local preflightAnimationApi = RayfieldAdvanced.AnimationAPI.new()
assertNotNil(preflightAnimationApi, "stale artifact / wrong commit: AnimationAPI.new() returned nil")
assertTrue(type(preflightAnimationApi.GetActiveAnimationCount) == "function",
	"stale artifact / wrong commit: missing AnimationAPI:GetActiveAnimationCount()")

print("✅ Module loaded successfully")

-- Create test container
local testGui = Instance.new("ScreenGui")
testGui.Name = "AnimationAPITest"
testGui.ResetOnSpawn = false
if gethui then
	testGui.Parent = gethui()
else
	testGui.Parent = game:GetService("CoreGui")
end

print("\n" .. string.rep("=", 60))
print("🧪 RAYFIELD ANIMATION API TESTS")
print(string.rep("=", 60))

-- ============================================
-- TEST CASE 1: Concurrent tweens on objects with same name
-- ============================================
test("Test 1: Concurrent tweens don't cancel each other", function()
	-- Create 2 frames with same name
	local frame1 = Instance.new("Frame")
	frame1.Name = "TestFrame"
	frame1.Size = UDim2.new(0, 100, 0, 100)
	frame1.Position = UDim2.new(0, 10, 0, 10)
	frame1.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	frame1.Parent = testGui
	
	local frame2 = Instance.new("Frame")
	frame2.Name = "TestFrame" -- Same name!
	frame2.Size = UDim2.new(0, 100, 0, 100)
	frame2.Position = UDim2.new(0, 120, 0, 10)
	frame2.BackgroundColor3 = Color3.fromRGB(0, 0, 255)
	frame2.Parent = testGui
	
	-- Start tweens on both frames simultaneously
	local animAPI = RayfieldAdvanced.AnimationAPI.new()
	
	local tween1 = animAPI:Animate(frame1, "BackgroundTransparency", 0.5, 1)
	local tween2 = animAPI:Animate(frame2, "BackgroundTransparency", 0.5, 1)
	
	assertNotNil(tween1, "Tween 1 should not be nil")
	assertNotNil(tween2, "Tween 2 should not be nil")
	
	-- Wait until both tweens are mid-flight to reduce scheduler-related flakiness
	local reachedMidTween = waitUntil(function()
		return frame1.BackgroundTransparency > 0 and frame2.BackgroundTransparency > 0
	end, 0.8, 0.03)
	assertTrue(reachedMidTween, "Frames did not enter tween state before timeout")

	assertTrue(frame1.BackgroundTransparency > 0 and frame1.BackgroundTransparency < 1, 
		"Frame 1 should be mid-tween (transparency between 0 and 1)")
	assertTrue(frame2.BackgroundTransparency > 0 and frame2.BackgroundTransparency < 1, 
		"Frame 2 should be mid-tween (transparency between 0 and 1)")
	
	-- Wait for completion
	task.wait(0.8)
	
	assertTrue(math.abs(frame1.BackgroundTransparency - 0.5) < 0.1, "Frame 1 should reach target transparency 0.5")
	assertTrue(math.abs(frame2.BackgroundTransparency - 0.5) < 0.1, "Frame 2 should reach target transparency 0.5")
	
	-- Cleanup
	frame1:Destroy()
	frame2:Destroy()
end)

-- ============================================
-- TEST CASE 2: Destroy object mid-tween
-- ============================================
test("Test 2: Destroying object mid-tween doesn't cause errors", function()
	local frame = Instance.new("Frame")
	frame.Name = "DestroyTestFrame"
	frame.Size = UDim2.new(0, 100, 0, 100)
	frame.Position = UDim2.new(0, 10, 0, 120)
	frame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	frame.Parent = testGui
	
	local animAPI = RayfieldAdvanced.AnimationAPI.new()

	-- Start a long tween (2 seconds)
	local tween = animAPI:Animate(frame, "Position", UDim2.new(0, 300, 0, 120), 2)
	assertNotNil(tween, "Tween should not be nil")

	-- Wait until mid-tween (50% complete)
	task.wait(1)

	-- Check that animation is active
	local activeCount = animAPI:GetActiveAnimationCount()
	assertTrue(activeCount > 0, "Should have active animations before destroy")

	-- Destroy the frame mid-tween
	local destroySuccess = pcall(function()
		frame:Destroy()
	end)

	assertTrue(destroySuccess, "Destroying frame should not throw error")

	-- Wait a bit to ensure cleanup happens
	task.wait(0.2)

	-- Check that animation was cleaned up
	local activeCountAfter = animAPI:GetActiveAnimationCount()
	assertEquals(activeCountAfter, 0, "All animations should be cleaned up after destroy")
end)

-- ============================================
-- TEST CASE 3: Multiple properties on same object
-- ============================================
test("Test 3: Multiple tweens on different properties of same object", function()
	local frame = Instance.new("Frame")
	frame.Name = "MultiPropertyFrame"
	frame.Size = UDim2.new(0, 100, 0, 100)
	frame.Position = UDim2.new(0, 10, 0, 230)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
	frame.BackgroundTransparency = 0
	frame.Parent = testGui

	local animAPI = RayfieldAdvanced.AnimationAPI.new()

	-- Start multiple tweens on different properties simultaneously
	local tween1 = animAPI:Animate(frame, "BackgroundTransparency", 0.7, 1)
	local tween2 = animAPI:Animate(frame, "Size", UDim2.new(0, 150, 0, 150), 1)
	local tween3 = animAPI:Animate(frame, "Position", UDim2.new(0, 50, 0, 230), 1)

	assertNotNil(tween1, "Transparency tween should not be nil")
	assertNotNil(tween2, "Size tween should not be nil")
	assertNotNil(tween3, "Position tween should not be nil")

	-- Check active animation count
	local activeCount = animAPI:GetActiveAnimationCount()
	assertEquals(activeCount, 3, "Should have 3 active animations")

	-- Wait for completion
	task.wait(1.2)

	-- Verify all tweens completed
	assertTrue(frame.BackgroundTransparency > 0.6, "Transparency should be near target")
	assertTrue(frame.Size.X.Offset > 140, "Size should be near target")
	assertTrue(frame.Position.X.Offset > 40, "Position should be near target")

	-- Cleanup
	frame:Destroy()
end)

-- ============================================
-- TEST CASE 4: Cancel previous tween on same property
-- ============================================
test("Test 4: New tween on same property cancels previous tween", function()
	local frame = Instance.new("Frame")
	frame.Name = "CancelTestFrame"
	frame.Size = UDim2.new(0, 100, 0, 100)
	frame.Position = UDim2.new(0, 10, 0, 340)
	frame.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
	frame.BackgroundTransparency = 0
	frame.Parent = testGui

	local animAPI = RayfieldAdvanced.AnimationAPI.new()

	-- Start first tween
	local tween1 = animAPI:Animate(frame, "BackgroundTransparency", 1, 2)
	assertNotNil(tween1, "First tween should not be nil")

	-- Wait a bit
	task.wait(0.3)

	-- Start second tween on same property (should cancel first)
	local tween2 = animAPI:Animate(frame, "BackgroundTransparency", 0.3, 1)
	assertNotNil(tween2, "Second tween should not be nil")

	-- Should only have 1 active animation for this property
	local activeCount = animAPI:GetActiveAnimationCount()
	assertEquals(activeCount, 1, "Should only have 1 active animation after canceling previous")

	-- Wait for second tween to complete
	task.wait(1.2)

	-- Verify second tween's target was reached
	assertTrue(math.abs(frame.BackgroundTransparency - 0.3) < 0.1,
		"Should reach second tween's target, not first tween's target")

	-- Cleanup
	frame:Destroy()
end)

-- ============================================
-- TEST CASE 5: Memory leak check
-- ============================================
test("Test 5: No memory leaks after multiple destroy cycles", function()
	local animAPI = RayfieldAdvanced.AnimationAPI.new()

	-- Create and destroy multiple frames with tweens
	for i = 1, 10 do
		local frame = Instance.new("Frame")
		frame.Name = "LeakTestFrame_" .. i
		frame.Size = UDim2.new(0, 50, 0, 50)
		frame.Position = UDim2.new(0, 10 + (i * 60), 0, 450)
		frame.BackgroundColor3 = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
		frame.Parent = testGui

		-- Start tween
		animAPI:Animate(frame, "BackgroundTransparency", 0.5, 2)

		-- Destroy immediately
		task.wait(0.05)
		frame:Destroy()
	end

	-- Wait for cleanup
	task.wait(0.5)

	-- All animations should be cleaned up
	local activeCount = animAPI:GetActiveAnimationCount()
	assertEquals(activeCount, 0, "All animations should be cleaned up, no memory leaks")
end)

-- ============================================
-- Print Results
-- ============================================
print("\n" .. string.rep("=", 60))
print("📊 TEST RESULTS")
print(string.rep("=", 60))
print(string.format("Total Tests: %d", testCount))
print(string.format("✅ Passed: %d", passCount))
print(string.format("❌ Failed: %d", failCount))
print(string.format("Pass Rate: %.1f%%", (passCount / testCount) * 100))
print(string.rep("=", 60))

-- Cleanup
task.wait(2)
testGui:Destroy()
print("\n✨ Test cleanup complete. GUI removed.")

return {
	total = testCount,
	passed = passCount,
	failed = failCount,
	results = testResults
}
