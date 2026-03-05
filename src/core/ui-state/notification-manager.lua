local NotificationManager = {}

function NotificationManager.create(ctx)
	ctx = type(ctx) == "table" and ctx or {}

	local manager = {}
	local Main = ctx.Main
	local Topbar = ctx.Topbar
	local Notifications = ctx.Notifications
	local Animation = ctx.Animation
	local getIcon = ctx.getIcon
	local getAssetUri = ctx.getAssetUri
	local getSelectedTheme = ctx.getSelectedTheme
	local rayfieldDestroyed = ctx.rayfieldDestroyed
	local onOpenSettingsTab = ctx.onOpenSettingsTab
	local onToggleAudioFeedback = ctx.onToggleAudioFeedback
	local onTogglePinBadges = ctx.onTogglePinBadges
	local onToggleVisibility = ctx.onToggleVisibility
	local onTogglePerformanceHUD = ctx.onTogglePerformanceHUD
	local onResetPerformanceHUD = ctx.onResetPerformanceHUD
	local localize = ctx.localize
	local playTween = ctx.playTween

	if type(playTween) ~= "function" then
		playTween = function(instance, tweenInfo, properties)
			if instance and Animation then
				Animation:Create(instance, tweenInfo, properties):Play()
			end
		end
	end

	if type(getAssetUri) ~= "function" then
		getAssetUri = function(id)
			return "rbxassetid://" .. tostring(type(id) == "number" and id or 0)
		end
	end

	if type(getSelectedTheme) ~= "function" then
		getSelectedTheme = function()
			return {}
		end
	end

	if type(rayfieldDestroyed) ~= "function" then
		rayfieldDestroyed = function()
			return false
		end
	end

	if type(localize) ~= "function" then
		localize = function(_, fallback)
			return tostring(fallback or "")
		end
	end

	local actionCenterOpen = false
	local actionCenterRefs = {}
	local topbarActionCenterButton = nil
	local topbarActionCenterBadge = nil
	local notificationHistory = {}
	local notificationUnreadCount = 0
	local historyMaxEntries = math.max(
		5,
		math.floor(tonumber(type(_G) == "table" and _G.__RAYFIELD_ACTION_CENTER_MAX_HISTORY or 20) or 20)
	)
	local notificationFilterLevel = "all"
	local notificationFilterQuery = ""

	local renderActionCenterHistory
	local openActionCenter
	local closeActionCenter
	local Notify

	local function lowerText(value)
		return string.lower(tostring(value or ""))
	end

	local function L(key, fallback)
		local okValue, value = pcall(localize, key, fallback)
		if okValue and type(value) == "string" and value ~= "" then
			return value
		end
		return tostring(fallback or key or "")
	end

	local function getThemeValueOrDefault(key, fallback)
		local theme = getSelectedTheme and getSelectedTheme()
		if theme and theme[key] ~= nil then
			return theme[key]
		end
		return fallback
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
		if not Topbar then
			return nil
		end

		local button = Instance.new("ImageButton")
		button.Name = "ActionCenter"
		button.Size = UDim2.fromOffset(18, 18)
		button.AnchorPoint = Vector2.new(0, 0.5)
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Image = getAssetUri(4483362458)
		button.ImageTransparency = 0.8
		button.Parent = Topbar

		local hideButton = Topbar:FindFirstChild("Hide")
		if hideButton and hideButton:IsA("GuiObject") then
			button.Position = UDim2.new(
				hideButton.Position.X.Scale,
				hideButton.Position.X.Offset - 30,
				hideButton.Position.Y.Scale,
				hideButton.Position.Y.Offset
			)
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
				closeActionCenter()
			else
				openActionCenter()
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
		if not Main then
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
		panel.Parent = Main

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
		title.Text = L("action_center.title", "Action Center")
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
		unread.Text = L("action_center.unread", "Unread: 0")
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
		filterLevel.Text = "  " .. L("action_center.filter.level", "Level") .. ": all"
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
		filterInput.PlaceholderText = L("action_center.filter.placeholder", "Filter text...")
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
		actionsHolder.Size = UDim2.new(1, -24, 0, 138)
		actionsHolder.Parent = panel

		local actionsLayout = Instance.new("UIListLayout")
		actionsLayout.Padding = UDim.new(0, 6)
		actionsLayout.Parent = actionsHolder

		local historyList = Instance.new("ScrollingFrame")
		historyList.Name = "History"
		historyList.BackgroundTransparency = 1
		historyList.Position = UDim2.new(0, 12, 0, 222)
		historyList.Size = UDim2.new(1, -24, 1, -234)
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
					Notify({
						Title = L("action_center.title", "Action Center"),
						Content = tostring(resultA),
						Duration = 3
					})
					return
				end
				local success = resultA == true or resultA == nil
				local message = resultB or resultA or L("action_center.action_completed", "Action completed.")
				Notify({
					Title = L("action_center.title", "Action Center"),
					Content = tostring(message),
					Duration = 2,
					Image = success and 4483362458 or 4384402990
				})
			end)
			return button
		end

		makeQuickAction(L("action_center.quick.toggle_audio", "Toggle Audio Feedback"), function()
			if type(onToggleAudioFeedback) ~= "function" then
				return false, "Audio feedback handler unavailable."
			end
			return onToggleAudioFeedback()
		end)
		makeQuickAction(L("action_center.quick.toggle_pin_badges", "Toggle Pin Badges"), function()
			if type(onTogglePinBadges) ~= "function" then
				return false, "Pin badge handler unavailable."
			end
			return onTogglePinBadges()
		end)
		makeQuickAction(L("action_center.quick.toggle_visibility", "Hide/Show Interface"), function()
			if type(onToggleVisibility) ~= "function" then
				return false, "Visibility handler unavailable."
			end
			return onToggleVisibility()
		end)
		makeQuickAction(L("palette.cmd.open_settings.name", "Open Settings"), function()
			if type(onOpenSettingsTab) ~= "function" then
				return false, "Settings handler unavailable."
			end
			return onOpenSettingsTab()
		end)
		makeQuickAction(L("palette.cmd.toggle_performance_hud.name", "Toggle Performance HUD"), function()
			if type(onTogglePerformanceHUD) == "function" then
				return onTogglePerformanceHUD()
			end
			return false, "Performance HUD handler unavailable."
		end)
		makeQuickAction(L("palette.cmd.reset_performance_hud_position.name", "Reset HUD Position"), function()
			if type(onResetPerformanceHUD) == "function" then
				return onResetPerformanceHUD()
			end
			return false, "Performance HUD reset handler unavailable."
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
			filterLevel.Text = "  " .. L("action_center.filter.level", "Level") .. ": " .. tostring(notificationFilterLevel)
			renderActionCenterHistory()
		end)

		filterInput:GetPropertyChangedSignal("Text"):Connect(function()
			notificationFilterQuery = tostring(filterInput.Text or "")
			renderActionCenterHistory()
		end)

		return actionCenterRefs
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

	function renderActionCenterHistory()
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
			refs.Unread.Text = string.format(
				L("action_center.unread_total", "Unread: %d  |  Total: %d"),
				notificationUnreadCount,
				#notificationHistory
			)
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

		local timestamp = type(os.date) == "function" and os.date("%H:%M:%S") or tostring(os.clock())
		local entry = {
			id = tostring(type(os.clock) == "function" and math.floor(os.clock() * 1000000) or math.random(100000, 999999)),
			title = title,
			content = content,
			image = type(data) == "table" and data.Image or nil,
			timestamp = timestamp,
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

	Notify = function(data)
		pushNotificationHistory(data)
		task.spawn(function()
			data = type(data) == "table" and data or {}
			if rayfieldDestroyed() then
				return
			end
			if not (Notifications and Notifications.Parent) then
				return
			end

			local template = Notifications:FindFirstChild("Template")
			local listLayout = Notifications:FindFirstChildOfClass("UIListLayout")
			if not (template and template:IsA("Frame") and listLayout) then
				return
			end

			local newNotification = template:Clone()
			newNotification.Name = data.Title or "No Title Provided"
			newNotification.Parent = Notifications
			newNotification.LayoutOrder = #Notifications:GetChildren()
			newNotification.Visible = false

			local function isNotificationValid()
				return not rayfieldDestroyed()
					and newNotification
					and newNotification.Parent
					and Notifications
					and Notifications.Parent
					and listLayout
					and listLayout.Parent == Notifications
			end

			newNotification.Title.Text = data.Title or "Unknown Title"
			newNotification.Description.Text = data.Content or "Unknown Content"

			if data.Image then
				if typeof(data.Image) == "string" and type(getIcon) == "function" then
					local iconSuccess, asset = pcall(getIcon, data.Image)
					if iconSuccess and asset then
						newNotification.Icon.Image = "rbxassetid://" .. tostring(asset.id or 0)
						newNotification.Icon.ImageRectOffset = asset.imageRectOffset or Vector2.new(0, 0)
						newNotification.Icon.ImageRectSize = asset.imageRectSize or Vector2.new(0, 0)
					else
						newNotification.Icon.Image = getAssetUri(data.Image)
					end
				else
					newNotification.Icon.Image = getAssetUri(data.Image)
				end
			else
				newNotification.Icon.Image = "rbxassetid://0"
			end

			local selectedTheme = getSelectedTheme() or {}
			newNotification.Title.TextColor3 = selectedTheme.TextColor or Color3.fromRGB(255, 255, 255)
			newNotification.Description.TextColor3 = selectedTheme.TextColor or Color3.fromRGB(255, 255, 255)
			newNotification.BackgroundColor3 = selectedTheme.Background or Color3.fromRGB(24, 24, 24)
			newNotification.UIStroke.Color = selectedTheme.TextColor or Color3.fromRGB(255, 255, 255)
			newNotification.Icon.ImageColor3 = selectedTheme.TextColor or Color3.fromRGB(255, 255, 255)

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
				warn("Rayfield | Not seeing your actions in notifications?")
				print("Notification Actions are being sunset for now, keep up to date on when they're back in the discord. (sirius.menu/discord)")
			end

			local bounds = { newNotification.Title.TextBounds.Y, newNotification.Description.TextBounds.Y }
			local listPadding = -(listLayout.Padding.Offset)
			newNotification.Size = UDim2.new(1, -60, 0, listPadding)

			newNotification.Icon.Size = UDim2.new(0, 32, 0, 32)
			newNotification.Icon.Position = UDim2.new(0, 20, 0.5, 0)

			Animation:Create(newNotification, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
				Size = UDim2.new(1, 0, 0, math.max(bounds[1] + bounds[2] + 31, 60))
			}):Play()

			task.wait(0.15)
			Animation:Create(newNotification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.45}):Play()
			Animation:Create(newNotification.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

			task.wait(0.05)
			Animation:Create(newNotification.Icon, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()

			task.wait(0.05)
			Animation:Create(newNotification.Description, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.35}):Play()
			Animation:Create(newNotification.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.95}):Play()
			Animation:Create(newNotification.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.82}):Play()

			local waitDuration = math.min(math.max((#newNotification.Description.Text * 0.1) + 2.5, 3), 10)
			task.wait(data.Duration or waitDuration)
			if not isNotificationValid() then
				if newNotification and newNotification.Parent then
					newNotification:Destroy()
				end
				return
			end

			newNotification.Icon.Visible = false
			Animation:Create(newNotification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
			Animation:Create(newNotification.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			Animation:Create(newNotification.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
			Animation:Create(newNotification.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			Animation:Create(newNotification.Description, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()

			Animation:Create(newNotification, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -90, 0, 0)}):Play()

			task.wait(1)
			if not isNotificationValid() then
				if newNotification and newNotification.Parent then
					newNotification:Destroy()
				end
				return
			end

			Animation:Create(newNotification, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -90, 0, listPadding)}):Play()

			newNotification.Visible = false
			newNotification:Destroy()
		end)
	end

	openActionCenter = function()
		ensureActionCenterButton()
		local refs = ensureActionCenterPanel()
		if not refs.Panel then
			return false, "Action Center unavailable."
		end
		if refs.FilterLevel then
			refs.FilterLevel.Text = "  " .. L("action_center.filter.level", "Level") .. ": " .. tostring(notificationFilterLevel)
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
		playTween(refs.Panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1, -8, 0, 45)})
		return true, L("action_center.status.opened", "Action Center opened.")
	end

	closeActionCenter = function()
		local refs = ensureActionCenterPanel()
		if not refs.Panel then
			return false, "Action Center unavailable."
		end
		actionCenterOpen = false
		playTween(refs.Panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 12, 0, 45)})
		task.delay(0.22, function()
			if refs.Panel and refs.Panel.Parent and actionCenterOpen == false then
				refs.Panel.Visible = false
			end
		end)
		return true, L("action_center.status.closed", "Action Center closed.")
	end

	local function toggleActionCenter()
		if actionCenterOpen then
			return closeActionCenter()
		end
		return openActionCenter()
	end

	function manager.initialize()
		ensureActionCenterButton()
		ensureActionCenterPanel()
		applyActionCenterTheme()
	end

	function manager.onThemeChanged()
		applyActionCenterTheme()
	end

	function manager.notify(data)
		Notify(data)
	end

	manager.openActionCenter = openActionCenter
	manager.closeActionCenter = closeActionCenter
	manager.toggleActionCenter = toggleActionCenter
	manager.getNotificationHistory = getNotificationHistory
	manager.getNotificationHistoryEx = getNotificationHistoryEx
	manager.getUnreadNotificationCount = getUnreadNotificationCount
	manager.markAllNotificationsRead = markAllNotificationsRead
	manager.clearNotificationHistory = clearNotificationHistory
	manager.renderActionCenterHistory = renderActionCenterHistory
	manager.applyActionCenterTheme = applyActionCenterTheme
	manager.isActionCenterOpen = function()
		return actionCenterOpen == true
	end

	return manager
end

return NotificationManager
