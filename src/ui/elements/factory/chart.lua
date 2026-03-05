local ChartFactory = {}

function ChartFactory.create(context)
	context = context or {}
	local self = context.self
	local TabPage = context.TabPage
	local Settings = context.Settings or {}
	local addExtendedAPI = context.addExtendedAPI
	local resolveElementParentFromSettings = context.resolveElementParentFromSettings
	local connectThemeRefresh = context.connectThemeRefresh
	local cloneSerializable = context.cloneSerializable
	local clampNumber = context.clampNumber
	local isHeadlessPerformanceMode = context.isHeadlessPerformanceMode
	local settingsValue = context.settings or {}

	if type(self) ~= "table" or not TabPage then
		return nil
	end
	if type(cloneSerializable) ~= "function" then
		cloneSerializable = function(value)
			return value
		end
	end
	if type(clampNumber) ~= "function" then
		clampNumber = function(value, minimum, maximum, fallback)
			local numberValue = tonumber(value)
			if not numberValue then
				numberValue = tonumber(fallback) or 0
			end
			if minimum ~= nil then
				numberValue = math.max(minimum, numberValue)
			end
			if maximum ~= nil then
				numberValue = math.min(maximum, numberValue)
			end
			return numberValue
		end
	end
	if type(connectThemeRefresh) ~= "function" then
		connectThemeRefresh = function() end
	end
	if type(isHeadlessPerformanceMode) ~= "function" then
		isHeadlessPerformanceMode = function()
			if Settings.PerformanceMode == true then
				return true
			end
			local profile = type(Settings.PerformanceProfile) == "table" and Settings.PerformanceProfile or nil
			if not profile or profile.Enabled ~= true then
				return false
			end
			local mode = string.lower(tostring(profile.Mode or ""))
			if profile.DisableAnimations == true then
				return true
			end
			if profile.Aggressive == true then
				return true
			end
			return mode == "potato" or mode == "mobile"
		end
	end

	local chart = {}
	chart.Name = tostring(settingsValue.Name or "Chart")
	chart.Flag = settingsValue.Flag
	chart.CurrentValue = {
		points = {},
		zoom = 1,
		offset = 0,
		preset = settingsValue.Preset
	}
	local maxPoints = math.max(10, math.floor(tonumber(settingsValue.MaxPoints) or 300))
	local updateHz = math.max(1, math.floor(tonumber(settingsValue.UpdateHz) or 10))
	if isHeadlessPerformanceMode() then
		updateHz = math.min(updateHz, 4)
	end
	local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
	local showAreaFill = settingsValue.ShowAreaFill ~= false
	if isHeadlessPerformanceMode() and settingsValue.ShowAreaFill == nil then
		showAreaFill = false
	end
	local renderPending = false
	local lastRender = 0
	local segmentPool = {}
	local fillPool = {}
	local dragging = false
	local dragStartX = 0

	local root = Instance.new("Frame")
	root.Name = chart.Name
	root.Size = UDim2.new(1, -10, 0, clampNumber(settingsValue.Height, 150, 380, 220))
	root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
	root.BorderSizePixel = 0
	root.Visible = true
	root.Parent = TabPage

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = self.getSelectedTheme().ElementStroke
	stroke.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 10, 0, 0)
	title.Size = UDim2.new(1, -90, 0, 22)
	title.Font = Enum.Font.GothamSemibold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 13
	title.TextColor3 = self.getSelectedTheme().TextColor
	title.Text = chart.Name
	title.Parent = root

	local zoomIn = Instance.new("TextButton")
	zoomIn.Size = UDim2.new(0, 22, 0, 20)
	zoomIn.AnchorPoint = Vector2.new(1, 0)
	zoomIn.Position = UDim2.new(1, -34, 0, 2)
	zoomIn.Text = "+"
	zoomIn.Font = Enum.Font.GothamBold
	zoomIn.TextSize = 14
	zoomIn.TextColor3 = self.getSelectedTheme().TextColor
	zoomIn.BackgroundColor3 = self.getSelectedTheme().InputBackground
	zoomIn.BorderSizePixel = 0
	zoomIn.Parent = root

	local zoomOut = Instance.new("TextButton")
	zoomOut.Size = UDim2.new(0, 22, 0, 20)
	zoomOut.AnchorPoint = Vector2.new(1, 0)
	zoomOut.Position = UDim2.new(1, -8, 0, 2)
	zoomOut.Text = "-"
	zoomOut.Font = Enum.Font.GothamBold
	zoomOut.TextSize = 14
	zoomOut.TextColor3 = self.getSelectedTheme().TextColor
	zoomOut.BackgroundColor3 = self.getSelectedTheme().InputBackground
	zoomOut.BorderSizePixel = 0
	zoomOut.Parent = root

	local plot = Instance.new("Frame")
	plot.Name = "Plot"
	plot.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
	plot.BorderSizePixel = 0
	plot.Position = UDim2.new(0, 8, 0, 26)
	plot.Size = UDim2.new(1, -16, 1, -34)
	plot.ClipsDescendants = true
	plot.Parent = root

	local plotStroke = Instance.new("UIStroke")
	plotStroke.Color = self.getSelectedTheme().ElementStroke
	plotStroke.Transparency = 0.2
	plotStroke.Parent = plot

	local gridLines = {}
	for i = 1, 4 do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Position = UDim2.new(0, 0, (i - 1) / 3, 0)
		line.BackgroundColor3 = self.getSelectedTheme().ChartGrid or self.getSelectedTheme().ElementStroke
		line.BackgroundTransparency = 0.65
		line.Parent = plot
		gridLines[i] = line
	end

	local drawLayer = Instance.new("Frame")
	drawLayer.BackgroundTransparency = 1
	drawLayer.Size = UDim2.new(1, 0, 1, 0)
	drawLayer.Parent = plot

	local function ensurePoolEntry(pool, index, factory)
		if pool[index] and pool[index].Parent then
			return pool[index]
		end
		local entry = factory()
		pool[index] = entry
		return entry
	end

	local function trimPoints()
		while #chart.CurrentValue.points > maxPoints do
			table.remove(chart.CurrentValue.points, 1)
		end
	end

	local function getVisiblePoints()
		local points = chart.CurrentValue.points
		local total = #points
		if total == 0 then
			return {}
		end
		local visibleCount = math.max(2, math.floor(total / math.max(1, chart.CurrentValue.zoom)))
		local maxOffset = math.max(0, total - visibleCount)
		chart.CurrentValue.offset = math.floor(clampNumber(chart.CurrentValue.offset, 0, maxOffset, chart.CurrentValue.offset))
		local startIndex = total - visibleCount - chart.CurrentValue.offset + 1
		if startIndex < 1 then
			startIndex = 1
		end
		local out = {}
		for index = startIndex, math.min(total, startIndex + visibleCount - 1) do
			table.insert(out, points[index])
		end
		return out
	end

	local function renderNow()
		lastRender = os.clock()
		local visible = getVisiblePoints()
		local pointCount = #visible
		local minY = math.huge
		local maxY = -math.huge
		for _, point in ipairs(visible) do
			local y = tonumber(point.y) or 0
			if y < minY then minY = y end
			if y > maxY then maxY = y end
		end
		if pointCount == 0 then
			minY, maxY = 0, 1
		elseif minY == maxY then
			minY -= 1
			maxY += 1
		end

		local width = math.max(1, plot.AbsoluteSize.X)
		local height = math.max(1, plot.AbsoluteSize.Y)
		local function toPoint(index, yValue)
			local x = pointCount <= 1 and (width * 0.5) or (((index - 1) / (pointCount - 1)) * width)
			local safeY = tonumber(yValue) or minY
			local y = height - (((safeY - minY) / math.max(0.00001, (maxY - minY))) * height)
			return x, y
		end

		local segmentIndex = 0
		for index = 1, pointCount - 1 do
			local x1, y1 = toPoint(index, visible[index].y)
			local x2, y2 = toPoint(index + 1, visible[index + 1].y)
			local dx, dy = x2 - x1, y2 - y1
			local length = math.sqrt((dx * dx) + (dy * dy))
			if length > 0 then
				segmentIndex += 1
				local segment = ensurePoolEntry(segmentPool, segmentIndex, function()
					local line = Instance.new("Frame")
					line.BorderSizePixel = 0
					line.AnchorPoint = Vector2.new(0, 0.5)
					line.Size = UDim2.new(0, 1, 0, 2)
					line.Parent = drawLayer
					return line
				end)
				segment.Visible = true
				segment.BackgroundColor3 = self.getSelectedTheme().ChartLine or self.getSelectedTheme().SliderProgress
				segment.Position = UDim2.new(0, x1, 0, y1)
				segment.Size = UDim2.new(0, length, 0, 2)
				segment.Rotation = math.deg(math.atan2(dy, dx))
			end
		end
		for index = segmentIndex + 1, #segmentPool do
			if segmentPool[index] then
				segmentPool[index].Visible = false
			end
		end

		if showAreaFill then
			local fillIndex = 0
			for index = 1, pointCount do
				local x, y = toPoint(index, visible[index].y)
				fillIndex += 1
				local fill = ensurePoolEntry(fillPool, fillIndex, function()
					local bar = Instance.new("Frame")
					bar.BorderSizePixel = 0
					bar.AnchorPoint = Vector2.new(0.5, 1)
					bar.BackgroundTransparency = 0.78
					bar.Parent = drawLayer
					return bar
				end)
				fill.Visible = true
				fill.BackgroundColor3 = self.getSelectedTheme().ChartFill or self.getSelectedTheme().SliderBackground
				fill.Position = UDim2.new(0, x, 0, height)
				fill.Size = UDim2.new(0, 2, 0, math.max(1, height - y))
			end
			for index = fillIndex + 1, #fillPool do
				if fillPool[index] then
					fillPool[index].Visible = false
				end
			end
		else
			for _, fill in ipairs(fillPool) do
				if fill then
					fill.Visible = false
				end
			end
		end
	end

	local function scheduleRender()
		local interval = 1 / math.max(1, updateHz)
		local now = os.clock()
		local elapsed = now - lastRender
		if elapsed >= interval then
			renderNow()
			return
		end
		if renderPending then
			return
		end
		renderPending = true
		task.delay(interval - elapsed, function()
			renderPending = false
			if root and root.Parent then
				renderNow()
			end
		end)
	end

	local function emitDataChanged(persist)
		trimPoints()
		scheduleRender()
		local okCallback, callbackErr = pcall(callback, chart:GetData())
		if not okCallback then
			warn("Rayfield | Chart callback failed: " .. tostring(callbackErr))
		end
		if persist ~= false and settingsValue.Ext ~= true then
			self.SaveConfiguration()
		end
	end

	function chart:AddPoint(y, x)
		local nextX = tonumber(x)
		if nextX == nil then
			local lastPoint = chart.CurrentValue.points[#chart.CurrentValue.points]
			nextX = (lastPoint and tonumber(lastPoint.x) or 0) + 1
		end
		table.insert(chart.CurrentValue.points, {x = nextX, y = tonumber(y) or 0})
		emitDataChanged(true)
	end

	function chart:SetData(points)
		chart.CurrentValue.points = {}
		if type(points) == "table" then
			for _, point in ipairs(points) do
				if type(point) == "table" then
					local px = tonumber(point.x or point[1]) or (#chart.CurrentValue.points + 1)
					local py = tonumber(point.y or point[2])
					if py ~= nil then
						table.insert(chart.CurrentValue.points, {x = px, y = py})
					end
				elseif tonumber(point) ~= nil then
					table.insert(chart.CurrentValue.points, {x = #chart.CurrentValue.points + 1, y = tonumber(point)})
				end
			end
		end
		emitDataChanged(true)
	end

	function chart:GetData()
		return cloneSerializable(chart.CurrentValue)
	end

	function chart:Clear()
		chart.CurrentValue.points = {}
		chart.CurrentValue.offset = 0
		emitDataChanged(true)
	end

	function chart:SetPreset(nameOrNil)
		chart.CurrentValue.preset = nameOrNil
		if settingsValue.Ext ~= true then
			self.SaveConfiguration()
		end
		return true, "ok"
	end

	function chart:Zoom(factor)
		chart.CurrentValue.zoom = clampNumber((chart.CurrentValue.zoom or 1) * (tonumber(factor) or 1), 1, 12, chart.CurrentValue.zoom)
		emitDataChanged(true)
	end

	function chart:Pan(delta)
		local total = #chart.CurrentValue.points
		local visibleCount = math.max(2, math.floor(total / math.max(1, chart.CurrentValue.zoom)))
		local maxOffset = math.max(0, total - visibleCount)
		chart.CurrentValue.offset = math.floor(clampNumber((chart.CurrentValue.offset or 0) + (tonumber(delta) or 0), 0, maxOffset, 0))
		emitDataChanged(true)
	end

	function chart:GetPersistValue()
		return chart:GetData()
	end

	function chart:Set(value)
		if type(value) == "table" then
			if type(value.points) == "table" then
				chart.CurrentValue.points = cloneSerializable(value.points) or {}
			elseif #value > 0 then
				chart:SetData(value)
				return
			end
			chart.CurrentValue.zoom = clampNumber(value.zoom, 1, 12, chart.CurrentValue.zoom)
			chart.CurrentValue.offset = clampNumber(value.offset, 0, math.huge, chart.CurrentValue.offset)
			if value.preset ~= nil then
				chart.CurrentValue.preset = value.preset
			end
			emitDataChanged(true)
		end
	end

	function chart:Destroy()
		root:Destroy()
	end

	zoomIn.MouseButton1Click:Connect(function()
		chart:Zoom(1.2)
	end)
	zoomOut.MouseButton1Click:Connect(function()
		chart:Zoom(1 / 1.2)
	end)
	plot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStartX = input.Position.X
		end
	end)
	plot.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position.X - dragStartX
		if math.abs(delta) >= 10 then
			dragStartX = input.Position.X
			chart:Pan(math.floor(-delta / 22))
		end
	end)
	plot.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	connectThemeRefresh(function()
		root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
		stroke.Color = self.getSelectedTheme().ElementStroke
		title.TextColor3 = self.getSelectedTheme().TextColor
		zoomIn.BackgroundColor3 = self.getSelectedTheme().InputBackground
		zoomIn.TextColor3 = self.getSelectedTheme().TextColor
		zoomOut.BackgroundColor3 = self.getSelectedTheme().InputBackground
		zoomOut.TextColor3 = self.getSelectedTheme().TextColor
		plot.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
		plotStroke.Color = self.getSelectedTheme().ElementStroke
		for _, line in ipairs(gridLines) do
			line.BackgroundColor3 = self.getSelectedTheme().ChartGrid or self.getSelectedTheme().ElementStroke
		end
		scheduleRender()
	end)

	resolveElementParentFromSettings(chart, settingsValue)
	if type(settingsValue.Data) == "table" then
		chart:SetData(settingsValue.Data)
	else
		scheduleRender()
	end
	addExtendedAPI(chart, chart.Name, "Chart", root)
	if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and chart.Flag then
		self.RayfieldLibrary.Flags[chart.Flag] = chart
	end
	return chart
end

return ChartFactory
