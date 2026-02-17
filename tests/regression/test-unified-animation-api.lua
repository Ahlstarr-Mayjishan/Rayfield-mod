-- Unified Animation API regression smoke test
-- Usage:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-unified-animation-api.lua"))()

local BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
local Rayfield = loadstring(game:HttpGet(BASE_URL))()

assert(Rayfield, "Rayfield is nil")
assert(type(Rayfield.CreateWindow) == "function", "CreateWindow missing")
assert(type(Rayfield.Animate) == "table", "Rayfield.Animate missing")
assert(type(Rayfield.Animate.Create) == "function", "Rayfield.Animate.Create missing")
assert(type(Rayfield.Animate.UI) == "function", "Rayfield.Animate.UI missing")
assert(type(Rayfield.Animate.Text) == "function", "Rayfield.Animate.Text missing")

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Name = "UnifiedAnimationApiTest"
if gethui then
	screenGui.Parent = gethui()
else
	screenGui.Parent = game:GetService("CoreGui")
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 120, 0, 40)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundTransparency = 1
frame.Parent = screenGui

local tween = Rayfield.Animate.Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {
	BackgroundTransparency = 0.3
})
assert(tween, "Animate.Create returned nil")
tween:Play()
tween.Completed:Wait()

assert(frame.BackgroundTransparency <= 0.35, "Animate.Create did not tween to expected value")

local seq = Rayfield.Animate(frame)
seq:SetInfo(TweenInfo.new(0.15, Enum.EasingStyle.Linear)):To({BackgroundTransparency = 0.8}):Play()
task.wait(0.2)
assert(frame.BackgroundTransparency >= 0.75, "Sequence chain did not apply")

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 200, 0, 32)
label.Position = UDim2.new(0, 20, 0, 70)
label.Text = ""
label.BackgroundTransparency = 1
label.Parent = screenGui

local textFx = Rayfield.Animate.Text(label)
assert(textFx, "Animate.Text returned nil")
local handle = textFx:Type("Unified Animation", 0.01)
assert(handle and handle.IsRunning and handle.Stop, "Type effect handle invalid")
task.wait(0.25)
handle:Stop()

screenGui:Destroy()
print("✅ Unified animation API smoke test passed")
