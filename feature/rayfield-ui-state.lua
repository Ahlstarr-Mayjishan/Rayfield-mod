-- Rayfield UI State Management Module
-- Handles notifications, search, hide/show, minimize/maximize

local UIStateModule = {}

function UIStateModule.init(ctx)
	local self = {}

	-- Inject dependencies
	self.TweenService = ctx.TweenService
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.TabList = ctx.TabList
	self.Elements = ctx.Elements
	self.Notifications = ctx.Notifications
	self.MPrompt = ctx.MPrompt
	self.dragInteract = ctx.dragInteract
	self.dragBarCosmetic = ctx.dragBarCosmetic
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

	-- Forward declare functions
	local closeSearch

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
				if typeof(data.Image) == 'string' and Icons then
					local asset = self.getIcon(data.Image)
	
					newNotification.Icon.Image = 'rbxassetid://'..asset.id
					newNotification.Icon.ImageRectOffset = asset.imageRectOffset
					newNotification.Icon.ImageRectSize = asset.imageRectSize
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
	
			self.TweenService:Create(newNotification, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, math.max(bounds[1] + bounds[2] + 31, 60))}):Play()
	
			task.wait(0.15)
			self.TweenService:Create(newNotification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.45}):Play()
			self.TweenService:Create(newNotification.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	
			task.wait(0.05)
	
			self.TweenService:Create(newNotification.Icon, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
	
			task.wait(0.05)
			self.TweenService:Create(newNotification.Description, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.35}):Play()
			self.TweenService:Create(newNotification.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0.95}):Play()
			self.TweenService:Create(newNotification.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.82}):Play()
	
			local waitDuration = math.min(math.max((#newNotification.Description.Text * 0.1) + 2.5, 3), 10)
			task.wait(data.Duration or waitDuration)
			if not isNotificationValid() then
				if newNotification and newNotification.Parent then
					newNotification:Destroy()
				end
				return
			end
	
			newNotification.Icon.Visible = false
			self.TweenService:Create(newNotification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
			self.TweenService:Create(newNotification.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			self.TweenService:Create(newNotification.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
			self.TweenService:Create(newNotification.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			self.TweenService:Create(newNotification.Description, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
	
			self.TweenService:Create(newNotification, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -90, 0, 0)}):Play()
	
			task.wait(1)
			if not isNotificationValid() then
				if newNotification and newNotification.Parent then
					newNotification:Destroy()
				end
				return
			end
	
			self.TweenService:Create(newNotification, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -90, 0, listPadding)}):Play()
	
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
	
		for _, tabbtn in ipairs(self.TabList:GetChildren()) do
			if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
				tabbtn.Interact.Visible = false
				self.TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
				self.TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
				self.TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
				self.TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			end
		end
	
		self.Main.Search.Input:CaptureFocus()
		self.TweenService:Create(self.Main.Search.Shadow, TweenInfo.new(0.05, Enum.EasingStyle.Quint), {ImageTransparency = 0.95}):Play()
		self.TweenService:Create(self.Main.Search, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5, 0, 0, 57), BackgroundTransparency = 0.9}):Play()
		self.TweenService:Create(self.Main.Search.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.8}):Play()
		self.TweenService:Create(self.Main.Search.Input, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
		self.TweenService:Create(self.Main.Search.Search, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5}):Play()
		self.TweenService:Create(self.Main.Search, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -35, 0, 35)}):Play()
	end
	
	local function closeSearch()
		searchOpen = false
	
		self.TweenService:Create(self.Main.Search, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {BackgroundTransparency = 1, Size = UDim2.new(1, -55, 0, 30)}):Play()
		self.TweenService:Create(self.Main.Search.Search, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
		self.TweenService:Create(self.Main.Search.Shadow, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
		self.TweenService:Create(self.Main.Search.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
		self.TweenService:Create(self.Main.Search.Input, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	
		for _, tabbtn in ipairs(self.TabList:GetChildren()) do
			if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
				tabbtn.Interact.Visible = true
				if tostring(self.Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
					self.TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
					self.TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
					self.TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
					self.TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
				else
					self.TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
					self.TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
					self.TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
					self.TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
				end
			end
		end
	
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

		self.TweenService:Create(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 470, 0, 0)}):Play()
		self.TweenService:Create(self.Main.self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 470, 0, 45)}):Play()
		self.TweenService:Create(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		self.TweenService:Create(self.Main.self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		self.TweenService:Create(self.Main.self.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		self.TweenService:Create(self.Main.self.Topbar.CornerRepair, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		self.TweenService:Create(self.Main.self.Topbar.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
		self.TweenService:Create(self.Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
		self.TweenService:Create(self.Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
		self.TweenService:Create(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
	
		if self.useMobilePrompt and self.MPrompt then
			self.TweenService:Create(self.MPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 120, 0, 30), Position = UDim2.new(0.5, 0, 0, 20), BackgroundTransparency = 0.3}):Play()
			self.TweenService:Create(self.MPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0.3}):Play()
		end
	
		for _, TopbarButton in ipairs(self.Topbar:GetChildren()) do
			if TopbarButton.ClassName == "ImageButton" then
				self.TweenService:Create(TopbarButton, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
			end
		end
	
		for _, tabbtn in ipairs(self.TabList:GetChildren()) do
			if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
				self.TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
				self.TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
				self.TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
				self.TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			end
		end
	
		self.dragInteract.Visible = false
	
		for _, tab in ipairs(self.Elements:GetChildren()) do
			if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
				for _, element in ipairs(tab:GetChildren()) do
					if element.ClassName == "Frame" then
						if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
							if element.Name == "SectionTitle" or element.Name == 'SearchTitle-fsefsefesfsefesfesfThanks' then
								self.TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
							elseif element.Name == 'Divider' then
								self.TweenService:Create(element.Divider, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
							else
								self.TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
								self.TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
								self.TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
							end
							for _, child in ipairs(element:GetChildren()) do
								if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
									child.Visible = false
								end
							end
						end
					end
				end
			end
		end
	
		task.wait(0.5)
		self.Main.Visible = false
		Debounce = false
	end
	
	local function Maximise()
		Debounce = true
		self.Topbar.ChangeSize.Image = "rbxassetid://"..10137941941
	
		self.TweenService:Create(self.Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
		self.TweenService:Create(self.Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6}):Play()
		self.TweenService:Create(self.Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		self.TweenService:Create(self.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		self.TweenService:Create(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7}):Play()
		self.TweenService:Create(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = self.useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475)}):Play()
		self.TweenService:Create(self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 500, 0, 45)}):Play()
		self.TabList.Visible = true
		task.wait(0.2)
	
		self.Elements.Visible = true
	
		for _, tab in ipairs(self.Elements:GetChildren()) do
			if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
				for _, element in ipairs(tab:GetChildren()) do
					if element.ClassName == "Frame" then
						if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
							if element.Name == "SectionTitle" or element.Name == 'SearchTitle-fsefsefesfsefesfesfThanks' then
								self.TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.4}):Play()
							elseif element.Name == 'Divider' then
								self.TweenService:Create(element.Divider, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.85}):Play()
							else
								self.TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
								self.TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
								self.TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
							end
							for _, child in ipairs(element:GetChildren()) do
								if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
									child.Visible = true
								end
							end
						end
					end
				end
			end
		end
	
		task.wait(0.1)
	
		for _, tabbtn in ipairs(self.TabList:GetChildren()) do
			if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
				if tostring(self.Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
					self.TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
					self.TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
					self.TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
					self.TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
				else
					self.TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
					self.TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
					self.TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
					self.TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
				end
	
			end
		end
	
		task.wait(0.5)
		Debounce = false
	end
	
	
	local function Unhide()
		Debounce = true
		self.Main.Position = UDim2.new(0.5, 0, 0.5, 0)
		self.Main.Visible = true
		self.TweenService:Create(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = self.useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475)}):Play()
		self.TweenService:Create(self.Main.self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 500, 0, 45)}):Play()
		self.TweenService:Create(self.Main.Shadow.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6}):Play()
		self.TweenService:Create(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		self.TweenService:Create(self.Main.self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		self.TweenService:Create(self.Main.self.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		self.TweenService:Create(self.Main.self.Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		self.TweenService:Create(self.Main.self.Topbar.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	
		if self.MPrompt then
			self.TweenService:Create(self.MPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 40, 0, 10), Position = UDim2.new(0.5, 0, 0, -50), BackgroundTransparency = 1}):Play()
			self.TweenService:Create(self.MPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
	
			task.spawn(function()
				task.wait(0.5)
				self.MPrompt.Visible = false
			end)
		end
	
		if Minimised then
			task.spawn(Maximise)
		end
	
		dragBar.Position = self.useMobileSizing and UDim2.new(0.5, 0, 0.5, dragOffsetMobile) or UDim2.new(0.5, 0, 0.5, dragOffset)
	
		self.dragInteract.Visible = true
	
		for _, TopbarButton in ipairs(self.Topbar:GetChildren()) do
			if TopbarButton.ClassName == "ImageButton" then
				if TopbarButton.Name == 'Icon' then
					self.TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
				else
					self.TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8}):Play()
				end
	
			end
		end
	
		for _, tabbtn in ipairs(self.TabList:GetChildren()) do
			if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
				if tostring(self.Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
					self.TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
					self.TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
					self.TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
					self.TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
				else
					self.TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
					self.TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
					self.TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
					self.TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
				end
			end
		end
	
		for _, tab in ipairs(self.Elements:GetChildren()) do
			if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
				for _, element in ipairs(tab:GetChildren()) do
					if element.ClassName == "Frame" then
						if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
							if element.Name == "SectionTitle" or element.Name == 'SearchTitle-fsefsefesfsefesfesfThanks' then
								self.TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.4}):Play()
							elseif element.Name == 'Divider' then
								self.TweenService:Create(element.Divider, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.85}):Play()
							else
								self.TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
								self.TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
								self.TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
							end
							for _, child in ipairs(element:GetChildren()) do
								if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
									child.Visible = true
								end
							end
						end
					end
				end
			end
		end
	
		self.TweenService:Create(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5}):Play()
	
		task.wait(0.5)
		Minimised = false
		Debounce = false
	end
	
	local function Minimise()
		Debounce = true
		self.Topbar.ChangeSize.Image = "rbxassetid://"..11036884234
	
		self.Topbar.UIStroke.Color = self.getSelectedTheme().ElementStroke
	
		task.spawn(closeSearch)
	
		for _, tabbtn in ipairs(self.TabList:GetChildren()) do
			if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
				self.TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
				self.TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
				self.TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
				self.TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			end
		end
	
		for _, tab in ipairs(self.Elements:GetChildren()) do
			if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
				for _, element in ipairs(tab:GetChildren()) do
					if element.ClassName == "Frame" then
						if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
							if element.Name == "SectionTitle" or element.Name == 'SearchTitle-fsefsefesfsefesfesfThanks' then
								self.TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
							elseif element.Name == 'Divider' then
								self.TweenService:Create(element.Divider, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
							else
								self.TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
								self.TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
								self.TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
							end
							for _, child in ipairs(element:GetChildren()) do
								if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
									child.Visible = false
								end
							end
						end
					end
				end
			end
		end
	
		self.TweenService:Create(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
		self.TweenService:Create(self.Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
		self.TweenService:Create(self.Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
		self.TweenService:Create(self.Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		self.TweenService:Create(self.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		self.TweenService:Create(self.Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 495, 0, 45)}):Play()
		self.TweenService:Create(self.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 495, 0, 45)}):Play()
	
		task.wait(0.3)
	
		self.Elements.Visible = false
		self.TabList.Visible = false
	
		task.wait(0.2)
		Debounce = false
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
	
	return self
end

return UIStateModule
