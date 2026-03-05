local FeedbackWidgetsFactory = {}

local function readContext(context)
	context = type(context) == "table" and context or {}
	local self = context.self
	local TabPage = context.TabPage
	local Settings = context.Settings
	if type(self) ~= "table" or typeof(TabPage) ~= "Instance" then
		return nil
	end
	return {
		self = self,
		TabPage = TabPage,
		Settings = Settings,
		addExtendedAPI = context.addExtendedAPI,
		resolveElementParentFromSettings = context.resolveElementParentFromSettings,
		connectThemeRefresh = context.connectThemeRefresh,
		subscribeGlobalLogs = context.subscribeGlobalLogs,
		cloneSerializable = context.cloneSerializable,
		clampNumber = context.clampNumber,
		packColor3 = context.packColor3,
		unpackColor3 = context.unpackColor3,
		startRenderLoop = context.startRenderLoop,
		stopRenderLoop = context.stopRenderLoop
	}
end

function FeedbackWidgetsFactory.createLogConsole(context, logSettings)
	local deps = readContext(context)
	if not deps then
		warn("Rayfield | FeedbackWidgets context invalid for LogConsole.")
		return nil
	end
	local self = deps.self
	local TabPage = deps.TabPage
	local Settings = deps.Settings
	local addExtendedAPI = deps.addExtendedAPI
	local resolveElementParentFromSettings = deps.resolveElementParentFromSettings
	local connectThemeRefresh = deps.connectThemeRefresh
	local cloneSerializable = deps.cloneSerializable
	local subscribeGlobalLogs = deps.subscribeGlobalLogs
	local clampNumber = deps.clampNumber

	if type(addExtendedAPI) ~= "function" or type(resolveElementParentFromSettings) ~= "function" or type(connectThemeRefresh) ~= "function" then
		warn("Rayfield | FeedbackWidgets missing required helpers for LogConsole.")
		return nil
	end

	local settingsValue = logSettings or {}
	local console = {}
	console.Name = tostring(settingsValue.Name or "Log Console")
	console.Flag = settingsValue.Flag
	local captureMode = tostring(settingsValue.CaptureMode or "manual"):lower()
	if captureMode ~= "manual" and captureMode ~= "global" and captureMode ~= "both" then
		captureMode = "manual"
	end
	local maxEntries = math.max(10, math.floor(tonumber(settingsValue.MaxEntries) or 500))
	local autoScroll = settingsValue.AutoScroll ~= false
	local showTimestamp = settingsValue.ShowTimestamp ~= false
	local entries = {}
	local globalUnsubscribe = nil

	local root = Instance.new("Frame")
	root.Name = console.Name
	root.Size = UDim2.new(1, -10, 0, type(clampNumber) == "function" and clampNumber(settingsValue.Height, 150, 420, 230) or 230)
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
	title.Size = UDim2.new(1, -110, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 13
	title.TextColor3 = self.getSelectedTheme().TextColor
	title.Text = console.Name
	title.Parent = root

	local modeLabel = Instance.new("TextLabel")
	modeLabel.BackgroundTransparency = 1
	modeLabel.AnchorPoint = Vector2.new(1, 0)
	modeLabel.Position = UDim2.new(1, -40, 0, 2)
	modeLabel.Size = UDim2.new(0, 64, 0, 18)
	modeLabel.Font = Enum.Font.Gotham
	modeLabel.TextSize = 11
	modeLabel.TextXAlignment = Enum.TextXAlignment.Right
	modeLabel.TextColor3 = self.getSelectedTheme().TextColor
	modeLabel.Text = string.upper(captureMode)
	modeLabel.Parent = root

	local clearButton = Instance.new("TextButton")
	clearButton.AnchorPoint = Vector2.new(1, 0)
	clearButton.Position = UDim2.new(1, -6, 0, 2)
	clearButton.Size = UDim2.new(0, 28, 0, 18)
	clearButton.Text = "CLR"
	clearButton.Font = Enum.Font.GothamBold
	clearButton.TextSize = 9
	clearButton.TextColor3 = self.getSelectedTheme().TextColor
	clearButton.BackgroundColor3 = self.getSelectedTheme().InputBackground
	clearButton.BorderSizePixel = 0
	clearButton.Parent = root

	local list = Instance.new("ScrollingFrame")
	list.Name = "Entries"
	list.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 8, 0, 24)
	list.Size = UDim2.new(1, -16, 1, -32)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ScrollBarImageTransparency = 0.5
	list.Parent = root

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 3)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local function levelColor(level)
		local normalized = tostring(level or "info"):lower()
		if normalized == "warn" then
			return self.getSelectedTheme().LogWarn or self.getSelectedTheme().SliderStroke
		elseif normalized == "error" then
			return self.getSelectedTheme().LogError or self.getSelectedTheme().ToggleEnabled
		end
		return self.getSelectedTheme().LogInfo or self.getSelectedTheme().TextColor
	end

	local function formatEntry(entry)
		local ts = ""
		if showTimestamp then
			ts = "[" .. os.date("%H:%M:%S", math.floor(entry.time or os.time())) .. "] "
		end
		return ts .. "[" .. string.upper(tostring(entry.level or "info")) .. "] " .. tostring(entry.text or "")
	end

	local function trimEntries()
		while #entries > maxEntries do
			table.remove(entries, 1)
		end
	end

	local function renderEntries()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		for index, entry in ipairs(entries) do
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, -8, 0, 16)
			label.Position = UDim2.new(0, 4, 0, 0)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Font = Enum.Font.Code
			label.TextSize = 12
			label.TextColor3 = levelColor(entry.level)
			label.Text = formatEntry(entry)
			label.LayoutOrder = index
			label.Parent = list
		end
		task.defer(function()
			list.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 6)
			if autoScroll then
				list.CanvasPosition = Vector2.new(0, math.max(0, list.CanvasSize.Y.Offset - list.AbsoluteSize.Y))
			end
		end)
	end

	local function appendEntry(level, textValue, persist)
		table.insert(entries, {
			level = tostring(level or "info"):lower(),
			text = tostring(textValue or ""),
			time = os.time()
		})
		trimEntries()
		renderEntries()
		if persist ~= false and settingsValue.Ext ~= true then
			self.SaveConfiguration()
		end
	end

	local function setCaptureMode(nextMode, persist)
		local normalized = tostring(nextMode or "manual"):lower()
		if normalized ~= "manual" and normalized ~= "global" and normalized ~= "both" then
			return false, "Invalid capture mode."
		end
		captureMode = normalized
		modeLabel.Text = string.upper(captureMode)
		if globalUnsubscribe then
			globalUnsubscribe()
			globalUnsubscribe = nil
		end
		if captureMode == "global" or captureMode == "both" then
			if type(subscribeGlobalLogs) == "function" then
				globalUnsubscribe = subscribeGlobalLogs(function(level, textValue)
					appendEntry(level, textValue, true)
				end)
			else
				globalUnsubscribe = function() end
			end
		end
		if persist ~= false and settingsValue.Ext ~= true then
			self.SaveConfiguration()
		end
		return true, "ok"
	end

	function console:Log(level, textValue)
		appendEntry(level or "info", textValue, true)
	end

	function console:Info(textValue)
		appendEntry("info", textValue, true)
	end

	function console:Warn(textValue)
		appendEntry("warn", textValue, true)
	end

	function console:Error(textValue)
		appendEntry("error", textValue, true)
	end

	function console:Clear()
		entries = {}
		renderEntries()
		if settingsValue.Ext ~= true then
			self.SaveConfiguration()
		end
	end

	function console:SetCaptureMode(nextMode)
		return setCaptureMode(nextMode, true)
	end

	function console:GetEntries()
		return type(cloneSerializable) == "function" and cloneSerializable(entries) or entries
	end

	function console:GetPersistValue()
		return {
			captureMode = captureMode,
			entries = type(cloneSerializable) == "function" and cloneSerializable(entries) or entries
		}
	end

	function console:Set(value)
		if type(value) == "table" then
			if type(value.entries) == "table" then
				entries = (type(cloneSerializable) == "function" and cloneSerializable(value.entries)) or {}
				trimEntries()
				renderEntries()
			end
			if value.captureMode ~= nil then
				setCaptureMode(value.captureMode, false)
			end
		end
	end

	function console:Destroy()
		if globalUnsubscribe then
			globalUnsubscribe()
			globalUnsubscribe = nil
		end
		root:Destroy()
	end

	clearButton.MouseButton1Click:Connect(function()
		console:Clear()
	end)
	setCaptureMode(captureMode, false)

	connectThemeRefresh(function()
		root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
		stroke.Color = self.getSelectedTheme().ElementStroke
		title.TextColor3 = self.getSelectedTheme().TextColor
		modeLabel.TextColor3 = self.getSelectedTheme().TextColor
		clearButton.BackgroundColor3 = self.getSelectedTheme().InputBackground
		clearButton.TextColor3 = self.getSelectedTheme().TextColor
		list.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
		renderEntries()
	end)

	resolveElementParentFromSettings(console, settingsValue)
	if type(settingsValue.Entries) == "table" then
		console:Set({
			captureMode = captureMode,
			entries = settingsValue.Entries
		})
	else
		renderEntries()
	end
	addExtendedAPI(console, console.Name, "LogConsole", root)
	if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and console.Flag then
		self.RayfieldLibrary.Flags[console.Flag] = console
	end
	return console
