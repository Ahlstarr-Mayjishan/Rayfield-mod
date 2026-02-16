-- Rayfield Tab Split Module
-- Handles long-hold tab split into secondary panels (non-float detached windows)

local TabSplitModule = {}

function TabSplitModule.init(ctx)
	local self = {}

	self.UserInputService = ctx.UserInputService
	self.RunService = ctx.RunService
	self.TweenService = ctx.TweenService
	self.HttpService = ctx.HttpService
	self.Rayfield = ctx.Rayfield
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.TabList = ctx.TabList
	self.Elements = ctx.Elements
	self.getSelectedTheme = ctx.getSelectedTheme
	self.rayfieldDestroyed = ctx.rayfieldDestroyed
	self.useMobileSizing = ctx.useMobileSizing
	self.Notify = ctx.Notify
	self.getBlockedState = ctx.getBlockedState

	local enabled = ctx.enabled ~= false
	local holdDuration = tonumber(ctx.holdDuration) or 3
	if holdDuration < 0.5 then
		holdDuration = 0.5
	end

	local allowSettingsSplit = ctx.allowSettingsSplit == true
	local maxSplitTabs = tonumber(ctx.maxSplitTabs)
	if maxSplitTabs and maxSplitTabs < 1 then
		maxSplitTabs = nil
	end

	local splitRoot = nil
	local splitPanels = {}
	local tabToPanel = {}
	local panelOrder = {}
	local tabRecords = {}
	local tabGestureCleanup = {}
	local splitHidden = false
	local splitMinimized = false
	local splitIndex = 0

	local sharedInputChanged = {}
	local sharedInputEnded = {}
	local sharedInputConnections = nil
	local rootConnections = {}
	local tabZIndexState = setmetatable({}, { __mode = "k" })

	local DRAG_THRESHOLD = 4
	local PANEL_MARGIN = 8
	local TAB_GHOST_FOLLOW_SPEED = 0.24

	local function isDestroyed()
		return self.rayfieldDestroyed and self.rayfieldDestroyed()
	end

	local function isBlocked()
		if isDestroyed() then
			return true
		end
		if type(self.getBlockedState) == "function" then
			local ok, result = pcall(self.getBlockedState)
			if ok and result then
				return true
			end
		end
		return false
	end

	local function safeNotify(data)
		if type(self.Notify) == "function" then
			pcall(self.Notify, data)
		end
	end

	local function ensureSharedInput()
		if sharedInputConnections then
			return
		end

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
			end)
		}
	end

	local function registerSharedInput(id, onChanged, onEnded)
		ensureSharedInput()
		if type(onChanged) == "function" then
			sharedInputChanged[id] = onChanged
		end
		if type(onEnded) == "function" then
			sharedInputEnded[id] = onEnded
		end
	end

	local function unregisterSharedInput(id)
		sharedInputChanged[id] = nil
		sharedInputEnded[id] = nil
	end

	local function disconnectSharedInput()
		table.clear(sharedInputChanged)
		table.clear(sharedInputEnded)
		if sharedInputConnections then
			for _, connection in ipairs(sharedInputConnections) do
				if connection then
					connection:Disconnect()
				end
			end
			sharedInputConnections = nil
		end
	end

	local function getInputPosition(input)
		if input and input.Position then
			return Vector2.new(input.Position.X, input.Position.Y)
		end
		return self.UserInputService:GetMouseLocation()
	end

	local function isPointInside(guiObject, point, padding)
		if not (guiObject and guiObject.Parent and point) then
			return false
		end

		local pad = padding or 0
		local absPos = guiObject.AbsolutePosition
		local absSize = guiObject.AbsoluteSize
		return point.X >= (absPos.X - pad)
			and point.X <= (absPos.X + absSize.X + pad)
			and point.Y >= (absPos.Y - pad)
			and point.Y <= (absPos.Y + absSize.Y + pad)
	end

	local function isPointInsideMain(point)
		return isPointInside(self.Main, point, 0)
	end

	local function isPointInsideTabList(point)
		return isPointInside(self.TabList, point, 10)
	end

	local function clampPositionToViewport(root, desiredPosition, panelSize)
		local viewport = root.AbsoluteSize
		local clampedX = math.clamp(
			desiredPosition.X,
			PANEL_MARGIN,
			math.max(PANEL_MARGIN, viewport.X - panelSize.X - PANEL_MARGIN)
		)
		local clampedY = math.clamp(
			desiredPosition.Y,
			PANEL_MARGIN,
			math.max(PANEL_MARGIN, viewport.Y - panelSize.Y - PANEL_MARGIN)
		)
		return Vector2.new(clampedX, clampedY)
	end

	local function hasZIndex(guiObject)
		return pcall(function()
			local _ = guiObject.ZIndex
		end)
	end

	local function getOriginalZState(tabRecord)
		local state = tabZIndexState[tabRecord]
		if state then
			return state
		end

		state = {
			Original = setmetatable({}, { __mode = "k" }),
			DescendantConn = nil,
			LastBaseZ = 200,
			LastAppliedBase = nil
		}
		tabZIndexState[tabRecord] = state
		return state
	end

	local function captureOriginalZIndex(tabRecord)
		if not (tabRecord and tabRecord.TabPage) then
			return
		end

		local state = getOriginalZState(tabRecord)
		local objects = { tabRecord.TabPage }
		for _, descendant in ipairs(tabRecord.TabPage:GetDescendants()) do
			table.insert(objects, descendant)
		end

		for _, object in ipairs(objects) do
			if hasZIndex(object) and state.Original[object] == nil then
				state.Original[object] = object.ZIndex
			end
		end
	end

	local function applySplitZIndex(tabRecord, zBase)
		if not (tabRecord and tabRecord.TabPage) then
			return
		end

		local state = getOriginalZState(tabRecord)
		local nextBase = zBase or state.LastBaseZ or 200
		state.LastBaseZ = nextBase

		captureOriginalZIndex(tabRecord)

		if state.LastAppliedBase ~= nextBase then
			for object, original in pairs(state.Original) do
				if object and object.Parent and hasZIndex(object) then
					object.ZIndex = nextBase + original
				end
			end
			state.LastAppliedBase = nextBase
		end

		if not state.DescendantConn then
			state.DescendantConn = tabRecord.TabPage.DescendantAdded:Connect(function(descendant)
				if not tabRecord.IsSplit then
					return
				end
				if not hasZIndex(descendant) then
					return
				end
				if state.Original[descendant] == nil then
					state.Original[descendant] = descendant.ZIndex
				end
				descendant.ZIndex = state.LastBaseZ + state.Original[descendant]
			end)
		end
	end

	local function restoreOriginalZIndex(tabRecord)
		local state = tabZIndexState[tabRecord]
		if not state then
			return
		end

		if state.DescendantConn then
			state.DescendantConn:Disconnect()
			state.DescendantConn = nil
		end

		for object, original in pairs(state.Original) do
			if object and object.Parent and hasZIndex(object) then
				object.ZIndex = original
			end
		end

		tabZIndexState[tabRecord] = nil
	end

	local function getPanelSize(root)
		local viewport = root.AbsoluteSize
		local mainSize = self.Main.AbsoluteSize

		local panelWidth = math.clamp(math.floor(mainSize.X * 0.68), 250, 420)
		local panelHeight = math.clamp(math.floor(mainSize.Y), 180, math.max(180, viewport.Y - 12))
		return Vector2.new(panelWidth, panelHeight)
	end

	local function setPanelLayer(panelData, baseZ)
		panelData.LayerZ = baseZ
		panelData.Frame.ZIndex = baseZ
		panelData.Header.ZIndex = baseZ + 1
		panelData.Content.ZIndex = baseZ + 1
		panelData.Title.ZIndex = baseZ + 2
		panelData.DockButton.ZIndex = baseZ + 2
		applySplitZIndex(panelData.TabRecord, baseZ + 2)
	end

	local setPanelHoverState
	local applyPanelTheme

	local function ensureSplitRoot()
		if splitRoot and splitRoot.Parent then
			return splitRoot
		end

		splitRoot = Instance.new("Frame")
		splitRoot.Name = "TabSplitRoot"
		splitRoot.BackgroundTransparency = 1
		splitRoot.BorderSizePixel = 0
		splitRoot.Size = UDim2.fromScale(1, 1)
		splitRoot.ZIndex = 180
		splitRoot.Visible = (not splitHidden) and (not splitMinimized)
		splitRoot.Parent = self.Rayfield

		table.insert(rootConnections, self.Main:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			self.layoutPanels()
		end))
		table.insert(rootConnections, self.Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self.layoutPanels()
		end))
		table.insert(rootConnections, self.Rayfield:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self.layoutPanels()
		end))
		table.insert(rootConnections, self.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			for _, panelData in pairs(splitPanels) do
				if panelData then
					applyPanelTheme(panelData)
				end
			end
		end))

		return splitRoot
	end

	local function refreshRootVisibility()
		if splitRoot and splitRoot.Parent then
			splitRoot.Visible = (not splitHidden) and (not splitMinimized)
		end
	end

	if enabled then
		task.defer(function()
			if isDestroyed() then
				return
			end
			ensureSplitRoot()
			refreshRootVisibility()
		end)
	end

	local function createHoldIndicator(parent)
		if not (parent and parent.Parent) then
			return nil, nil
		end

		local theme = self.getSelectedTheme and self.getSelectedTheme()
		local indicator = Instance.new("Frame")
		indicator.Name = "SplitHoldIndicator"
		indicator.BackgroundColor3 = (theme and theme.SliderProgress) or Color3.fromRGB(100, 170, 255)
		indicator.BackgroundTransparency = 0.1
		indicator.BorderSizePixel = 0
		indicator.Size = UDim2.new(0, 0, 0, 2)
		indicator.Position = UDim2.new(0, 0, 1, -2)
		indicator.ZIndex = parent.ZIndex + 10
		indicator.Parent = parent

		local tween = self.TweenService:Create(indicator, TweenInfo.new(holdDuration, Enum.EasingStyle.Linear), {
			Size = UDim2.new(1, 0, 0, 2)
		})
		tween:Play()
		return indicator, tween
	end

	local function clearHoldIndicator(indicator, tween)
		if tween then
			pcall(function()
				tween:Cancel()
			end)
		end
		if indicator and indicator.Parent then
			self.TweenService:Create(indicator, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1
			}):Play()
			task.delay(0.09, function()
				if indicator and indicator.Parent then
					indicator:Destroy()
				end
			end)
		end
	end

	local function createGhost(text, position)
		local root = ensureSplitRoot()
		local theme = self.getSelectedTheme and self.getSelectedTheme()

		local ghost = Instance.new("Frame")
		ghost.Name = "TabSplitGhost"
		ghost.BackgroundColor3 = (theme and theme.ElementBackground) or Color3.fromRGB(35, 35, 35)
		ghost.BackgroundTransparency = 0.18
		ghost.BorderSizePixel = 0
		ghost.Size = UDim2.fromOffset(170, 28)
		ghost.Position = UDim2.fromOffset(position.X - 85, position.Y - 14)
		ghost.ZIndex = 240
		ghost.Parent = root

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = ghost

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.2
		stroke.Transparency = 0.2
		stroke.Color = (theme and theme.ElementStroke) or Color3.fromRGB(90, 90, 90)
		stroke.Parent = ghost

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -10, 1, 0)
		label.Position = UDim2.new(0, 5, 0, 0)
		label.Text = text
		label.Font = Enum.Font.GothamSemibold
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = (theme and theme.TextColor) or Color3.fromRGB(255, 255, 255)
		label.ZIndex = ghost.ZIndex + 1
		label.Parent = ghost

		return ghost
	end

	local function updateGhostPosition(ghost, point)
		if ghost and ghost.Parent and point then
			ghost.Position = UDim2.fromOffset(point.X - math.floor(ghost.AbsoluteSize.X / 2), point.Y - math.floor(ghost.AbsoluteSize.Y / 2))
		end
	end

	local function clearGhost(ghost)
		if ghost and ghost.Parent then
			self.TweenService:Create(ghost, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1
			}):Play()
			task.delay(0.09, function()
				if ghost and ghost.Parent then
					ghost:Destroy()
				end
			end)
		end
	end

	if enabled then
		task.defer(function()
			if isDestroyed() then
				return
			end
			local warmGhost = createGhost("", Vector2.new(-9999, -9999))
			if warmGhost then
				warmGhost:Destroy()
			end
		end)
	end

	local function getSplitPanelCount()
		return #panelOrder
	end

	local function canSplitTab(tabRecord)
		if not enabled then
			return false, "Tab split is disabled for this window."
		end
		if isBlocked() then
			return false, "Tab split is temporarily blocked while UI is busy."
		end
		if not tabRecord then
			return false, "Invalid tab."
		end
		if tabRecord.IsSplit then
			return false, "This tab is already split."
		end
		if tabRecord.Name == "Rayfield Settings" and tabRecord.Ext and not allowSettingsSplit then
			return false, "Splitting Rayfield Settings is disabled."
		end
		if maxSplitTabs and getSplitPanelCount() >= maxSplitTabs then
			return false, "Reached max split tabs: " .. tostring(maxSplitTabs)
		end
		local dockedCount = 0
		for _, record in ipairs(tabRecords) do
			if not record.IsSplit and record.TabPage and record.TabPage.Parent == self.Elements then
				dockedCount += 1
			end
		end
		if dockedCount <= 1 then
			return false, "At least one tab must remain in main UI."
		end
		return true
	end

	local function chooseFallbackTab(excluded)
		for _, record in ipairs(tabRecords) do
			if record ~= excluded and not record.IsSplit and record.TabPage and record.TabPage.Parent == self.Elements then
				return record
			end
		end
		return nil
	end

	setPanelHoverState = function(panelData, active, instant)
		if not (panelData and panelData.Frame and panelData.Frame.Parent) then
			return
		end

		panelData.HoverActive = active and true or false

		local theme = self.getSelectedTheme and self.getSelectedTheme()
		local accent = (theme and theme.SliderProgress) or Color3.fromRGB(112, 189, 255)
		local strokeColor = (theme and theme.ElementStroke) or Color3.fromRGB(85, 85, 85)

		if panelData.GlowStroke then
			panelData.GlowStroke.Color = accent
		end
		if panelData.Stroke then
			panelData.Stroke.Color = active and accent:Lerp(strokeColor, 0.35) or strokeColor
		end

		local duration = instant and 0 or 0.12
		if panelData.Stroke then
			self.TweenService:Create(panelData.Stroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = active and 1.7 or 1.1,
				Transparency = active and 0.05 or 0.25
			}):Play()
		end
		if panelData.GlowStroke then
			self.TweenService:Create(panelData.GlowStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = active and 4.6 or 1.2,
				Transparency = active and 0.35 or 1
			}):Play()
		end
	end

	applyPanelTheme = function(panelData)
		if not panelData then
			return
		end
		local theme = self.getSelectedTheme and self.getSelectedTheme()
		if not theme then
			return
		end

		panelData.Frame.BackgroundColor3 = theme.SecondaryElementBackground or panelData.Frame.BackgroundColor3
		panelData.Header.BackgroundColor3 = theme.Topbar or panelData.Header.BackgroundColor3
		panelData.Title.TextColor3 = theme.TextColor or panelData.Title.TextColor3
		panelData.DockButton.BackgroundColor3 = theme.ElementBackgroundHover or panelData.DockButton.BackgroundColor3
		panelData.DockButton.TextColor3 = theme.TextColor or panelData.DockButton.TextColor3
		setPanelHoverState(panelData, panelData.HoverActive or panelData.Dragging, true)
	end

	local function removePanelRecord(panelId)
		for i = #panelOrder, 1, -1 do
			if panelOrder[i] == panelId then
				table.remove(panelOrder, i)
				break
			end
		end
		splitPanels[panelId] = nil
	end

	local function cleanupPanel(panelData)
		if not panelData then
			return
		end

		if panelData.InputId then
			unregisterSharedInput(panelData.InputId)
		end

		if panelData.Cleanup then
			for _, cleanupFn in ipairs(panelData.Cleanup) do
				pcall(cleanupFn)
			end
			table.clear(panelData.Cleanup)
		end

		if panelData.Frame and panelData.Frame.Parent then
			panelData.Frame:Destroy()
		end
	end

	local function bringPanelToFront(panelData)
		if not panelData then
			return
		end

		for i = #panelOrder, 1, -1 do
			if panelOrder[i] == panelData.Id then
				table.remove(panelOrder, i)
				break
			end
		end
		table.insert(panelOrder, panelData.Id)
		self.layoutPanels()
	end

	local function attachPanelDrag(panelData)
		local state = {
			pressing = false,
			dragging = false,
			pressInput = nil,
			startPointer = nil,
			startPosition = nil,
			pointer = nil
		}

		local function resetState()
			state.pressing = false
			state.dragging = false
			state.pressInput = nil
			state.startPointer = nil
			state.startPosition = nil
			state.pointer = nil
			panelData.Dragging = false
			setPanelHoverState(panelData, panelData.HoverActive, false)
		end

		local function beginPress(input)
			if isBlocked() or not (panelData.Frame and panelData.Frame.Parent) then
				return
			end

			local pointer = getInputPosition(input)
			if isPointInside(panelData.DockButton, pointer, 0) then
				return
			end

			state.pressing = true
			state.dragging = false
			state.pressInput = input
			state.startPointer = pointer
			state.pointer = pointer
			if panelData.ManualPosition then
				state.startPosition = panelData.ManualPosition
			else
				state.startPosition = Vector2.new(panelData.Frame.AbsolutePosition.X, panelData.Frame.AbsolutePosition.Y)
			end

			bringPanelToFront(panelData)
		end

		local function finishPress(input)
			if not state.pressInput then
				return
			end

			local sameTouch = input == state.pressInput
			local mouseEnded = state.pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
			if not sameTouch and not mouseEnded then
				return
			end

			local wasDragging = state.dragging
			local dropPoint = state.pointer or getInputPosition(input)
			resetState()

			if not wasDragging then
				return
			end

			if isPointInsideTabList(dropPoint) then
				self.dockTab(panelData.TabRecord)
				return
			end

			local root = ensureSplitRoot()
			local panelSize = getPanelSize(root)
			local currentPosition = panelData.ManualPosition or Vector2.new(panelData.Frame.AbsolutePosition.X, panelData.Frame.AbsolutePosition.Y)
			local clamped = clampPositionToViewport(root, currentPosition, panelSize)
			panelData.ManualPosition = clamped
			panelData.Frame.Position = UDim2.fromOffset(clamped.X, clamped.Y)
			self.layoutPanels()
		end

		table.insert(panelData.Cleanup, panelData.Header.InputBegan:Connect(function(input)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end
			beginPress(input)
		end))

		registerSharedInput(panelData.InputId, function(input)
			if not state.pressing or not state.pressInput then
				return
			end

			local sameTouch = input == state.pressInput
			local mouseMove = state.pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
			if not sameTouch and not mouseMove then
				return
			end

			state.pointer = getInputPosition(input)
			local delta = state.pointer - state.startPointer
			if not state.dragging and delta.Magnitude >= DRAG_THRESHOLD then
				state.dragging = true
				panelData.Dragging = true
				setPanelHoverState(panelData, true, false)
			end

			if state.dragging then
				local root = ensureSplitRoot()
				local panelSize = getPanelSize(root)
				local desired = state.startPosition + delta
				local clamped = clampPositionToViewport(root, desired, panelSize)
				panelData.ManualPosition = clamped
				panelData.Frame.Position = UDim2.fromOffset(clamped.X, clamped.Y)
			end
		end, finishPress)

		table.insert(panelData.Cleanup, resetState)
	end

	local function createPanelShell(tabRecord)
		local root = ensureSplitRoot()
		splitIndex += 1
		local panelId = self.HttpService:GenerateGUID(false) .. "-" .. tostring(splitIndex)
		local theme = self.getSelectedTheme and self.getSelectedTheme()

		local panel = Instance.new("Frame")
		panel.Name = "TabSplitPanel-" .. tostring(tabRecord.Name)
		panel.BackgroundColor3 = (theme and theme.SecondaryElementBackground) or Color3.fromRGB(35, 35, 35)
		panel.BorderSizePixel = 0
		panel.ZIndex = 190
		panel.Parent = root

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 9)
		corner.Parent = panel

		local stroke = Instance.new("UIStroke")
		stroke.Color = (theme and theme.ElementStroke) or Color3.fromRGB(80, 80, 80)
		stroke.Thickness = 1.1
		stroke.Transparency = 0.25
		stroke.Parent = panel

		local glowStroke = Instance.new("UIStroke")
		glowStroke.Color = (theme and theme.SliderProgress) or Color3.fromRGB(112, 189, 255)
		glowStroke.Thickness = 1.2
		glowStroke.Transparency = 1
		glowStroke.Parent = panel

		local header = Instance.new("Frame")
		header.Name = "Header"
		header.BackgroundColor3 = (theme and theme.Topbar) or Color3.fromRGB(25, 25, 25)
		header.BorderSizePixel = 0
		header.Size = UDim2.new(1, 0, 0, 34)
		header.ZIndex = panel.ZIndex + 1
		header.Parent = panel
		header.Active = true

		local headerCorner = Instance.new("UICorner")
		headerCorner.CornerRadius = UDim.new(0, 9)
		headerCorner.Parent = header

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, -96, 1, 0)
		title.Position = UDim2.new(0, 10, 0, 0)
		title.Text = tostring(tabRecord.Name)
		title.TextColor3 = (theme and theme.TextColor) or Color3.fromRGB(255, 255, 255)
		title.Font = Enum.Font.GothamSemibold
		title.TextSize = 12
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = header.ZIndex + 1
		title.Parent = header

		local dockButton = Instance.new("TextButton")
		dockButton.Name = "Dock"
		dockButton.Size = UDim2.fromOffset(64, 22)
		dockButton.Position = UDim2.new(1, -74, 0.5, -11)
		dockButton.BackgroundColor3 = (theme and theme.ElementBackgroundHover) or Color3.fromRGB(55, 55, 55)
		dockButton.BorderSizePixel = 0
		dockButton.Text = "Dock"
		dockButton.TextColor3 = (theme and theme.TextColor) or Color3.fromRGB(255, 255, 255)
		dockButton.Font = Enum.Font.GothamBold
		dockButton.TextSize = 10
		dockButton.ZIndex = header.ZIndex + 1
		dockButton.Parent = header

		local dockCorner = Instance.new("UICorner")
		dockCorner.CornerRadius = UDim.new(0, 6)
		dockCorner.Parent = dockButton

		local content = Instance.new("Frame")
		content.Name = "Content"
		content.BackgroundTransparency = 1
		content.BorderSizePixel = 0
		content.Position = UDim2.fromOffset(0, 34)
		content.Size = UDim2.new(1, 0, 1, -34)
		content.ClipsDescendants = true
		content.Active = true
		content.ZIndex = panel.ZIndex + 1
		content.Parent = panel

		local panelData = {
			Id = panelId,
			Frame = panel,
			Header = header,
			Title = title,
			DockButton = dockButton,
			Content = content,
			Stroke = stroke,
			GlowStroke = glowStroke,
			TabRecord = tabRecord,
			Cleanup = {},
			InputId = self.HttpService:GenerateGUID(false),
			ManualPosition = nil,
			Dragging = false,
			HoverRefs = 0,
			HoverActive = false,
			LayerZ = 190
		}

		local function markHover(delta)
			panelData.HoverRefs = math.max(0, panelData.HoverRefs + delta)
			panelData.HoverActive = panelData.HoverRefs > 0
			if not panelData.Dragging then
				setPanelHoverState(panelData, panelData.HoverActive, false)
			end
		end

		table.insert(panelData.Cleanup, panel.MouseEnter:Connect(function()
			markHover(1)
		end))
		table.insert(panelData.Cleanup, panel.MouseLeave:Connect(function()
			markHover(-1)
		end))
		table.insert(panelData.Cleanup, header.MouseEnter:Connect(function()
			markHover(1)
		end))
		table.insert(panelData.Cleanup, header.MouseLeave:Connect(function()
			markHover(-1)
		end))

		table.insert(panelData.Cleanup, dockButton.MouseButton1Click:Connect(function()
			self.dockTab(tabRecord)
		end))

		applyPanelTheme(panelData)
		attachPanelDrag(panelData)
		return panelData
	end

	function self.layoutPanels()
		if isDestroyed() then
			return
		end

		local root = ensureSplitRoot()
		if not root or not root.Parent then
			return
		end

		if #panelOrder <= 0 then
			return
		end

		local panelSize = getPanelSize(root)
		local mainPos = self.Main.AbsolutePosition
		local mainSize = self.Main.AbsoluteSize

		local rightX = mainPos.X + mainSize.X + 16
		local leftX = mainPos.X - panelSize.X - 16
		local baseX = rightX
		if baseX + panelSize.X > root.AbsoluteSize.X - PANEL_MARGIN then
			baseX = math.max(PANEL_MARGIN, leftX)
		end

		for index, panelId in ipairs(panelOrder) do
			local panelData = splitPanels[panelId]
			if panelData and panelData.Frame and panelData.Frame.Parent then
				local baseZ = 190 + ((index - 1) * 8)
				setPanelLayer(panelData, baseZ)
				panelData.Frame.Size = UDim2.fromOffset(panelSize.X, panelSize.Y)

				if not panelData.Dragging then
					if panelData.ManualPosition then
						local clampedManual = clampPositionToViewport(root, panelData.ManualPosition, panelSize)
						panelData.ManualPosition = clampedManual
						panelData.Frame.Position = UDim2.fromOffset(clampedManual.X, clampedManual.Y)
					else
						local step = index - 1
						local targetX = math.clamp(baseX + ((step % 2) * 18), PANEL_MARGIN, math.max(PANEL_MARGIN, root.AbsoluteSize.X - panelSize.X - PANEL_MARGIN))
						local targetY = math.clamp(mainPos.Y + (step * 26), PANEL_MARGIN, math.max(PANEL_MARGIN, root.AbsoluteSize.Y - panelSize.Y - PANEL_MARGIN))
						self.TweenService:Create(panelData.Frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Position = UDim2.fromOffset(targetX, targetY)
						}):Play()
					end
				end
			end
		end
	end

	function self.splitTab(tabRecord, dropPoint)
		local allowed, reason = canSplitTab(tabRecord)
		if not allowed then
			if reason then
				safeNotify({
					Title = "Tab Split",
					Content = reason,
					Duration = 3
				})
			end
			return false
		end

		if not (tabRecord.TabPage and tabRecord.TabButton and tabRecord.TabPage.Parent) then
			return false
		end

		if isPointInsideMain(dropPoint) then
			return false
		end

		if self.Elements.UIPageLayout.CurrentPage == tabRecord.TabPage then
			local fallback = chooseFallbackTab(tabRecord)
			if fallback and type(fallback.Activate) == "function" then
				fallback.Activate(true)
			end
		end

		local panelData = createPanelShell(tabRecord)
		splitPanels[panelData.Id] = panelData
		table.insert(panelOrder, panelData.Id)
		tabToPanel[tabRecord] = panelData.Id

		local root = ensureSplitRoot()
		local panelSize = getPanelSize(root)
		local splitDropPoint = dropPoint or getInputPosition()
		local desiredStart = Vector2.new(
			splitDropPoint.X - math.floor(panelSize.X * 0.5),
			splitDropPoint.Y - 14
		)
		panelData.ManualPosition = clampPositionToViewport(root, desiredStart, panelSize)
		panelData.Frame.Position = UDim2.fromOffset(panelData.ManualPosition.X, panelData.ManualPosition.Y)

		tabRecord.IsSplit = true
		tabRecord.SplitPanelId = panelData.Id

		tabRecord.TabButton.Visible = false
		local interact = tabRecord.TabButton:FindFirstChild("Interact")
		if interact then
			interact.Visible = false
		end

		tabRecord.TabPage.Parent = panelData.Content
		tabRecord.TabPage.AnchorPoint = Vector2.zero
		tabRecord.TabPage.Position = UDim2.new(0, 0, 0, 0)
		tabRecord.TabPage.Size = UDim2.new(1, 0, 1, 0)
		tabRecord.TabPage.Visible = true
		tabRecord.TabPage.Active = true
		panelData.Content.Active = true
		panelData.Content.ClipsDescendants = true

		captureOriginalZIndex(tabRecord)
		bringPanelToFront(panelData)
		self.layoutPanels()
		refreshRootVisibility()
		self.syncMinimized(splitMinimized)

		return true
	end

	function self.dockTab(tabRecord)
		if not tabRecord then
			return false
		end

		local panelId = tabToPanel[tabRecord] or tabRecord.SplitPanelId
		if not panelId then
			return false
		end

		local panelData = splitPanels[panelId]
		if not panelData then
			tabRecord.IsSplit = false
			tabRecord.SplitPanelId = nil
			tabToPanel[tabRecord] = nil
			restoreOriginalZIndex(tabRecord)
			return false
		end

		if tabRecord.TabPage then
			tabRecord.TabPage.Parent = self.Elements
			tabRecord.TabPage.AnchorPoint = Vector2.zero
			tabRecord.TabPage.Position = UDim2.new(0, 0, 0, 0)
			tabRecord.TabPage.Size = UDim2.new(1, 0, 1, 0)
			tabRecord.TabPage.Visible = true
			tabRecord.TabPage.Active = true
		end

		restoreOriginalZIndex(tabRecord)

		if tabRecord.TabButton then
			local shouldBeVisible = tabRecord.DefaultVisible
			if shouldBeVisible == nil then
				shouldBeVisible = true
			end
			tabRecord.TabButton.Visible = shouldBeVisible
			local interact = tabRecord.TabButton:FindFirstChild("Interact")
			if interact then
				interact.Visible = shouldBeVisible
			end
		end

		tabRecord.IsSplit = false
		tabRecord.SplitPanelId = nil
		tabToPanel[tabRecord] = nil

		removePanelRecord(panelId)
		cleanupPanel(panelData)

		if type(tabRecord.Activate) == "function" then
			tabRecord.Activate(true)
		end

		self.layoutPanels()
		return true
	end

	local function unregisterTab(tabRecord)
		local cleanup = tabGestureCleanup[tabRecord]
		if not cleanup then
			return
		end

		if cleanup.InputId then
			unregisterSharedInput(cleanup.InputId)
		end
		if cleanup.Connections then
			for _, connection in ipairs(cleanup.Connections) do
				if connection then
					connection:Disconnect()
				end
			end
			table.clear(cleanup.Connections)
		end
		if cleanup.ClearVisuals then
			pcall(cleanup.ClearVisuals)
		end

		tabGestureCleanup[tabRecord] = nil
		for i = #tabRecords, 1, -1 do
			if tabRecords[i] == tabRecord then
				table.remove(tabRecords, i)
				break
			end
		end
	end

	function self.registerTab(tabRecord)
		if not tabRecord or tabGestureCleanup[tabRecord] then
			return
		end
		if not (tabRecord.TabButton and tabRecord.TabButton.Parent) then
			return
		end

		table.insert(tabRecords, tabRecord)
		tabRecord.IsSplit = false
		tabRecord.SplitPanelId = nil
		tabRecord.SuppressNextClick = false
		captureOriginalZIndex(tabRecord)

		local interact = tabRecord.TabButton:FindFirstChild("Interact")
		if not interact then
			return
		end

		local inputId = self.HttpService:GenerateGUID(false)
		local connections = {}
		local state = {
			pressing = false,
			dragArmed = false,
			pressInput = nil,
			pointer = nil,
			holdToken = 0,
			indicator = nil,
			indicatorTween = nil,
			ghost = nil,
			ghostTarget = nil,
			ghostFollowConnection = nil
		}

		local function stopGhostFollow()
			if state.ghostFollowConnection then
				state.ghostFollowConnection:Disconnect()
				state.ghostFollowConnection = nil
			end
		end

		local function startGhostFollow()
			stopGhostFollow()
			state.ghostFollowConnection = self.RunService.RenderStepped:Connect(function(deltaTime)
				if not (state.ghost and state.ghost.Parent and state.ghostTarget) then
					return
				end

				local halfWidth = math.floor(state.ghost.AbsoluteSize.X * 0.5)
				local halfHeight = math.floor(state.ghost.AbsoluteSize.Y * 0.5)
				local desired = Vector2.new(state.ghostTarget.X - halfWidth, state.ghostTarget.Y - halfHeight)
				local current = Vector2.new(state.ghost.Position.X.Offset, state.ghost.Position.Y.Offset)
				local alpha = math.clamp(deltaTime * (TAB_GHOST_FOLLOW_SPEED * 60), 0, 1)
				local nextPosition = current:Lerp(desired, alpha)

				state.ghost.Position = UDim2.fromOffset(math.floor(nextPosition.X + 0.5), math.floor(nextPosition.Y + 0.5))
			end)
		end

		local function clearVisuals()
			stopGhostFollow()
			clearHoldIndicator(state.indicator, state.indicatorTween)
			clearGhost(state.ghost)
			state.indicator = nil
			state.indicatorTween = nil
			state.ghost = nil
			state.ghostTarget = nil
		end

		local function beginPress(input)
			if isBlocked() then
				return
			end

			state.pressing = true
			state.dragArmed = false
			state.pressInput = input
			state.pointer = getInputPosition(input)
			state.ghostTarget = state.pointer
			state.holdToken += 1
			local token = state.holdToken

			state.indicator, state.indicatorTween = createHoldIndicator(tabRecord.TabButton)

			task.delay(holdDuration, function()
				if token ~= state.holdToken or not state.pressing then
					return
				end

				local allowed, reason = canSplitTab(tabRecord)
				if not allowed then
					if reason and reason ~= "This tab is already split." then
						safeNotify({
							Title = "Tab Split",
							Content = reason,
							Duration = 2.8
						})
					end
					tabRecord.SuppressNextClick = true
					clearHoldIndicator(state.indicator, state.indicatorTween)
					state.indicator = nil
					state.indicatorTween = nil
					return
				end

				state.dragArmed = true
				tabRecord.SuppressNextClick = true
				state.ghost = createGhost("Split: " .. tostring(tabRecord.Name), state.pointer)
				state.ghostTarget = state.pointer
				startGhostFollow()
			end)
		end

		local function finishPress(input)
			if not state.pressInput then
				return
			end

			local sameTouch = input == state.pressInput
			local mouseEnded = state.pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
			if not sameTouch and not mouseEnded then
				return
			end

			state.pressing = false
			state.pressInput = nil
			state.holdToken += 1

			clearHoldIndicator(state.indicator, state.indicatorTween)
			state.indicator = nil
			state.indicatorTween = nil

			if state.dragArmed then
				state.dragArmed = false
				stopGhostFollow()
				local dropPoint = state.pointer or getInputPosition(input)
				clearGhost(state.ghost)
				state.ghost = nil
				state.ghostTarget = nil
				tabRecord.SuppressNextClick = true

				if not isPointInsideMain(dropPoint) then
					self.splitTab(tabRecord, dropPoint)
				end
			else
				stopGhostFollow()
				clearGhost(state.ghost)
				state.ghost = nil
				state.ghostTarget = nil
			end
		end

		table.insert(connections, interact.InputBegan:Connect(function(input)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end
			beginPress(input)
		end))

		table.insert(connections, tabRecord.TabButton.AncestryChanged:Connect(function()
			if not tabRecord.TabButton:IsDescendantOf(game) then
				unregisterTab(tabRecord)
			end
		end))

		registerSharedInput(inputId, function(input)
			if not state.pressing or not state.pressInput then
				return
			end

			local sameTouch = input == state.pressInput
			local mouseMove = state.pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
			if not sameTouch and not mouseMove then
				return
			end

			state.pointer = getInputPosition(input)
			if state.dragArmed and state.ghost then
				state.ghostTarget = state.pointer
				updateGhostPosition(state.ghost, state.pointer)
			end
		end, finishPress)

		tabGestureCleanup[tabRecord] = {
			InputId = inputId,
			Connections = connections,
			ClearVisuals = clearVisuals
		}
	end

	function self.syncHidden(isHidden)
		splitHidden = isHidden and true or false
		refreshRootVisibility()
	end

	function self.syncMinimized(isMinimized)
		splitMinimized = isMinimized and true or false
		refreshRootVisibility()
		for _, panelData in pairs(splitPanels) do
			if panelData and panelData.Frame and panelData.Frame.Parent then
				panelData.Frame.Visible = (not splitHidden) and (not splitMinimized)
			end
		end
	end

	function self.destroy()
		for tabRecord, panelId in pairs(tabToPanel) do
			if panelId then
				restoreOriginalZIndex(tabRecord)
			end
		end

		for tabRecord, _ in pairs(tabGestureCleanup) do
			unregisterTab(tabRecord)
		end

		for _, panelData in pairs(splitPanels) do
			cleanupPanel(panelData)
		end

		table.clear(splitPanels)
		table.clear(tabToPanel)
		table.clear(panelOrder)
		table.clear(tabRecords)

		local zRecords = {}
		for tabRecord, _ in pairs(tabZIndexState) do
			table.insert(zRecords, tabRecord)
		end
		for _, tabRecord in ipairs(zRecords) do
			restoreOriginalZIndex(tabRecord)
		end

		for _, connection in ipairs(rootConnections) do
			if connection then
				connection:Disconnect()
			end
		end
		table.clear(rootConnections)

		disconnectSharedInput()

		if splitRoot and splitRoot.Parent then
			splitRoot:Destroy()
		end
		splitRoot = nil
	end

	return self
end

return TabSplitModule
