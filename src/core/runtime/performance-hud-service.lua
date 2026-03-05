local PerformanceHUDService = {}

local DEFAULT_POSITION = { x = 16, y = 52 }
local DEFAULT_SIZE = { width = 260, height = 176 }
local DEFAULT_DOCK = "top_left"
local TOP_SAFE_OFFSET = 52
local VIEWPORT_PADDING = 8

local function clampNumber(value, minValue, maxValue, fallback)
	local numeric = tonumber(value)
	if not numeric then
		return fallback
	end
	if numeric < minValue then
		return minValue
	end
	if numeric > maxValue then
		return maxValue
	end
	return numeric
end

local function cloneValue(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	for key, nested in pairs(value) do
		out[cloneValue(key, seen)] = cloneValue(nested, seen)
	end
	return out
end

local function normalizeDock(value)
	local dock = string.lower(tostring(value or ""))
	if dock == "top_left"
		or dock == "top_right"
		or dock == "bottom_left"
		or dock == "bottom_right"
		or dock == "center"
		or dock == "custom" then
		return dock
	end
	return DEFAULT_DOCK
end

function PerformanceHUDService.create(ctx)
	ctx = ctx or {}
	local Main = ctx.Main
	local Topbar = ctx.Topbar
	local RunService = ctx.RunService
	local UserInputService = ctx.UserInputService
	local bindTheme = type(ctx.bindTheme) == "function" and ctx.bindTheme or nil
	local getSelectedTheme = type(ctx.getSelectedTheme) == "function" and ctx.getSelectedTheme or function()
		return nil
	end
	local loadState = type(ctx.loadState) == "function" and ctx.loadState or nil
	local saveState = type(ctx.saveState) == "function" and ctx.saveState or nil
	local getRuntimeDiagnostics = type(ctx.getRuntimeDiagnostics) == "function" and ctx.getRuntimeDiagnostics or function()
		return {}
	end
	local getVisibilityState = type(ctx.getVisibilityState) == "function" and ctx.getVisibilityState or function()
		return { hidden = false, minimized = false }
	end
	local getMacroState = type(ctx.getMacroState) == "function" and ctx.getMacroState or function()
		return { recording = false, executing = false }
	end
	local getAutomationSummary = type(ctx.getAutomationSummary) == "function" and ctx.getAutomationSummary or function()
		return { scheduled = 0, rules = 0 }
	end
	local localize = type(ctx.localize) == "function" and ctx.localize or function(_, fallback)
		return tostring(fallback or "")
	end
	local function L(key, fallback)
		local okValue, value = pcall(localize, key, fallback)
		if okValue and type(value) == "string" and value ~= "" then
			return value
		end
		return tostring(fallback or key or "")
	end
	local function getValueType(value)
		if type(typeof) == "function" then
			return typeof(value)
		end
		return type(value)
	end
	local function isColor3(value)
		return getValueType(value) == "Color3"
	end
	local function getThemeColor(themeKey, fallback)
		local selectedTheme = getSelectedTheme()
		if type(selectedTheme) == "table" then
			local themedValue = selectedTheme[themeKey]
			if isColor3(themedValue) then
				return themedValue
			end
		end
		return fallback
	end
	local function resolveMainCornerRadius()
		if Main and type(Main.FindFirstChildOfClass) == "function" then
			local mainCorner = Main:FindFirstChildOfClass("UICorner")
			if mainCorner and mainCorner.CornerRadius then
				return mainCorner.CornerRadius
			end
		end
		return UDim.new(0, 8)
	end

	local defaultEnabled = not (type(_G) == "table" and _G.__RAYFIELD_PERF_HUD_ENABLED == false)
	local defaultHz = clampNumber(type(_G) == "table" and _G.__RAYFIELD_PERF_HUD_UPDATE_HZ or 4, 1, 30, 4)
	local defaultOpacity = clampNumber(type(_G) == "table" and _G.__RAYFIELD_PERF_HUD_OPACITY or 0.75, 0.15, 1, 0.75)

	local state = {
		enabled = defaultEnabled,
		updateHz = defaultHz,
		opacity = defaultOpacity,
		position = cloneValue(DEFAULT_POSITION),
		size = cloneValue(DEFAULT_SIZE),
		dock = DEFAULT_DOCK,
		visible = false,
		lastUpdatedAt = 0,
		lastMetrics = {},
		registeredProviders = {}
	}

	local refs = {}
	local destroyed = false
	local providers = {}
	local connections = {}
	local themeBound = false
	local fpsState = {
		lastClock = os.clock(),
		smoothed = 0,
		samplerBound = false
	}

	local function disconnectAll()
		for index = #connections, 1, -1 do
			local connection = connections[index]
			if connection then
				pcall(function()
					connection:Disconnect()
				end)
			end
			connections[index] = nil
		end
	end

	local function connectSignal(signal, callback)
		if not signal or type(callback) ~= "function" then
			return nil
		end
		local okConnect, connectionOrErr = pcall(function()
			return signal:Connect(callback)
		end)
		if okConnect and connectionOrErr then
			table.insert(connections, connectionOrErr)
			return connectionOrErr
		end
		return nil
	end

	local function sampleFpsFromDelta(deltaTime)
		local delta = tonumber(deltaTime)
		if not delta or delta <= 0 then
			return
		end
		local instantFps = 1 / delta
		if instantFps <= 0 or instantFps > 1000 then
			return
		end
		fpsState.lastClock = os.clock()
		if fpsState.smoothed <= 0 then
			fpsState.smoothed = instantFps
		else
			fpsState.smoothed = (fpsState.smoothed * 0.9) + (instantFps * 0.1)
		end
	end

	local function bindFpsSampler()
		if fpsState.samplerBound or not RunService then
			return
		end
		local signal = RunService.RenderStepped or RunService.Heartbeat
		if not signal then
			return
		end
		local okConnect, connectionOrErr = pcall(function()
			return signal:Connect(function(deltaTime)
				sampleFpsFromDelta(deltaTime)
			end)
		end)
		if okConnect and connectionOrErr then
			fpsState.samplerBound = true
			table.insert(connections, connectionOrErr)
		end
	end

	local function applyThemeFallbackColors()
		if bindTheme then
			return
		end
		if refs.Root then
			refs.Root.BackgroundColor3 = getThemeColor("Background", Color3.fromRGB(16, 20, 26))
		end
		if refs.Stroke then
			refs.Stroke.Color = getThemeColor("ElementStroke", Color3.fromRGB(150, 180, 255))
		end
		if refs.TitleBar then
			refs.TitleBar.BackgroundColor3 = getThemeColor("Topbar", Color3.fromRGB(24, 30, 42))
			refs.TitleBar.TextColor3 = getThemeColor("TextColor", Color3.fromRGB(235, 240, 255))
		end
		if refs.CloseButton then
			refs.CloseButton.BackgroundColor3 = getThemeColor("SecondaryElementBackground", Color3.fromRGB(48, 60, 82))
			refs.CloseButton.TextColor3 = getThemeColor("TextColor", Color3.fromRGB(230, 235, 245))
		end
		if refs.Body then
			refs.Body.TextColor3 = getThemeColor("TextColor", Color3.fromRGB(222, 232, 255))
		end
		if refs.ResizeHandle then
			refs.ResizeHandle.BackgroundColor3 = getThemeColor("SecondaryElementBackground", Color3.fromRGB(64, 78, 104))
			refs.ResizeHandle.TextColor3 = getThemeColor("TextColor", Color3.fromRGB(230, 240, 255))
		end
	end

	local function bindThemeColors()
		if themeBound or not bindTheme or not refs.Root then
			return
		end
		themeBound = true
		pcall(bindTheme, refs.Root, "BackgroundColor3", "Background")
		pcall(bindTheme, refs.Stroke, "Color", "ElementStroke")
		pcall(bindTheme, refs.TitleBar, "BackgroundColor3", "Topbar")
		pcall(bindTheme, refs.TitleBar, "TextColor3", "TextColor")
		pcall(bindTheme, refs.CloseButton, "BackgroundColor3", "SecondaryElementBackground")
		pcall(bindTheme, refs.CloseButton, "TextColor3", "TextColor")
		pcall(bindTheme, refs.Body, "TextColor3", "TextColor")
		pcall(bindTheme, refs.ResizeHandle, "BackgroundColor3", "SecondaryElementBackground")
		pcall(bindTheme, refs.ResizeHandle, "TextColor3", "TextColor")
	end

	local function syncStyleFromMain()
		if not refs.Root then
			return
		end
		local cornerRadius = resolveMainCornerRadius()
		if refs.Corner then
			refs.Corner.CornerRadius = cornerRadius
		end

		local topbarTransparency = nil
		if Topbar then
			topbarTransparency = tonumber(Topbar.BackgroundTransparency)
		end
		if topbarTransparency == nil and Main then
			topbarTransparency = tonumber(Main.BackgroundTransparency)
		end
		topbarTransparency = clampNumber(topbarTransparency, 0, 1, 0.15)

		if refs.TitleBar then
			refs.TitleBar.BackgroundTransparency = topbarTransparency
		end
		if refs.CloseButton then
			refs.CloseButton.BackgroundTransparency = clampNumber(topbarTransparency + 0.1, 0, 1, 0.25)
		end
		if refs.ResizeHandle then
			refs.ResizeHandle.BackgroundTransparency = clampNumber(topbarTransparency + 0.1, 0, 1, 0.2)
		end

		local topbarTitle = Topbar and Topbar:FindFirstChild("Title")
		if topbarTitle and topbarTitle:IsA("TextLabel") then
			local titleTextSize = clampNumber(topbarTitle.TextSize, 10, 24, 11)
			if refs.TitleBar then
				refs.TitleBar.Font = topbarTitle.Font
				refs.TitleBar.TextSize = titleTextSize
			end
			if refs.Body then
				refs.Body.Font = topbarTitle.Font
				refs.Body.TextSize = clampNumber(titleTextSize - 1, 10, 22, 11)
			end
		end
	end

	local function getHudParent()
		if Main and Main.Parent then
			return Main.Parent
		end
		return nil
	end

	local function getParentAbsoluteSize()
		local parent = getHudParent()
		if parent and parent.AbsoluteSize then
			return parent.AbsoluteSize
		end
		return nil
	end

	local function clampStateSize()
		state.size.width = math.max(220, math.floor(tonumber(state.size.width) or DEFAULT_SIZE.width))
		state.size.height = math.max(140, math.floor(tonumber(state.size.height) or DEFAULT_SIZE.height))
	end

	local function clampStatePosition()
		state.position.x = math.max(0, math.floor(tonumber(state.position.x) or DEFAULT_POSITION.x))
		state.position.y = math.max(0, math.floor(tonumber(state.position.y) or DEFAULT_POSITION.y))
		local parentSize = getParentAbsoluteSize()
		if not parentSize then
			return
		end
		local maxX = math.max(0, parentSize.X - state.size.width - VIEWPORT_PADDING)
		local maxY = math.max(0, parentSize.Y - state.size.height - VIEWPORT_PADDING)
		state.position.x = math.min(state.position.x, maxX)
		state.position.y = math.min(state.position.y, maxY)
	end

	local function resolveDockPosition(dock)
		local parentSize = getParentAbsoluteSize()
		local key = normalizeDock(dock)
		if key == "custom" then
			return state.position.x, state.position.y
		end
		if not parentSize then
			if key == "top_right" then
				return DEFAULT_POSITION.x + 140, DEFAULT_POSITION.y
			elseif key == "bottom_left" then
				return DEFAULT_POSITION.x, DEFAULT_POSITION.y + 120
			elseif key == "bottom_right" then
				return DEFAULT_POSITION.x + 140, DEFAULT_POSITION.y + 120
			elseif key == "center" then
				return DEFAULT_POSITION.x + 70, DEFAULT_POSITION.y + 60
			end
			return DEFAULT_POSITION.x, DEFAULT_POSITION.y
		end
		local maxX = math.max(0, parentSize.X - state.size.width - VIEWPORT_PADDING)
		local maxY = math.max(0, parentSize.Y - state.size.height - VIEWPORT_PADDING)
		if key == "top_right" then
			return maxX, TOP_SAFE_OFFSET
		elseif key == "bottom_left" then
			return VIEWPORT_PADDING, maxY
		elseif key == "bottom_right" then
			return maxX, maxY
		elseif key == "center" then
			return math.max(0, math.floor((parentSize.X - state.size.width) / 2)), math.max(0, math.floor((parentSize.Y - state.size.height) / 2))
		end
		return VIEWPORT_PADDING, TOP_SAFE_OFFSET
	end

	local function makePersistedSnapshot()
		return {
			updateHz = state.updateHz,
			opacity = state.opacity,
			position = {
				x = state.position.x,
				y = state.position.y
			},
			size = {
				width = state.size.width,
				height = state.size.height
			},
			dock = state.dock
		}
	end

	local function persistState()
		if type(saveState) ~= "function" then
			return
		end
		pcall(saveState, makePersistedSnapshot())
	end

	local function applyPersistedState(raw)
		if type(raw) ~= "table" then
			return
		end
		if raw.updateHz ~= nil then
			state.updateHz = clampNumber(raw.updateHz, 1, 30, state.updateHz)
		end
		if raw.opacity ~= nil then
			state.opacity = clampNumber(raw.opacity, 0.15, 1, state.opacity)
		end
		if type(raw.position) == "table" then
			state.position.x = math.floor(tonumber(raw.position.x or raw.position.X) or state.position.x)
			state.position.y = math.floor(tonumber(raw.position.y or raw.position.Y) or state.position.y)
		end
		if type(raw.size) == "table" then
			state.size.width = math.floor(tonumber(raw.size.width or raw.size.w) or state.size.width)
			state.size.height = math.floor(tonumber(raw.size.height or raw.size.h) or state.size.height)
		end
		state.dock = normalizeDock(raw.dock)
		clampStateSize()
		clampStatePosition()
	end

	if type(loadState) == "function" then
		local okLoad, persisted = pcall(loadState)
		if okLoad and type(persisted) == "table" then
			applyPersistedState(persisted)
		end
	end

	local function updateRootVisual()
		if not refs.Root then
			return
		end
		clampStateSize()
		clampStatePosition()
		local baseTransparency = 1 - state.opacity
		local mainTransparency = Main and tonumber(Main.BackgroundTransparency) or 0
		refs.Root.BackgroundTransparency = clampNumber(baseTransparency + (clampNumber(mainTransparency, 0, 1, 0) * 0.2), 0, 1, baseTransparency)
		refs.Root.Visible = state.visible
		refs.Root.Position = UDim2.fromOffset(state.position.x, state.position.y)
		refs.Root.Size = UDim2.fromOffset(state.size.width, state.size.height)
		syncStyleFromMain()
		applyThemeFallbackColors()
	end

	local function ensureGui()
		if refs.Root and refs.Root.Parent then
			local parent = getHudParent()
			if parent and refs.Root.Parent ~= parent then
				refs.Root.Parent = parent
			end
			bindThemeColors()
			syncStyleFromMain()
			applyThemeFallbackColors()
			return true
		end
		local parent = getHudParent()
		if not parent then
			return false
		end

		local root = Instance.new("Frame")
		root.Name = "RayfieldPerformanceHUD"
		root.BorderSizePixel = 0
		root.ZIndex = 95
		root.BackgroundColor3 = getThemeColor("Background", Color3.fromRGB(16, 20, 26))
		root.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = resolveMainCornerRadius()
		corner.Parent = root

		local stroke = Instance.new("UIStroke")
		stroke.Transparency = 0.3
		stroke.Thickness = 1
		stroke.Color = getThemeColor("ElementStroke", Color3.fromRGB(150, 180, 255))
		stroke.Parent = root

		local titleBar = Instance.new("TextButton")
		titleBar.Name = "TitleBar"
		titleBar.BorderSizePixel = 0
		titleBar.BackgroundColor3 = getThemeColor("Topbar", Color3.fromRGB(24, 30, 42))
		titleBar.BackgroundTransparency = 0.15
		titleBar.Size = UDim2.new(1, -24, 0, 22)
		titleBar.Position = UDim2.fromOffset(0, 0)
		titleBar.Font = Enum.Font.GothamBold
		titleBar.TextSize = 11
		titleBar.TextXAlignment = Enum.TextXAlignment.Left
		titleBar.Text = "  " .. L("hud.title", "Performance HUD")
		titleBar.TextColor3 = getThemeColor("TextColor", Color3.fromRGB(235, 240, 255))
		titleBar.ZIndex = 96
		titleBar.Parent = root

		local closeButton = Instance.new("TextButton")
		closeButton.Name = "Close"
		closeButton.BorderSizePixel = 0
		closeButton.BackgroundColor3 = getThemeColor("SecondaryElementBackground", Color3.fromRGB(48, 60, 82))
		closeButton.BackgroundTransparency = 0.15
		closeButton.Size = UDim2.fromOffset(22, 22)
		closeButton.Position = UDim2.new(1, -22, 0, 0)
		closeButton.Font = Enum.Font.GothamBold
		closeButton.TextSize = 12
		closeButton.Text = "x"
		closeButton.TextColor3 = getThemeColor("TextColor", Color3.fromRGB(230, 235, 245))
		closeButton.ZIndex = 96
		closeButton.Parent = root

		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(8, 26)
		body.Size = UDim2.new(1, -16, 1, -34)
		body.Font = Enum.Font.Code
		body.TextSize = 12
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextWrapped = true
		body.RichText = false
		body.TextColor3 = getThemeColor("TextColor", Color3.fromRGB(222, 232, 255))
		body.Text = L("hud.status.ready", "HUD ready.")
		body.ZIndex = 96
		body.Parent = root

		local resizeHandle = Instance.new("TextButton")
		resizeHandle.Name = "ResizeHandle"
		resizeHandle.BorderSizePixel = 0
		resizeHandle.BackgroundColor3 = getThemeColor("SecondaryElementBackground", Color3.fromRGB(64, 78, 104))
		resizeHandle.BackgroundTransparency = 0.1
		resizeHandle.Size = UDim2.fromOffset(16, 16)
		resizeHandle.Position = UDim2.new(1, -16, 1, -16)
		resizeHandle.Font = Enum.Font.GothamBold
		resizeHandle.TextSize = 10
		resizeHandle.Text = "<>"
		resizeHandle.TextColor3 = getThemeColor("TextColor", Color3.fromRGB(230, 240, 255))
		resizeHandle.ZIndex = 96
		resizeHandle.Parent = root

		refs = {
			Root = root,
			Corner = corner,
			Stroke = stroke,
			TitleBar = titleBar,
			CloseButton = closeButton,
			Body = body,
			ResizeHandle = resizeHandle
		}

		local function refreshStyleFromSources()
			syncStyleFromMain()
			applyThemeFallbackColors()
		end

		bindThemeColors()
		refreshStyleFromSources()

		if Main and type(Main.GetPropertyChangedSignal) == "function" then
			connectSignal(Main:GetPropertyChangedSignal("BackgroundTransparency"), refreshStyleFromSources)
			local mainCorner = Main:FindFirstChildOfClass("UICorner")
			if mainCorner and type(mainCorner.GetPropertyChangedSignal) == "function" then
				connectSignal(mainCorner:GetPropertyChangedSignal("CornerRadius"), refreshStyleFromSources)
			end
			connectSignal(Main.ChildAdded, function(child)
				if child and child:IsA("UICorner") and type(child.GetPropertyChangedSignal) == "function" then
					connectSignal(child:GetPropertyChangedSignal("CornerRadius"), refreshStyleFromSources)
					refreshStyleFromSources()
				end
			end)
		end

		if Topbar and type(Topbar.GetPropertyChangedSignal) == "function" then
			connectSignal(Topbar:GetPropertyChangedSignal("BackgroundTransparency"), refreshStyleFromSources)
			local topbarTitle = Topbar:FindFirstChild("Title")
			if topbarTitle and topbarTitle:IsA("TextLabel") and type(topbarTitle.GetPropertyChangedSignal) == "function" then
				connectSignal(topbarTitle:GetPropertyChangedSignal("Font"), refreshStyleFromSources)
				connectSignal(topbarTitle:GetPropertyChangedSignal("TextSize"), refreshStyleFromSources)
			end
		end

		local dragging = false
		local dragStart = nil
		local positionStart = nil
		local resizing = false
		local sizeStart = nil

		table.insert(connections, titleBar.MouseButton1Down:Connect(function()
			dragging = true
			dragStart = UserInputService and UserInputService:GetMouseLocation() or Vector2.new(0, 0)
			positionStart = { x = state.position.x, y = state.position.y }
		end))

		table.insert(connections, resizeHandle.MouseButton1Down:Connect(function()
			resizing = true
			dragStart = UserInputService and UserInputService:GetMouseLocation() or Vector2.new(0, 0)
			sizeStart = { width = state.size.width, height = state.size.height }
		end))

		if UserInputService then
			table.insert(connections, UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local hadMovement = dragging or resizing
					dragging = false
					resizing = false
					if hadMovement then
						persistState()
					end
				end
			end))

			table.insert(connections, UserInputService.InputChanged:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				if dragging and dragStart and positionStart then
					local current = UserInputService:GetMouseLocation()
					local deltaX = current.X - dragStart.X
					local deltaY = current.Y - dragStart.Y
					state.position.x = math.max(0, math.floor(positionStart.x + deltaX))
					state.position.y = math.max(0, math.floor(positionStart.y + deltaY))
					state.dock = "custom"
					updateRootVisual()
				elseif resizing and dragStart and sizeStart then
					local current = UserInputService:GetMouseLocation()
					local deltaX = current.X - dragStart.X
					local deltaY = current.Y - dragStart.Y
					state.size.width = math.max(220, math.floor(sizeStart.width + deltaX))
					state.size.height = math.max(140, math.floor(sizeStart.height + deltaY))
					state.dock = "custom"
					updateRootVisual()
				end
			end))
		end

		table.insert(connections, closeButton.MouseButton1Click:Connect(function()
			state.visible = false
			updateRootVisual()
			persistState()
		end))

		updateRootVisual()
		return true
	end

	local function readPingValue()
		local pingText = "N/A"
		local statsService = game and game:GetService("Stats") or nil
		if statsService then
			local okPing, pingValue = pcall(function()
				local network = statsService:FindFirstChild("Network")
				local serverStats = network and network:FindFirstChild("ServerStatsItem")
				local dataPing = serverStats and serverStats:FindFirstChild("Data Ping")
				return dataPing and dataPing:GetValueString() or nil
			end)
			if okPing and type(pingValue) == "string" and pingValue ~= "" then
				pingText = pingValue
			end
		end
		return pingText
	end

	local function collectDefaultMetrics()
		local diagnostics = getRuntimeDiagnostics() or {}
		local visibility = getVisibilityState() or {}
		local macroState = getMacroState() or {}
		local automation = getAutomationSummary() or {}
		if fpsState.smoothed <= 0 then
			local nowClock = os.clock()
			local delta = math.max(0.0001, nowClock - (fpsState.lastClock or nowClock))
			sampleFpsFromDelta(delta)
		end

		return {
			fps = math.floor(fpsState.smoothed + 0.5),
			ping = readPingValue(),
			activeTweens = tonumber(diagnostics.activeTweens) or 0,
			activeTextHandles = tonumber(diagnostics.activeTextHandles) or 0,
			ownershipScopes = tonumber(diagnostics.ownership and diagnostics.ownership.scopes) or 0,
			ownershipTasks = tonumber(diagnostics.ownership and diagnostics.ownership.tasks) or 0,
			visible = visibility.hidden ~= true,
			minimized = visibility.minimized == true,
			macroRecording = macroState.recording == true,
			macroExecuting = macroState.executing == true,
			scheduledActions = tonumber(automation.scheduled) or 0,
			automationRules = tonumber(automation.rules) or 0
		}
	end

	local function updateBody()
		if not refs.Body then
			return
		end
		bindThemeColors()
		syncStyleFromMain()
		applyThemeFallbackColors()
		local metrics = collectDefaultMetrics()
		for id, provider in pairs(providers) do
			local okProvider, providerValue = pcall(provider.fn, metrics, cloneValue(state))
			if okProvider and providerValue ~= nil then
				metrics[id] = providerValue
			end
		end
		state.lastMetrics = cloneValue(metrics)
		state.lastUpdatedAt = os.clock()

		local lines = {
			string.format(L("hud.metric.fps", "FPS: %s"), tostring(metrics.fps)),
			string.format(L("hud.metric.ping", "Ping: %s"), tostring(metrics.ping)),
			string.format(L("hud.metric.tweens_text", "Tweens: %s | Text: %s"), tostring(metrics.activeTweens), tostring(metrics.activeTextHandles)),
			string.format(L("hud.metric.ownership", "Ownership scopes/tasks: %s/%s"), tostring(metrics.ownershipScopes), tostring(metrics.ownershipTasks)),
			string.format(L("hud.metric.ui_state", "UI visible: %s | minimized: %s"), tostring(metrics.visible), tostring(metrics.minimized)),
			string.format(L("hud.metric.macro", "Macro rec/exec: %s/%s"), tostring(metrics.macroRecording), tostring(metrics.macroExecuting)),
			string.format(L("hud.metric.automation", "Automation scheduled/rules: %s/%s"), tostring(metrics.scheduledActions), tostring(metrics.automationRules))
		}
		refs.Body.Text = table.concat(lines, "\n")
	end

	local function openHUD()
		if destroyed then
			return false, L("hud.error.destroyed", "Performance HUD is destroyed.")
		end
		if not ensureGui() then
			return false, L("hud.error.parent_unavailable", "Performance HUD parent unavailable.")
		end
		state.enabled = true
		state.visible = true
		updateRootVisual()
		updateBody()
		persistState()
		return true, L("hud.status.opened", "Performance HUD opened.")
	end

	local function closeHUD()
		state.visible = false
		updateRootVisual()
		persistState()
		return true, L("hud.status.closed", "Performance HUD closed.")
	end

	local function toggleHUD()
		if state.visible then
			return closeHUD()
		end
		return openHUD()
	end

	local function configureHUD(options)
		options = type(options) == "table" and options or {}
		if options.enabled ~= nil then
			state.enabled = options.enabled == true
		end
		if options.updateHz ~= nil then
			state.updateHz = clampNumber(options.updateHz, 1, 30, state.updateHz)
		end
		if options.opacity ~= nil then
			state.opacity = clampNumber(options.opacity, 0.15, 1, state.opacity)
		end
		if type(options.position) == "table" then
			state.position.x = math.max(0, math.floor(tonumber(options.position.x or options.position.X) or state.position.x))
			state.position.y = math.max(0, math.floor(tonumber(options.position.y or options.position.Y) or state.position.y))
			state.dock = "custom"
		end
		if type(options.size) == "table" then
			state.size.width = math.max(220, math.floor(tonumber(options.size.width or options.size.w) or state.size.width))
			state.size.height = math.max(140, math.floor(tonumber(options.size.height or options.h) or state.size.height))
			state.dock = "custom"
		end
		if options.dock ~= nil then
			local dock = normalizeDock(options.dock)
			state.dock = dock
			if dock ~= "custom" then
				local nextX, nextY = resolveDockPosition(dock)
				state.position.x = nextX
				state.position.y = nextY
			end
		end
		if options.visible ~= nil then
			state.visible = options.visible == true
		end
		updateRootVisual()
		if state.visible then
			updateBody()
		end
		persistState()
		return true, L("hud.status.configured", "Performance HUD configured.")
	end

	local function resetPosition(dock)
		local nextDock = normalizeDock(dock or DEFAULT_DOCK)
		if nextDock == "custom" then
			nextDock = DEFAULT_DOCK
		end
		state.dock = nextDock
		local nextX, nextY = resolveDockPosition(nextDock)
		state.position.x = nextX
		state.position.y = nextY
		updateRootVisual()
		persistState()
		return true, L("hud.status.position_reset", "Performance HUD position reset.")
	end

	local function getStateSnapshot()
		local snapshot = cloneValue(state)
		snapshot.providerCount = 0
		for _ in pairs(providers) do
			snapshot.providerCount += 1
		end
		snapshot.registeredProviders = nil
		return snapshot
	end

	local function registerProvider(id, providerFn, options)
		local key = tostring(id or "")
		if key == "" then
			return false, L("hud.error.provider_id_required", "Provider id is required.")
		end
		if type(providerFn) ~= "function" then
			return false, L("hud.error.provider_must_be_function", "Provider must be a function.")
		end
		providers[key] = {
			fn = providerFn,
			options = type(options) == "table" and cloneValue(options) or {}
		}
		state.registeredProviders[key] = true
		return true, L("hud.status.provider_registered", "HUD provider registered: ") .. key
	end

	local function unregisterProvider(id)
		local key = tostring(id or "")
		if key == "" then
			return false, L("hud.error.provider_id_required", "Provider id is required.")
		end
		providers[key] = nil
		state.registeredProviders[key] = nil
		return true, L("hud.status.provider_removed", "HUD provider removed: ") .. key
	end

	bindFpsSampler()

	task.spawn(function()
		while destroyed == false do
			local delaySec = 1 / math.max(1, state.updateHz)
			task.wait(delaySec)
			if state.visible then
				ensureGui()
				updateBody()
			end
		end
	end)

	ensureGui()
	if defaultEnabled then
		openHUD()
	else
		state.visible = false
		updateRootVisual()
	end

	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		disconnectAll()
		if refs.Root then
			pcall(function()
				refs.Root:Destroy()
			end)
		end
	end

	return {
		open = openHUD,
		close = closeHUD,
		toggle = toggleHUD,
		configure = configureHUD,
		resetPosition = resetPosition,
		getState = getStateSnapshot,
		registerProvider = registerProvider,
		unregisterProvider = unregisterProvider,
		destroy = destroy
	}
end

return PerformanceHUDService
