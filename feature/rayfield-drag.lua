-- Rayfield Drag/Detach System Module
-- Handles element detachment, mini windows, drag preview, and dock/undock logic

local DragModule = {}

-- Initialize module with dependencies
function DragModule.init(ctx)
	local self = {}

	-- Inject dependencies
	self.UserInputService = ctx.UserInputService
	self.TweenService = ctx.TweenService
	self.RunService = ctx.RunService
	self.HttpService = ctx.HttpService
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.Elements = ctx.Elements
	self.Rayfield = ctx.Rayfield
	self.Icons = ctx.Icons
	self.getIcon = ctx.getIcon
	self.getAssetUri = ctx.getAssetUri
	self.getSelectedTheme = ctx.getSelectedTheme
	self.rayfieldDestroyed = ctx.rayfieldDestroyed

	-- Extract code starts here

	local DETACH_HOLD_DURATION = 3
	local DETACH_HEADER_HEIGHT = 28
	local DETACH_MIN_WIDTH = 250
	local DETACH_MIN_HEIGHT = 90
	local DETACH_GHOST_FOLLOW_SPEED = 0.22
	local DETACH_WINDOW_DRAG_FOLLOW_SPEED = 0.28
	local DETACH_POP_IN_DURATION = 0.2
	local DETACH_POP_OUT_DURATION = 0.14
	local DETACH_CUE_HOVER_TRANSPARENCY = 0.72
	local DETACH_CUE_HOLD_TRANSPARENCY = 0.18
	local DETACH_CUE_READY_TRANSPARENCY = 0.04
	local DETACH_CUE_IDLE_THICKNESS = 1
	local DETACH_CUE_HOVER_THICKNESS = 1.2
	local DETACH_CUE_HOLD_THICKNESS = 2.2
	local DETACH_CUE_READY_THICKNESS = 2.4
	local DETACH_MERGE_DETECT_PADDING = 56
	local MERGE_INDICATOR_HEIGHT = 3
	local MERGE_INDICATOR_MARGIN = 8
	local MERGE_INDICATOR_TWEEN_DURATION = 0.12
	local DETACH_MOD_BUILD = "overlay-indicator-v1"
	_G.__RAYFIELD_MOD_BUILD = DETACH_MOD_BUILD
	
	local detachedScreenGui = nil
	local detachedLayer = nil
	local detachedCleanupBound = false
	local detachedWindowsRegistry = {}
	
	-- Shared global input dispatcher: one InputChanged + one InputEnded connection
	-- instead of 2 per element. Callbacks keyed by unique ID.
	local sharedInputChanged = {}-- [id] = function(input)
	local sharedInputEnded = {}-- [id] = function(input)
	local sharedInputConnections = nil
	
	local function ensureSharedInputConnections()
		if sharedInputConnections then return end
		sharedInputConnections = {
			self.UserInputService.InputChanged:Connect(function(input)
				for _, cb in pairs(sharedInputChanged) do
					cb(input)
				end
			end),
			self.UserInputService.InputEnded:Connect(function(input)
				for _, cb in pairs(sharedInputEnded) do
					cb(input)
				end
			end),
		}
	end
	
	local function registerSharedInput(id, onChanged, onEnded)
		ensureSharedInputConnections()
		if onChanged then sharedInputChanged[id] = onChanged end
		if onEnded then sharedInputEnded[id] = onEnded end
	end
	
	local function unregisterSharedInput(id)
		sharedInputChanged[id] = nil
		sharedInputEnded[id] = nil
	end
	
	local function registerDetachedWindow(record)
		if not record then
			return
		end
		table.insert(detachedWindowsRegistry, record)
	end
	
	local function unregisterDetachedWindow(record)
		for i = #detachedWindowsRegistry, 1, -1 do
			if detachedWindowsRegistry[i] == record then
				table.remove(detachedWindowsRegistry, i)
				break
			end
		end
	end
	
	local function isPointNearFrame(point, frame, padding)
		if not (point and frame and frame.Parent) then
			return false
		end
	
		local pad = padding or 0
		local framePosition = frame.AbsolutePosition
		local frameSize = frame.AbsoluteSize
		local minX = framePosition.X - pad
		local minY = framePosition.Y - pad
		local maxX = framePosition.X + frameSize.X + pad
		local maxY = framePosition.Y + frameSize.Y + pad
		return point.X >= minX and point.X <= maxX and point.Y >= minY and point.Y <= maxY
	end
	
	local function findMergeTargetWindow(point, excludeRecord)
		for _, record in ipairs(detachedWindowsRegistry) do
			if record ~= excludeRecord and record.frame and record.frame.Parent and isPointNearFrame(point, record.frame, DETACH_MERGE_DETECT_PADDING) then
				return record
			end
		end
		return nil
	end
	
	local function ensureDetachedLayer()
		if detachedLayer and detachedLayer.Parent then
			return detachedLayer
		end
	
		if detachedScreenGui and not detachedScreenGui.Parent then
			detachedScreenGui = nil
			detachedLayer = nil
		end
	
		if not detachedScreenGui then
			local existing = self.Rayfield.Parent and self.Rayfield.Parent:FindFirstChild("self.Rayfield-DetachedWindows")
			if existing and existing:IsA("ScreenGui") then
				detachedScreenGui = existing
			else
				detachedScreenGui = Instance.new("ScreenGui")
				detachedScreenGui.Name = "self.Rayfield-DetachedWindows"
				detachedScreenGui.ResetOnSpawn = false
				detachedScreenGui.IgnoreGuiInset = self.Rayfield.IgnoreGuiInset
				detachedScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
				detachedScreenGui.DisplayOrder = math.max((self.Rayfield.DisplayOrder or 100) + 1, 101)
				detachedScreenGui.Parent = self.Rayfield.Parent
			end
		end
	
		detachedLayer = detachedScreenGui:FindFirstChild("WindowLayer")
		if not detachedLayer then
			detachedLayer = Instance.new("Frame")
			detachedLayer.Name = "WindowLayer"
			detachedLayer.BackgroundTransparency = 1
			detachedLayer.BorderSizePixel = 0
			detachedLayer.Size = UDim2.fromScale(1, 1)
			detachedLayer.Parent = detachedScreenGui
		end
	
		if not detachedCleanupBound then
			detachedCleanupBound = true
			self.Rayfield.Destroying:Connect(function()
				if detachedScreenGui then
					detachedScreenGui:Destroy()
					detachedScreenGui = nil
					detachedLayer = nil
				end
				table.clear(detachedWindowsRegistry)
				-- Tear down shared input dispatcher
				table.clear(sharedInputChanged)
				table.clear(sharedInputEnded)
				if sharedInputConnections then
					for _, conn in ipairs(sharedInputConnections) do
						conn:Disconnect()
					end
					sharedInputConnections = nil
				end
			end)
		end
	
		return detachedLayer
	end
	
	local function getInputPosition(input)
		if input and input.Position then
			return Vector2.new(input.Position.X, input.Position.Y)
		end
		return self.UserInputService:GetMouseLocation()
	end
	
	local function clampDetachedPosition(desiredPosition, windowSize)
		local layer = ensureDetachedLayer()
		local layerSize = layer.AbsoluteSize
		local maxX = math.max(layerSize.X - windowSize.X, 0)
		local maxY = math.max(layerSize.Y - windowSize.Y, 0)
		return Vector2.new(
			math.clamp(desiredPosition.X, 0, maxX),
			math.clamp(desiredPosition.Y, 0, maxY)
		)
	end
	
	local function isOutsideMain(point)
		local mainPosition = self.Main.AbsolutePosition
		local mainSize = self.Main.AbsoluteSize
		return point.X < mainPosition.X
			or point.Y < mainPosition.Y
			or point.X > (mainPosition.X + mainSize.X)
			or point.Y > (mainPosition.Y + mainSize.Y)
	end
	
	local function isInsideMain(point)
		return not isOutsideMain(point)
	end
	
	local function makeFloatingDraggable(frame, dragHandle, onDragEnd)
		local dragging = false
		local dragInput = nil
		local dragStartPointer = nil
		local dragStartFramePosition = nil
		local targetPosition = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
		local connections = {}
		local dragId = self.HttpService:GenerateGUID(false)
	
		dragHandle.Active = true
	
		table.insert(connections, dragHandle.InputBegan:Connect(function(input)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end
	
			dragging = true
			dragInput = input
			dragStartPointer = getInputPosition(input)
			dragStartFramePosition = targetPosition
		end))
	
		registerSharedInput(dragId, function(input) -- InputChanged
			if not dragging or not dragInput then
				return
			end
	
			local matchesTouch = input == dragInput
			local matchesMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
			if not matchesTouch and not matchesMouse then
				return
			end
	
			local currentPointer = getInputPosition(input)
			local delta = currentPointer - dragStartPointer
			local desired = dragStartFramePosition + delta
			targetPosition = clampDetachedPosition(desired, frame.AbsoluteSize)
		end, function(input) -- InputEnded
			if not dragging or not dragInput then
				return
			end
	
			local mouseEnded = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
			if input == dragInput or mouseEnded then
				local releasePoint = getInputPosition(input)
				dragging = false
				dragInput = nil
				if typeof(onDragEnd) == "function" then
					task.defer(onDragEnd, releasePoint, frame)
				end
			end
		end)
	
		table.insert(connections, self.RunService.RenderStepped:Connect(function(deltaTime)
			if not dragging then
				targetPosition = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
				return
			end
	
			local current = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
			local alpha = math.clamp(deltaTime * (DETACH_WINDOW_DRAG_FOLLOW_SPEED * 60), 0, 1)
			local nextPosition = current:Lerp(targetPosition, alpha)
			frame.Position = UDim2.fromOffset(math.floor(nextPosition.X + 0.5), math.floor(nextPosition.Y + 0.5))
		end))
	
		return function()
			unregisterSharedInput(dragId)
			for _, connection in ipairs(connections) do
				if connection then
					connection:Disconnect()
				end
			end
			table.clear(connections)
		end
	end
	
	local function createElementDetacher(guiObject, elementName, elementType)
		if not guiObject or not guiObject:IsA("GuiObject") then
			return nil
		end
	
		if elementType == "Section" or elementType == "Divider" then
			return nil
		end
	
		local dragInputSources = {}
		local adaptiveHoldDuration = DETACH_HOLD_DURATION
		local hoverCounter = 0
	
		local function addDragInputSource(source)
			if not (source and source:IsA("GuiObject")) then
				return
			end
			if table.find(dragInputSources, source) then
				return
			end
			source.Active = true
			table.insert(dragInputSources, source)
		end
	
		if elementType == "Button" then
			adaptiveHoldDuration = 2.2
		elseif elementType == "Dropdown" then
			adaptiveHoldDuration = 1.85
		elseif elementType == "Input" then
			adaptiveHoldDuration = 1.7
		end
	
		-- Prefer Interact for elements like Button/Toggle, then Title, then fallback to full element.
		addDragInputSource(guiObject:FindFirstChild("Interact"))
		addDragInputSource(guiObject:FindFirstChild("Title"))
		if elementType == "Dropdown" then
			addDragInputSource(guiObject:FindFirstChild("Selected"))
		end
		if elementType == "Input" then
			local inputFrame = guiObject:FindFirstChild("InputFrame")
			addDragInputSource(inputFrame)
			if inputFrame then
				addDragInputSource(inputFrame:FindFirstChild("InputBox"))
			end
		end
		if elementType ~= "Input" and elementType ~= "Dropdown" then
			addDragInputSource(guiObject)
		end
		if #dragInputSources == 0 then
			addDragInputSource(guiObject)
		end
	
		local detached = false
		local floatingWindow = nil
		local floatingContent = nil
		local floatingWindowWidth = nil
		local floatingDragCleanup = nil
		local floatingTitleBar = nil
		local floatingStroke = nil
		local floatingTitleLabel = nil
		local floatingDockButton = nil
		local detachedPlaceholder = nil
		local windowRecord = nil
		local windowConnections = {}
		local eventConnections = {}
		local originalState = nil
		local rememberedState = nil
		local detacherId = self.HttpService:GenerateGUID(false)
	
		local pressInput = nil
		local pressToken = 0
		local pressing = false
		local dragArmed = false
		local pointerPosition = nil
		local dragGhost = nil
		local ghostTargetPosition = nil
		local ghostFollowConnection = nil
		local hoverActive = false
		local cueFrame = nil
		local cueStroke = nil
		local cueThemeConnection = nil
		local mergePreviewRecord = nil
		local clearMergePreview = nil
		local mergeIndicator = nil
		local mergeIndicatorRecord = nil
		local mergeIndicatorTween = nil
		local lastMergeUpdateTime = 0
		local lastMergeInsertIndex = nil
		local mainDropIndicator = nil
		local mainDropIndicatorTween = nil
		local lastMainDropInsertIndex = nil
		local MERGE_UPDATE_INTERVAL = 0.05 -- ~20fps for preview, smooth enough while light
	
		local function getDetachCueColor()
			return self.getSelectedTheme().SliderProgress or self.getSelectedTheme().TextColor or Color3.fromRGB(120, 170, 255)
		end
	
		local function ensureDetachCue()
			if self.rayfieldDestroyed() or not (guiObject and guiObject.Parent) or not (self.Main and self.Main.Parent) then
				if cueThemeConnection then
					cueThemeConnection:Disconnect()
					cueThemeConnection = nil
				end
				if cueFrame then
					cueFrame:Destroy()
					cueFrame = nil
					cueStroke = nil
				end
				return false
			end
	
			if cueFrame and cueFrame.Parent and cueStroke and cueStroke.Parent then
				return true
			end
	
			if cueThemeConnection then
				cueThemeConnection:Disconnect()
				cueThemeConnection = nil
			end
	
			cueFrame = Instance.new("Frame")
			cueFrame.Name = "DetachCue"
			cueFrame.BackgroundTransparency = 1
			cueFrame.BorderSizePixel = 0
			cueFrame.Size = UDim2.fromScale(1, 1)
			cueFrame.Position = UDim2.fromOffset(0, 0)
			cueFrame.ZIndex = (guiObject.ZIndex or 1) + 6
			cueFrame.Active = false
			cueFrame.Parent = guiObject
	
			local sourceCorner = guiObject:FindFirstChildOfClass("UICorner")
			if sourceCorner then
				local cueCorner = Instance.new("UICorner")
				cueCorner.CornerRadius = sourceCorner.CornerRadius
				cueCorner.Parent = cueFrame
			end
	
			cueStroke = Instance.new("UIStroke")
			cueStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			cueStroke.Color = getDetachCueColor()
			cueStroke.Thickness = DETACH_CUE_IDLE_THICKNESS
			cueStroke.Transparency = 1
			cueStroke.Parent = cueFrame
	
			cueThemeConnection = self.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
				if cueStroke and cueStroke.Parent then
					cueStroke.Color = getDetachCueColor()
				end
			end)
	
			return true
		end
	
		local function setDetachCue(transparency, thickness, duration)
			if not cueStroke or not cueStroke.Parent then
				return
			end
	
			if not duration or duration <= 0 then
				cueStroke.Transparency = transparency
				cueStroke.Thickness = thickness
				return
			end
	
			self.TweenService:Create(cueStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = transparency,
				Thickness = thickness
			}):Play()
		end
	
		local function refreshDetachCue()
			if not ensureDetachCue() then
				return
			end
			if detached then
				setDetachCue(1, DETACH_CUE_IDLE_THICKNESS, 0.1)
				return
			end
	
			if dragArmed then
				setDetachCue(DETACH_CUE_READY_TRANSPARENCY, DETACH_CUE_READY_THICKNESS, 0.08)
				return
			end
	
			if pressing then
				setDetachCue(DETACH_CUE_HOLD_TRANSPARENCY, DETACH_CUE_HOLD_THICKNESS, 0.08)
				return
			end
	
			if hoverActive then
				setDetachCue(DETACH_CUE_HOVER_TRANSPARENCY, DETACH_CUE_HOVER_THICKNESS, 0.12)
			else
				setDetachCue(1, DETACH_CUE_IDLE_THICKNESS, 0.12)
			end
		end
	
		local function runHoldCueProgress(token)
			local started = os.clock()
			while pressing and pressToken == token and not dragArmed and not detached do
				local progress = math.clamp((os.clock() - started) / adaptiveHoldDuration, 0, 1)
				local transparency = DETACH_CUE_HOVER_TRANSPARENCY + ((DETACH_CUE_HOLD_TRANSPARENCY - DETACH_CUE_HOVER_TRANSPARENCY) * progress)
				local thickness = DETACH_CUE_HOVER_THICKNESS + ((DETACH_CUE_HOLD_THICKNESS - DETACH_CUE_HOVER_THICKNESS) * progress)
				setDetachCue(transparency, thickness, 0)
				task.wait()
			end
		end
	
		local function cleanupDetachCue()
			if cueThemeConnection then
				cueThemeConnection:Disconnect()
				cueThemeConnection = nil
			end
			if cueFrame then
				cueFrame:Destroy()
				cueFrame = nil
				cueStroke = nil
			end
		end
	
		local function cleanupWindowConnections()
			for _, connection in ipairs(windowConnections) do
				if connection then
					connection:Disconnect()
				end
			end
			table.clear(windowConnections)
		end
	
		local function getOrderedGuiChildren(parent, excludeA, excludeB)
			if not parent then
				return {}
			end
	
			local rawChildren = parent:GetChildren()
			local insertionOrder = {}
			for index, child in ipairs(rawChildren) do
				insertionOrder[child] = index
			end
	
			local ordered = {}
			for _, child in ipairs(rawChildren) do
				if child:IsA("GuiObject") and child ~= excludeA and child ~= excludeB then
					table.insert(ordered, child)
				end
			end
	
			table.sort(ordered, function(a, b)
				if a.LayoutOrder ~= b.LayoutOrder then
					return a.LayoutOrder < b.LayoutOrder
				end
				return (insertionOrder[a] or 0) < (insertionOrder[b] or 0)
			end)
	
			return ordered
		end
	
		local function normalizeOrderedGuiLayout(ordered)
			for index, child in ipairs(ordered) do
				child.LayoutOrder = index * 10
			end
		end
	
		local function parentUsesLayoutOrder(parent)
			if not parent then
				return false
			end
			local listLayout = parent:FindFirstChildOfClass("UIListLayout")
			return listLayout ~= nil and listLayout.SortOrder == Enum.SortOrder.LayoutOrder
		end
	
		local function resolveInsertIndexFromState(parent, state, ordered)
			if not (parent and state) then
				return nil
			end
	
			local candidates = ordered or getOrderedGuiChildren(parent)
	
			if state.NextSibling and state.NextSibling.Parent == parent then
				for index, child in ipairs(candidates) do
					if child == state.NextSibling then
						return index
					end
				end
			end
	
			if state.PreviousSibling and state.PreviousSibling.Parent == parent then
				for index, child in ipairs(candidates) do
					if child == state.PreviousSibling then
						return index + 1
					end
				end
			end
	
			if type(state.SiblingIndex) == "number" then
				return math.floor(state.SiblingIndex)
			end
	
			return nil
		end
	
		local function captureCurrentElementState()
			local parent = guiObject.Parent
			local siblingIndex = nil
			local previousSibling = nil
			local nextSibling = nil
	
			if parent and parentUsesLayoutOrder(parent) then
				local ordered = getOrderedGuiChildren(parent)
				for index, child in ipairs(ordered) do
					if child == guiObject then
						siblingIndex = index
						previousSibling = ordered[index - 1]
						nextSibling = ordered[index + 1]
						break
					end
				end
			end
	
			return {
				Parent = parent,
				AnchorPoint = guiObject.AnchorPoint,
				Position = guiObject.Position,
				Size = guiObject.Size,
				LayoutOrder = guiObject.LayoutOrder,
				SiblingIndex = siblingIndex,
				PreviousSibling = previousSibling,
				NextSibling = nextSibling
			}
		end
	
		local function updateDetachedPlaceholder()
			if not detachedPlaceholder then
				return
			end
	
			local height = math.max(guiObject.AbsoluteSize.Y, 36)
			detachedPlaceholder.Size = UDim2.new(1, 0, 0, height)
		end
	
		local function destroyDetachedPlaceholder()
			if detachedPlaceholder then
				detachedPlaceholder:Destroy()
				detachedPlaceholder = nil
			end
		end
	
		local function createDetachedPlaceholder()
			if detachedPlaceholder or not originalState or not originalState.Parent then
				return
			end
	
			detachedPlaceholder = Instance.new("Frame")
			detachedPlaceholder.Name = "DetachPlaceholder"
			detachedPlaceholder.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
			detachedPlaceholder.BackgroundTransparency = 0.82
			detachedPlaceholder.BorderSizePixel = 0
			detachedPlaceholder.LayoutOrder = originalState.LayoutOrder
			detachedPlaceholder.Parent = originalState.Parent
	
			if parentUsesLayoutOrder(originalState.Parent) then
				local ordered = getOrderedGuiChildren(originalState.Parent, detachedPlaceholder)
				local insertIndex = resolveInsertIndexFromState(originalState.Parent, originalState, ordered)
				if type(insertIndex) ~= "number" then
					insertIndex = #ordered + 1
				end
				insertIndex = math.clamp(insertIndex, 1, #ordered + 1)
				table.insert(ordered, insertIndex, detachedPlaceholder)
				normalizeOrderedGuiLayout(ordered)
				detachedPlaceholder:SetAttribute("DetachSlotIndex", insertIndex)
			else
				detachedPlaceholder:SetAttribute("DetachSlotIndex", nil)
			end
	
			local sourceCorner = guiObject:FindFirstChildOfClass("UICorner")
			if sourceCorner then
				local placeholderCorner = Instance.new("UICorner")
				placeholderCorner.CornerRadius = sourceCorner.CornerRadius
				placeholderCorner.Parent = detachedPlaceholder
			end
	
			local placeholderStroke = Instance.new("UIStroke")
			placeholderStroke.Color = self.getSelectedTheme().SliderProgress or self.getSelectedTheme().ElementStroke
			placeholderStroke.Thickness = 1.2
			placeholderStroke.Transparency = 0.35
			placeholderStroke.Parent = detachedPlaceholder
	
			local placeholderLabel = Instance.new("TextLabel")
			placeholderLabel.Name = "Hint"
			placeholderLabel.BackgroundTransparency = 1
			placeholderLabel.Size = UDim2.new(1, -12, 1, 0)
			placeholderLabel.Position = UDim2.new(0, 6, 0, 0)
			placeholderLabel.Text = "Detached slot (origin): " .. tostring(elementName)
			placeholderLabel.TextColor3 = self.getSelectedTheme().TextColor
			placeholderLabel.TextTransparency = 0.35
			placeholderLabel.TextSize = 11
			placeholderLabel.Font = Enum.Font.Gotham
			placeholderLabel.TextXAlignment = Enum.TextXAlignment.Left
			placeholderLabel.Parent = detachedPlaceholder
	
			updateDetachedPlaceholder()
		end
	
		local function destroyDragGhost(instant)
			if clearMergePreview then
				clearMergePreview(true)
			end
	
			if ghostFollowConnection then
				ghostFollowConnection:Disconnect()
				ghostFollowConnection = nil
			end
	
			if not dragGhost then
				ghostTargetPosition = nil
				return
			end
	
			local ghost = dragGhost
			dragGhost = nil
			ghostTargetPosition = nil
	
			if instant then
				ghost:Destroy()
				return
			end
	
			local shrinkWidth = math.max(math.floor(ghost.AbsoluteSize.X * 0.9), 120)
			local shrinkHeight = math.max(math.floor(ghost.AbsoluteSize.Y * 0.88), 26)
			self.TweenService:Create(ghost, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(shrinkWidth, shrinkHeight)
			}):Play()
	
			for _, child in ipairs(ghost:GetChildren()) do
				if child:IsA("TextLabel") then
					self.TweenService:Create(child, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
				elseif child:IsA("UIStroke") then
					self.TweenService:Create(child, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
				end
			end
	
			task.delay(DETACH_POP_OUT_DURATION + 0.03, function()
				if ghost and ghost.Parent then
					ghost:Destroy()
				end
			end)
		end
	
		local function updateGhostPosition()
			if not dragGhost or not pointerPosition then
				return
			end
	
			local size = dragGhost.AbsoluteSize
			ghostTargetPosition = Vector2.new(
				pointerPosition.X - (size.X / 2),
				pointerPosition.Y - (size.Y / 2)
			)
		end
	
		local function createDragGhost()
			if dragGhost then
				return
			end
	
			local layer = ensureDetachedLayer()
			local targetSize = Vector2.new(
				math.max(guiObject.AbsoluteSize.X, 160),
				math.max(guiObject.AbsoluteSize.Y, 34)
			)
			local startSize = Vector2.new(
				math.max(math.floor(targetSize.X * 0.9), 120),
				math.max(math.floor(targetSize.Y * 0.88), 26)
			)
	
			dragGhost = Instance.new("Frame")
			dragGhost.Name = "DetachGhost"
			dragGhost.Size = UDim2.fromOffset(startSize.X, startSize.Y)
			dragGhost.BorderSizePixel = 0
			dragGhost.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
			dragGhost.BackgroundTransparency = 1
			dragGhost.ZIndex = 250
			dragGhost.Parent = layer
	
			local ghostCorner = Instance.new("UICorner")
			ghostCorner.CornerRadius = UDim.new(0, 8)
			ghostCorner.Parent = dragGhost
	
			local ghostStroke = Instance.new("UIStroke")
			ghostStroke.Thickness = 1.5
			ghostStroke.Color = self.getSelectedTheme().ElementStroke
			ghostStroke.Transparency = 1
			ghostStroke.Parent = dragGhost
	
			local ghostLabel = Instance.new("TextLabel")
			ghostLabel.BackgroundTransparency = 1
			ghostLabel.Size = UDim2.new(1, -14, 1, 0)
			ghostLabel.Position = UDim2.new(0, 7, 0, 0)
			ghostLabel.Text = "Detach: " .. tostring(elementName)
			ghostLabel.TextSize = 12
			ghostLabel.Font = Enum.Font.Gotham
			ghostLabel.TextColor3 = self.getSelectedTheme().TextColor
			ghostLabel.TextTransparency = 1
			ghostLabel.TextXAlignment = Enum.TextXAlignment.Left
			ghostLabel.ZIndex = 251
			ghostLabel.Parent = dragGhost
	
			updateGhostPosition()
			if ghostTargetPosition then
				dragGhost.Position = UDim2.fromOffset(ghostTargetPosition.X, ghostTargetPosition.Y)
			end
	
			ghostFollowConnection = self.RunService.RenderStepped:Connect(function(deltaTime)
				if not dragGhost or not ghostTargetPosition then
					return
				end
	
				local current = Vector2.new(dragGhost.Position.X.Offset, dragGhost.Position.Y.Offset)
				local alpha = math.clamp(deltaTime * (DETACH_GHOST_FOLLOW_SPEED * 60), 0, 1)
				local nextPosition = current:Lerp(ghostTargetPosition, alpha)
				dragGhost.Position = UDim2.fromOffset(math.floor(nextPosition.X + 0.5), math.floor(nextPosition.Y + 0.5))
			end)
	
			self.TweenService:Create(dragGhost, TweenInfo.new(DETACH_POP_IN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(targetSize.X, targetSize.Y),
				BackgroundTransparency = 0.25
			}):Play()
			self.TweenService:Create(ghostStroke, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
			self.TweenService:Create(ghostLabel, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
		end
	
		local function clearMergeIndicator(instant)
			if mergeIndicatorTween then
				pcall(function() mergeIndicatorTween:Cancel() end)
				mergeIndicatorTween = nil
			end
	
			if mergeIndicator then
				local indicator = mergeIndicator
				mergeIndicator = nil
				mergeIndicatorRecord = nil
	
				if instant then
					indicator:Destroy()
					return
				end
	
				self.TweenService:Create(indicator, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1
				}):Play()
				for _, child in ipairs(indicator:GetChildren()) do
					if child:IsA("TextLabel") then
						self.TweenService:Create(child, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							TextTransparency = 1,
							BackgroundTransparency = 1
						}):Play()
					end
				end
				task.delay(0.09, function()
					if indicator and indicator.Parent then
						indicator:Destroy()
					end
				end)
			else
				mergeIndicatorRecord = nil
			end
		end
	
		local function calculateRecordInsertIndex(record, point)
			if not (record and record.content and record.content.Parent and point) then
				return nil
			end
	
			local ordered = getOrderedGuiChildren(record.content)
			local insertIndex = #ordered + 1
	
			for index, child in ipairs(ordered) do
				local childCenterY = child.AbsolutePosition.Y + (child.AbsoluteSize.Y * 0.5)
				if point.Y <= childCenterY then
					insertIndex = index
					break
				end
			end
	
			return insertIndex, ordered
		end
	
		local function getMergeSiblingNameForPreview(child)
			if not (child and child:IsA("GuiObject")) then
				return nil
			end
	
			local title = child:FindFirstChild("Title")
			if title and title:IsA("TextLabel") then
				local text = tostring(title.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
				if text ~= "" then
					return text
				end
			end
	
			return tostring(child.Name or "")
		end
	
		local function computeIndicatorY(record, insertIndex, ordered)
			local content = record.content
			if not ordered or #ordered == 0 then
				return content.AbsolutePosition.Y + 4
			end
	
			if insertIndex <= 1 then
				local first = ordered[1]
				return first.AbsolutePosition.Y - 2
			end
	
			if insertIndex > #ordered then
				local last = ordered[#ordered]
				return last.AbsolutePosition.Y + last.AbsoluteSize.Y + 2
			end
	
			local before = ordered[insertIndex - 1]
			local after = ordered[insertIndex]
			local beforeBottom = before.AbsolutePosition.Y + before.AbsoluteSize.Y
			local afterTop = after.AbsolutePosition.Y
			return (beforeBottom + afterTop) / 2
		end
	
		local function ensureMergeIndicator(record, insertIndex, ordered)
			if not (record and record.content and record.content.Parent) then
				clearMergeIndicator(true)
				return
			end
	
			-- Recycle: just update record reference, no destroy/recreate needed
			mergeIndicatorRecord = record
	
			local layer = ensureDetachedLayer()
			-- Convert screen-space AbsolutePosition to layer-local coordinates
			-- This handles IgnoreGuiInset correctly regardless of setting
			local layerOffset = layer.AbsolutePosition
			local contentX = record.content.AbsolutePosition.X - layerOffset.X
			local contentW = record.content.AbsoluteSize.X
			local indicatorW = math.max(contentW - (MERGE_INDICATOR_MARGIN * 2), 20)
			local indicatorX = contentX + MERGE_INDICATOR_MARGIN
			local indicatorY = computeIndicatorY(record, insertIndex, ordered) - layerOffset.Y - math.floor(MERGE_INDICATOR_HEIGHT / 2)
	
			if not mergeIndicator then
				mergeIndicator = Instance.new("Frame")
				mergeIndicator.Name = "MergeIndicator"
				mergeIndicator.BackgroundColor3 = getDetachCueColor()
				mergeIndicator.BackgroundTransparency = 0.05
				mergeIndicator.BorderSizePixel = 0
				mergeIndicator.Size = UDim2.fromOffset(indicatorW, MERGE_INDICATOR_HEIGHT)
				mergeIndicator.Position = UDim2.fromOffset(indicatorX, indicatorY)
				mergeIndicator.ZIndex = 210
				mergeIndicator.Parent = layer
	
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 2)
				corner.Parent = mergeIndicator
	
				local label = Instance.new("TextLabel")
				label.Name = "ReviewLabel"
				label.BackgroundColor3 = getDetachCueColor()
				label.BackgroundTransparency = 0.08
				label.BorderSizePixel = 0
				label.Size = UDim2.fromOffset(0, 16)
				label.AutomaticSize = Enum.AutomaticSize.X
				label.Position = UDim2.fromOffset(0, -18)
				label.Font = Enum.Font.GothamBold
				label.TextSize = 10
				label.TextColor3 = self.getSelectedTheme().TextColor
				label.TextTransparency = 0.05
				label.Text = ""
				label.Parent = mergeIndicator
	
				local labelPadding = Instance.new("UIPadding")
				labelPadding.PaddingLeft = UDim.new(0, 5)
				labelPadding.PaddingRight = UDim.new(0, 5)
				labelPadding.Parent = label
	
				local labelCorner = Instance.new("UICorner")
				labelCorner.CornerRadius = UDim.new(0, 4)
				labelCorner.Parent = label
			end
	
			-- Update label text
			local orderedCount = ordered and #ordered or 0
			local indexNumber = math.clamp(math.floor(tonumber(insertIndex) or 1), 1, orderedCount + 1)
			local hint = "at end"
			local targetSibling = type(ordered) == "table" and ordered[indexNumber] or nil
			if targetSibling then
				local siblingName = getMergeSiblingNameForPreview(targetSibling)
				if siblingName and siblingName ~= "" then
					hint = "before " .. siblingName
				else
					hint = "before next"
				end
			end
	
			local reviewLabel = mergeIndicator:FindFirstChild("ReviewLabel")
			if reviewLabel and reviewLabel:IsA("TextLabel") then
				reviewLabel.Text = string.format("#%d · %s", indexNumber, hint)
				reviewLabel.BackgroundColor3 = getDetachCueColor()
			end
	
			-- Update indicator color/size in case theme changed
			mergeIndicator.BackgroundColor3 = getDetachCueColor()
			mergeIndicator.Size = UDim2.fromOffset(indicatorW, MERGE_INDICATOR_HEIGHT)
	
			-- Tween to new position
			local targetPos = UDim2.fromOffset(indicatorX, indicatorY)
	
			if mergeIndicatorTween then
				pcall(function() mergeIndicatorTween:Cancel() end)
				mergeIndicatorTween = nil
			end
	
			local tween = self.TweenService:Create(mergeIndicator, TweenInfo.new(
				MERGE_INDICATOR_TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
			), { Position = targetPos })
			mergeIndicatorTween = tween
			tween.Completed:Connect(function()
				if mergeIndicatorTween == tween then
					mergeIndicatorTween = nil
				end
			end)
			tween:Play()
		end
	
		local function calculateMainInsertIndex(tabPage, point)
			if not (tabPage and tabPage.Parent and point) then
				return nil, {}
			end
			local rawChildren = tabPage:GetChildren()
			local insertionOrder = {}
			for index, child in ipairs(rawChildren) do
				insertionOrder[child] = index
			end
			local ordered = {}
			for _, child in ipairs(rawChildren) do
				if child:IsA("GuiObject") and child.Visible then
					table.insert(ordered, child)
				end
			end
			table.sort(ordered, function(a, b)
				if a.LayoutOrder ~= b.LayoutOrder then
					return a.LayoutOrder < b.LayoutOrder
				end
				return (insertionOrder[a] or 0) < (insertionOrder[b] or 0)
			end)
			local insertIndex = #ordered + 1
			for index, child in ipairs(ordered) do
				local childCenterY = child.AbsolutePosition.Y + (child.AbsoluteSize.Y * 0.5)
				if point.Y <= childCenterY then
					insertIndex = index
					break
				end
			end
			return insertIndex, ordered
		end
	
		local function computeMainIndicatorY(tabPage, insertIndex, ordered)
			if not ordered or #ordered == 0 then
				return tabPage.AbsolutePosition.Y + 4
			end
			if insertIndex <= 1 then
				return ordered[1].AbsolutePosition.Y - 2
			end
			if insertIndex > #ordered then
				local last = ordered[#ordered]
				return last.AbsolutePosition.Y + last.AbsoluteSize.Y + 2
			end
			local before = ordered[insertIndex - 1]
			local after = ordered[insertIndex]
			return (before.AbsolutePosition.Y + before.AbsoluteSize.Y + after.AbsolutePosition.Y) / 2
		end
	
		local function clearMainDropPreview(instant)
			if mainDropIndicatorTween then
				pcall(function() mainDropIndicatorTween:Cancel() end)
				mainDropIndicatorTween = nil
			end
			lastMainDropInsertIndex = nil
			if mainDropIndicator then
				local indicator = mainDropIndicator
				mainDropIndicator = nil
				if instant then
					indicator:Destroy()
					return
				end
				self.TweenService:Create(indicator, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1
				}):Play()
				for _, child in ipairs(indicator:GetChildren()) do
					if child:IsA("TextLabel") then
						self.TweenService:Create(child, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							TextTransparency = 1,
							BackgroundTransparency = 1
						}):Play()
					end
				end
				task.delay(0.09, function()
					if indicator and indicator.Parent then
						indicator:Destroy()
					end
				end)
			end
		end
	
		local function showMainDropPreview(point)
			local currentTabPage = self.Elements.UIPageLayout.CurrentPage
			if not (currentTabPage and currentTabPage.Parent) then
				clearMainDropPreview(false)
				return
			end
			local insertIndex, ordered = calculateMainInsertIndex(currentTabPage, point)
			if not insertIndex then
				clearMainDropPreview(false)
				return
			end
			lastMainDropInsertIndex = insertIndex
	
			local layer = ensureDetachedLayer()
			local layerOffset = layer.AbsolutePosition
			local contentX = currentTabPage.AbsolutePosition.X - layerOffset.X
			local contentW = currentTabPage.AbsoluteSize.X
			local indicatorW = math.max(contentW - (MERGE_INDICATOR_MARGIN * 2), 20)
			local indicatorX = contentX + MERGE_INDICATOR_MARGIN
			local indicatorY = computeMainIndicatorY(currentTabPage, insertIndex, ordered) - layerOffset.Y - math.floor(MERGE_INDICATOR_HEIGHT / 2)
	
			if not mainDropIndicator then
				mainDropIndicator = Instance.new("Frame")
				mainDropIndicator.Name = "MainDropIndicator"
				mainDropIndicator.BackgroundColor3 = getDetachCueColor()
				mainDropIndicator.BackgroundTransparency = 0.05
				mainDropIndicator.BorderSizePixel = 0
				mainDropIndicator.Size = UDim2.fromOffset(indicatorW, MERGE_INDICATOR_HEIGHT)
				mainDropIndicator.Position = UDim2.fromOffset(indicatorX, indicatorY)
				mainDropIndicator.ZIndex = 210
				mainDropIndicator.Parent = layer
	
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 2)
				corner.Parent = mainDropIndicator
	
				local label = Instance.new("TextLabel")
				label.Name = "ReviewLabel"
				label.BackgroundColor3 = getDetachCueColor()
				label.BackgroundTransparency = 0.08
				label.BorderSizePixel = 0
				label.Size = UDim2.fromOffset(0, 16)
				label.AutomaticSize = Enum.AutomaticSize.X
				label.Position = UDim2.fromOffset(0, -18)
				label.Font = Enum.Font.GothamBold
				label.TextSize = 10
				label.TextColor3 = self.getSelectedTheme().TextColor
				label.TextTransparency = 0.05
				label.Text = ""
				label.Parent = mainDropIndicator
	
				local labelPadding = Instance.new("UIPadding")
				labelPadding.PaddingLeft = UDim.new(0, 5)
				labelPadding.PaddingRight = UDim.new(0, 5)
				labelPadding.Parent = label
	
				local labelCorner = Instance.new("UICorner")
				labelCorner.CornerRadius = UDim.new(0, 4)
				labelCorner.Parent = label
			end
	
			local orderedCount = #ordered
			local indexNumber = math.clamp(insertIndex, 1, orderedCount + 1)
			local hint = "at end"
			local targetSibling = ordered[indexNumber]
			if targetSibling then
				local siblingName = getMergeSiblingNameForPreview(targetSibling)
				if siblingName and siblingName ~= "" then
					hint = "before " .. siblingName
				else
					hint = "before next"
				end
			end
	
			local reviewLabel = mainDropIndicator:FindFirstChild("ReviewLabel")
			if reviewLabel and reviewLabel:IsA("TextLabel") then
				reviewLabel.Text = string.format("Dock #%d · %s", indexNumber, hint)
				reviewLabel.BackgroundColor3 = getDetachCueColor()
			end
	
			mainDropIndicator.BackgroundColor3 = getDetachCueColor()
			mainDropIndicator.Size = UDim2.fromOffset(indicatorW, MERGE_INDICATOR_HEIGHT)
	
			local targetPos = UDim2.fromOffset(indicatorX, indicatorY)
			if mainDropIndicatorTween then
				pcall(function() mainDropIndicatorTween:Cancel() end)
				mainDropIndicatorTween = nil
			end
			local tween = self.TweenService:Create(mainDropIndicator, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos })
			mainDropIndicatorTween = tween
			tween.Completed:Connect(function()
				if mainDropIndicatorTween == tween then
					mainDropIndicatorTween = nil
				end
			end)
			tween:Play()
		end
	
		clearMergePreview = function(instant)
			local previous = mergePreviewRecord
			mergePreviewRecord = nil
			lastMergeInsertIndex = nil
			clearMergeIndicator(instant)
			clearMainDropPreview(instant)
	
			if not previous or not previous.stroke or not previous.stroke.Parent then
				return
			end
	
			local targetThickness = 1.5
			local targetColor = self.getSelectedTheme().ElementStroke
			if instant then
				previous.stroke.Thickness = targetThickness
				previous.stroke.Color = targetColor
				return
			end
	
			self.TweenService:Create(previous.stroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = targetThickness,
				Color = targetColor
			}):Play()
		end
	
		local function updateMergePreview(point)
			if not dragArmed or not point then
				clearMergePreview(false)
				return
			end
	
			-- Throttle: cap at ~20 updates/sec to avoid per-pixel recalculation
			local now = os.clock()
			if now - lastMergeUpdateTime < MERGE_UPDATE_INTERVAL then
				return
			end
			lastMergeUpdateTime = now
	
			local excludeRecord = detached and windowRecord or nil
			local targetRecord = findMergeTargetWindow(point, excludeRecord)
			if targetRecord ~= mergePreviewRecord then
				local previous = mergePreviewRecord
				mergePreviewRecord = nil
				lastMergeInsertIndex = nil
	
				if previous and previous.stroke and previous.stroke.Parent then
					self.TweenService:Create(previous.stroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Thickness = 1.5,
						Color = self.getSelectedTheme().ElementStroke
					}):Play()
				end
	
				if targetRecord and targetRecord.stroke and targetRecord.stroke.Parent then
					mergePreviewRecord = targetRecord
					self.TweenService:Create(targetRecord.stroke, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Thickness = 2.35,
						Color = self.getSelectedTheme().SliderProgress or self.getSelectedTheme().TextColor
					}):Play()
				end
			end
	
			if targetRecord then
				clearMainDropPreview(false)
				local insertIndex, ordered = calculateRecordInsertIndex(targetRecord, point)
				lastMergeInsertIndex = insertIndex
				ensureMergeIndicator(targetRecord, insertIndex, ordered)
			elseif detached and isInsideMain(point) then
				clearMergeIndicator(false)
				lastMergeInsertIndex = nil
				showMainDropPreview(point)
			else
				clearMergeIndicator(false)
				clearMainDropPreview(false)
				lastMergeInsertIndex = nil
			end
		end
	
		local function getWindowElementCount(record)
			if not (record and record.elements) then
				return 0
			end
			local count = 0
			for _ in pairs(record.elements) do
				count += 1
			end
			return count
		end
	
		local function updateWindowRecordLayout(record)
			if not (record and record.frame and record.frame.Parent) then
				return
			end
	
			local count = getWindowElementCount(record)
			if count <= 0 then
				return
			end
	
			local contentHeight = ((record.layout and record.layout.AbsoluteContentSize.Y) or 0) + 8
			local windowHeight = math.max(contentHeight + DETACH_HEADER_HEIGHT + 12, DETACH_MIN_HEIGHT)
			record.frame.Size = UDim2.fromOffset(record.width or DETACH_MIN_WIDTH, windowHeight)
			record.content.Size = UDim2.new(1, -10, 1, -(DETACH_HEADER_HEIGHT + 10))
	
			if record.titleLabel then
				if count == 1 then
					for _, entry in pairs(record.elements) do
						record.titleLabel.Text = tostring(entry.name or elementName)
						break
					end
				else
					record.titleLabel.Text = string.format("Merged (%d)", count)
				end
			end
	
			if record.dockButton then
				if count > 1 then
					record.dockButton.Size = UDim2.fromOffset(64, 20)
					record.dockButton.Position = UDim2.new(1, -70, 0.5, -10)
					record.dockButton.Text = "DockAll"
				else
					record.dockButton.Size = UDim2.fromOffset(48, 20)
					record.dockButton.Position = UDim2.new(1, -54, 0.5, -10)
					record.dockButton.Text = "Dock"
				end
			end
		end
	
		local function destroyWindowRecord(record)
			if not record then
				return
			end
	
			if record.dragCleanup then
				record.dragCleanup()
				record.dragCleanup = nil
			end
	
			if record.connections then
				for _, connection in ipairs(record.connections) do
					if connection then
						connection:Disconnect()
					end
				end
				table.clear(record.connections)
			end
	
			unregisterDetachedWindow(record)
	
			if record.frame then
				record.frame:Destroy()
			end
	
			if windowRecord == record then
				windowRecord = nil
			end
		end
	
		local function cleanupFloatingWindow()
			if floatingDragCleanup then
				floatingDragCleanup()
				floatingDragCleanup = nil
			end
	
			cleanupWindowConnections()
	
			local record = windowRecord
			if record and record.elements then
				record.elements[detacherId] = nil
				if getWindowElementCount(record) <= 0 then
					destroyWindowRecord(record)
				else
					updateWindowRecordLayout(record)
				end
			end
	
			windowRecord = nil
			destroyDetachedPlaceholder()
			floatingWindow = nil
			floatingContent = nil
			floatingWindowWidth = nil
			floatingTitleBar = nil
			floatingStroke = nil
			floatingTitleLabel = nil
			floatingDockButton = nil
		end
	
		local dockBack
		local dockBackToPosition
		local moveToWindowRecord
		local moveDetachedAt
	
		local function reorderElementInRecord(record, requestedInsertIndex)
			if not (record and record.content and record.content.Parent) then
				return false
			end
	
			local ordered = getOrderedGuiChildren(record.content)
			local currentIndex = nil
			for index, child in ipairs(ordered) do
				if child == guiObject then
					currentIndex = index
					break
				end
			end
			if not currentIndex then
				return false
			end
	
			local insertIndex = tonumber(requestedInsertIndex)
			if type(insertIndex) == "number" then
				insertIndex = math.floor(insertIndex)
			else
				insertIndex = currentIndex
			end
	
			table.remove(ordered, currentIndex)
			insertIndex = math.clamp(insertIndex, 1, #ordered + 1)
			table.insert(ordered, insertIndex, guiObject)
			normalizeOrderedGuiLayout(ordered)
			record.nextOrder = (#ordered + 1) * 10
			updateWindowRecordLayout(record)
			return true
		end
	
		local function attachToWindowRecord(record, requestedInsertIndex)
			if not (record and record.content and record.content.Parent) then
				return false
			end
	
			windowRecord = record
			floatingWindow = record.frame
			floatingContent = record.content
			floatingWindowWidth = record.width
			floatingTitleBar = record.titleBar
			floatingStroke = record.stroke
			floatingTitleLabel = record.titleLabel
			floatingDockButton = record.dockButton
			floatingDragCleanup = nil
	
			local elementHeight = math.max(guiObject.AbsoluteSize.Y, 36)
	
			guiObject.Parent = record.content
			guiObject.AnchorPoint = Vector2.zero
			guiObject.Position = UDim2.new(0, 0, 0, 0)
			guiObject.Size = UDim2.new(1, 0, 0, elementHeight)
	
			local ordered = getOrderedGuiChildren(record.content, guiObject)
			local insertIndex = tonumber(requestedInsertIndex)
			if type(insertIndex) == "number" then
				insertIndex = math.clamp(math.floor(insertIndex), 1, #ordered + 1)
			else
				insertIndex = #ordered + 1
			end
			table.insert(ordered, insertIndex, guiObject)
			normalizeOrderedGuiLayout(ordered)
			record.nextOrder = (#ordered + 1) * 10
	
			record.elements[detacherId] = {
				name = elementName,
				dock = function(skipAnimation)
					return dockBack(skipAnimation)
				end,
				mergeTo = function(targetRecord)
					return moveToWindowRecord(targetRecord)
				end
			}
	
			createDetachedPlaceholder()
	
			cleanupWindowConnections()
			table.insert(windowConnections, guiObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				updateWindowRecordLayout(record)
				updateDetachedPlaceholder()
			end))
	
			detached = true
			updateWindowRecordLayout(record)
			updateDetachedPlaceholder()
			return true
		end
	
		moveToWindowRecord = function(targetRecord, requestedInsertIndex)
			if not detached then
				return false
			end
			if not (targetRecord and targetRecord.content and targetRecord.content.Parent) then
				return false
			end
			if targetRecord == windowRecord then
				return reorderElementInRecord(targetRecord, requestedInsertIndex)
			end
	
			local previousRecord = windowRecord
			cleanupWindowConnections()
	
			if previousRecord and previousRecord.elements then
				previousRecord.elements[detacherId] = nil
			end
	
			local attached = attachToWindowRecord(targetRecord, requestedInsertIndex)
			if not attached then
				if previousRecord and previousRecord.content and previousRecord.content.Parent then
					attachToWindowRecord(previousRecord)
				end
				return false
			end
	
			if previousRecord then
				if getWindowElementCount(previousRecord) <= 0 then
					destroyWindowRecord(previousRecord)
				else
					updateWindowRecordLayout(previousRecord)
				end
			end
	
			return true
		end
	
		moveDetachedAt = function(point)
			if not detached then
				return false
			end
	
			local currentRecord = windowRecord
			if not (currentRecord and currentRecord.content and currentRecord.content.Parent) then
				return false
			end
	
			local targetRecord = findMergeTargetWindow(point, currentRecord)
	
			-- Float → Float: merge into another floating window (takes priority over self.Main)
			if targetRecord then
				local targetInsertIndex = nil
				if mergeIndicatorRecord == targetRecord and lastMergeInsertIndex then
					targetInsertIndex = lastMergeInsertIndex
				end
				if type(targetInsertIndex) ~= "number" then
					targetInsertIndex = calculateRecordInsertIndex(targetRecord, point)
				end
				return moveToWindowRecord(targetRecord, targetInsertIndex)
			end
	
			-- Float → self.Main: dock back to a specific position in the self.Main UI
			if isInsideMain(point) then
				local targetInsertIndex = lastMainDropInsertIndex
				if type(targetInsertIndex) ~= "number" then
					local currentTabPage = self.Elements.UIPageLayout.CurrentPage
					if currentTabPage and currentTabPage.Parent then
						targetInsertIndex = calculateMainInsertIndex(currentTabPage, point)
					end
				end
				if type(targetInsertIndex) == "number" then
					return dockBackToPosition(targetInsertIndex)
				end
				return dockBack()
			end
	
			-- Float → same window: reorder within current window
			if not isPointNearFrame(point, currentRecord.frame, DETACH_MERGE_DETECT_PADDING) then
				return false
			end
			local targetInsertIndex = nil
			if mergeIndicatorRecord == currentRecord and lastMergeInsertIndex then
				targetInsertIndex = lastMergeInsertIndex
			end
			if type(targetInsertIndex) ~= "number" then
				targetInsertIndex = calculateRecordInsertIndex(currentRecord, point)
			end
	
			return moveToWindowRecord(currentRecord, targetInsertIndex)
		end
	
		local function createWindowRecord(point, windowWidth, windowHeight)
			local layer = ensureDetachedLayer()
			local desiredPosition = Vector2.new(point.X - (windowWidth / 2), point.Y - (DETACH_HEADER_HEIGHT / 2))
			local clampedPosition = clampDetachedPosition(desiredPosition, Vector2.new(windowWidth, windowHeight))
			local finalPosition = Vector2.new(clampedPosition.X, clampedPosition.Y)
	
			local startSize = Vector2.new(
				math.max(math.floor(windowWidth * 0.92), 140),
				math.max(math.floor(windowHeight * 0.9), 70)
			)
			local startPosition = Vector2.new(
				finalPosition.X + math.floor((windowWidth - startSize.X) / 2),
				finalPosition.Y + 8
			)
	
			local record = {
				id = self.HttpService:GenerateGUID(false),
				frame = nil,
				titleBar = nil,
				content = nil,
				layout = nil,
				stroke = nil,
				titleLabel = nil,
				dockButton = nil,
				width = windowWidth,
				elements = {},
				nextOrder = 1,
				connections = {},
				dragCleanup = nil
			}
	
			record.frame = Instance.new("Frame")
			record.frame.Name = "Detached-" .. guiObject.Name
			record.frame.Size = UDim2.fromOffset(startSize.X, startSize.Y)
			record.frame.Position = UDim2.fromOffset(startPosition.X, startPosition.Y)
			record.frame.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
			record.frame.BackgroundTransparency = 1
			record.frame.BorderSizePixel = 0
			record.frame.ZIndex = 200
			record.frame.Parent = layer
	
			local floatingCorner = Instance.new("UICorner")
			floatingCorner.CornerRadius = UDim.new(0, 9)
			floatingCorner.Parent = record.frame
	
			record.stroke = Instance.new("UIStroke")
			record.stroke.Color = self.getSelectedTheme().ElementStroke
			record.stroke.Thickness = 1.5
			record.stroke.Transparency = 1
			record.stroke.Parent = record.frame
	
			record.titleBar = Instance.new("Frame")
			record.titleBar.Name = "TitleBar"
			record.titleBar.Size = UDim2.new(1, 0, 0, DETACH_HEADER_HEIGHT)
			record.titleBar.BackgroundColor3 = self.getSelectedTheme().ElementBackground
			record.titleBar.BackgroundTransparency = 1
			record.titleBar.BorderSizePixel = 0
			record.titleBar.ZIndex = 201
			record.titleBar.Parent = record.frame
	
			record.titleLabel = Instance.new("TextLabel")
			record.titleLabel.Name = "Title"
			record.titleLabel.BackgroundTransparency = 1
			record.titleLabel.Size = UDim2.new(1, -72, 1, 0)
			record.titleLabel.Position = UDim2.new(0, 10, 0, 0)
			record.titleLabel.Text = tostring(elementName)
			record.titleLabel.TextColor3 = self.getSelectedTheme().TextColor
			record.titleLabel.TextSize = 12
			record.titleLabel.TextTransparency = 1
			record.titleLabel.Font = Enum.Font.GothamSemibold
			record.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
			record.titleLabel.ZIndex = 202
			record.titleLabel.Parent = record.titleBar
	
			record.dockButton = Instance.new("TextButton")
			record.dockButton.Name = "DockButton"
			record.dockButton.Size = UDim2.fromOffset(48, 20)
			record.dockButton.Position = UDim2.new(1, -54, 0.5, -10)
			record.dockButton.BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover
			record.dockButton.BackgroundTransparency = 1
			record.dockButton.BorderSizePixel = 0
			record.dockButton.Text = "Dock"
			record.dockButton.TextColor3 = self.getSelectedTheme().TextColor
			record.dockButton.TextSize = 10
			record.dockButton.TextTransparency = 1
			record.dockButton.Font = Enum.Font.GothamBold
			record.dockButton.ZIndex = 202
			record.dockButton.Parent = record.titleBar
	
			local dockCorner = Instance.new("UICorner")
			dockCorner.CornerRadius = UDim.new(0, 6)
			dockCorner.Parent = record.dockButton
	
			record.content = Instance.new("Frame")
			record.content.Name = "Content"
			record.content.BackgroundTransparency = 1
			record.content.BorderSizePixel = 0
			record.content.Size = UDim2.new(1, -10, 1, -(DETACH_HEADER_HEIGHT + 10))
			record.content.Position = UDim2.fromOffset(5, DETACH_HEADER_HEIGHT + 5)
			record.content.ClipsDescendants = true
			record.content.ZIndex = 201
			record.content.Parent = record.frame
	
			record.layout = Instance.new("UIListLayout")
			record.layout.Padding = UDim.new(0, 6)
			record.layout.SortOrder = Enum.SortOrder.LayoutOrder
			record.layout.Parent = record.content
	
			record.dragCleanup = makeFloatingDraggable(record.frame, record.titleBar, function(releasePoint)
				if not (record.frame and record.frame.Parent) then
					return
				end
	
				local point = releasePoint
				if not point then
					local absPos = record.frame.AbsolutePosition
					local absSize = record.frame.AbsoluteSize
					point = Vector2.new(absPos.X + (absSize.X * 0.5), absPos.Y + (absSize.Y * 0.5))
				end
	
				local targetRecord = findMergeTargetWindow(point, record)
				if not targetRecord then
					return
				end
	
				local mergeHandlers = {}
				for _, entry in pairs(record.elements) do
					if entry and entry.mergeTo then
						table.insert(mergeHandlers, entry.mergeTo)
					end
				end
	
				for _, mergeFn in ipairs(mergeHandlers) do
					pcall(function()
						mergeFn(targetRecord)
					end)
				end
			end)
	
			table.insert(record.connections, record.dockButton.MouseButton1Click:Connect(function()
				local docks = {}
				for _, entry in pairs(record.elements) do
					if entry and entry.dock then
						table.insert(docks, entry.dock)
					end
				end
				for _, dockFn in ipairs(docks) do
					pcall(function()
						dockFn(true)
					end)
				end
			end))
	
			registerDetachedWindow(record)
	
			self.TweenService:Create(record.frame, TweenInfo.new(DETACH_POP_IN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(windowWidth, windowHeight),
				Position = UDim2.fromOffset(finalPosition.X, finalPosition.Y),
				BackgroundTransparency = 0
			}):Play()
			self.TweenService:Create(record.stroke, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
			self.TweenService:Create(record.titleBar, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
			self.TweenService:Create(record.titleLabel, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
			self.TweenService:Create(record.dockButton, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
				TextTransparency = 0
			}):Play()
	
			return record
		end
	
		dockBack = function(skipWindowAnimation)
			if not detached then
				return false
			end
	
			local targetState = originalState or rememberedState
			local targetParent = targetState and targetState.Parent
			if not targetParent or not targetParent.Parent then
				cleanupFloatingWindow()
				detached = false
				originalState = nil
				return false
			end
	
			local record = windowRecord
			local recordCountBefore = getWindowElementCount(record)
			local shouldCollapse = (not skipWindowAnimation) and record and record.frame and record.frame.Parent and recordCountBefore <= 1
	
			if shouldCollapse then
				local collapseWidth = math.max(math.floor(record.frame.Size.X.Offset * 0.94), 120)
				local collapseHeight = math.max(math.floor(record.frame.Size.Y.Offset * 0.92), 70)
				self.TweenService:Create(record.frame, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(collapseWidth, collapseHeight)
				}):Play()
				if record.stroke then
					self.TweenService:Create(record.stroke, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
				end
				if record.titleBar then
					self.TweenService:Create(record.titleBar, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
				end
				if record.titleLabel then
					self.TweenService:Create(record.titleLabel, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
				end
				if record.dockButton then
					self.TweenService:Create(record.dockButton, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						BackgroundTransparency = 1,
						TextTransparency = 1
					}):Play()
				end
				task.wait(DETACH_POP_OUT_DURATION)
			end
	
			local placeholder = detachedPlaceholder
			guiObject.Parent = targetParent
			guiObject.AnchorPoint = targetState.AnchorPoint
			guiObject.Position = targetState.Position
			guiObject.Size = targetState.Size
	
			if parentUsesLayoutOrder(targetParent) then
				local ordered = getOrderedGuiChildren(targetParent, guiObject, placeholder)
				local slotIndex = nil
	
				if placeholder and placeholder.Parent == targetParent then
					slotIndex = placeholder:GetAttribute("DetachSlotIndex")
				end
				if type(slotIndex) ~= "number" then
					slotIndex = resolveInsertIndexFromState(targetParent, targetState, ordered)
				end
	
				if type(slotIndex) == "number" then
					slotIndex = math.clamp(slotIndex, 1, #ordered + 1)
					table.insert(ordered, slotIndex, guiObject)
					normalizeOrderedGuiLayout(ordered)
				else
					guiObject.LayoutOrder = targetState.LayoutOrder
				end
			else
				guiObject.LayoutOrder = targetState.LayoutOrder
			end
	
			destroyDetachedPlaceholder()
	
			if record and record.elements then
				record.elements[detacherId] = nil
				if getWindowElementCount(record) <= 0 then
					destroyWindowRecord(record)
				else
					updateWindowRecordLayout(record)
				end
			end
	
			windowRecord = nil
			floatingWindow = nil
			floatingContent = nil
			floatingWindowWidth = nil
			floatingTitleBar = nil
			floatingStroke = nil
			floatingTitleLabel = nil
			floatingDockButton = nil
			cleanupWindowConnections()
	
			detached = false
			originalState = nil
			hoverCounter = 0
			hoverActive = false
			refreshDetachCue()
			return true
		end
	
		dockBackToPosition = function(insertIndex)
			if not detached then
				return false
			end
	
			local targetState = originalState or rememberedState
			if not targetState then
				return dockBack()
			end
	
			local currentTabPage = self.Elements.UIPageLayout.CurrentPage
			if not (currentTabPage and currentTabPage.Parent) then
				return dockBack()
			end
	
			-- Only allow position-aware dock to the original parent tab page
			local targetParent = targetState.Parent
			if targetParent ~= currentTabPage then
				return dockBack()
			end
	
			local record = windowRecord
			local recordCountBefore = getWindowElementCount(record)
			local shouldCollapse = record and record.frame and record.frame.Parent and recordCountBefore <= 1
	
			if shouldCollapse then
				local collapseWidth = math.max(math.floor(record.frame.Size.X.Offset * 0.94), 120)
				local collapseHeight = math.max(math.floor(record.frame.Size.Y.Offset * 0.92), 70)
				self.TweenService:Create(record.frame, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(collapseWidth, collapseHeight)
				}):Play()
				if record.stroke then
					self.TweenService:Create(record.stroke, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
				end
				if record.titleBar then
					self.TweenService:Create(record.titleBar, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
				end
				if record.titleLabel then
					self.TweenService:Create(record.titleLabel, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
				end
				if record.dockButton then
					self.TweenService:Create(record.dockButton, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						BackgroundTransparency = 1,
						TextTransparency = 1
					}):Play()
				end
				task.wait(DETACH_POP_OUT_DURATION)
			end
	
			local placeholder = detachedPlaceholder
			guiObject.Parent = targetParent
			guiObject.AnchorPoint = targetState.AnchorPoint
			guiObject.Position = targetState.Position
			guiObject.Size = targetState.Size
	
			if parentUsesLayoutOrder(targetParent) then
				local ordered = getOrderedGuiChildren(targetParent, guiObject, placeholder)
				local clampedIndex = math.clamp(insertIndex, 1, #ordered + 1)
				table.insert(ordered, clampedIndex, guiObject)
				normalizeOrderedGuiLayout(ordered)
			else
				guiObject.LayoutOrder = targetState.LayoutOrder
			end
	
			destroyDetachedPlaceholder()
	
			if record and record.elements then
				record.elements[detacherId] = nil
				if getWindowElementCount(record) <= 0 then
					destroyWindowRecord(record)
				else
					updateWindowRecordLayout(record)
				end
			end
	
			windowRecord = nil
			floatingWindow = nil
			floatingContent = nil
			floatingWindowWidth = nil
			floatingTitleBar = nil
			floatingStroke = nil
			floatingTitleLabel = nil
			floatingDockButton = nil
			cleanupWindowConnections()
	
			detached = false
			originalState = nil
			hoverCounter = 0
			hoverActive = false
			refreshDetachCue()
			return true
		end
	
		local function detachAt(point)
			if detached or not guiObject.Parent then
				return false
			end
	
			originalState = captureCurrentElementState()
			rememberedState = {
				Parent = originalState.Parent,
				AnchorPoint = originalState.AnchorPoint,
				Position = originalState.Position,
				Size = originalState.Size,
				LayoutOrder = originalState.LayoutOrder,
				SiblingIndex = originalState.SiblingIndex,
				PreviousSibling = originalState.PreviousSibling,
				NextSibling = originalState.NextSibling
			}
	
			if not originalState.Parent then
				return false
			end
	
			local elementHeight = math.max(guiObject.AbsoluteSize.Y, 36)
			local windowWidth = math.max(guiObject.AbsoluteSize.X + 20, DETACH_MIN_WIDTH)
			local windowHeight = math.max(elementHeight + DETACH_HEADER_HEIGHT + 12, DETACH_MIN_HEIGHT)
	
			local targetRecord = findMergeTargetWindow(point, nil)
			local targetInsertIndex = nil
			if targetRecord then
				if mergeIndicatorRecord == targetRecord and lastMergeInsertIndex then
					targetInsertIndex = lastMergeInsertIndex
				end
				if type(targetInsertIndex) ~= "number" then
					targetInsertIndex = calculateRecordInsertIndex(targetRecord, point)
				end
			end
			if not targetRecord then
				targetRecord = createWindowRecord(point, windowWidth, windowHeight)
			end
			if not targetRecord then
				return false
			end
	
			local attached = attachToWindowRecord(targetRecord, targetInsertIndex)
			if not attached then
				return false
			end
	
			if targetRecord.stroke then
				local baseThickness = targetRecord.stroke.Thickness
				targetRecord.stroke.Thickness = baseThickness + 0.9
				self.TweenService:Create(targetRecord.stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Thickness = baseThickness
				}):Play()
			end
	
			refreshDetachCue()
			return true
		end
	
		local function handleDetachHoverEnter()
			if detached then
				return
			end
			hoverCounter += 1
			hoverActive = hoverCounter > 0
			refreshDetachCue()
		end
	
		local function handleDetachHoverLeave()
			hoverCounter = math.max(hoverCounter - 1, 0)
			hoverActive = hoverCounter > 0
			if not pressing and not dragArmed then
				refreshDetachCue()
			end
		end
	
		local function handleDetachInputBegan(input)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end
			if elementType == "Input" and self.UserInputService:GetFocusedTextBox() then
				return
			end
			if pressing or dragArmed then
				return
			end
	
			ensureDetachCue()
			pressing = true
			pressInput = input
			pressToken += 1
			dragArmed = false
			pointerPosition = getInputPosition(input)
			local token = pressToken
			refreshDetachCue()
			task.spawn(runHoldCueProgress, token)
	
			task.delay(adaptiveHoldDuration, function()
				if pressToken ~= token or not pressing then
					return
				end
				dragArmed = true
				refreshDetachCue()
				createDragGhost()
			end)
		end
	
		for _, source in ipairs(dragInputSources) do
			table.insert(eventConnections, source.MouseEnter:Connect(handleDetachHoverEnter))
			table.insert(eventConnections, source.MouseLeave:Connect(handleDetachHoverLeave))
			table.insert(eventConnections, source.InputBegan:Connect(handleDetachInputBegan))
		end
	
		-- Use shared global dispatcher instead of per-element InputChanged/InputEnded
		registerSharedInput(detacherId, function(input) -- InputChanged
			if not pressing or not pressInput then
				return
			end
	
			local matchesTouch = input == pressInput
			local matchesMouse = pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
			if not matchesTouch and not matchesMouse then
				return
			end
	
			pointerPosition = getInputPosition(input)
			if dragArmed then
				updateGhostPosition()
				updateMergePreview(pointerPosition)
			end
		end, function(input) -- InputEnded
			if not pressInput then
				return
			end
	
			local sameTouch = input == pressInput
			local mouseEnded = pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
			if not sameTouch and not mouseEnded then
				return
			end
	
			pressing = false
			pressInput = nil
			pressToken += 1
	
			-- Snapshot cached insert indices before clearMergePreview wipes them
			local cachedMainDropIndex = lastMainDropInsertIndex
			local cachedMergeInsertIndex = lastMergeInsertIndex
			clearMergePreview(false)
	
			local dropPoint = pointerPosition or self.UserInputService:GetMouseLocation()
			if dragArmed then
				dragArmed = false
				destroyDragGhost()
				if detached then
					if dropPoint then
						-- Restore cached index so moveDetachedAt can use the indicator's value
						lastMainDropInsertIndex = cachedMainDropIndex
						lastMergeInsertIndex = cachedMergeInsertIndex
						if not moveDetachedAt(dropPoint) then
							refreshDetachCue()
						end
						lastMainDropInsertIndex = nil
						lastMergeInsertIndex = nil
					else
						refreshDetachCue()
					end
				else
					local hasMergeTarget = dropPoint and findMergeTargetWindow(dropPoint, nil) ~= nil
					if dropPoint and (isOutsideMain(dropPoint) or hasMergeTarget) then
						if not detachAt(dropPoint) then
							refreshDetachCue()
						end
					else
						refreshDetachCue()
					end
				end
			else
				destroyDragGhost()
				refreshDetachCue()
			end
		end)
	
		local function fullCleanup()
			unregisterSharedInput(detacherId)
			destroyDragGhost(true)
			cleanupFloatingWindow()
			cleanupDetachCue()
			for _, connection in ipairs(eventConnections) do
				if connection then
					connection:Disconnect()
				end
			end
			table.clear(eventConnections)
		end
	
		local function connectIfAvailable(signalName, callback)
			local ok, signal = pcall(function()
				return guiObject[signalName]
			end)
			if ok and signal and signal.Connect then
				table.insert(eventConnections, signal:Connect(callback))
			end
		end

		-- Cleanup when guiObject is destroyed
		connectIfAvailable("Destroying", fullCleanup)
	
		-- Safety net: cleanup if element leaves the DataModel without being destroyed
		-- (e.g. parent set to nil, or ancestor removed)
		connectIfAvailable("AncestryChanged", function()
			if not guiObject:IsDescendantOf(game) then
				task.defer(function()
					-- Re-check after defer in case of rapid reparent
					if not guiObject:IsDescendantOf(game) then
						fullCleanup()
					end
				end)
			end
		end)
	
		return {
			Detach = function(position)
				local pos = position or self.UserInputService:GetMouseLocation()
				return detachAt(pos)
			end,
			Dock = function()
				return dockBack()
			end,
			GetRememberedState = function()
				if not rememberedState then
					return nil
				end
				return {
					Parent = rememberedState.Parent,
					AnchorPoint = rememberedState.AnchorPoint,
					Position = rememberedState.Position,
					Size = rememberedState.Size,
					LayoutOrder = rememberedState.LayoutOrder,
					SiblingIndex = rememberedState.SiblingIndex,
					PreviousSibling = rememberedState.PreviousSibling,
					NextSibling = rememberedState.NextSibling
				}
			end,
			IsDetached = function()
				return detached
			end,
			Destroy = fullCleanup
		}
	end

	-- Export main function
	self.makeElementDetachable = createElementDetacher
	
	return self
end

return DragModule
