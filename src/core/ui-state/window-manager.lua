local WindowManager = {}

function WindowManager.create(ctx)
	ctx = type(ctx) == "table" and ctx or {}

	local manager = {}
	local Main = ctx.Main
	local Topbar = ctx.Topbar
	local TabList = ctx.TabList
	local Elements = ctx.Elements
	local MPrompt = ctx.MPrompt
	local dragInteract = ctx.dragInteract
	local dragBarCosmetic = ctx.dragBarCosmetic
	local dragBar = ctx.dragBar
	local dragOffset = ctx.dragOffset
	local dragOffsetMobile = ctx.dragOffsetMobile
	local getSelectedTheme = type(ctx.getSelectedTheme) == "function" and ctx.getSelectedTheme or function()
		return {}
	end
	local getSetting = type(ctx.getSetting) == "function" and ctx.getSetting or function()
		return "Unknown"
	end
	local useMobileSizing = ctx.useMobileSizing == true
	local useMobilePrompt = ctx.useMobilePrompt == true
	local closeSearch = type(ctx.closeSearch) == "function" and ctx.closeSearch or function() end
	local notify = type(ctx.notify) == "function" and ctx.notify or function() end
	local animateTabButtonsHidden = type(ctx.animateTabButtonsHidden) == "function" and ctx.animateTabButtonsHidden or function() end
	local animateTabButtonsByCurrentPage = type(ctx.animateTabButtonsByCurrentPage) == "function" and ctx.animateTabButtonsByCurrentPage or function() end
	local animateElementFramesCollapsed = type(ctx.animateElementFramesCollapsed) == "function" and ctx.animateElementFramesCollapsed or function() end
	local playTween = type(ctx.playTween) == "function" and ctx.playTween or function(instance, tweenInfo, properties)
		local animation = ctx.Animation
		if instance and animation then
			animation:Create(instance, tweenInfo, properties):Play()
		end
	end
	local Animation = ctx.Animation

	local Debounce = false
	local Minimised = false
	local Hidden = false
	local expandedSize = useMobileSizing and UDim2.new(0, 500, 0, 275) or UDim2.new(0, 500, 0, 475)

	local function clampExpandedOffsets(width, height)
		local clampedWidth = math.max(math.floor(width), 320)
		local clampedHeight = math.max(math.floor(height), useMobileSizing and 170 or 220)

		local parentGui = Main and Main.Parent
		if parentGui and parentGui.AbsoluteSize then
			local viewport = parentGui.AbsoluteSize
			if viewport.X > 0 then
				clampedWidth = math.min(clampedWidth, math.max(320, viewport.X - 24))
			end
			if viewport.Y > 0 then
				local minHeight = useMobileSizing and 170 or 220
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
		if Main then
			Main.Size = targetSize
		end
		if Topbar then
			Topbar.Size = UDim2.fromOffset(targetSize.X.Offset, 45)
		end
	end

	local function clampMainToViewport()
		if not (Main and Main.Parent and Main.Parent.AbsoluteSize) then
			return
		end
		local parentSize = Main.Parent.AbsoluteSize
		local mainPosition = Main.AbsolutePosition
		local mainSize = Main.AbsoluteSize

		local clampedX = math.clamp(mainPosition.X, 0, math.max(0, parentSize.X - mainSize.X))
		local clampedY = math.clamp(mainPosition.Y, 0, math.max(0, parentSize.Y - mainSize.Y))
		local deltaX = clampedX - mainPosition.X
		local deltaY = clampedY - mainPosition.Y
		if deltaX ~= 0 or deltaY ~= 0 then
			Main.Position = UDim2.new(
				Main.Position.X.Scale,
				Main.Position.X.Offset + deltaX,
				Main.Position.Y.Scale,
				Main.Position.Y.Offset + deltaY
			)
		end
	end

	local function Hide(showNotification)
		if MPrompt then
			MPrompt.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
			MPrompt.Position = UDim2.new(0.5, 0, 0, -50)
			MPrompt.Size = UDim2.new(0, 40, 0, 10)
			MPrompt.BackgroundTransparency = 1
			MPrompt.Title.TextTransparency = 1
			MPrompt.Visible = true
		end

		task.spawn(closeSearch)
		Debounce = true

		if showNotification then
			if useMobilePrompt then
				notify({
					Title = "Interface Hidden",
					Content = "The interface has been hidden, you can unhide the interface by tapping 'Show'.",
					Duration = 7,
					Image = 4400697855
				})
			else
				notify({
					Title = "Interface Hidden",
					Content = "The interface has been hidden, you can unhide the interface by tapping " .. tostring(getSetting("General", "rayfieldOpen")) .. ".",
					Duration = 7,
					Image = 4400697855
				})
			end
		end

		playTween(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 470, 0, 0)})
		playTween(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 470, 0, 45)})
		playTween(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(Topbar and Topbar:FindFirstChild("Divider"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(Topbar and Topbar:FindFirstChild("CornerRepair"), TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(Topbar and Topbar:FindFirstChild("Title"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1})
		playTween(Main and Main:FindFirstChild("Shadow") and Main.Shadow:FindFirstChild("Image"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
		playTween(Topbar and Topbar:FindFirstChild("UIStroke"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1})
		playTween(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 1})

		if useMobilePrompt and MPrompt and Animation then
			Animation:Create(MPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
				Size = UDim2.new(0, 120, 0, 30),
				Position = UDim2.new(0.5, 0, 0, 20),
				BackgroundTransparency = 0.3
			}):Play()
			Animation:Create(MPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0.3}):Play()
		end

		if Topbar then
			for _, TopbarButton in ipairs(Topbar:GetChildren()) do
				if TopbarButton.ClassName == "ImageButton" then
					playTween(TopbarButton, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
				end
			end
		end

		animateTabButtonsHidden(nil)

		if dragInteract then
			dragInteract.Visible = false
		end

		animateElementFramesCollapsed(true)

		task.wait(0.5)
		if Main then
			Main.Visible = false
		end
		Debounce = false
	end

	local function Maximise()
		Debounce = true
		if Topbar and Topbar:FindFirstChild("ChangeSize") then
			Topbar.ChangeSize.Image = "rbxassetid://10137941941"
		end

		playTween(Topbar and Topbar:FindFirstChild("UIStroke"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1})
		playTween(Main and Main:FindFirstChild("Shadow") and Main.Shadow:FindFirstChild("Image"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6})
		playTween(Topbar and Topbar:FindFirstChild("CornerRepair"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(Topbar and Topbar:FindFirstChild("Divider"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7})
		playTween(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = getExpandedSize()})
		playTween(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.fromOffset(getExpandedSize().X.Offset, 45)})

		if TabList then
			TabList.Visible = true
		end
		task.wait(0.2)

		if Elements then
			Elements.Visible = true
		end

		animateElementFramesCollapsed(false)

		task.wait(0.1)
		animateTabButtonsByCurrentPage(nil)

		task.wait(0.5)
		Debounce = false
	end

	local function Unhide()
		Debounce = true
		if Main then
			Main.Position = UDim2.new(0.5, 0, 0.5, 0)
			Main.Visible = true
		end

		playTween(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = getExpandedSize()})
		playTween(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.fromOffset(getExpandedSize().X.Offset, 45)})
		playTween(Main and Main:FindFirstChild("Shadow") and Main.Shadow:FindFirstChild("Image"), TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.6})
		playTween(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(Topbar and Topbar:FindFirstChild("Divider"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(Topbar and Topbar:FindFirstChild("CornerRepair"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0})
		playTween(Topbar and Topbar:FindFirstChild("Title"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0})

		if MPrompt and Animation then
			Animation:Create(MPrompt, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {
				Size = UDim2.new(0, 40, 0, 10),
				Position = UDim2.new(0.5, 0, 0, -50),
				BackgroundTransparency = 1
			}):Play()
			Animation:Create(MPrompt.Title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()

			task.spawn(function()
				task.wait(0.5)
				MPrompt.Visible = false
			end)
		end

		if Minimised then
			task.spawn(Maximise)
		end

		if dragBar then
			dragBar.Position = useMobileSizing
				and UDim2.new(0.5, 0, 0.5, dragOffsetMobile)
				or UDim2.new(0.5, 0, 0.5, dragOffset)
		end

		if dragInteract then
			dragInteract.Visible = true
		end

		if Topbar then
			for _, TopbarButton in ipairs(Topbar:GetChildren()) do
				if TopbarButton.ClassName == "ImageButton" then
					if TopbarButton.Name == "Icon" then
						playTween(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0})
					else
						playTween(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.8})
					end
				end
			end
		end

		animateTabButtonsByCurrentPage(nil)
		animateElementFramesCollapsed(false)
		playTween(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5})

		task.wait(0.5)
		Minimised = false
		Debounce = false
	end

	local function Minimise()
		Debounce = true
		if Topbar and Topbar:FindFirstChild("ChangeSize") then
			Topbar.ChangeSize.Image = "rbxassetid://11036884234"
		end

		if Topbar and Topbar:FindFirstChild("UIStroke") then
			Topbar.UIStroke.Color = getSelectedTheme().ElementStroke
		end

		task.spawn(closeSearch)
		animateTabButtonsHidden(nil)
		animateElementFramesCollapsed(true)

		playTween(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
		playTween(Topbar and Topbar:FindFirstChild("UIStroke"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 0})
		playTween(Main and Main:FindFirstChild("Shadow") and Main.Shadow:FindFirstChild("Image"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
		playTween(Topbar and Topbar:FindFirstChild("CornerRepair"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(Topbar and Topbar:FindFirstChild("Divider"), TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1})
		playTween(Main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 495, 0, 45)})
		playTween(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 495, 0, 45)})

		task.wait(0.3)

		if Elements then
			Elements.Visible = false
		end
		if TabList then
			TabList.Visible = false
		end

		task.wait(0.2)
		Debounce = false
	end

	local function getLayoutSnapshot()
		local currentExpanded = getExpandedSize()
		return {
			position = {
				xScale = Main.Position.X.Scale,
				xOffset = Main.Position.X.Offset,
				yScale = Main.Position.Y.Scale,
				yOffset = Main.Position.Y.Offset
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
			local xScale = tonumber(position.xScale) or Main.Position.X.Scale
			local xOffset = tonumber(position.xOffset) or Main.Position.X.Offset
			local yScale = tonumber(position.yScale) or Main.Position.Y.Scale
			local yOffset = tonumber(position.yOffset) or Main.Position.Y.Offset
			Main.Position = UDim2.new(xScale, xOffset, yScale, yOffset)
			clampMainToViewport()
		end

		local targetHidden = layout.hidden == true
		local targetMinimized = layout.minimized == true
		if targetHidden then
			Hidden = true
			Minimised = false
			Main.Visible = false
			if Elements then
				Elements.Visible = false
			end
			if TabList then
				TabList.Visible = false
			end
		elseif targetMinimized then
			Hidden = false
			Minimised = true
			Main.Visible = true
			Main.Size = UDim2.fromOffset(495, 45)
			Topbar.Size = UDim2.fromOffset(495, 45)
			if Elements then
				Elements.Visible = false
			end
			if TabList then
				TabList.Visible = false
			end
		else
			Hidden = false
			Minimised = false
			Main.Visible = true
			if Elements then
				Elements.Visible = true
			end
			if TabList then
				TabList.Visible = true
			end
			applyExpandedSizeToFrames()
		end

		return true
	end

	manager.Hide = Hide
	manager.Unhide = Unhide
	manager.Maximise = Maximise
	manager.Minimise = Minimise

	manager.getDebounce = function()
		return Debounce
	end
	manager.setDebounce = function(value)
		Debounce = value
	end
	manager.getMinimised = function()
		return Minimised
	end
	manager.setMinimised = function(value)
		Minimised = value
	end
	manager.getHidden = function()
		return Hidden
	end
	manager.setHidden = function(value)
		Hidden = value
	end
	manager.getExpandedSize = getExpandedSize
	manager.setExpandedSize = setExpandedSize
	manager.getLayoutSnapshot = getLayoutSnapshot
	manager.applyLayoutSnapshot = applyLayoutSnapshot

	return manager
end

return WindowManager
