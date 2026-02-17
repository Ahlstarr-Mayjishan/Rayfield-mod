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

local function buildFallbackAnimateFacade()
	local engine = (_G and _G.__RayfieldSharedAnimationEngine) or nil
	if not engine then
		local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
		local okEngineLib, engineLib = pcall(function()
			if _G and _G.__RayfieldApiClient then
				return _G.__RayfieldApiClient.fetchAndExecute(root .. "src/core/animation/engine.lua")
			end
			return nil
		end)
		if okEngineLib and engineLib and type(engineLib.new) == "function" then
			local okEngine, createdEngine = pcall(function()
				return engineLib.new({
					TweenService = TweenService,
					RunService = RunService,
					mode = "raw"
				})
			end)
			if okEngine then
				engine = createdEngine
			end
		end
	end

	if not engine then
		return {
			Create = function(_, guiObject, tweenInfo, goals)
				local creator = TweenService["Create"]
				if type(creator) == "function" then
					return creator(TweenService, guiObject, tweenInfo, goals)
				end
				return nil
			end,
			UI = function()
				return nil
			end,
			Text = function()
				return nil
			end,
			GetEngine = function()
				return nil
			end
		}
	end

	return {
		Create = function(_, guiObject, tweenInfo, goals)
			return engine:Create(guiObject, tweenInfo, goals)
		end,
		UI = function()
			return nil
		end,
		Text = function()
			return nil
		end,
		GetEngine = function()
			return engine
		end
	}
end

local Animation = (_G and _G.__RayfieldSharedAnimateFacade) or buildFallbackAnimateFacade()

local RayfieldAdvanced = {Version = "1.1.0"}

-- ============================================
-- 1. SHARED ANIMATION LAYER
-- ============================================
-- Legacy standalone AnimationAPI bridge removed.
-- Enhanced module now relies on shared `Rayfield.Animate` runtime layer.

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
RayfieldAdvanced.StatePersistence = StatePersistence




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
	local holdThemeConnection = nil

	local function getHoldIndicatorColor()
		local fallback = Color3.fromRGB(100, 200, 255)
		if not guiObject then
			return fallback
		end

		local cursor = guiObject
		while cursor do
			local themeValues = cursor:FindFirstChild("ThemeValues")
			if themeValues and themeValues:IsA("Folder") then
				local sliderProgress = themeValues:FindFirstChild("SliderProgress")
				if sliderProgress and sliderProgress:IsA("Color3Value") then
					return sliderProgress.Value
				end
			end
			cursor = cursor.Parent
		end

		return fallback
	end

	local function cleanupHoldThemeSync()
		if holdThemeConnection then
			holdThemeConnection:Disconnect()
			holdThemeConnection = nil
		end
	end

	local function bindHoldThemeSync()
		cleanupHoldThemeSync()
		if not guiObject then
			return
		end

		local cursor = guiObject
		while cursor do
			local themeValues = cursor:FindFirstChild("ThemeValues")
			if themeValues and themeValues:IsA("Folder") then
				local sliderProgress = themeValues:FindFirstChild("SliderProgress")
				if sliderProgress and sliderProgress:IsA("Color3Value") then
					holdThemeConnection = sliderProgress:GetPropertyChangedSignal("Value"):Connect(function()
						if holdIndicator and holdIndicator.Parent then
							holdIndicator.BackgroundColor3 = sliderProgress.Value
						end
					end)
					break
				end
			end
			cursor = cursor.Parent
		end
	end

	guiObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
		   input.UserInputType == Enum.UserInputType.Touch then
			holding = true

			holdIndicator = Instance.new("Frame")
			holdIndicator.Name = "HoldIndicator"
			holdIndicator.Size = UDim2.new(0, 0, 0, 3)
			holdIndicator.Position = UDim2.new(0, 0, 1, -3)
			holdIndicator.BackgroundColor3 = getHoldIndicatorColor()
			holdIndicator.BorderSizePixel = 0
			holdIndicator.ZIndex = 1000
			holdIndicator.Parent = guiObject
			bindHoldThemeSync()

			local progressTween = Animation:Create(
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
					Animation:Create(holdIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Exponential),
						{BackgroundTransparency = 1}):Play()
					task.wait(0.2)
					if holdIndicator then
						holdIndicator:Destroy()
						holdIndicator = nil
					end
					cleanupHoldThemeSync()
				end
			end)
		end
	end)

	guiObject.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
		   input.UserInputType == Enum.UserInputType.Touch then
			holding = false
			cleanupHoldThemeSync()
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

return RayfieldAdvanced
