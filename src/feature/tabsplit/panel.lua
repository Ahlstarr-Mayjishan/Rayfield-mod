local TabSplitPanel = {}

function TabSplitPanel.bindHover(panelData, syncPanelHover)
	table.insert(panelData.Cleanup, panelData.Frame.MouseEnter:Connect(function()
		panelData.HoverPanel = true
		syncPanelHover()
	end))
	table.insert(panelData.Cleanup, panelData.Frame.MouseLeave:Connect(function()
		panelData.HoverPanel = false
		syncPanelHover()
	end))
	table.insert(panelData.Cleanup, panelData.Header.MouseEnter:Connect(function()
		panelData.HoverHeader = true
		syncPanelHover()
	end))
	table.insert(panelData.Cleanup, panelData.Header.MouseLeave:Connect(function()
		panelData.HoverHeader = false
		syncPanelHover()
	end))
	table.insert(panelData.Cleanup, panelData.DockButton.MouseEnter:Connect(function()
		panelData.HoverDock = true
		syncPanelHover()
	end))
	table.insert(panelData.Cleanup, panelData.DockButton.MouseLeave:Connect(function()
		panelData.HoverDock = false
		syncPanelHover()
	end))
end

function TabSplitPanel.createShell(opts)
	local panel = Instance.new("Frame")
	panel.Name = "TabSplitPanel-" .. tostring(opts.tabRecord.Name)
	panel.BackgroundColor3 = (opts.theme and opts.theme.SecondaryElementBackground) or Color3.fromRGB(35, 35, 35)
	panel.BorderSizePixel = 0
	panel.ZIndex = opts.baseZ
	panel.Parent = opts.root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = (opts.theme and opts.theme.ElementStroke) or Color3.fromRGB(80, 80, 80)
	stroke.Thickness = 1.1
	stroke.Transparency = 0.25
	stroke.Parent = panel

	local glowStroke = Instance.new("UIStroke")
	glowStroke.Color = (opts.theme and opts.theme.SliderProgress) or Color3.fromRGB(112, 189, 255)
	glowStroke.Thickness = 1.2
	glowStroke.Transparency = 1
	glowStroke.Parent = panel

	local softGlowStroke = Instance.new("UIStroke")
	softGlowStroke.Color = (opts.theme and opts.theme.SliderProgress) or Color3.fromRGB(112, 189, 255)
	softGlowStroke.Thickness = 2.8
	softGlowStroke.Transparency = 1
	softGlowStroke.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = (opts.theme and opts.theme.Topbar) or Color3.fromRGB(25, 25, 25)
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
	title.Text = tostring(opts.tabRecord.Name)
	title.TextColor3 = (opts.theme and opts.theme.TextColor) or Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = header.ZIndex + 1
	title.Parent = header

	local dockButton = Instance.new("TextButton")
	dockButton.Name = "Dock"
	dockButton.Size = UDim2.fromOffset(64, 22)
	dockButton.Position = UDim2.new(1, -74, 0.5, -11)
	dockButton.BackgroundColor3 = (opts.theme and opts.theme.ElementBackgroundHover) or Color3.fromRGB(55, 55, 55)
	dockButton.BorderSizePixel = 0
	dockButton.Text = "Dock"
	dockButton.TextColor3 = (opts.theme and opts.theme.TextColor) or Color3.fromRGB(255, 255, 255)
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
		Id = opts.panelId,
		Frame = panel,
		Header = header,
		Title = title,
		DockButton = dockButton,
		Content = content,
		Stroke = stroke,
		GlowStroke = glowStroke,
		SoftGlowStroke = softGlowStroke,
		TabRecord = opts.tabRecord,
		Cleanup = {},
		InputId = opts.inputId,
		ManualPosition = nil,
		Dragging = false,
		HoverPanel = false,
		HoverHeader = false,
		HoverDock = false,
		HoverActive = false,
		LayerZ = opts.baseZ
	}

	local function syncPanelHover()
		panelData.HoverActive = panelData.HoverPanel or panelData.HoverHeader or panelData.HoverDock
		if not panelData.Dragging then
			opts.setPanelHoverState(panelData, panelData.HoverActive, false)
		end
	end

	TabSplitPanel.bindHover(panelData, syncPanelHover)
	return panelData
end

return TabSplitPanel
