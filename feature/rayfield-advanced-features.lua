--[[
	Rayfield Advanced Features - Complete Module

	Tính năng:
	✅ Animation API - Animate bất kỳ property nào
	✅ Drag & Drop - Kéo thả elements (giữ 3 giây)
	✅ Detachable Windows - Tách element thành cửa sổ riêng
	✅ State Persistence - Lưu trạng thái elements
	✅ Performance Monitor - Theo dõi hiệu suất
	✅ Default Templates - Main & Settings tabs mặc định

]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local RayfieldAdvanced = {Version = "1.0.0"}

-- ============================================
-- 1. ANIMATION API
-- ============================================

local AnimationAPI = {}
AnimationAPI.__index = AnimationAPI

function AnimationAPI.new()
	local self = setmetatable({}, AnimationAPI)
	self.activeAnimations = {}
	return self
end

-- Core animate function
function AnimationAPI:Animate(guiObject, property, targetValue, duration, easingStyle, easingDirection)
	duration = duration or 0.5
	easingStyle = easingStyle or Enum.EasingStyle.Exponential
	easingDirection = easingDirection or Enum.EasingDirection.Out

	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	local tween = TweenService:Create(guiObject, tweenInfo, {[property] = targetValue})

	local animId = tostring(guiObject) .. "_" .. property
	if self.activeAnimations[animId] then
		self.activeAnimations[animId]:Cancel()
	end
	self.activeAnimations[animId] = tween

	tween:Play()
	tween.Completed:Connect(function()
		self.activeAnimations[animId] = nil
	end)

	return tween
end

-- Preset animations
function AnimationAPI:FadeIn(guiObject, duration)
	guiObject.Visible = true
	return self:Animate(guiObject, "BackgroundTransparency", 0, duration)
end

function AnimationAPI:FadeOut(guiObject, duration)
	local tween = self:Animate(guiObject, "BackgroundTransparency", 1, duration)
	tween.Completed:Connect(function()
		guiObject.Visible = false
	end)
	return tween
end

function AnimationAPI:SlideIn(guiObject, direction, duration)
	direction = direction or "left"
	local originalPos = guiObject.Position

	if direction == "left" then
		guiObject.Position = UDim2.new(-1, 0, originalPos.Y.Scale, originalPos.Y.Offset)
	elseif direction == "right" then
		guiObject.Position = UDim2.new(2, 0, originalPos.Y.Scale, originalPos.Y.Offset)
	elseif direction == "top" then
		guiObject.Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, -1, 0)
	else -- bottom
		guiObject.Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, 2, 0)
	end

	guiObject.Visible = true
	return self:Animate(guiObject, "Position", originalPos, duration, Enum.EasingStyle.Back)
end

