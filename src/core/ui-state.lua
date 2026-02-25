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

	-- Module state
	local searchOpen = false
	local Debounce = false
	local Minimised = false
	local Hidden = false
	local expandedSize = self.useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475)

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

	-- Extract code starts here

	local function Notify(data) -- action e.g open messages
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