end

function FeedbackWidgetsFactory.createLoadingSpinner(context, spinnerSettings)
	local deps = readContext(context)
	if not deps then
		warn("Rayfield | FeedbackWidgets context invalid for LoadingSpinner.")
		return nil
	end
	local self = deps.self
	local TabPage = deps.TabPage
	local Settings = deps.Settings
	local addExtendedAPI = deps.addExtendedAPI
	local resolveElementParentFromSettings = deps.resolveElementParentFromSettings
	local connectThemeRefresh = deps.connectThemeRefresh
	local cloneSerializable = deps.cloneSerializable
	local clampNumber = deps.clampNumber
	local packColor3 = deps.packColor3
	local unpackColor3 = deps.unpackColor3
	local startRenderLoop = deps.startRenderLoop
	local stopRenderLoop = deps.stopRenderLoop

	if type(addExtendedAPI) ~= "function" or type(resolveElementParentFromSettings) ~= "function" or type(connectThemeRefresh) ~= "function" then
		warn("Rayfield | FeedbackWidgets missing required helpers for LoadingSpinner.")
		return nil
	end

	local settingsValue = spinnerSettings or {}
	local spinner = {}
	spinner.Name = tostring(settingsValue.Name or "Loading Spinner")
	spinner.Flag = settingsValue.Flag

	local spinnerSize = math.floor(type(clampNumber) == "function" and clampNumber(settingsValue.Size, 14, 64, 26) or 26)
	local spinnerThickness = type(clampNumber) == "function" and clampNumber(settingsValue.Thickness, 1, 8, 3) or 3
	local spinnerSpeed = type(clampNumber) == "function" and clampNumber(settingsValue.Speed, 0.1, 8, 1.2) or 1.2
	local running = settingsValue.AutoStart ~= false
	local customColor = typeof(settingsValue.Color) == "Color3" and settingsValue.Color or nil
	local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
	local rotation = 0
	local loopState = {}

	local root = Instance.new("Frame")
	root.Name = spinner.Name
	root.Size = UDim2.new(1, -10, 0, 44)
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
	title.Size = UDim2.new(1, -70, 1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 13
	title.TextColor3 = self.getSelectedTheme().TextColor
	title.Text = spinner.Name
	title.Parent = root

	local spinnerHost = Instance.new("Frame")
	spinnerHost.Name = "SpinnerHost"
	spinnerHost.AnchorPoint = Vector2.new(1, 0.5)
	spinnerHost.Position = UDim2.new(1, -12, 0.5, 0)
	spinnerHost.Size = UDim2.new(0, spinnerSize, 0, spinnerSize)
	spinnerHost.BackgroundTransparency = 1
	spinnerHost.Parent = root

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.new(1, 0, 1, 0)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.Parent = spinnerHost

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = ring

	local ringStroke = Instance.new("UIStroke")
	ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ringStroke.Thickness = spinnerThickness
	ringStroke.Transparency = 0.55
	ringStroke.Parent = ring

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.new(0, math.max(4, math.floor(spinnerThickness * 1.9)), 0, math.max(4, math.floor(spinnerThickness * 1.9)))
	dot.BackgroundColor3 = self.getSelectedTheme().LoadingSpinner or self.getSelectedTheme().SliderProgress
	dot.BorderSizePixel = 0
	dot.Parent = spinnerHost

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local function resolveSpinnerColor()
		return customColor or self.getSelectedTheme().LoadingSpinner or self.getSelectedTheme().SliderProgress
	end

	local function updateSpinnerPosition()
		local hostWidth = math.max(1, spinnerHost.AbsoluteSize.X)
		local hostHeight = math.max(1, spinnerHost.AbsoluteSize.Y)
		local dotSize = math.max(4, math.floor(spinnerThickness * 1.9))
		dot.Size = UDim2.new(0, dotSize, 0, dotSize)
		local radius = math.max(3, math.min(hostWidth, hostHeight) * 0.5 - math.max(dotSize * 0.55, spinnerThickness))
		local centerX = hostWidth * 0.5
		local centerY = hostHeight * 0.5
		local x = centerX + math.cos(rotation) * radius - (dotSize * 0.5)
		local y = centerY + math.sin(rotation) * radius - (dotSize * 0.5)
		dot.Position = UDim2.new(0, x, 0, y)
	end

	local function applySpinnerVisual()
		root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
		stroke.Color = self.getSelectedTheme().ElementStroke
		title.TextColor3 = self.getSelectedTheme().TextColor
		ringStroke.Color = self.getSelectedTheme().LoadingTrack or self.getSelectedTheme().SliderBackground
		ringStroke.Thickness = spinnerThickness
		dot.BackgroundColor3 = resolveSpinnerColor()
		spinnerHost.Size = UDim2.new(0, spinnerSize, 0, spinnerSize)
		updateSpinnerPosition()
	end

	local function getStateSnapshot()
		return {
			running = running == true,
			speed = spinnerSpeed,
			size = spinnerSize,
			thickness = spinnerThickness
		}
	end

	local function emitStateChanged(persist)
		local okCallback, callbackErr = pcall(callback, type(cloneSerializable) == "function" and cloneSerializable(getStateSnapshot()) or getStateSnapshot())
		if not okCallback then
			warn("Rayfield | LoadingSpinner callback failed: " .. tostring(callbackErr))
		end
		if persist ~= false and settingsValue.Ext ~= true then
			self.SaveConfiguration()
		end
	end

	local function stepSpinner(deltaTime)
		if running ~= true then
			return
		end
		rotation += (deltaTime * spinnerSpeed * math.pi * 2)
		if rotation > (math.pi * 2) then
			rotation -= (math.pi * 2)
		end
		updateSpinnerPosition()
	end

	function spinner:Start(persist)
		if running == true then
			if type(startRenderLoop) == "function" then
				startRenderLoop(loopState, stepSpinner)
			end
			return true, "already_running"
		end
		running = true
		if type(startRenderLoop) == "function" then
			startRenderLoop(loopState, stepSpinner)
		end
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function spinner:Stop(persist)
		if running ~= true then
			if type(stopRenderLoop) == "function" then
				stopRenderLoop(loopState)
			end
			return true, "already_stopped"
		end
		running = false
		if type(stopRenderLoop) == "function" then
			stopRenderLoop(loopState)
		end
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function spinner:IsRunning()
		return running == true and loopState.Connection ~= nil
	end

	function spinner:SetSpeed(nextSpeed, persist)
		if type(clampNumber) == "function" then
			spinnerSpeed = clampNumber(nextSpeed, 0.1, 8, spinnerSpeed)
		end
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function spinner:GetSpeed()
		return spinnerSpeed
	end

	function spinner:SetColor(nextColor, persist)
		if typeof(nextColor) ~= "Color3" then
			return false, "SetColor expects Color3."
		end
		customColor = nextColor
		applySpinnerVisual()
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function spinner:SetSize(nextSize, persist)
		if type(clampNumber) == "function" then
			spinnerSize = math.floor(clampNumber(nextSize, 14, 64, spinnerSize))
		end
		applySpinnerVisual()
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function spinner:GetPersistValue()
		local snapshot = getStateSnapshot()
		local packed = type(packColor3) == "function" and packColor3(customColor) or nil
		if packed then
			snapshot.colorPacked = packed
		end
		return snapshot
	end

	function spinner:Set(value)
		if type(value) ~= "table" then
			return
		end
		if value.size ~= nil and type(clampNumber) == "function" then
			spinnerSize = math.floor(clampNumber(value.size, 14, 64, spinnerSize))
		end
		if value.thickness ~= nil and type(clampNumber) == "function" then
			spinnerThickness = clampNumber(value.thickness, 1, 8, spinnerThickness)
		end
		if value.speed ~= nil and type(clampNumber) == "function" then
			spinnerSpeed = clampNumber(value.speed, 0.1, 8, spinnerSpeed)
		end
		if value.colorPacked ~= nil and type(unpackColor3) == "function" then
			customColor = unpackColor3(value.colorPacked) or customColor
		elseif typeof(value.color) == "Color3" then
			customColor = value.color
		end
		applySpinnerVisual()
		if value.running == true then
			spinner:Start(false)
		elseif value.running == false then
			spinner:Stop(false)
		else
			emitStateChanged(false)
		end
	end

	function spinner:Destroy()
		if type(stopRenderLoop) == "function" then
			stopRenderLoop(loopState)
		end
		root:Destroy()
	end

	connectThemeRefresh(function()
		applySpinnerVisual()
	end)

	resolveElementParentFromSettings(spinner, settingsValue)
	applySpinnerVisual()
	if running == true and type(startRenderLoop) == "function" then
		startRenderLoop(loopState, stepSpinner)
	end
	addExtendedAPI(spinner, spinner.Name, "LoadingSpinner", root)
	if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and spinner.Flag then
		self.RayfieldLibrary.Flags[spinner.Flag] = spinner
	end
	return spinner
end

function FeedbackWidgetsFactory.createLoadingBar(context, barSettings)
	local deps = readContext(context)
	if not deps then
		warn("Rayfield | FeedbackWidgets context invalid for LoadingBar.")
		return nil
	end
	local self = deps.self
	local TabPage = deps.TabPage
	local Settings = deps.Settings
	local addExtendedAPI = deps.addExtendedAPI
	local resolveElementParentFromSettings = deps.resolveElementParentFromSettings
	local connectThemeRefresh = deps.connectThemeRefresh
	local cloneSerializable = deps.cloneSerializable
	local clampNumber = deps.clampNumber
	local startRenderLoop = deps.startRenderLoop
	local stopRenderLoop = deps.stopRenderLoop

	if type(addExtendedAPI) ~= "function" or type(resolveElementParentFromSettings) ~= "function" or type(connectThemeRefresh) ~= "function" then
		warn("Rayfield | FeedbackWidgets missing required helpers for LoadingBar.")
		return nil
	end

	local settingsValue = barSettings or {}
	local loadingBar = {}
	loadingBar.Name = tostring(settingsValue.Name or "Loading Bar")
	loadingBar.Flag = settingsValue.Flag

	local mode = tostring(settingsValue.Mode or "indeterminate"):lower()
	if mode ~= "indeterminate" and mode ~= "determinate" then
		mode = "indeterminate"
	end
	local speed = type(clampNumber) == "function" and clampNumber(settingsValue.Speed, 0.1, 6, 1.1) or 1.1
	local chunkScale = type(clampNumber) == "function" and clampNumber(settingsValue.ChunkScale, 0.1, 0.8, 0.35) or 0.35
	local progress = type(clampNumber) == "function" and clampNumber(settingsValue.Progress, 0, 1, 0) or 0
	local showLabel = settingsValue.ShowLabel == true
	local customLabel = nil
	local labelFormatter = type(settingsValue.LabelFormatter) == "function" and settingsValue.LabelFormatter or nil
	local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
	local running = mode == "indeterminate" and settingsValue.AutoStart ~= false
	local loopState = {}
	local animationPhase = 0
	local barHeight = math.floor(type(clampNumber) == "function" and clampNumber(settingsValue.Height, 12, 40, 18) or 18)

	local root = Instance.new("Frame")
	root.Name = loadingBar.Name
	root.Size = UDim2.new(1, -10, 0, math.max(44, barHeight + 26))
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
	title.Size = UDim2.new(0.65, 0, 0, 20)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 13
	title.TextColor3 = self.getSelectedTheme().TextColor
	title.Text = loadingBar.Name
	title.Parent = root

	local statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.AnchorPoint = Vector2.new(1, 0)
	statusLabel.Position = UDim2.new(1, -10, 0, 2)
	statusLabel.Size = UDim2.new(0.35, -4, 0, 18)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 11
	statusLabel.TextColor3 = self.getSelectedTheme().LoadingText or self.getSelectedTheme().TextColor
	statusLabel.Visible = showLabel
	statusLabel.Parent = root

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 10, 0, 22)
	track.Size = UDim2.new(1, -20, 0, barHeight)
	track.BackgroundColor3 = self.getSelectedTheme().LoadingTrack or self.getSelectedTheme().SliderBackground
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = root

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, math.max(4, math.floor(barHeight * 0.5)))
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(progress, 0, 1, 0)
	fill.BackgroundColor3 = self.getSelectedTheme().LoadingBar or self.getSelectedTheme().SliderProgress
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, math.max(4, math.floor(barHeight * 0.5)))
	fillCorner.Parent = fill

	local chunk = Instance.new("Frame")
	chunk.Name = "Chunk"
	chunk.Size = UDim2.new(chunkScale, 0, 1, 0)
	chunk.Position = UDim2.new(0, 0, 0, 0)
	chunk.BackgroundColor3 = self.getSelectedTheme().LoadingBar or self.getSelectedTheme().SliderProgress
	chunk.BorderSizePixel = 0
	chunk.Parent = track

	local chunkCorner = Instance.new("UICorner")
	chunkCorner.CornerRadius = UDim.new(0, math.max(4, math.floor(barHeight * 0.5)))
	chunkCorner.Parent = chunk

	local function getStateSnapshot()
		return {
			mode = mode,
			running = running == true and mode == "indeterminate",
			progress = progress,
			speed = speed,
			chunkScale = chunkScale,
			label = customLabel
		}
	end

	local function emitStateChanged(persist)
		local payload = type(cloneSerializable) == "function" and cloneSerializable(getStateSnapshot()) or getStateSnapshot()
		local okCallback, callbackErr = pcall(callback, payload)
		if not okCallback then
			warn("Rayfield | LoadingBar callback failed: " .. tostring(callbackErr))
		end
		if persist ~= false and settingsValue.Ext ~= true then
			self.SaveConfiguration()
		end
	end

	local function formatLabelText()
		if customLabel and customLabel ~= "" then
			return customLabel
		end
		local percent = math.floor((progress * 100) + 0.5)
		if labelFormatter then
			local okFormat, formatted = pcall(labelFormatter, progress, percent, mode)
			if okFormat and formatted ~= nil then
				return tostring(formatted)
			end
		end
		if mode == "determinate" then
			return tostring(percent) .. "%"
		end
		return "Loading..."
	end

	local function updateBarVisual()
		root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
		stroke.Color = self.getSelectedTheme().ElementStroke
		title.TextColor3 = self.getSelectedTheme().TextColor
		statusLabel.TextColor3 = self.getSelectedTheme().LoadingText or self.getSelectedTheme().TextColor
		statusLabel.Visible = showLabel
		if showLabel then
			statusLabel.Text = formatLabelText()
		end
		track.BackgroundColor3 = self.getSelectedTheme().LoadingTrack or self.getSelectedTheme().SliderBackground
		fill.BackgroundColor3 = self.getSelectedTheme().LoadingBar or self.getSelectedTheme().SliderProgress
		chunk.BackgroundColor3 = self.getSelectedTheme().LoadingBar or self.getSelectedTheme().SliderProgress
		fill.Visible = mode == "determinate"
		chunk.Visible = mode == "indeterminate" and running == true
		if mode == "determinate" then
			fill.Size = UDim2.new(progress, 0, 1, 0)
		end
	end

	local function stepBar(deltaTime)
		if mode ~= "indeterminate" or running ~= true then
			return
		end
		local trackWidth = math.max(1, track.AbsoluteSize.X)
		local chunkWidth = math.max(8, math.floor(trackWidth * chunkScale))
		chunk.Size = UDim2.new(0, chunkWidth, 1, 0)
		animationPhase = (animationPhase + (deltaTime * speed)) % 2
		local t = animationPhase
		if t > 1 then
			t = 2 - t
		end
		local usableWidth = math.max(0, trackWidth - chunkWidth)
		local x = math.floor(usableWidth * t + 0.5)
		chunk.Position = UDim2.new(0, x, 0, 0)
	end

	function loadingBar:Start(persist)
		if mode ~= "indeterminate" then
			return false, "Start is available only in indeterminate mode."
		end
		if running == true then
			if type(startRenderLoop) == "function" then
				startRenderLoop(loopState, stepBar)
			end
			return true, "already_running"
		end
		running = true
		if type(startRenderLoop) == "function" then
			startRenderLoop(loopState, stepBar)
		end
		updateBarVisual()
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function loadingBar:Stop(persist)
		if running ~= true then
			if type(stopRenderLoop) == "function" then
				stopRenderLoop(loopState)
			end
			return true, "already_stopped"
		end
		running = false
		if type(stopRenderLoop) == "function" then
			stopRenderLoop(loopState)
		end
		updateBarVisual()
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function loadingBar:IsRunning()
		return mode == "indeterminate" and running == true and loopState.Connection ~= nil
	end

	function loadingBar:SetMode(nextMode, persist)
		local normalized = tostring(nextMode or ""):lower()
		if normalized ~= "indeterminate" and normalized ~= "determinate" then
			return false, "Invalid mode."
		end
		mode = normalized
		if mode ~= "indeterminate" then
			running = false
			if type(stopRenderLoop) == "function" then
				stopRenderLoop(loopState)
			end
		end
		updateBarVisual()
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function loadingBar:GetMode()
		return mode
	end

	function loadingBar:SetProgress(nextProgress, persist)
		if type(clampNumber) == "function" then
			progress = clampNumber(nextProgress, 0, 1, progress)
		end
		if mode ~= "determinate" then
			mode = "determinate"
			running = false
			if type(stopRenderLoop) == "function" then
				stopRenderLoop(loopState)
			end
		end
		updateBarVisual()
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function loadingBar:GetProgress()
		return progress
	end

	function loadingBar:SetSpeed(nextSpeed, persist)
		if type(clampNumber) == "function" then
			speed = clampNumber(nextSpeed, 0.1, 6, speed)
		end
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function loadingBar:SetLabel(text, persist)
		if not showLabel then
			return false, "ShowLabel is disabled."
		end
		customLabel = tostring(text or "")
		updateBarVisual()
		emitStateChanged(persist ~= false)
		return true, "ok"
	end

	function loadingBar:GetPersistValue()
		return getStateSnapshot()
	end

	function loadingBar:Set(value)
		if type(value) ~= "table" then
			return
		end
		if value.mode ~= nil then
			local normalized = tostring(value.mode):lower()
			if normalized == "indeterminate" or normalized == "determinate" then
				mode = normalized
			end
		end
		if value.speed ~= nil and type(clampNumber) == "function" then
			speed = clampNumber(value.speed, 0.1, 6, speed)
		end
		if value.chunkScale ~= nil and type(clampNumber) == "function" then
			chunkScale = clampNumber(value.chunkScale, 0.1, 0.8, chunkScale)
		end
		if value.progress ~= nil and type(clampNumber) == "function" then
			progress = clampNumber(value.progress, 0, 1, progress)
		end
		if value.label ~= nil then
			customLabel = tostring(value.label or "")
		end
		if value.running == true and mode == "indeterminate" then
			running = true
		elseif value.running == false or mode ~= "indeterminate" then
			running = false
		end
		updateBarVisual()
		if mode == "indeterminate" and running == true then
			if type(startRenderLoop) == "function" then
				startRenderLoop(loopState, stepBar)
			end
		else
			if type(stopRenderLoop) == "function" then
				stopRenderLoop(loopState)
			end
		end
		emitStateChanged(false)
	end

	function loadingBar:Destroy()
		if type(stopRenderLoop) == "function" then
			stopRenderLoop(loopState)
		end
		root:Destroy()
	end

	connectThemeRefresh(function()
		updateBarVisual()
	end)

	resolveElementParentFromSettings(loadingBar, settingsValue)
	updateBarVisual()
	if mode == "indeterminate" and running == true and type(startRenderLoop) == "function" then
		startRenderLoop(loopState, stepBar)
	end
	addExtendedAPI(loadingBar, loadingBar.Name, "LoadingBar", root)
	if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and loadingBar.Flag then
		self.RayfieldLibrary.Flags[loadingBar.Flag] = loadingBar
	end
	return loadingBar
end

return FeedbackWidgetsFactory
