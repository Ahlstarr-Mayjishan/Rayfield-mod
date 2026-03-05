-- Rayfield UI State Management Module
-- Orchestrates notification/search/window managers and keeps inspector/context menu APIs.

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
	self.onResetPerformanceHUD = type(ctx.onResetPerformanceHUD) == "function" and ctx.onResetPerformanceHUD or nil
	self.getAudioFeedbackEnabled = type(ctx.getAudioFeedbackEnabled) == "function" and ctx.getAudioFeedbackEnabled or nil
	self.getPinBadgesVisible = type(ctx.getPinBadgesVisible) == "function" and ctx.getPinBadgesVisible or nil
	self.setElementInspectorEnabled = type(ctx.setElementInspectorEnabled) == "function" and ctx.setElementInspectorEnabled or nil
	self.getElementInspectorEnabled = type(ctx.getElementInspectorEnabled) == "function" and ctx.getElementInspectorEnabled or function()
		return false
	end
	self.inspectElementAtPointer = type(ctx.inspectElementAtPointer) == "function" and ctx.inspectElementAtPointer or function()
		return false, nil
	end
	self.localize = type(ctx.localize) == "function" and ctx.localize or function(_, fallback)
		return tostring(fallback or "")
	end

	local NotificationManagerModule = ctx.NotificationManagerModule
	local SearchEngineModule = ctx.SearchEngineModule
	local WindowManagerModule = ctx.WindowManagerModule

	if type(NotificationManagerModule) ~= "table" or type(NotificationManagerModule.create) ~= "function" then
		error("UIStateModule.init missing NotificationManagerModule")
	end
	if type(SearchEngineModule) ~= "table" or type(SearchEngineModule.create) ~= "function" then
		error("UIStateModule.init missing SearchEngineModule")
	end
	if type(WindowManagerModule) ~= "table" or type(WindowManagerModule.create) ~= "function" then
		error("UIStateModule.init missing WindowManagerModule")
	end

	local contextMenuOpen = false
	local contextMenuConnections = {}
	local contextMenuRefs = {}
	local inspectorOpen = self.getElementInspectorEnabled() == true
	local inspectorRefs = {}
	local inspectorLoopRunning = false
	local lastInspectorSnapshot = nil
	local uiConnections = {}

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

	local function L(key, fallback)
		local okValue, value = pcall(self.localize, key, fallback)
		if okValue and type(value) == "string" and value ~= "" then
			return value
		end
		return tostring(fallback or key or "")
	end

	local function getThemeValueOrDefault(key, fallback)
		local theme = self.getSelectedTheme and self.getSelectedTheme()
		if theme and theme[key] ~= nil then
			return theme[key]
		end
		return fallback
	end

	local notificationManager = NotificationManagerModule.create({
		Main = self.Main,
		Topbar = self.Topbar,
		Notifications = self.Notifications,
		Animation = self.Animation,
		getIcon = self.getIcon,
		getAssetUri = self.getAssetUri,
		getSelectedTheme = self.getSelectedTheme,
		rayfieldDestroyed = self.rayfieldDestroyed,
		onOpenSettingsTab = self.onOpenSettingsTab,
		onToggleAudioFeedback = self.onToggleAudioFeedback,
		onTogglePinBadges = self.onTogglePinBadges,
		onToggleVisibility = self.onToggleVisibility,
		onTogglePerformanceHUD = self.onTogglePerformanceHUD,
		onResetPerformanceHUD = self.onResetPerformanceHUD,
		localize = self.localize,
		playTween = playTween
	})

	local searchEngine = SearchEngineModule.create({
		Main = self.Main,
		Animation = self.Animation,
		UserInputService = self.UserInputService,
		onCommandPaletteQuery = self.onCommandPaletteQuery,
		onCommandPaletteSelect = self.onCommandPaletteSelect,
		localize = self.localize,
		notify = function(data)
			notificationManager.notify(data)
		end,
		animateTabButtonsHidden = animateTabButtonsHidden,
		animateTabButtonsByCurrentPage = animateTabButtonsByCurrentPage,
		getThemeValueOrDefault = getThemeValueOrDefault,
		playTween = playTween
	})

	local windowManager = WindowManagerModule.create({
		Main = self.Main,
		Topbar = self.Topbar,
		TabList = self.TabList,
		Elements = self.Elements,
		MPrompt = self.MPrompt,
		dragInteract = self.dragInteract,
		dragBarCosmetic = self.dragBarCosmetic,
		dragBar = self.dragBar,
		dragOffset = self.dragOffset,
		dragOffsetMobile = self.dragOffsetMobile,
		getSelectedTheme = self.getSelectedTheme,
		getSetting = self.getSetting,
		useMobileSizing = self.useMobileSizing,
		useMobilePrompt = self.useMobilePrompt,
		closeSearch = function()
			searchEngine.closeSearch()
		end,
		notify = function(data)
			notificationManager.notify(data)
		end,
		animateTabButtonsHidden = animateTabButtonsHidden,
		animateTabButtonsByCurrentPage = animateTabButtonsByCurrentPage,
		animateElementFramesCollapsed = animateElementFramesCollapsed,
		playTween = playTween,
		Animation = self.Animation
	})

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

	notificationManager.initialize()
	searchEngine.initialize()
	ensureContextMenuHost()
	ensureInspectorOverlay()
	applyInspectorTheme()
	ensureInspectorLoop()

	if self.Main then
		table.insert(uiConnections, self.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			notificationManager.onThemeChanged()
			searchEngine.onThemeChanged()
			applyInspectorTheme()
		end))
	end

	self.Notify = function(data)
		notificationManager.notify(data)
	end
	self.openSearch = searchEngine.openSearch
	self.closeSearch = searchEngine.closeSearch
	self.OpenActionCenter = notificationManager.openActionCenter
	self.CloseActionCenter = notificationManager.closeActionCenter
	self.ToggleActionCenter = notificationManager.toggleActionCenter
	self.GetNotificationHistory = notificationManager.getNotificationHistory
	self.GetNotificationHistoryEx = notificationManager.getNotificationHistoryEx
	self.GetUnreadNotificationCount = notificationManager.getUnreadNotificationCount
	self.MarkAllNotificationsRead = function()
		notificationManager.markAllNotificationsRead()
		notificationManager.renderActionCenterHistory()
		return true, L("notifications.marked_read", "Notifications marked as read.")
	end
	self.ClearNotificationHistory = function()
		notificationManager.clearNotificationHistory()
		notificationManager.renderActionCenterHistory()
		return true, L("notifications.history_cleared", "Notification history cleared.")
	end
	self.OpenCommandPalette = searchEngine.openCommandPalette
	self.CloseCommandPalette = searchEngine.closeCommandPalette
	self.ToggleCommandPalette = searchEngine.toggleCommandPalette
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
	self.Hide = windowManager.Hide
	self.Unhide = windowManager.Unhide
	self.Maximise = windowManager.Maximise
	self.Minimise = windowManager.Minimise
	self.getSearchOpen = searchEngine.getSearchOpen
	self.getDebounce = windowManager.getDebounce
	self.setDebounce = windowManager.setDebounce
	self.getMinimised = windowManager.getMinimised
	self.setMinimised = windowManager.setMinimised
	self.getHidden = windowManager.getHidden
	self.setHidden = windowManager.setHidden
	self.getExpandedSize = windowManager.getExpandedSize
	self.setExpandedSize = windowManager.setExpandedSize
	self.getLayoutSnapshot = windowManager.getLayoutSnapshot
	self.applyLayoutSnapshot = windowManager.applyLayoutSnapshot
	self.destroy = function()
		searchEngine.destroy()
		disconnectConnections(contextMenuConnections)
		disconnectConnections(uiConnections)
		inspectorLoopRunning = false
	end

	return self
end

return UIStateModule
