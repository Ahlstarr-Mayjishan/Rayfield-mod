-- Rayfield UI State Management Module
-- Handles notifications, search, hide/show, minimize/maximize

local UIStateModule = {}

function UIStateModule.init(ctx)
	local self = {}

	-- Inject dependencies
	self.TweenService = ctx.TweenService
	self.Animation = ctx.Animation or ctx.TweenService
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.TabList = ctx.TabList
	self.Elements = ctx.Elements
	self.Notifications = ctx.Notifications
	self.MPrompt = ctx.MPrompt
	self.dragInteract = ctx.dragInteract
	self.dragBarCosmetic = ctx.dragBarCosmetic
	self.dragBar = ctx.dragBar
	self.dragOffset = ctx.dragOffset
	self.dragOffsetMobile = ctx.dragOffsetMobile
	self.getIcon = ctx.getIcon
	self.getAssetUri = ctx.getAssetUri
	self.getSelectedTheme = ctx.getSelectedTheme
	self.rayfieldDestroyed = ctx.rayfieldDestroyed
	self.getSetting = ctx.getSetting
	self.useMobileSizing = ctx.useMobileSizing
	self.useMobilePrompt = ctx.useMobilePrompt
	self.UserInputService = ctx.UserInputService
	self.onCommandPaletteQuery = type(ctx.onCommandPaletteQuery) == "function" and ctx.onCommandPaletteQuery or function()
		return {}
	end
	self.onCommandPaletteSelect = type(ctx.onCommandPaletteSelect) == "function" and ctx.onCommandPaletteSelect or function()
		return false, "Command palette action unavailable."
	end
	self.onOpenSettingsTab = type(ctx.onOpenSettingsTab) == "function" and ctx.onOpenSettingsTab or nil
	self.onToggleAudioFeedback = type(ctx.onToggleAudioFeedback) == "function" and ctx.onToggleAudioFeedback or nil
	self.onTogglePinBadges = type(ctx.onTogglePinBadges) == "function" and ctx.onTogglePinBadges or nil
	self.onToggleVisibility = type(ctx.onToggleVisibility) == "function" and ctx.onToggleVisibility or nil
	self.onTogglePerformanceHUD = type(ctx.onTogglePerformanceHUD) == "function" and ctx.onTogglePerformanceHUD or nil
	self.onOpenPerformanceHUD = type(ctx.onOpenPerformanceHUD) == "function" and ctx.onOpenPerformanceHUD or nil
	self.onClosePerformanceHUD = type(ctx.onClosePerformanceHUD) == "function" and ctx.onClosePerformanceHUD or nil
	self.getAudioFeedbackEnabled = type(ctx.getAudioFeedbackEnabled) == "function" and ctx.getAudioFeedbackEnabled or nil
	self.getPinBadgesVisible = type(ctx.getPinBadgesVisible) == "function" and ctx.getPinBadgesVisible or nil
	self.setElementInspectorEnabled = type(ctx.setElementInspectorEnabled) == "function" and ctx.setElementInspectorEnabled or nil
	self.getElementInspectorEnabled = type(ctx.getElementInspectorEnabled) == "function" and ctx.getElementInspectorEnabled or function()
		return false
	end
	self.inspectElementAtPointer = type(ctx.inspectElementAtPointer) == "function" and ctx.inspectElementAtPointer or function()
		return false, nil
	end

	-- Module state
	local searchOpen = false
	local Debounce = false
	local Minimised = false
	local Hidden = false
	local expandedSize = self.useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475)
	local actionCenterOpen = false
	local commandPaletteOpen = false
	local commandPaletteSelectionIndex = 1
	local commandPaletteResults = {}
	local commandPaletteConnections = {}
	local contextMenuOpen = false
	local contextMenuConnections = {}
	local inspectorOpen = self.getElementInspectorEnabled() == true
	local inspectorRefs = {}
	local inspectorLoopRunning = false
	local lastInspectorSnapshot = nil
	local actionCenterRefs = {}
	local commandPaletteRefs = {}
	local contextMenuRefs = {}
	local topbarActionCenterButton = nil
	local topbarActionCenterBadge = nil
	local notificationHistory = {}
	local notificationUnreadCount = 0
	local historyMaxEntries = math.max(5, math.floor(tonumber(type(_G) == "table" and _G.__RAYFIELD_ACTION_CENTER_MAX_HISTORY or 20) or 20))
	local notificationFilterLevel = "all"
	local notificationFilterQuery = ""
	local commandPaletteKeybind = tostring(type(_G) == "table" and _G.__RAYFIELD_COMMAND_PALETTE_KEY or "LeftControl+K")

	local function clampExpandedOffsets(width, height)
		local clampedWidth = math.max(math.floor(width), 320)
		local clampedHeight = math.max(math.floor(height), self.useMobileSizing and 170 or 220)

		local parentGui = self.Main and self.Main.Parent
		if parentGui and parentGui.AbsoluteSize then
			local viewport = parentGui.AbsoluteSize
			if viewport.X > 0 then
				clampedWidth = math.min(clampedWidth, math.max(320, viewport.X - 24))
			end
			if viewport.Y > 0 then
				local minHeight = self.useMobileSizing and 170 or 220
				clampedHeight = math.min(clampedHeight, math.max(minHeight, viewport.Y - 24))
			end
		end

		return clampedWidth, clampedHeight
	end

	local function normalizeExpandedSize(value)
		if typeof(value) == "UDim2" then
			return value.X.Offset, value.Y.Offset
		end
		if type(value) == "table" then
			local width = tonumber(value.width or value.x or value.X or value.xOffset)
			local height = tonumber(value.height or value.y or value.Y or value.yOffset)
			if width and height then
				return width, height
			end
		end
		return nil, nil
	end

	local function getExpandedSize()
		return expandedSize
	end

	local function setExpandedSize(nextSize)
		local width, height = normalizeExpandedSize(nextSize)
		if not width or not height then
			return false
		end
		width, height = clampExpandedOffsets(width, height)
		expandedSize = UDim2.fromOffset(width, height)
		return true
	end

	local function applyExpandedSizeToFrames()
		local targetSize = getExpandedSize()
		if self.Main then
			self.Main.Size = targetSize
		end
		if self.Topbar then
			self.Topbar.Size = UDim2.fromOffset(targetSize.X.Offset, 45)
		end
	end

	local function clampMainToViewport()
		if not (self.Main and self.Main.Parent and self.Main.Parent.AbsoluteSize) then
			return
		end
		local parentSize = self.Main.Parent.AbsoluteSize
		local mainPosition = self.Main.AbsolutePosition
		local mainSize = self.Main.AbsoluteSize

		local clampedX = math.clamp(mainPosition.X, 0, math.max(0, parentSize.X - mainSize.X))
		local clampedY = math.clamp(mainPosition.Y, 0, math.max(0, parentSize.Y - mainSize.Y))
		local deltaX = clampedX - mainPosition.X
		local deltaY = clampedY - mainPosition.Y
		if deltaX ~= 0 or deltaY ~= 0 then
			self.Main.Position = UDim2.new(
				self.Main.Position.X.Scale,
				self.Main.Position.X.Offset + deltaX,
				self.Main.Position.Y.Scale,
				self.Main.Position.Y.Offset + deltaY
			)
		end
	end

	-- Forward declare functions
	local closeSearch
	local Notify

	local function playTween(instance, tweenInfo, properties)
		if instance then
			self.Animation:Create(instance, tweenInfo, properties):Play()
		end
	end

	local TAB_BUTTON_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Exponential)
	local TAB_VISUAL_PRESETS = {
		hidden = { background = 1, image = 1, text = 1, stroke = 1 },
		selected = { background = 0, image = 0, text = 0, stroke = 1 },
		idle = { background = 0.7, image = 0.2, text = 0.2, stroke = 0.5 }
	}

	local function forEachTabButton(callback)
		if not self.TabList then
			return
		end
		for _, tabbtn in ipairs(self.TabList:GetChildren()) do
			if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
				callback(tabbtn)
			end
		end
	end

	local function applyTabButtonVisual(tabbtn, visual)
		if not (tabbtn and visual) then
			return
		end
		playTween(tabbtn, TAB_BUTTON_TWEEN, {BackgroundTransparency = visual.background})
		playTween(tabbtn:FindFirstChild("Title"), TAB_BUTTON_TWEEN, {TextTransparency = visual.text})
		playTween(tabbtn:FindFirstChild("Image"), TAB_BUTTON_TWEEN, {ImageTransparency = visual.image})
		playTween(tabbtn:FindFirstChild("UIStroke"), TAB_BUTTON_TWEEN, {Transparency = visual.stroke})
	end

	local function isCurrentTabButton(tabbtn)
		return tostring(self.Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text
	end

	local function animateTabButtonsHidden(interactVisible)
		forEachTabButton(function(tabbtn)
			local interact = tabbtn:FindFirstChild("Interact")
			if interact and interactVisible ~= nil then
				interact.Visible = interactVisible
			end
			applyTabButtonVisual(tabbtn, TAB_VISUAL_PRESETS.hidden)
		end)
	end

	local function animateTabButtonsByCurrentPage(interactVisible)
		forEachTabButton(function(tabbtn)
			local interact = tabbtn:FindFirstChild("Interact")
			if interact and interactVisible ~= nil then
				interact.Visible = interactVisible
			end
			applyTabButtonVisual(tabbtn, isCurrentTabButton(tabbtn) and TAB_VISUAL_PRESETS.selected or TAB_VISUAL_PRESETS.idle)
		end)
	end

	local function forEachElementFrame(callback)
		if not self.Elements then
			return
		end
		for _, tab in ipairs(self.Elements:GetChildren()) do
			if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
				for _, element in ipairs(tab:GetChildren()) do
					if element.ClassName == "Frame" and element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
						callback(element)
					end
				end
			end
		end
	end

	local function setElementChildrenVisible(element, visible)
		for _, child in ipairs(element:GetChildren()) do
			if child.ClassName == "Frame"
				or child.ClassName == "TextLabel"
				or child.ClassName == "TextBox"
				or child.ClassName == "ImageButton"
				or child.ClassName == "ImageLabel" then
				child.Visible = visible
			end
		end
	end

	local function applyElementFrameState(element, collapsed)
		local targetTitleTransparency = collapsed and 1 or 0.4
		local targetDividerTransparency = collapsed and 1 or 0.85
		local targetBackgroundTransparency = collapsed and 1 or 0
		local targetStrokeTransparency = collapsed and 1 or 0

		if element.Name == "SectionTitle" or element.Name == "SearchTitle-fsefsefesfsefesfesfThanks" then
			playTween(element:FindFirstChild("Title"), TAB_BUTTON_TWEEN, {TextTransparency = targetTitleTransparency})
		elseif element.Name == "Divider" then
			playTween(element:FindFirstChild("Divider"), TAB_BUTTON_TWEEN, {BackgroundTransparency = targetDividerTransparency})
		else
			playTween(element, TAB_BUTTON_TWEEN, {BackgroundTransparency = targetBackgroundTransparency})
			playTween(element:FindFirstChild("UIStroke"), TAB_BUTTON_TWEEN, {Transparency = targetStrokeTransparency})
			playTween(element:FindFirstChild("Title"), TAB_BUTTON_TWEEN, {TextTransparency = targetBackgroundTransparency})
		end

		setElementChildrenVisible(element, not collapsed)
	end

	local function animateElementFramesCollapsed(collapsed)
		forEachElementFrame(function(element)
			applyElementFrameState(element, collapsed == true)
		end)
	end

	local function disconnectConnections(store)
		if type(store) ~= "table" then
			return
		end
		for index = #store, 1, -1 do
			local connection = store[index]
			if connection then
				pcall(function()
					connection:Disconnect()
				end)
			end
			store[index] = nil
		end
	end

	local function lowerText(value)
		return string.lower(tostring(value or ""))
	end

	local function cloneHistoryEntry(entry)
		return {
			id = tostring(entry and entry.id or ""),
			title = tostring(entry and entry.title or ""),
			content = tostring(entry and entry.content or ""),
			image = entry and entry.image or nil,
			timestamp = tostring(entry and entry.timestamp or ""),
			level = tostring(entry and entry.level or "info"),
			source = tostring(entry and entry.source or "rayfield"),
			read = entry and entry.read == true or false
		}
	end

	local function getNotificationHistory(limit)
		local out = {}
		local maxCount = tonumber(limit)
		if not maxCount or maxCount <= 0 then
			maxCount = #notificationHistory
		end
		for index = #notificationHistory, 1, -1 do
			table.insert(out, cloneHistoryEntry(notificationHistory[index]))
			if #out >= maxCount then
				break
			end
		end
		return out
	end

	local function getNotificationHistoryEx(options)
		options = type(options) == "table" and options or {}
		local limit = tonumber(options.limit)
		local level = lowerText(options.level or "all")
		if level == "warning" then
			level = "warn"
		end
		local query = lowerText(options.query or "")
		local unreadOnly = options.unreadOnly == true
		local out = {}
		for index = #notificationHistory, 1, -1 do
			local entry = notificationHistory[index]
			if type(entry) == "table" then
				local entryLevel = lowerText(entry.level or "info")
				if level == "" then
					level = "all"
				end
				local levelMatch = level == "all" or entryLevel == level
				local queryPool = lowerText((entry.title or "") .. " " .. (entry.content or "") .. " " .. (entry.source or ""))
				local queryMatch = query == "" or string.find(queryPool, query, 1, true) ~= nil
				local unreadMatch = not unreadOnly or entry.read ~= true
				if levelMatch and queryMatch and unreadMatch then
					table.insert(out, cloneHistoryEntry(entry))
					if limit and limit > 0 and #out >= limit then
						break
					end
				end
			end
		end
		return out
	end

	local function parsePaletteKeybind(binding)
		local tokens = {}
		for token in tostring(binding or ""):gmatch("[^%+]+") do
			local trimmed = token:gsub("^%s+", ""):gsub("%s+$", "")
			if trimmed ~= "" then
				table.insert(tokens, trimmed)
			end
		end

		local spec = {
			key = Enum.KeyCode.K,
			ctrl = false,
			shift = false,
			alt = false
		}

		for _, rawToken in ipairs(tokens) do
			local tokenLower = string.lower(rawToken)
			if tokenLower == "leftcontrol" or tokenLower == "rightcontrol" or tokenLower == "ctrl" or tokenLower == "control" then
				spec.ctrl = true
			elseif tokenLower == "leftshift" or tokenLower == "rightshift" or tokenLower == "shift" then
				spec.shift = true
			elseif tokenLower == "leftalt" or tokenLower == "rightalt" or tokenLower == "alt" then
				spec.alt = true
			else
				local enumKey = Enum.KeyCode[rawToken]
				if enumKey then
					spec.key = enumKey
				else
					local upperKey = Enum.KeyCode[string.upper(rawToken)]
					if upperKey then
						spec.key = upperKey
					end
				end
			end
		end
		return spec
	end

	local paletteKeySpec = parsePaletteKeybind(commandPaletteKeybind)

	local function isModifierDown(modifierName)
		if not self.UserInputService then
			return false
		end
		if modifierName == "ctrl" then
			return self.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or self.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		elseif modifierName == "shift" then
			return self.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or self.UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		elseif modifierName == "alt" then
			return self.UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
				or self.UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
		end
		return false
	end

	local function isPaletteKeyMatch(input)
		if not input or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return false
		end
		if input.KeyCode ~= paletteKeySpec.key then
			return false
		end
		if paletteKeySpec.ctrl and not isModifierDown("ctrl") then
			return false
		end
		if paletteKeySpec.shift and not isModifierDown("shift") then
			return false
		end
		if paletteKeySpec.alt and not isModifierDown("alt") then
			return false
		end
		return true
	end

	local function getThemeValueOrDefault(key, fallback)
		local theme = self.getSelectedTheme and self.getSelectedTheme()
		if theme and theme[key] ~= nil then
			return theme[key]
		end
		return fallback
	end

	local function updateActionCenterBadge()
		if not topbarActionCenterBadge or not topbarActionCenterBadge.Parent then
			return
		end
		local show = notificationUnreadCount > 0
		topbarActionCenterBadge.Visible = show
		local textLabel = topbarActionCenterBadge:FindFirstChild("Count")
		if textLabel then
			textLabel.Text = notificationUnreadCount > 99 and "99+" or tostring(notificationUnreadCount)
		end
	end

	local function clearNotificationHistory()
		table.clear(notificationHistory)
		notificationUnreadCount = 0
		updateActionCenterBadge()
	end

	local function markAllNotificationsRead()
		for _, entry in ipairs(notificationHistory) do
			if type(entry) == "table" then
				entry.read = true
			end
		end
		notificationUnreadCount = 0
		updateActionCenterBadge()
		return true
	end

	local function getUnreadNotificationCount()
		return math.max(0, tonumber(notificationUnreadCount) or 0)
	end

	local function ensureActionCenterButton()
		if topbarActionCenterButton and topbarActionCenterButton.Parent then
			return topbarActionCenterButton
		end
		if not self.Topbar then
			return nil
		end

		local button = Instance.new("ImageButton")
		button.Name = "ActionCenter"
		button.Size = UDim2.fromOffset(18, 18)
		button.AnchorPoint = Vector2.new(0, 0.5)
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Image = self.getAssetUri and self.getAssetUri(4483362458) or "rbxassetid://4483362458"
		button.ImageTransparency = 0.8
		button.Parent = self.Topbar

		local hideButton = self.Topbar:FindFirstChild("Hide")
		if hideButton and hideButton:IsA("GuiObject") then
			button.Position = UDim2.new(hideButton.Position.X.Scale, hideButton.Position.X.Offset - 30, hideButton.Position.Y.Scale, hideButton.Position.Y.Offset)
		else
			button.Position = UDim2.new(1, -142, 0.5, 0)
		end

		local badge = Instance.new("Frame")
		badge.Name = "UnreadBadge"
		badge.Size = UDim2.fromOffset(16, 16)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 4, 0, -4)
		badge.BackgroundColor3 = Color3.fromRGB(225, 65, 65)
		badge.BorderSizePixel = 0
		badge.Visible = false
		badge.Parent = button

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(1, 0)
		badgeCorner.Parent = badge

		local badgeLabel = Instance.new("TextLabel")
		badgeLabel.Name = "Count"
		badgeLabel.BackgroundTransparency = 1
		badgeLabel.Size = UDim2.fromScale(1, 1)
		badgeLabel.Text = "0"
		badgeLabel.TextScaled = true
		badgeLabel.Font = Enum.Font.GothamBold
		badgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		badgeLabel.Parent = badge

		button.MouseButton1Click:Connect(function()
			if actionCenterOpen then
				self.CloseActionCenter()
			else
				self.OpenActionCenter()
			end
		end)
		button.MouseEnter:Connect(function()
			playTween(button, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0})
		end)
		button.MouseLeave:Connect(function()
			playTween(button, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0.8})
		end)

		topbarActionCenterButton = button
		topbarActionCenterBadge = badge
		updateActionCenterBadge()
		return button
	end

	local function ensureActionCenterPanel()
		if actionCenterRefs.Panel and actionCenterRefs.Panel.Parent then
			return actionCenterRefs
		end
		if not self.Main then
			return actionCenterRefs
		end

		local panel = Instance.new("Frame")
		panel.Name = "ActionCenterPanel"
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.new(1, 12, 0, 45)
		panel.Size = UDim2.new(0, 300, 1, -56)
		panel.BackgroundTransparency = 0.08
		panel.BorderSizePixel = 0
		panel.Visible = false
		panel.ZIndex = 40
		panel.Parent = self.Main

		local panelCorner = Instance.new("UICorner")
		panelCorner.CornerRadius = UDim.new(0, 10)
		panelCorner.Parent = panel

		local panelStroke = Instance.new("UIStroke")
		panelStroke.Thickness = 1
		panelStroke.Transparency = 0.25
		panelStroke.Parent = panel

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.new(0, 12, 0, 10)
		title.Size = UDim2.new(1, -24, 0, 20)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 15
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "Action Center"
		title.ZIndex = 41
		title.Parent = panel

		local unread = Instance.new("TextLabel")
		unread.Name = "Unread"
		unread.BackgroundTransparency = 1
		unread.Position = UDim2.new(0, 12, 0, 30)
		unread.Size = UDim2.new(1, -24, 0, 18)
		unread.Font = Enum.Font.Gotham
		unread.TextSize = 12
		unread.TextXAlignment = Enum.TextXAlignment.Left
		unread.Text = "Unread: 0"
		unread.ZIndex = 41
		unread.Parent = panel

		local filterLevel = Instance.new("TextButton")
		filterLevel.Name = "FilterLevel"
		filterLevel.BackgroundTransparency = 0.1
		filterLevel.BorderSizePixel = 0
		filterLevel.Position = UDim2.new(0, 12, 0, 52)
		filterLevel.Size = UDim2.new(0.4, -6, 0, 22)
		filterLevel.Font = Enum.Font.Gotham
		filterLevel.TextSize = 11
		filterLevel.TextXAlignment = Enum.TextXAlignment.Left
		filterLevel.Text = "  Level: all"
		filterLevel.ZIndex = 41
		filterLevel.Parent = panel

		local filterLevelCorner = Instance.new("UICorner")
		filterLevelCorner.CornerRadius = UDim.new(0, 6)
		filterLevelCorner.Parent = filterLevel

		local filterInput = Instance.new("TextBox")
		filterInput.Name = "FilterInput"
		filterInput.BackgroundTransparency = 0.1
		filterInput.BorderSizePixel = 0
		filterInput.Position = UDim2.new(0.4, 2, 0, 52)
		filterInput.Size = UDim2.new(0.6, -14, 0, 22)
		filterInput.Font = Enum.Font.Gotham
		filterInput.TextSize = 11
		filterInput.TextXAlignment = Enum.TextXAlignment.Left
		filterInput.ClearTextOnFocus = false
		filterInput.PlaceholderText = "Filter text..."
		filterInput.Text = ""
		filterInput.ZIndex = 41
		filterInput.Parent = panel

		local filterInputCorner = Instance.new("UICorner")
		filterInputCorner.CornerRadius = UDim.new(0, 6)
		filterInputCorner.Parent = filterInput

		local actionsHolder = Instance.new("Frame")
		actionsHolder.Name = "QuickActions"
		actionsHolder.BackgroundTransparency = 1
		actionsHolder.Position = UDim2.new(0, 12, 0, 80)
		actionsHolder.Size = UDim2.new(1, -24, 0, 108)
		actionsHolder.Parent = panel

		local actionsLayout = Instance.new("UIListLayout")
		actionsLayout.Padding = UDim.new(0, 6)
		actionsLayout.Parent = actionsHolder

		local historyList = Instance.new("ScrollingFrame")
		historyList.Name = "History"
		historyList.BackgroundTransparency = 1
		historyList.Position = UDim2.new(0, 12, 0, 192)
		historyList.Size = UDim2.new(1, -24, 1, -204)
		historyList.AutomaticCanvasSize = Enum.AutomaticSize.None
		historyList.ScrollBarThickness = 4
		historyList.CanvasSize = UDim2.fromOffset(0, 0)
		historyList.BorderSizePixel = 0
		historyList.ZIndex = 41
		historyList.Parent = panel

		local historyLayout = Instance.new("UIListLayout")
		historyLayout.Padding = UDim.new(0, 6)
		historyLayout.Parent = historyList

		actionCenterRefs = {
			Panel = panel,
			Title = title,
			Unread = unread,
			FilterLevel = filterLevel,
			FilterInput = filterInput,
			QuickActions = actionsHolder,
			History = historyList,
			HistoryLayout = historyLayout,
			PanelStroke = panelStroke
		}

		local function makeQuickAction(name, callback)
			local button = Instance.new("TextButton")
			button.Name = name:gsub("%s+", "")
			button.Size = UDim2.new(1, 0, 0, 24)
			button.BackgroundTransparency = 0.2
			button.BorderSizePixel = 0
			button.AutoButtonColor = true
			button.Font = Enum.Font.Gotham
			button.TextSize = 12
			button.TextXAlignment = Enum.TextXAlignment.Left
			button.Text = "  " .. tostring(name)
			button.Parent = actionsHolder

			local buttonCorner = Instance.new("UICorner")
			buttonCorner.CornerRadius = UDim.new(0, 6)
			buttonCorner.Parent = button

			button.MouseButton1Click:Connect(function()
				local okCall, resultA, resultB = pcall(callback)
				if not okCall then
					if Notify then
						Notify({
							Title = "Action Center",
							Content = tostring(resultA),
							Duration = 3
						})
					end
					return
				end
				if Notify then
					local success = resultA == true or resultA == nil
					local message = resultB or resultA or "Action completed."
					Notify({
						Title = "Action Center",
						Content = tostring(message),
						Duration = 2,
						Image = success and 4483362458 or 4384402990
					})
				end
			end)
			return button
		end

		makeQuickAction("Toggle Audio Feedback", function()
			if not self.onToggleAudioFeedback then
				return false, "Audio feedback handler unavailable."
			end
			return self.onToggleAudioFeedback()
		end)
		makeQuickAction("Toggle Pin Badges", function()
			if not self.onTogglePinBadges then
				return false, "Pin badge handler unavailable."
			end
			return self.onTogglePinBadges()
		end)
		makeQuickAction("Hide/Show Interface", function()
			if not self.onToggleVisibility then
				return false, "Visibility handler unavailable."
			end
			return self.onToggleVisibility()
		end)
		makeQuickAction("Open Settings", function()
			if not self.onOpenSettingsTab then
				return false, "Settings handler unavailable."
			end
			return self.onOpenSettingsTab()
		end)
		makeQuickAction("Toggle Performance HUD", function()
			if self.onTogglePerformanceHUD then
				return self.onTogglePerformanceHUD()
			end
			return false, "Performance HUD handler unavailable."
		end)

		local levelOrder = { "all", "error", "warn", "info" }
		local function nextLevel(current)
			local lower = lowerText(current or "all")
			for index, value in ipairs(levelOrder) do
				if value == lower then
					return levelOrder[(index % #levelOrder) + 1]
				end
			end
			return "all"
		end

		filterLevel.MouseButton1Click:Connect(function()
			notificationFilterLevel = nextLevel(notificationFilterLevel)
			filterLevel.Text = "  Level: " .. tostring(notificationFilterLevel)
			renderActionCenterHistory()
		end)

		filterInput:GetPropertyChangedSignal("Text"):Connect(function()
			notificationFilterQuery = tostring(filterInput.Text or "")
			renderActionCenterHistory()
		end)
	end

	local function applyActionCenterTheme()
		local refs = ensureActionCenterPanel()
		if not refs.Panel then
			return
		end
		refs.Panel.BackgroundColor3 = getThemeValueOrDefault("Background", Color3.fromRGB(25, 25, 30))
		if refs.PanelStroke then
			refs.PanelStroke.Color = getThemeValueOrDefault("ElementStroke", Color3.fromRGB(85, 85, 85))
		end
		if refs.Title then
			refs.Title.TextColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(255, 255, 255))
		end
		if refs.Unread then
			refs.Unread.TextColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(220, 220, 220))
		end
		if refs.FilterLevel then
			refs.FilterLevel.BackgroundColor3 = getThemeValueOrDefault("ElementBackground", Color3.fromRGB(35, 35, 40))
			refs.FilterLevel.TextColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(255, 255, 255))
		end
		if refs.FilterInput then
			refs.FilterInput.BackgroundColor3 = getThemeValueOrDefault("InputBackground", Color3.fromRGB(40, 40, 45))
			refs.FilterInput.TextColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(255, 255, 255))
			refs.FilterInput.PlaceholderColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(185, 185, 185))
		end
		for _, child in ipairs((refs.QuickActions and refs.QuickActions:GetChildren()) or {}) do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = getThemeValueOrDefault("ElementBackground", Color3.fromRGB(35, 35, 40))
				child.TextColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(255, 255, 255))
			end
		end
		for _, child in ipairs((refs.History and refs.History:GetChildren()) or {}) do
			if child:IsA("Frame") then
				child.BackgroundColor3 = getThemeValueOrDefault("ElementBackground", Color3.fromRGB(30, 30, 35))
				local title = child:FindFirstChild("Title")
				local content = child:FindFirstChild("Content")
				if title then
					title.TextColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(255, 255, 255))
				end
				if content then
					content.TextColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(210, 210, 210))
				end
			end
		end
	end

	local function renderActionCenterHistory()
		local refs = ensureActionCenterPanel()
		if not refs.History then
			return
		end
		for _, child in ipairs(refs.History:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		for _, entry in ipairs(getNotificationHistoryEx({
			limit = historyMaxEntries,
			level = notificationFilterLevel,
			query = notificationFilterQuery
		})) do
			local row = Instance.new("Frame")
			row.Name = "HistoryEntry"
			row.BackgroundTransparency = 0.15
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, -4, 0, 62)
			row.Parent = refs.History

			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 6)
			rowCorner.Parent = row

			if entry.read ~= true then
				local rowStroke = Instance.new("UIStroke")
				rowStroke.Thickness = 1
				rowStroke.Transparency = 0.35
				rowStroke.Color = Color3.fromRGB(255, 200, 90)
				rowStroke.Parent = row
			end

			local rowTitle = Instance.new("TextLabel")
			rowTitle.Name = "Title"
			rowTitle.BackgroundTransparency = 1
			rowTitle.Position = UDim2.new(0, 8, 0, 4)
			rowTitle.Size = UDim2.new(1, -16, 0, 16)
			rowTitle.Font = Enum.Font.GothamBold
			rowTitle.TextSize = 12
			rowTitle.TextXAlignment = Enum.TextXAlignment.Left
			rowTitle.Text = string.format("[%s][%s] %s", tostring(entry.timestamp), string.upper(tostring(entry.level or "info")), tostring(entry.title))
			rowTitle.Parent = row

			local rowContent = Instance.new("TextLabel")
			rowContent.Name = "Content"
			rowContent.BackgroundTransparency = 1
			rowContent.Position = UDim2.new(0, 8, 0, 22)
			rowContent.Size = UDim2.new(1, -16, 0, 34)
			rowContent.Font = Enum.Font.Gotham
			rowContent.TextSize = 11
			rowContent.TextXAlignment = Enum.TextXAlignment.Left
			rowContent.TextYAlignment = Enum.TextYAlignment.Top
			rowContent.TextWrapped = true
			rowContent.Text = string.format("%s\nSource: %s", tostring(entry.content), tostring(entry.source or "rayfield"))
			rowContent.Parent = row
		end

		local listHeight = refs.HistoryLayout.AbsoluteContentSize.Y
		refs.History.CanvasSize = UDim2.fromOffset(0, math.max(listHeight + 4, refs.History.AbsoluteSize.Y))
		if refs.Unread then
			refs.Unread.Text = string.format("Unread: %d  |  Total: %d", notificationUnreadCount, #notificationHistory)
		end
		applyActionCenterTheme()
	end

	local function pushNotificationHistory(data)
		local title = tostring((type(data) == "table" and data.Title) or "Notification")
		local content = tostring((type(data) == "table" and data.Content) or "")
		local explicitLevel = type(data) == "table" and tostring(data.Level or "") or ""
		explicitLevel = lowerText(explicitLevel)
		local inferredLevel = "info"
		if explicitLevel == "error" or explicitLevel == "warn" or explicitLevel == "warning" or explicitLevel == "info" then
			inferredLevel = explicitLevel == "warning" and "warn" or explicitLevel
		else
			local haystack = lowerText(title .. " " .. content)
			if string.find(haystack, "error", 1, true) or string.find(haystack, "failed", 1, true) then
				inferredLevel = "error"
			elseif string.find(haystack, "warn", 1, true) or string.find(haystack, "timeout", 1, true) then
				inferredLevel = "warn"
			end
		end
		local entry = {
			id = tostring(type(os.clock) == "function" and math.floor(os.clock() * 1000000) or math.random(100000, 999999)),
			title = title,
			content = content,
			image = type(data) == "table" and data.Image or nil,
			timestamp = os.date("%H:%M:%S"),
			level = inferredLevel,
			source = tostring(type(data) == "table" and data.Source or "rayfield"),
			read = actionCenterOpen == true
		}
		table.insert(notificationHistory, entry)
		if #notificationHistory > historyMaxEntries then
			table.remove(notificationHistory, 1)
		end
		if not actionCenterOpen then
			notificationUnreadCount += 1
		end
		updateActionCenterBadge()
		if actionCenterOpen then
			renderActionCenterHistory()
		end
	end

	local function ensureCommandPaletteOverlay()
		if commandPaletteRefs.Overlay and commandPaletteRefs.Overlay.Parent then
			return commandPaletteRefs
		end
		if not self.Main then
			return commandPaletteRefs
		end

		local overlay = Instance.new("Frame")
		overlay.Name = "CommandPaletteOverlay"
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.42
		overlay.BorderSizePixel = 0
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.Visible = false
		overlay.ZIndex = 60
		overlay.Parent = self.Main

		local card = Instance.new("Frame")
		card.Name = "Card"
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, 54)
		card.Size = UDim2.new(0, 430, 0, 300)
		card.BackgroundTransparency = 0.06
		card.BorderSizePixel = 0
		card.ZIndex = 61
		card.Parent = overlay

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Thickness = 1
		cardStroke.Transparency = 0.2
		cardStroke.Parent = card

		local input = Instance.new("TextBox")
		input.Name = "Input"
		input.BackgroundTransparency = 0.1
		input.BorderSizePixel = 0
		input.Position = UDim2.new(0, 10, 0, 10)
		input.Size = UDim2.new(1, -20, 0, 34)
		input.Text = ""
		input.PlaceholderText = "Type command or control name..."
		input.Font = Enum.Font.Gotham
		input.TextSize = 14
		input.ClearTextOnFocus = false
		input.TextXAlignment = Enum.TextXAlignment.Left
		input.ZIndex = 62
		input.Parent = card

		local inputCorner = Instance.new("UICorner")
		inputCorner.CornerRadius = UDim.new(0, 7)
		inputCorner.Parent = input

		local resultList = Instance.new("ScrollingFrame")
		resultList.Name = "Results"
		resultList.BackgroundTransparency = 1
		resultList.Position = UDim2.new(0, 10, 0, 50)
		resultList.Size = UDim2.new(1, -20, 1, -60)
		resultList.BorderSizePixel = 0
		resultList.ScrollBarThickness = 4
		resultList.CanvasSize = UDim2.fromOffset(0, 0)
		resultList.ZIndex = 62
		resultList.Parent = card

		local resultLayout = Instance.new("UIListLayout")
		resultLayout.Padding = UDim.new(0, 4)
		resultLayout.Parent = resultList

		commandPaletteRefs = {
			Overlay = overlay,
			Card = card,
			CardStroke = cardStroke,
			Input = input,
			Results = resultList,
			ResultsLayout = resultLayout
		}
	end

	local function renderCommandPaletteResults()
		local refs = ensureCommandPaletteOverlay()
		if not refs.Results then
			return
		end
		for _, child in ipairs(refs.Results:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		if commandPaletteSelectionIndex < 1 then
			commandPaletteSelectionIndex = 1
		end
		if commandPaletteSelectionIndex > #commandPaletteResults then
			commandPaletteSelectionIndex = #commandPaletteResults
		end

		for index, item in ipairs(commandPaletteResults) do
			local marker = item.suggested == true and "[Suggested] " or ""
			local typeName = tostring(item.type or "command")
			local subtitle = tostring(item.description or item.tabId or "")
			local shortcuts = tostring(item.shortcuts or "Enter auto | Shift+Enter execute | Alt+Enter ask")
			local usageSuffix = tonumber(item.usageCount) and tonumber(item.usageCount) > 0 and (" x" .. tostring(item.usageCount)) or ""
			local row = Instance.new("TextButton")
			row.Name = "Result" .. tostring(index)
			row.Size = UDim2.new(1, -2, 0, 48)
			row.BackgroundTransparency = commandPaletteSelectionIndex == index and 0.05 or 0.35
			row.BorderSizePixel = 0
			row.AutoButtonColor = true
			row.Font = Enum.Font.Gotham
			row.TextSize = 11
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextYAlignment = Enum.TextYAlignment.Top
			row.TextWrapped = true
			row.Text = string.format("  %s%s [%s%s]\n  %s | %s", marker, tostring(item.name or item.title or "Unnamed"), typeName, usageSuffix, subtitle, shortcuts)
			row.ZIndex = 63
			row.Parent = refs.Results

			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 6)
			rowCorner.Parent = row

			row.MouseButton1Click:Connect(function()
				local okAction, message, meta = self.onCommandPaletteSelect(item, nil, {
					trigger = "mouse"
				})
				if not okAction and Notify then
					Notify({
						Title = "Command Palette",
						Content = tostring(message or "Command failed."),
						Duration = 3,
						Image = 4384402990
					})
				end
				if not (type(meta) == "table" and meta.keepPaletteOpen == true) then
					self.CloseCommandPalette()
				end
			end)
		end

		local listHeight = refs.ResultsLayout.AbsoluteContentSize.Y
		refs.Results.CanvasSize = UDim2.fromOffset(0, math.max(listHeight + 4, refs.Results.AbsoluteSize.Y))

		local bg = getThemeValueOrDefault("Background", Color3.fromRGB(24, 24, 28))
		local textColor = getThemeValueOrDefault("TextColor", Color3.fromRGB(255, 255, 255))
		refs.Card.BackgroundColor3 = bg
		refs.Input.BackgroundColor3 = getThemeValueOrDefault("InputBackground", Color3.fromRGB(40, 40, 45))
		refs.Input.TextColor3 = textColor
		refs.Input.PlaceholderColor3 = textColor:Lerp(Color3.fromRGB(80, 80, 80), 0.55)
		if refs.CardStroke then
			refs.CardStroke.Color = getThemeValueOrDefault("ElementStroke", Color3.fromRGB(95, 95, 100))
		end
		for _, child in ipairs(refs.Results:GetChildren()) do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = getThemeValueOrDefault("ElementBackground", Color3.fromRGB(35, 35, 40))
				child.TextColor3 = textColor
			end
		end
	end

	local function scorePaletteItem(item, queryLower)
		if type(item) == "table" and tonumber(item.matchScore) then
			return tonumber(item.matchScore)
		end
		local text = string.lower(tostring(item.searchText or item.name or item.title or ""))
		if queryLower == "" then
			return tonumber(item.score) or 0
		end
		if text:sub(1, #queryLower) == queryLower then
			return 200
		end
		if string.find(text, queryLower, 1, true) then
			return 100
		end
		return tonumber(item.score) or 0
	end

	local function refreshCommandPaletteQuery()
		local refs = ensureCommandPaletteOverlay()
		if not refs.Input then
			return
		end
		local query = tostring(refs.Input.Text or "")
		local results = self.onCommandPaletteQuery(query)
		if type(results) ~= "table" then
			results = {}
		end
		local queryLower = string.lower(query)
		table.sort(results, function(a, b)
			local scoreA = scorePaletteItem(a, queryLower)
			local scoreB = scorePaletteItem(b, queryLower)
			if scoreA ~= scoreB then
				return scoreA > scoreB
			end
			local nameA = string.lower(tostring(a.name or a.title or ""))
			local nameB = string.lower(tostring(b.name or b.title or ""))
			return nameA < nameB
		end)
		commandPaletteResults = results
		commandPaletteSelectionIndex = #commandPaletteResults > 0 and 1 or 0
		renderCommandPaletteResults()
	end

	local function ensureContextMenuHost()
		if contextMenuRefs.Root and contextMenuRefs.Root.Parent then
			return contextMenuRefs
		end
		if not self.Main then
			return contextMenuRefs
		end

		local root = Instance.new("Frame")
		root.Name = "ContextMenuRoot"
		root.BackgroundTransparency = 1
		root.Size = UDim2.fromScale(1, 1)
		root.Visible = false
		root.ZIndex = 80
		root.Parent = self.Main

		local menu = Instance.new("Frame")
		menu.Name = "ContextMenu"
		menu.BackgroundTransparency = 0.06
		menu.Size = UDim2.fromOffset(180, 10)
		menu.BorderSizePixel = 0
		menu.Visible = false
		menu.ZIndex = 81
		menu.Parent = root

		local menuCorner = Instance.new("UICorner")
		menuCorner.CornerRadius = UDim.new(0, 8)
		menuCorner.Parent = menu

		local menuStroke = Instance.new("UIStroke")
		menuStroke.Thickness = 1
		menuStroke.Transparency = 0.2
		menuStroke.Parent = menu

		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 4)
		list.Parent = menu

		contextMenuRefs = {
			Root = root,
			Menu = menu,
			List = list,
			MenuStroke = menuStroke
		}
		return contextMenuRefs
	end
	
	-- Extract code starts here

	Notify = function(data) -- action e.g open messages
		pushNotificationHistory(data)
		task.spawn(function()
			data = type(data) == "table" and data or {}
			if self.rayfieldDestroyed() then
				return
			end
			if not (self.Notifications and self.Notifications.Parent) then
				return
			end
	
			local template = self.Notifications:FindFirstChild("Template")
			local listLayout = self.Notifications:FindFirstChildOfClass("UIListLayout")
			if not (template and template:IsA("Frame") and listLayout) then
				return
			end
	
			-- Notification Object Creation
			local newNotification = template:Clone()
			newNotification.Name = data.Title or 'No Title Provided'
			newNotification.Parent = self.Notifications
			newNotification.LayoutOrder = #self.Notifications:GetChildren()
			newNotification.Visible = false
	
			local function isNotificationValid()
				return not self.rayfieldDestroyed()
					and newNotification
					and newNotification.Parent
					and self.Notifications
					and self.Notifications.Parent
					and listLayout
					and listLayout.Parent == self.Notifications
			end
	
			-- Set Data
			newNotification.Title.Text = data.Title or "Unknown Title"
			newNotification.Description.Text = data.Content or "Unknown Content"
	
			if data.Image then
				if typeof(data.Image) == 'string' and self.getIcon then
					local iconSuccess, asset = pcall(self.getIcon, data.Image)
					if iconSuccess and asset then
						newNotification.Icon.Image = 'rbxassetid://' .. tostring(asset.id or 0)
						newNotification.Icon.ImageRectOffset = asset.imageRectOffset or Vector2.new(0, 0)
						newNotification.Icon.ImageRectSize = asset.imageRectSize or Vector2.new(0, 0)
					else
						newNotification.Icon.Image = self.getAssetUri(data.Image)
					end
				else
					newNotification.Icon.Image = self.getAssetUri(data.Image)
				end
			else
				newNotification.Icon.Image = "rbxassetid://" .. 0
			end
	
			-- Set initial transparency values
	
			newNotification.Title.TextColor3 = self.getSelectedTheme().TextColor
			newNotification.Description.TextColor3 = self.getSelectedTheme().TextColor
			newNotification.BackgroundColor3 = self.getSelectedTheme().Background
			newNotification.UIStroke.Color = self.getSelectedTheme().TextColor
			newNotification.Icon.ImageColor3 = self.getSelectedTheme().TextColor
	
			newNotification.BackgroundTransparency = 1
			newNotification.Title.TextTransparency = 1
			newNotification.Description.TextTransparency = 1
			newNotification.UIStroke.Transparency = 1
			newNotification.Shadow.ImageTransparency = 1
			newNotification.Size = UDim2.new(1, 0, 0, 800)
			newNotification.Icon.ImageTransparency = 1
			newNotification.Icon.BackgroundTransparency = 1
	
			task.wait()
			if not isNotificationValid() then
				if newNotification and newNotification.Parent then
					newNotification:Destroy()
				end
				return
			end
	
			newNotification.Visible = true
	
			if data.Actions then
				warn('Rayfield | Not seeing your actions in notifications?')
				print("Notification Actions are being sunset for now, keep up to date on when they're back in the discord. (sirius.menu/discord)")
			end
	
			-- Calculate textbounds and set initial values
			local bounds = {newNotification.Title.TextBounds.Y, newNotification.Description.TextBounds.Y}
			local listPadding = -(listLayout.Padding.Offset)
			newNotification.Size = UDim2.new(1, -60, 0, listPadding)
	
			newNotification.Icon.Size = UDim2.new(0, 32, 0, 32)
			newNotification.Icon.Position = UDim2.new(0, 20, 0.5, 0)
	
			self.Animation:Create(newNotification, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, math.max(bounds[1] + bounds[2] + 31, 60))}):Play()
	
			task.wait(0.15)
			self.Animation:Create(newNotification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.45}):Play()
			self.Animation:Create(newNotification.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	
			task.wait(0.05)
	
			self.Animation:Create(newNotification.Icon, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
	
			task.wait(0.05)
			self.Animation:Create(newNotification.Description, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.35}):Play()
			self.Animation:Create(newNotification.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.95}):Play()
			self.Animation:Create(newNotification.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.82}):Play()
	
			local waitDuration = math.min(math.max((#newNotification.Description.Text * 0.1) + 2.5, 3), 10)
			task.wait(data.Duration or waitDuration)
			if not isNotificationValid() then
				if newNotification and newNotification.Parent then
					newNotification:Destroy()
				end
				return
			end
	
			newNotification.Icon.Visible = false
			self.Animation:Create(newNotification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
			self.Animation:Create(newNotification.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			self.Animation:Create(newNotification.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
			self.Animation:Create(newNotification.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			self.Animation:Create(newNotification.Description, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
	
			self.Animation:Create(newNotification, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -90, 0, 0)}):Play()
	
			task.wait(1)
			if not isNotificationValid() then
				if newNotification and newNotification.Parent then
					newNotification:Destroy()
				end
				return
			end
	
			self.Animation:Create(newNotification, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -90, 0, listPadding)}):Play()
	
			newNotification.Visible = false
			newNotification:Destroy()
		end)
	end
	
	local function openSearch()
		searchOpen = true
	
		self.Main.Search.BackgroundTransparency = 1
		self.Main.Search.Shadow.ImageTransparency = 1
		self.Main.Search.Input.TextTransparency = 1
		self.Main.Search.Search.ImageTransparency = 1
		self.Main.Search.UIStroke.Transparency = 1
		self.Main.Search.Size = UDim2.new(1, 0, 0, 80)
		self.Main.Search.Position = UDim2.new(0.5, 0, 0, 70)
	
		self.Main.Search.Input.Interactable = true
	
		self.Main.Search.Visible = true
	
		animateTabButtonsHidden(false)
	
		self.Main.Search.Input:CaptureFocus()
		self.Animation:Create(self.Main.Search.Shadow, TweenInfo.new(0.05, Enum.EasingStyle.Quint), {ImageTransparency = 0.95}):Play()
		self.Animation:Create(self.Main.Search, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5, 0, 0, 57), BackgroundTransparency = 0.9}):Play()
		self.Animation:Create(self.Main.Search.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.8}):Play()
		self.Animation:Create(self.Main.Search.Input, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
		self.Animation:Create(self.Main.Search.Search, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5}):Play()
		self.Animation:Create(self.Main.Search, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -35, 0, 35)}):Play()
	end
	
	local function closeSearch()
		searchOpen = false
	
		self.Animation:Create(self.Main.Search, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {BackgroundTransparency = 1, Size = UDim2.new(1, -55, 0, 30)}):Play()
		self.Animation:Create(self.Main.Search.Search, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
		self.Animation:Create(self.Main.Search.Shadow, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
		self.Animation:Create(self.Main.Search.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
		self.Animation:Create(self.Main.Search.Input, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	
		animateTabButtonsByCurrentPage(true)
	
		self.Main.Search.Input.Text = ''
		self.Main.Search.Input.Interactable = false
	end

	local function openActionCenter()
		ensureActionCenterButton()
		local refs = ensureActionCenterPanel()
		if not refs.Panel then
			return false, "Action Center unavailable."
		end
		if refs.FilterLevel then
			refs.FilterLevel.Text = "  Level: " .. tostring(notificationFilterLevel)
		end
		if refs.FilterInput then
			refs.FilterInput.Text = tostring(notificationFilterQuery or "")
		end
		refs.Panel.Visible = true
		actionCenterOpen = true
		markAllNotificationsRead()
		updateActionCenterBadge()
		renderActionCenterHistory()
		applyActionCenterTheme()
		self.Animation:Create(refs.Panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1, -8, 0, 45)}):Play()
		return true, "Action Center opened."
	end

	local function closeActionCenter()
		local refs = ensureActionCenterPanel()
		if not refs.Panel then
			return false, "Action Center unavailable."
		end
		actionCenterOpen = false
		self.Animation:Create(refs.Panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 12, 0, 45)}):Play()
		task.delay(0.22, function()
			if refs.Panel and refs.Panel.Parent and actionCenterOpen == false then
				refs.Panel.Visible = false
			end
		end)
		return true, "Action Center closed."
	end

	local function toggleActionCenter()
		if actionCenterOpen then
			return closeActionCenter()
		end
		return openActionCenter()
	end

	local function openCommandPalette(seedText)
		local refs = ensureCommandPaletteOverlay()
		if not refs.Overlay then
			return false, "Command palette unavailable."
		end
		refs.Overlay.Visible = true
		commandPaletteOpen = true
		local text = seedText ~= nil and tostring(seedText) or ""
		refs.Input.Text = text
		refreshCommandPaletteQuery()
		task.defer(function()
			if refs.Input and refs.Input.Parent and commandPaletteOpen then
				refs.Input:CaptureFocus()
			end
		end)
		return true, "Command palette opened."
	end

	local function closeCommandPalette()
		local refs = ensureCommandPaletteOverlay()
		if not refs.Overlay then
			return false, "Command palette unavailable."
		end
		commandPaletteOpen = false
		refs.Overlay.Visible = false
		commandPaletteResults = {}
		commandPaletteSelectionIndex = 0
		if refs.Input then
			refs.Input.Text = ""
		end
		return true, "Command palette closed."
	end

	local function toggleCommandPalette(seedText)
		if commandPaletteOpen then
			return closeCommandPalette()
		end
		return openCommandPalette(seedText)
	end

	local function ensureInspectorOverlay()
		if inspectorRefs.Root and inspectorRefs.Root.Parent then
			return inspectorRefs
		end
		if not self.Main then
			return inspectorRefs
		end

		local root = Instance.new("Frame")
		root.Name = "ElementInspectorOverlay"
		root.AnchorPoint = Vector2.new(1, 0)
		root.Position = UDim2.new(1, -10, 0, 50)
		root.Size = UDim2.new(0, 280, 0, 108)
		root.BackgroundTransparency = 0.08
		root.BorderSizePixel = 0
		root.ZIndex = 85
		root.Visible = inspectorOpen
		root.Parent = self.Main

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = root

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Transparency = 0.22
		stroke.Parent = root

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.new(0, 8, 0, 6)
		title.Size = UDim2.new(1, -16, 0, 18)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 12
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "Element Inspector"
		title.ZIndex = 86
		title.Parent = root

		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Position = UDim2.new(0, 8, 0, 28)
		body.Size = UDim2.new(1, -16, 1, -34)
		body.Font = Enum.Font.Code
		body.TextSize = 11
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.Text = "Hover an element to inspect."
		body.ZIndex = 86
		body.Parent = root

		inspectorRefs = {
			Root = root,
			Stroke = stroke,
			Title = title,
			Body = body
		}
		return inspectorRefs
	end

	local function applyInspectorTheme()
		local refs = ensureInspectorOverlay()
		if not refs.Root then
			return
		end
		refs.Root.BackgroundColor3 = getThemeValueOrDefault("Background", Color3.fromRGB(24, 24, 28))
		if refs.Stroke then
			refs.Stroke.Color = getThemeValueOrDefault("ElementStroke", Color3.fromRGB(92, 92, 96))
		end
		if refs.Title then
			refs.Title.TextColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(255, 255, 255))
		end
		if refs.Body then
			refs.Body.TextColor3 = getThemeValueOrDefault("TextColor", Color3.fromRGB(215, 215, 215))
		end
	end

	local function refreshInspectorOverlay()
		local refs = ensureInspectorOverlay()
		if not refs.Root then
			return
		end
		refs.Root.Visible = inspectorOpen == true
		if inspectorOpen ~= true then
			return
		end
		if not self.UserInputService then
			refs.Body.Text = "Pointer input unavailable."
			return
		end

		local okPointer, pointer = pcall(function()
			return self.UserInputService:GetMouseLocation()
		end)
		if not okPointer or not pointer then
			refs.Body.Text = "Pointer position unavailable."
			return
		end

		local okInspect, inspectResult = self.inspectElementAtPointer({
			x = pointer.X,
			y = pointer.Y
		})
		if okInspect and type(inspectResult) == "table" then
			lastInspectorSnapshot = inspectResult
			local valueText = tostring(inspectResult.value)
			if type(inspectResult.value) == "table" then
				valueText = "<table>"
			end
			refs.Body.Text = string.format(
				"ID: %s\nName: %s\nType: %s\nValue: %s",
				tostring(inspectResult.id or ""),
				tostring(inspectResult.name or ""),
				tostring(inspectResult.type or ""),
				valueText
			)
		else
			lastInspectorSnapshot = nil
			refs.Body.Text = "Hover an element to inspect."
		end
	end

	local function ensureInspectorLoop()
		if inspectorLoopRunning then
			return
		end
		inspectorLoopRunning = true
		task.spawn(function()
			while inspectorLoopRunning do
				if inspectorOpen and not self.rayfieldDestroyed() then
					refreshInspectorOverlay()
				end
				task.wait(0.12)
				if self.rayfieldDestroyed() then
					inspectorLoopRunning = false
				end
			end
		end)
	end

	local function setElementInspectorEnabled(enabled)
		local nextEnabled = enabled == true
		if self.setElementInspectorEnabled then
			local okSet, resultEnabled = pcall(self.setElementInspectorEnabled, nextEnabled)
			if okSet and type(resultEnabled) == "boolean" then
				nextEnabled = resultEnabled
			end
		end
		inspectorOpen = nextEnabled
		ensureInspectorOverlay()
		applyInspectorTheme()
		refreshInspectorOverlay()
		if inspectorOpen then
			ensureInspectorLoop()
		else
			inspectorLoopRunning = false
		end
		return true, inspectorOpen and "Element inspector enabled." or "Element inspector disabled."
	end

	local function toggleElementInspector()
		return setElementInspectorEnabled(not inspectorOpen)
	end

	local function hideContextMenu()
		local refs = ensureContextMenuHost()
		if refs.Root then
			refs.Root.Visible = false
		end
		if refs.Menu then
			refs.Menu.Visible = false
		end
		contextMenuOpen = false
		disconnectConnections(contextMenuConnections)
		return true, "Context menu hidden."
	end

	local function showContextMenu(items, anchor)
		local refs = ensureContextMenuHost()
		if not refs.Menu then
			return false, "Context menu unavailable."
		end
		if type(items) ~= "table" or #items == 0 then
			return false, "Context menu requires at least one item."
		end

		for _, child in ipairs(refs.Menu:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		local textColor = getThemeValueOrDefault("TextColor", Color3.fromRGB(255, 255, 255))
		local background = getThemeValueOrDefault("Background", Color3.fromRGB(28, 28, 32))
		local rowBackground = getThemeValueOrDefault("ElementBackground", Color3.fromRGB(38, 38, 42))
		refs.Menu.BackgroundColor3 = background
		if refs.MenuStroke then
			refs.MenuStroke.Color = getThemeValueOrDefault("ElementStroke", Color3.fromRGB(95, 95, 95))
		end

		local rowHeight = 26
		local topPadding = 6
		local totalHeight = topPadding
		for _, item in ipairs(items) do
			local row = Instance.new("TextButton")
			row.Name = tostring(item.id or item.actionId or item.label or "ContextItem")
			row.Size = UDim2.new(1, -8, 0, rowHeight)
			row.Position = UDim2.new(0, 4, 0, totalHeight)
			row.BackgroundColor3 = rowBackground
			row.BackgroundTransparency = 0.15
			row.BorderSizePixel = 0
			row.AutoButtonColor = true
			row.Font = Enum.Font.Gotham
			row.TextSize = 12
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextColor3 = textColor
			row.Text = "  " .. tostring(item.label or item.name or item.title or "Item")
			row.ZIndex = 82
			row.Parent = refs.Menu

			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 6)
			rowCorner.Parent = row

			row.MouseButton1Click:Connect(function()
				local callback = item.callback or item.onClick
				if type(callback) == "function" then
					pcall(callback, item)
				end
				hideContextMenu()
			end)
			totalHeight += rowHeight + 4
		end

		refs.Menu.Size = UDim2.fromOffset(190, math.max(34, totalHeight + 2))

		local anchorX = nil
		local anchorY = nil
		if type(anchor) == "table" then
			anchorX = tonumber(anchor.x or anchor.X)
			anchorY = tonumber(anchor.y or anchor.Y)
		end
		if (not anchorX or not anchorY) and self.UserInputService then
			local okMouse, mousePos = pcall(function()
				return self.UserInputService:GetMouseLocation()
			end)
			if okMouse then
				anchorX = mousePos.X
				anchorY = mousePos.Y
			end
		end
		if not anchorX then anchorX = 16 end
		if not anchorY then anchorY = 16 end

		local parentPos = self.Main.AbsolutePosition
		local localX = anchorX - parentPos.X
		local localY = anchorY - parentPos.Y
		local maxX = math.max(8, self.Main.AbsoluteSize.X - refs.Menu.AbsoluteSize.X - 8)
		local maxY = math.max(8, self.Main.AbsoluteSize.Y - refs.Menu.AbsoluteSize.Y - 8)
		localX = math.clamp(localX, 8, maxX)
		localY = math.clamp(localY, 8, maxY)

		refs.Menu.Position = UDim2.fromOffset(localX, localY)
		refs.Menu.Visible = true
		refs.Root.Visible = true
		contextMenuOpen = true

		if self.UserInputService then
			table.insert(contextMenuConnections, self.UserInputService.InputBegan:Connect(function(input, processed)
				if processed or not contextMenuOpen then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.MouseButton2
					or input.UserInputType == Enum.UserInputType.Touch then
					hideContextMenu()
				end
			end))
		end

		return true, "Context menu shown."
	end

	local function bindCommandPaletteUiSignals()
		local refs = ensureCommandPaletteOverlay()
		if not refs.Input then
			return
		end
		table.insert(commandPaletteConnections, refs.Input:GetPropertyChangedSignal("Text"):Connect(function()
			if commandPaletteOpen then
				refreshCommandPaletteQuery()
			end
		end))
		table.insert(commandPaletteConnections, refs.Input.FocusLost:Connect(function()
			if not commandPaletteOpen then
				return
			end
			task.delay(0.05, function()
				if commandPaletteOpen and refs.Input and (refs.Input.Text == "" or refs.Input:IsFocused() == false) then
					-- Keep palette open when user clicks result list.
				end
			end)
		end))
		if self.UserInputService then
			table.insert(commandPaletteConnections, self.UserInputService.InputBegan:Connect(function(input, processed)
				if processed or not commandPaletteOpen then
					return
				end
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end
				if input.KeyCode == Enum.KeyCode.Escape then
					closeCommandPalette()
					return
				end
				if input.KeyCode == Enum.KeyCode.Down then
					if #commandPaletteResults > 0 then
						commandPaletteSelectionIndex = math.min(#commandPaletteResults, commandPaletteSelectionIndex + 1)
						renderCommandPaletteResults()
					end
					return
				end
				if input.KeyCode == Enum.KeyCode.Up then
					if #commandPaletteResults > 0 then
						commandPaletteSelectionIndex = math.max(1, commandPaletteSelectionIndex - 1)
						renderCommandPaletteResults()
					end
					return
				end
				if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
					local selected = commandPaletteResults[commandPaletteSelectionIndex] or commandPaletteResults[1]
					if selected then
						local forcedMode = nil
						if isModifierDown("shift") then
							forcedMode = "execute"
						elseif isModifierDown("alt") then
							forcedMode = "ask"
						end
						local okAction, message, meta = self.onCommandPaletteSelect(selected, forcedMode, {
							trigger = "keyboard"
						})
						if not okAction and Notify then
							Notify({
								Title = "Command Palette",
								Content = tostring(message or "Command failed."),
								Duration = 3,
								Image = 4384402990
							})
						end
						if type(meta) == "table" and meta.keepPaletteOpen == true then
							return
						end
					end
					closeCommandPalette()
				end
			end))
		end
	end

	local function bindPaletteHotkey()
		if not self.UserInputService then
			return
		end
		table.insert(commandPaletteConnections, self.UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if isPaletteKeyMatch(input) then
				toggleCommandPalette()
			end
		end))
	end

	ensureActionCenterButton()
	ensureActionCenterPanel()
	applyActionCenterTheme()
	ensureCommandPaletteOverlay()
	bindCommandPaletteUiSignals()
	bindPaletteHotkey()
	ensureContextMenuHost()
	ensureInspectorOverlay()
	applyInspectorTheme()
	ensureInspectorLoop()
	if self.Main then
		table.insert(commandPaletteConnections, self.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			applyActionCenterTheme()
			renderCommandPaletteResults()
			applyInspectorTheme()
		end))
	end
	
	local function Hide(notify)
		if self.MPrompt then
			self.MPrompt.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
			self.MPrompt.Position = UDim2.new(0.5, 0, 0, -50)
			self.MPrompt.Size = UDim2.new(0, 40, 0, 10)
			self.MPrompt.BackgroundTransparency = 1
			self.MPrompt.Title.TextTransparency = 1
			self.MPrompt.Visible = true
		end
	
		task.spawn(closeSearch)
	
		Debounce = true
		if notify then
			if self.useMobilePrompt then
				Notify({Title = "Interface Hidden", Content = "The interface has been hidden, you can unhide the interface by tapping 'Show'.", Duration = 7, Image = 4400697855})
			else
				Notify({Title = "Interface Hidden", Content = "The interface has been hidden, you can unhide the interface by tapping " .. tostring(self.getSetting("General", "rayfieldOpen")) .. ".", Duration = 7, Image = 4400697855})
			end
		end

		playTween(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 470, 0, 0)})
		playTween(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 470, 0, 45)})
		playTween(self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(self.Topbar and self.Topbar:FindFirstChild("Divider"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(self.Topbar and self.Topbar:FindFirstChild("CornerRepair"), TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(self.Topbar and self.Topbar:FindFirstChild("Title"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1})
		playTween(self.Main and self.Main:FindFirstChild("Shadow") and self.Main.Shadow:FindFirstChild("Image"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
		playTween(self.Topbar and self.Topbar:FindFirstChild("UIStroke"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1})
		playTween(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
	
		if self.useMobilePrompt and self.MPrompt then
			self.Animation:Create(self.MPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 120, 0, 30), Position = UDim2.new(0.5, 0, 0, 20), BackgroundTransparency = 0.3}):Play()
			self.Animation:Create(self.MPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0.3}):Play()
		end
	
		if self.Topbar then
			for _, TopbarButton in ipairs(self.Topbar:GetChildren()) do
				if TopbarButton.ClassName == "ImageButton" then
					playTween(TopbarButton, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
				end
			end
		end
	
		animateTabButtonsHidden(nil)
	
		if self.dragInteract then
			self.dragInteract.Visible = false
		end
	
		animateElementFramesCollapsed(true)
	
		task.wait(0.5)
		self.Main.Visible = false
		Debounce = false
	end
	
	local function Maximise()
		Debounce = true
		if self.Topbar and self.Topbar:FindFirstChild("ChangeSize") then
			self.Topbar.ChangeSize.Image = "rbxassetid://" .. 10137941941
		end
	
		playTween(self.Topbar and self.Topbar:FindFirstChild("UIStroke"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1})
		playTween(self.Main and self.Main:FindFirstChild("Shadow") and self.Main.Shadow:FindFirstChild("Image"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6})
		playTween(self.Topbar and self.Topbar:FindFirstChild("CornerRepair"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(self.Topbar and self.Topbar:FindFirstChild("Divider"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7})
		playTween(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = getExpandedSize()})
		playTween(self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.fromOffset(getExpandedSize().X.Offset, 45)})
		if self.TabList then
			self.TabList.Visible = true
		end
		task.wait(0.2)
	
		if self.Elements then
			self.Elements.Visible = true
		end
	
		animateElementFramesCollapsed(false)
	
		task.wait(0.1)
	
		animateTabButtonsByCurrentPage(nil)
	
		task.wait(0.5)
		Debounce = false
	end
	
	
	local function Unhide()
		Debounce = true
		self.Main.Position = UDim2.new(0.5, 0, 0.5, 0)
		self.Main.Visible = true
		playTween(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = getExpandedSize()})
		playTween(self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.fromOffset(getExpandedSize().X.Offset, 45)})
		playTween(self.Main and self.Main:FindFirstChild("Shadow") and self.Main.Shadow:FindFirstChild("Image"), TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6})
		playTween(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(self.Topbar and self.Topbar:FindFirstChild("Divider"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(self.Topbar and self.Topbar:FindFirstChild("CornerRepair"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(self.Topbar and self.Topbar:FindFirstChild("Title"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0})
	
		if self.MPrompt then
			self.Animation:Create(self.MPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 40, 0, 10), Position = UDim2.new(0.5, 0, 0, -50), BackgroundTransparency = 1}):Play()
			self.Animation:Create(self.MPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
	
			task.spawn(function()
				task.wait(0.5)
				self.MPrompt.Visible = false
			end)
		end
	
		if Minimised then
			task.spawn(Maximise)
		end
	
		if self.dragBar then
			self.dragBar.Position = self.useMobileSizing
				and UDim2.new(0.5, 0, 0.5, self.dragOffsetMobile)
				or UDim2.new(0.5, 0, 0.5, self.dragOffset)
		end
	
		if self.dragInteract then
			self.dragInteract.Visible = true
		end
	
		if self.Topbar then
			for _, TopbarButton in ipairs(self.Topbar:GetChildren()) do
				if TopbarButton.ClassName == "ImageButton" then
					if TopbarButton.Name == 'Icon' then
						playTween(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0})
					else
						playTween(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8})
					end
				end
			end
		end
	
		animateTabButtonsByCurrentPage(nil)
	
		animateElementFramesCollapsed(false)
	
		playTween(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5})
	
		task.wait(0.5)
		Minimised = false
		Debounce = false
	end
	
	local function Minimise()
		Debounce = true
		if self.Topbar and self.Topbar:FindFirstChild("ChangeSize") then
			self.Topbar.ChangeSize.Image = "rbxassetid://" .. 11036884234
		end
	
		if self.Topbar and self.Topbar:FindFirstChild("UIStroke") then
			self.Topbar.UIStroke.Color = self.getSelectedTheme().ElementStroke
		end
	
		task.spawn(closeSearch)
	
		animateTabButtonsHidden(nil)
	
		animateElementFramesCollapsed(true)
	
		playTween(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
		playTween(self.Topbar and self.Topbar:FindFirstChild("UIStroke"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 0})
		playTween(self.Main and self.Main:FindFirstChild("Shadow") and self.Main.Shadow:FindFirstChild("Image"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
		playTween(self.Topbar and self.Topbar:FindFirstChild("CornerRepair"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(self.Topbar and self.Topbar:FindFirstChild("Divider"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 495, 0, 45)})
		playTween(self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 495, 0, 45)})
	
		task.wait(0.3)
	
		if self.Elements then
			self.Elements.Visible = false
		end
		if self.TabList then
			self.TabList.Visible = false
		end
	
		task.wait(0.2)
		Debounce = false
	end

	local function getLayoutSnapshot()
		local currentExpanded = getExpandedSize()
		return {
			position = {
				xScale = self.Main.Position.X.Scale,
				xOffset = self.Main.Position.X.Offset,
				yScale = self.Main.Position.Y.Scale,
				yOffset = self.Main.Position.Y.Offset
			},
			expandedSize = {
				xOffset = currentExpanded.X.Offset,
				yOffset = currentExpanded.Y.Offset
			},
			minimized = Minimised == true,
			hidden = Hidden == true
		}
	end

	local function applyLayoutSnapshot(layout)
		if type(layout) ~= "table" then
			return false
		end

		local expanded = layout.expandedSize
		if type(expanded) == "table" then
			setExpandedSize({
				xOffset = tonumber(expanded.xOffset) or tonumber(expanded.width),
				yOffset = tonumber(expanded.yOffset) or tonumber(expanded.height)
			})
		end

		applyExpandedSizeToFrames()

		local position = layout.position
		if type(position) == "table" then
			local xScale = tonumber(position.xScale) or self.Main.Position.X.Scale
			local xOffset = tonumber(position.xOffset) or self.Main.Position.X.Offset
			local yScale = tonumber(position.yScale) or self.Main.Position.Y.Scale
			local yOffset = tonumber(position.yOffset) or self.Main.Position.Y.Offset
			self.Main.Position = UDim2.new(xScale, xOffset, yScale, yOffset)
			clampMainToViewport()
		end

		local targetHidden = layout.hidden == true
		local targetMinimized = layout.minimized == true
		if targetHidden then
			Hidden = true
			Minimised = false
			self.Main.Visible = false
			if self.Elements then
				self.Elements.Visible = false
			end
			if self.TabList then
				self.TabList.Visible = false
			end
		elseif targetMinimized then
			Hidden = false
			Minimised = true
			self.Main.Visible = true
			self.Main.Size = UDim2.fromOffset(495, 45)
			self.Topbar.Size = UDim2.fromOffset(495, 45)
			if self.Elements then
				self.Elements.Visible = false
			end
			if self.TabList then
				self.TabList.Visible = false
			end
		else
			Hidden = false
			Minimised = false
			self.Main.Visible = true
			if self.Elements then
				self.Elements.Visible = true
			end
			if self.TabList then
				self.TabList.Visible = true
			end
			applyExpandedSizeToFrames()
		end

		return true
	end

	-- Export functions
	self.Notify = Notify
	self.openSearch = openSearch
	self.closeSearch = closeSearch
	self.OpenActionCenter = openActionCenter
	self.CloseActionCenter = closeActionCenter
	self.ToggleActionCenter = toggleActionCenter
	self.GetNotificationHistory = getNotificationHistory
	self.GetNotificationHistoryEx = getNotificationHistoryEx
	self.GetUnreadNotificationCount = getUnreadNotificationCount
	self.MarkAllNotificationsRead = function()
		markAllNotificationsRead()
		renderActionCenterHistory()
		return true, "Notifications marked as read."
	end
	self.ClearNotificationHistory = function()
		clearNotificationHistory()
		renderActionCenterHistory()
		return true, "Notification history cleared."
	end
	self.OpenCommandPalette = openCommandPalette
	self.CloseCommandPalette = closeCommandPalette
	self.ToggleCommandPalette = toggleCommandPalette
	self.ShowContextMenu = showContextMenu
	self.HideContextMenu = hideContextMenu
	self.SetElementInspectorEnabled = setElementInspectorEnabled
	self.ToggleElementInspector = toggleElementInspector
	self.IsElementInspectorEnabled = function()
		return inspectorOpen == true
	end
	self.GetElementInspectorSnapshot = function()
		return lastInspectorSnapshot
	end
	self.Hide = Hide
	self.Unhide = Unhide
	self.Maximise = Maximise
	self.Minimise = Minimise
	self.getSearchOpen = function() return searchOpen end
	self.getDebounce = function() return Debounce end
	self.setDebounce = function(value) Debounce = value end
	self.getMinimised = function() return Minimised end
	self.setMinimised = function(value) Minimised = value end
	self.getHidden = function() return Hidden end
	self.setHidden = function(value) Hidden = value end
	self.getExpandedSize = getExpandedSize
	self.setExpandedSize = setExpandedSize
	self.getLayoutSnapshot = getLayoutSnapshot
	self.applyLayoutSnapshot = applyLayoutSnapshot
	
	return self
end

return UIStateModule
