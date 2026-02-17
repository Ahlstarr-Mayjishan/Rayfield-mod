--[[
	Rayfield Unified Animation API Regression Test

	Usage:
		loadstring(game:HttpGet('https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/test-animation-api.lua'))()
]]

local RayfieldURL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local function assertTrue(condition, message)
	if not condition then
		error(message or "Assertion failed")
	end
end

local function assertNear(actual, expected, epsilon, message)
	epsilon = epsilon or 0.1
	if math.abs(actual - expected) > epsilon then
		error(message or string.format("Expected %.3f ~= %.3f (epsilon=%.3f)", actual, expected, epsilon))
	end
end

local Rayfield = compileString(game:HttpGet(RayfieldURL))()
assertTrue(type(Rayfield) == "table", "Rayfield module load failed")
assertTrue(type(Rayfield.Animate) == "table", "Rayfield.Animate missing")
assertTrue(type(Rayfield.Animate.Create) == "function", "Rayfield.Animate.Create missing")
assertTrue(type(Rayfield.Animate.GetActiveAnimationCount) == "function", "Rayfield.Animate.GetActiveAnimationCount missing")

local rootGui = Instance.new("ScreenGui")
rootGui.Name = "UnifiedAnimationApiRegression"
rootGui.ResetOnSpawn = false
if gethui then
	rootGui.Parent = gethui()
else
	rootGui.Parent = game:GetService("CoreGui")
end

local frameA = Instance.new("Frame")
frameA.Name = "TestFrame"
frameA.Size = UDim2.new(0, 100, 0, 100)
frameA.Position = UDim2.new(0, 10, 0, 10)
frameA.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
frameA.Parent = rootGui

local frameB = Instance.new("Frame")
frameB.Name = "TestFrame"
frameB.Size = UDim2.new(0, 100, 0, 100)
frameB.Position = UDim2.new(0, 120, 0, 10)
frameB.BackgroundColor3 = Color3.fromRGB(0, 0, 255)
frameB.Parent = rootGui

local tweenA = Rayfield.Animate.Create(frameA, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {
	BackgroundTransparency = 0.5
})
local tweenB = Rayfield.Animate.Create(frameB, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {
	BackgroundTransparency = 0.5
})
assertTrue(tweenA ~= nil and tweenB ~= nil, "Failed to create concurrent tweens")
tweenA:Play()
tweenB:Play()

task.wait(0.45)
assertTrue(frameA.BackgroundTransparency > 0 and frameB.BackgroundTransparency > 0, "Frames did not enter tween state")

task.wait(0.55)
assertNear(frameA.BackgroundTransparency, 0.5, 0.15, "Frame A not near target")
assertNear(frameB.BackgroundTransparency, 0.5, 0.15, "Frame B not near target")

local activeBeforeDestroy = Rayfield.Animate.GetActiveAnimationCount()
assertTrue(activeBeforeDestroy >= 0, "Invalid active animation count")

local longTween = Rayfield.Animate.Create(frameA, TweenInfo.new(2, Enum.EasingStyle.Linear), {
	Position = UDim2.new(0, 300, 0, 10)
})
assertTrue(longTween ~= nil, "Failed to create long tween")
longTween:Play()

task.wait(0.4)
frameA:Destroy()
task.wait(0.2)

local activeAfterDestroy = Rayfield.Animate.GetActiveAnimationCount()
assertTrue(activeAfterDestroy >= 0, "Invalid active animation count after destroy")

local sequenceTarget = frameB
local sequence = Rayfield.Animate(sequenceTarget)
sequence:SetInfo(TweenInfo.new(0.2, Enum.EasingStyle.Linear)):To({
	Position = UDim2.new(0, 200, 0, 10)
}):Play()

task.wait(0.3)
assertTrue(sequenceTarget.Position.X.Offset >= 180, "Sequence API did not update target position")

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 260, 0, 28)
label.Position = UDim2.new(0, 10, 0, 130)
label.BackgroundTransparency = 1
label.Text = ""
label.Parent = rootGui

local textFx = Rayfield.Animate.Text(label)
assertTrue(textFx ~= nil, "Rayfield.Animate.Text returned nil")
local textHandle = textFx:Type("Unified Animation API", 0.01)
assertTrue(textHandle and textHandle.Stop and textHandle.IsRunning, "Invalid text effect handle")
task.wait(0.2)
textHandle:Stop()
assertTrue(not textHandle:IsRunning(), "Text effect did not stop")

rootGui:Destroy()
print("✅ Unified animation regression test passed")