function AnimationAPI:Bounce(guiObject, duration)
	duration = duration or 0.4
	local originalSize = guiObject.Size
	local tween1 = self:Animate(guiObject, "Size",
		UDim2.new(originalSize.X.Scale * 1.1, 0, originalSize.Y.Scale * 1.1, 0),
		duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	tween1.Completed:Connect(function()
		self:Animate(guiObject, "Size", originalSize, duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)

	return tween1
end

function AnimationAPI:Shake(guiObject, intensity, duration)
	intensity = intensity or 5
	duration = duration or 0.5
	local originalPos = guiObject.Position
	local shakeCount = 10
	local shakeDelay = duration / shakeCount

	task.spawn(function()
		for i = 1, shakeCount do
			local offsetX = math.random(-intensity, intensity)
			local offsetY = math.random(-intensity, intensity)
			guiObject.Position = UDim2.new(
				originalPos.X.Scale, originalPos.X.Offset + offsetX,
				originalPos.Y.Scale, originalPos.Y.Offset + offsetY
			)
			task.wait(shakeDelay)
		end
		guiObject.Position = originalPos
	end)
end

function AnimationAPI:Pulse(guiObject, duration, pulseCount)
	duration = duration or 1
	pulseCount = pulseCount or 3
	local pulseDuration = duration / pulseCount

	task.spawn(function()
		for i = 1, pulseCount do
			self:Bounce(guiObject, pulseDuration)
			task.wait(pulseDuration)
		end
	end)
end

-- ============================================
-- 2. STATE PERSISTENCE
-- ============================================

local StatePersistence = {}
StatePersistence.__index = StatePersistence

function StatePersistence.new(configFolder)
	local self = setmetatable({}, StatePersistence)
	self.configFolder = configFolder or "RayfieldAdvanced"
	self.stateFile = self.configFolder .. "/element_states.json"
	self.states = {}

	if makefolder and not isfolder(self.configFolder) then
		pcall(makefolder, self.configFolder)
	end

	self:Load()
	return self
end

function StatePersistence:SaveState(elementId, state)
	self.states[elementId] = {
		visible = state.visible,
		position = state.position,
		size = state.size,
		detached = state.detached or false,
		timestamp = tick()
	}
	self:Save()
end

function StatePersistence:GetState(elementId)
	return self.states[elementId]
end

function StatePersistence:Save()
	if not writefile then return end
	local success, encoded = pcall(function()
		return HttpService:JSONEncode(self.states)
	end)
	if success then
		pcall(writefile, self.stateFile, encoded)
	end
end

function StatePersistence:Load()
	if not readfile or not isfile then return end
	local success, content = pcall(readfile, self.stateFile)
	if not success then return end

	local decoded
	success, decoded = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if success and decoded then
		self.states = decoded
	end
end

-- Export modules
RayfieldAdvanced.AnimationAPI = AnimationAPI
RayfieldAdvanced.StatePersistence = StatePersistence

return RayfieldAdvanced




-- ============================================
-- 3. PERFORMANCE MONITOR
-- ============================================

local PerformanceMonitor = {}
PerformanceMonitor.__index = PerformanceMonitor

function PerformanceMonitor.new()
	local self = setmetatable({}, PerformanceMonitor)

	self.elementCount = 0
	self.detachedWindowCount = 0
	self.activeAnimations = 0
	self.memoryUsage = 0
	self.fps = 0
	self.startTime = tick()

	self:StartMonitoring()
	return self
end

function PerformanceMonitor:StartMonitoring()
	local lastUpdate = tick()
	local frames = 0

	RunService.RenderStepped:Connect(function()
		frames = frames + 1
		if tick() - lastUpdate >= 1 then
			self.fps = frames
			frames = 0
			lastUpdate = tick()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			local stats = game:GetService("Stats")
			self.memoryUsage = stats:GetTotalMemoryUsageMb()
		end
	end)
end

function PerformanceMonitor:GetStats()
	return {
		elementCount = self.elementCount,
		detachedWindows = self.detachedWindowCount,
		activeAnimations = self.activeAnimations,
		memoryUsage = self.memoryUsage,
		fps = self.fps,
		uptime = tick() - self.startTime
	}
end

function PerformanceMonitor:PrintStats()
	local stats = self:GetStats()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📊 Rayfield Performance Stats")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print(string.format("Elements: %d", stats.elementCount))
	print(string.format("Detached Windows: %d", stats.detachedWindows))
	print(string.format("Active Animations: %d", stats.activeAnimations))
	print(string.format("Memory: %.2f MB", stats.memoryUsage))
	print(string.format("FPS: %d", stats.fps))
	print(string.format("Uptime: %.1f seconds", stats.uptime))
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

-- ============================================
-- 4. DRAG & DROP MANAGER
-- ============================================

local DragDropManager = {}
DragDropManager.__index = DragDropManager

function DragDropManager.new(performanceMonitor)
	local self = setmetatable({}, DragDropManager)

	self.performanceMonitor = performanceMonitor
	self.draggingElement = nil
	self.isDragging = false
	self.dragThreshold = 3
	self.detachedWindows = {}

	return self
end

function DragDropManager:EnableDrag(element, guiObject)
	local holding = false
	local holdIndicator = nil

	guiObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
		   input.UserInputType == Enum.UserInputType.Touch then
			holding = true

			holdIndicator = Instance.new("Frame")
			holdIndicator.Name = "HoldIndicator"
			holdIndicator.Size = UDim2.new(0, 0, 0, 3)
			holdIndicator.Position = UDim2.new(0, 0, 1, -3)
			holdIndicator.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
			holdIndicator.BorderSizePixel = 0
			holdIndicator.ZIndex = 1000
			holdIndicator.Parent = guiObject

			local progressTween = TweenService:Create(
				holdIndicator,
				TweenInfo.new(self.dragThreshold, Enum.EasingStyle.Linear),
				{Size = UDim2.new(1, 0, 0, 3)}
			)
			progressTween:Play()

			local holdStartTime = tick()
			task.spawn(function()
				while holding and tick() - holdStartTime < self.dragThreshold do
					task.wait(0.1)
				end

				if holding and tick() - holdStartTime >= self.dragThreshold then
					self:StartDragging(element, guiObject)
				end

				if holdIndicator then
					TweenService:Create(holdIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Exponential),
						{BackgroundTransparency = 1}):Play()
					task.wait(0.2)
					holdIndicator:Destroy()
				end
			end)
		end
	end)

	guiObject.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
		   input.UserInputType == Enum.UserInputType.Touch then
			holding = false
		end
	end)
end

function DragDropManager:StartDragging(element, guiObject)
	self.isDragging = true
	self.draggingElement = {
		element = element,
		guiObject = guiObject,
		originalParent = guiObject.Parent,
		originalPosition = guiObject.Position,
		originalSize = guiObject.Size,
		originalTransparency = guiObject.BackgroundTransparency
	}

	guiObject.BackgroundTransparency = 0.5
	guiObject.ZIndex = 1000

	print("🎯 Drag mode! Kéo ra ngoài để tách cửa sổ")
	self:TrackDragMovement(guiObject)
end