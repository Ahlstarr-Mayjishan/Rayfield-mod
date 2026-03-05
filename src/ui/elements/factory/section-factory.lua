local SectionFactory = {}

function SectionFactory.createSection(context, sectionName)
	context = type(context) == "table" and context or {}
	local self = context.self
	local TabPage = context.TabPage
	local addExtendedAPI = context.addExtendedAPI
	local getSectionSpacingDone = context.getSectionSpacingDone or function()
		return false
	end
	local setSectionSpacingDone = context.setSectionSpacingDone or function() end
	local setCurrentImplicitSection = context.setCurrentImplicitSection or function() end

	if type(self) ~= "table" or typeof(TabPage) ~= "Instance" then
		return nil
	end

	setCurrentImplicitSection(nil)

	local sectionTitle = tostring(sectionName or "Section")
	local sectionValue = {}

	if getSectionSpacingDone() then
		local sectionSpace = self.Elements.Template.SectionSpacing:Clone()
		sectionSpace.Visible = true
		sectionSpace.Parent = TabPage
	end

	local section = self.Elements.Template.SectionTitle:Clone()
	section.Title.Text = sectionTitle
	section.Visible = true
	section.Parent = TabPage

	section.Title.TextTransparency = 1
	self.Animation:Create(section.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), { TextTransparency = 0.4 }):Play()

	function sectionValue:Set(newSection)
		section.Title.Text = tostring(newSection or "")
	end

	function sectionValue:Destroy()
		section:Destroy()
	end

	addExtendedAPI(sectionValue, sectionTitle, "Section", section)
	setSectionSpacingDone(true)
	return sectionValue
end

function SectionFactory.createCollapsibleSection(context, sectionSettings)
	context = type(context) == "table" and context or {}
	local self = context.self
	local TabPage = context.TabPage
	local tabPersistenceId = tostring(context.tabPersistenceId or "")
	local addExtendedAPI = context.addExtendedAPI
	local getCollapsedSectionsMap = context.getCollapsedSectionsMap or function()
		return {}
	end
	local persistCollapsedState = context.persistCollapsedState or function() end
	local getCurrentImplicitSection = context.getCurrentImplicitSection or function()
		return nil
	end
	local setCurrentImplicitSection = context.setCurrentImplicitSection or function() end
	local tabSections = type(context.tabSections) == "table" and context.tabSections or {}
	local tabElements = type(context.tabElements) == "table" and context.tabElements or {}
	if type(self) ~= "table" or typeof(TabPage) ~= "Instance" then
		return nil
	end

	local settingsValue = sectionSettings
	if type(settingsValue) == "string" then
		settingsValue = { Name = settingsValue }
	end
	settingsValue = settingsValue or {}
	local sectionName = tostring(settingsValue.Name or settingsValue.Title or "Section")
	local sectionId = tostring(settingsValue.Id or sectionName)
	local sectionKey = tostring(tabPersistenceId) .. "::" .. sectionId
	local persistState = settingsValue.PersistState ~= false
	local implicitScope = settingsValue.ImplicitScope ~= false

	local collapsedMap = getCollapsedSectionsMap()
	local initialCollapsed = settingsValue.Collapsed == true
	if persistState and type(collapsedMap[sectionKey]) == "boolean" then
		initialCollapsed = collapsedMap[sectionKey]
	end

	local root = Instance.new("Frame")
	root.Name = "CollapsibleSection"
	root.Size = UDim2.new(1, -10, 0, 28)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Visible = true
	root.Parent = TabPage

	local rootList = Instance.new("UIListLayout")
	rootList.SortOrder = Enum.SortOrder.LayoutOrder
	rootList.Padding = UDim.new(0, 6)
	rootList.Parent = root

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 26)
	header.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
	header.BorderSizePixel = 0
	header.Parent = root

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 6)
	headerCorner.Parent = header

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = self.getSelectedTheme().SecondaryElementStroke
	headerStroke.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.Size = UDim2.new(1, -38, 1, 0)
	titleLabel.Font = Enum.Font.GothamSemibold
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = self.getSelectedTheme().TextColor
	titleLabel.Text = sectionName
	titleLabel.Parent = header

	local chevron = Instance.new("TextLabel")
	chevron.BackgroundTransparency = 1
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, -10, 0.5, 0)
	chevron.Size = UDim2.new(0, 16, 0, 16)
	chevron.Font = Enum.Font.GothamBold
	chevron.TextSize = 15
	chevron.TextColor3 = self.getSelectedTheme().SectionChevron or self.getSelectedTheme().TextColor
	chevron.Text = "v"
	chevron.Parent = header

	local interact = Instance.new("TextButton")
	interact.BackgroundTransparency = 1
	interact.Size = UDim2.new(1, 0, 1, 0)
	interact.Text = ""
	interact.Parent = header

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Parent = root

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 6)
	contentLayout.Parent = content

	local sectionRecord = {
		Key = sectionKey,
		Root = root,
		Header = header,
		ContentFrame = content,
		Collapsed = false,
		ImplicitScope = implicitScope
	}

	local sectionValue = {
		__SectionContentFrame = content,
		__SectionRecord = sectionRecord
	}

	local function applyCollapsedState(nextCollapsed, persist)
		sectionRecord.Collapsed = nextCollapsed == true
		content.Visible = not sectionRecord.Collapsed
		chevron.Text = sectionRecord.Collapsed and ">" or "v"
		if persist ~= false and persistState then
			persistCollapsedState(sectionKey, sectionRecord.Collapsed)
		end
	end

	function sectionValue:Set(newName)
		sectionName = tostring(newName or sectionName)
		titleLabel.Text = sectionName
	end

	function sectionValue:Collapse()
		applyCollapsedState(true, true)
	end

	function sectionValue:Expand()
		applyCollapsedState(false, true)
	end

	function sectionValue:Toggle()
		applyCollapsedState(not sectionRecord.Collapsed, true)
	end

	function sectionValue:IsCollapsed()
		return sectionRecord.Collapsed == true
	end

	function sectionValue:Destroy()
		if getCurrentImplicitSection() == sectionRecord then
			setCurrentImplicitSection(nil)
		end
		local snapshot = {}
		for _, tracked in ipairs(tabElements) do
			snapshot[#snapshot + 1] = tracked
		end
		for _, tracked in ipairs(snapshot) do
			if tracked.GuiObject and tracked.GuiObject:IsDescendantOf(content) and tracked.Object and type(tracked.Object.Destroy) == "function" then
				tracked.Object:Destroy()
			end
		end
		root:Destroy()
	end

	interact.MouseButton1Click:Connect(function()
		sectionValue:Toggle()
	end)

	self.Rayfield.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		if not root.Parent then
			return
		end
		header.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
		headerStroke.Color = self.getSelectedTheme().SecondaryElementStroke
		titleLabel.TextColor3 = self.getSelectedTheme().TextColor
		chevron.TextColor3 = self.getSelectedTheme().SectionChevron or self.getSelectedTheme().TextColor
	end)

	applyCollapsedState(initialCollapsed, false)
	setCurrentImplicitSection(implicitScope and sectionRecord or nil)
	table.insert(tabSections, sectionRecord)
	addExtendedAPI(sectionValue, sectionName, "CollapsibleSection", root)
	return sectionValue
end

return SectionFactory
