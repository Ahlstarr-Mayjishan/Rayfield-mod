local RangeBarsFactory = {}

local function normalizeBarSettings(rawSettings, defaults)
	local settings = rawSettings or {}
	settings.Name = settings.Name or defaults.name
	settings.Range = settings.Range or {0, 100}

	local rangeMin = tonumber(settings.Range[1]) or 0
	local rangeMax = tonumber(settings.Range[2]) or 100
	if rangeMax <= rangeMin then
		rangeMax = rangeMin + 1
	end
	settings.Range = {rangeMin, rangeMax}

	settings.Increment = tonumber(settings.Increment) or 1
	if settings.Increment <= 0 then
		settings.Increment = 1
	end

	local currentValue = tonumber(settings.CurrentValue)
	if currentValue == nil then
		currentValue = rangeMin
	end
	settings.CurrentValue = math.clamp(currentValue, rangeMin, rangeMax)

	if type(settings.Callback) ~= "function" then
		settings.Callback = function() end
	end

	if settings.Draggable == nil then
		settings.Draggable = defaults.draggable
	end

	settings.Type = defaults.typeName
	return settings
end

local function createCustomBar(context, rawSettings, customOptions)
	context = type(context) == "table" and context or {}
	local self = context.self
	local TabPage = context.TabPage
	local Settings = context.Settings
	local addExtendedAPI = context.addExtendedAPI
	local registerHoverBinding = context.registerHoverBinding
	local registerElementSync = context.registerElementSync
	local commitElementSync = context.commitElementSync

	if type(self) ~= "table" or typeof(TabPage) ~= "Instance" then
		warn("Rayfield | RangeBars factory context is invalid.")
		return nil
	end
	if type(addExtendedAPI) ~= "function" or type(registerHoverBinding) ~= "function" then
		warn("Rayfield | RangeBars factory missing required helpers.")
		return nil
	end

	customOptions = customOptions or {}
	local barSettings = normalizeBarSettings(rawSettings, {
		name = customOptions.defaultName or "Bar",
		draggable = customOptions.defaultDraggable ~= false,
		typeName = customOptions.typeName or "Bar"
	})
	local showText = customOptions.showText == true
	local statusMode = customOptions.statusMode == true
	local barMin = barSettings.Range[1]
	local barMax = barSettings.Range[2]
	local barDragging = false

	local Bar = self.Elements.Template.Slider:Clone()
	Bar.Name = barSettings.Name
	Bar.Title.Text = barSettings.Name
	Bar.Visible = true
	Bar.Parent = TabPage

	Bar.BackgroundTransparency = 1
	Bar.UIStroke.Transparency = 1
	Bar.Title.TextTransparency = 1

	local BarMain = Bar.Main
	local BarProgress = BarMain.Progress
	local BarValueLabel = BarMain.Information

	if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
		BarMain.Shadow.Visible = false
	end

	self.bindTheme(BarMain, "BackgroundColor3", "SliderBackground")
	self.bindTheme(BarMain.UIStroke, "Color", "SliderStroke")
	self.bindTheme(BarProgress.UIStroke, "Color", "SliderStroke")
	self.bindTheme(BarProgress, "BackgroundColor3", "SliderProgress")

	self.Animation:Create(Bar, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	self.Animation:Create(Bar.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
	self.Animation:Create(Bar.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

	if showText then
		BarValueLabel.Visible = true
		if statusMode then
			BarValueLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			BarValueLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
			BarValueLabel.Size = UDim2.new(1, -8, 1, 0)
			BarValueLabel.TextXAlignment = Enum.TextXAlignment.Center
			BarValueLabel.TextYAlignment = Enum.TextYAlignment.Center
			BarValueLabel.ZIndex = BarProgress.ZIndex + 2
			BarValueLabel.TextStrokeTransparency = 0.7
			if barSettings.TextSize then
				BarValueLabel.TextSize = barSettings.TextSize
			end
		end
	else
		BarValueLabel.Visible = false
		BarValueLabel.TextTransparency = 1
	end

	local function ensureCorner(target, radiusPx)
		local corner = target:FindFirstChildWhichIsA("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Parent = target
		end
		corner.CornerRadius = UDim.new(0, radiusPx)
	end

	local function applyBarGeometry()
		local desiredHeight = tonumber(barSettings.Height) or tonumber(barSettings.BarHeight)
		if statusMode and not desiredHeight and barSettings.AutoHeight ~= false then
			local textSize = tonumber(barSettings.TextSize) or (BarValueLabel and BarValueLabel.TextSize or 14)
			desiredHeight = math.clamp(math.floor(textSize + 12), 26, 44)
		end

		if desiredHeight then
			desiredHeight = math.max(12, math.floor(desiredHeight))
			local baseYOffset = BarMain.Position.Y.Offset
			if baseYOffset <= 0 then
				baseYOffset = 24
			end
			BarMain.Size = UDim2.new(BarMain.Size.X.Scale, BarMain.Size.X.Offset, 0, desiredHeight)
			Bar.Size = UDim2.new(1, -10, 0, baseYOffset + desiredHeight + 10)
		end

		if statusMode or barSettings.Roundness then
			local roundness = tonumber(barSettings.Roundness)
			if not roundness then
				local sourceHeight = BarMain.Size.Y.Offset
				roundness = math.max(6, math.floor(sourceHeight / 2))
			end
			ensureCorner(BarMain, roundness)
			ensureCorner(BarProgress, roundness)
		end
	end

	applyBarGeometry()

	local function formatBarText(value)
		if not showText then
			return ""
		end

		local percent = ((value - barMin) / (barMax - barMin)) * 100
		if type(barSettings.TextFormatter) == "function" then
			local ok, custom = pcall(barSettings.TextFormatter, value, barMax, percent)
			if ok and custom ~= nil then
				return tostring(custom)
			end
		end

		local defaultText = tostring(value) .. "/" .. tostring(barMax)
		if barSettings.Suffix and tostring(barSettings.Suffix) ~= "" then
			defaultText = defaultText .. " " .. tostring(barSettings.Suffix)
		end
		return defaultText
	end

	local function valueToWidth(value)
		local width = BarMain.AbsoluteSize.X
		if width <= 0 then
			return 0
		end
		local ratio = math.clamp((value - barMin) / (barMax - barMin), 0, 1)
		local result = width * ratio
		if ratio > 0 and result < 5 then
			result = 5
		end
		return result
	end

	local function applyVisualValue(value, animate)
		local targetWidth = valueToWidth(value)
		if animate then
			self.Animation:Create(BarProgress, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, targetWidth, 1, 0)}):Play()
		else
			BarProgress.Size = UDim2.new(0, targetWidth, 1, 0)
		end

		if showText and BarValueLabel then
			BarValueLabel.Text = formatBarText(value)
		end
	end

	local function handleBarCallbackError(response)
		self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
		self.Animation:Create(Bar.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
		Bar.Title.Text = "Callback Error"
		print("Rayfield | " .. barSettings.Name .. " Callback Error " .. tostring(response))
		warn('Check docs.sirius.menu for help with Rayfield specific development.')
		task.wait(0.5)
		Bar.Title.Text = barSettings.Name
		self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
		self.Animation:Create(Bar.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
	end

	local function triggerCallback(nextValue)
		local Success, Response = pcall(function()
			barSettings.Callback(nextValue)
		end)
		if not Success then
			handleBarCallbackError(Response)
		end
		return Success
	end

	local function normalizeValue(rawValue)
		local value = math.clamp(tonumber(rawValue) or barMin, barMin, barMax)
		value = math.floor((value / barSettings.Increment) + 0.5) * barSettings.Increment
		value = math.floor((value * 10000000) + 0.5) / 10000000
		return math.clamp(value, barMin, barMax)
	end

	local barSyncToken = nil
	local function applyBarValue(rawValue, opts)
		opts = opts or {}
		if barSyncToken and type(commitElementSync) == "function" then
			return commitElementSync(barSyncToken, rawValue, {
				reason = opts.reason or "bar_update",
				source = opts.source or "unknown",
				emitCallback = opts.emitCallback,
				persist = opts.persist,
				forceCallback = opts.forceCallback,
				animate = opts.animate
			})
		end

		local nextValue = normalizeValue(rawValue)
		applyVisualValue(nextValue, opts.animate ~= false)
		local callbackSuccess = triggerCallback(nextValue)
		barSettings.CurrentValue = nextValue
		if callbackSuccess and opts.persist and not barSettings.Ext then
			self.SaveConfiguration()
		end
		return callbackSuccess
	end

	if type(registerElementSync) == "function" then
		barSyncToken = registerElementSync({
			name = barSettings.Name,
			getState = function()
				return barSettings.CurrentValue
			end,
			normalize = function(rawValue)
				local nextValue = normalizeValue(rawValue)
				return nextValue, {
					changed = barSettings.CurrentValue ~= nextValue
				}
			end,
			applyVisual = function(value, syncMeta)
				local animate = true
				if syncMeta and syncMeta.options and syncMeta.options.animate == false then
					animate = false
				end
				applyVisualValue(value, animate)
				barSettings.CurrentValue = value
			end,
			emitCallback = function(value)
				barSettings.Callback(value)
			end,
			persist = function()
				self.SaveConfiguration()
			end,
			isExt = function()
				return barSettings.Ext == true
			end,
			isAlive = function()
				return Bar ~= nil and Bar.Parent ~= nil
			end,
			isVisibleContext = function()
				return Bar.Visible and Bar:IsDescendantOf(TabPage) and self.Elements.UIPageLayout.CurrentPage == TabPage
			end,
			onCallbackError = handleBarCallbackError
		})
	end

	applyVisualValue(barSettings.CurrentValue, false)
	task.defer(function()
		if Bar and Bar.Parent then
			applyVisualValue(barSettings.CurrentValue, false)
		end
	end)

	local barHoverBindingKey = registerHoverBinding(Bar,
		function()
			self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
		end,
		function()
			self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
		end
	)

	BarMain.Interact.InputBegan:Connect(function(Input)
		if not barSettings.Draggable then
			return
		end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			self.Animation:Create(BarMain.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			self.Animation:Create(BarProgress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			barDragging = true
		end
	end)

	BarMain.Interact.InputEnded:Connect(function(Input)
		if not barSettings.Draggable then
			return
		end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			self.Animation:Create(BarMain.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
			self.Animation:Create(BarProgress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.3}):Play()
			barDragging = false
		end
	end)

	BarMain.Interact.MouseButton1Down:Connect(function(mouseX)
		if not barSettings.Draggable then
			return
		end

		local currentX = BarProgress.AbsolutePosition.X + BarProgress.AbsoluteSize.X
		local startX = currentX
		local locationX = mouseX
		local progressTween = nil
		local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

		local loopConn
		loopConn = self.RunService.Stepped:Connect(function()
			if barDragging then
				locationX = self.UserInputService:GetMouseLocation().X
				currentX = currentX + 0.025 * (locationX - startX)

				local minX = BarMain.AbsolutePosition.X
				local maxX = BarMain.AbsolutePosition.X + BarMain.AbsoluteSize.X

				if locationX < minX then
					locationX = minX
				elseif locationX > maxX then
					locationX = maxX
				end

				if currentX < minX + 5 then
					currentX = minX + 5
				elseif currentX > maxX then
					currentX = maxX
				end

				if (currentX <= locationX and (locationX - startX) < 0) or (currentX >= locationX and (locationX - startX) > 0) then
					startX = locationX
				end

				if progressTween then
					progressTween:Cancel()
				end
				progressTween = self.Animation:Create(BarProgress, tweenInfo, {Size = UDim2.new(0, currentX - minX, 1, 0)})
				progressTween:Play()

				local nextValue = barMin + ((locationX - minX) / math.max(1, BarMain.AbsoluteSize.X)) * (barMax - barMin)
				if barSettings.CurrentValue ~= normalizeValue(nextValue) then
					applyBarValue(nextValue, {animate = false, persist = true})
				end
			else
				self.Animation:Create(BarProgress, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, locationX - BarMain.AbsolutePosition.X > 5 and locationX - BarMain.AbsolutePosition.X or 5, 1, 0)
				}):Play()

				if loopConn then
					loopConn:Disconnect()
				end
			end
		end)
	end)

	function barSettings:Set(NewVal)
		applyBarValue(NewVal, {animate = true, persist = true, forceCallback = true})
	end

	function barSettings:Get()
		return barSettings.CurrentValue
	end

	if Settings.ConfigurationSaving then
		if Settings.ConfigurationSaving.Enabled and barSettings.Flag then
			self.RayfieldLibrary.Flags[barSettings.Flag] = barSettings
		end
	end

	self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
		if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
			BarMain.Shadow.Visible = false
		end

		BarMain.BackgroundColor3 = self.getSelectedTheme().SliderBackground
		BarMain.UIStroke.Color = self.getSelectedTheme().SliderStroke
		BarProgress.UIStroke.Color = self.getSelectedTheme().SliderStroke
		BarProgress.BackgroundColor3 = self.getSelectedTheme().SliderProgress
		if showText and BarValueLabel then
			BarValueLabel.TextColor3 = self.getSelectedTheme().TextColor
		end
	end)

	function barSettings:Destroy()
		Bar:Destroy()
	end

	addExtendedAPI(barSettings, barSettings.Name, customOptions.typeName or "Bar", Bar, barHoverBindingKey, barSyncToken)
	return barSettings
end

function RangeBarsFactory.createTrackBar(context, settings)
	return createCustomBar(context, settings, {
		defaultName = "Track Bar",
		defaultDraggable = true,
		showText = false,
		statusMode = false,
		typeName = "TrackBar"
	})
end

function RangeBarsFactory.createStatusBar(context, settings)
	return createCustomBar(context, settings, {
		defaultName = "Status Bar",
		defaultDraggable = false,
		showText = true,
		statusMode = true,
		typeName = "StatusBar"
	})
end

function RangeBarsFactory.createDragBar(context, settings)
	return RangeBarsFactory.createTrackBar(context, settings)
end

function RangeBarsFactory.createSliderLite(context, settings)
	return RangeBarsFactory.createTrackBar(context, settings)
end

function RangeBarsFactory.createInfoBar(context, settings)
	return RangeBarsFactory.createStatusBar(context, settings)
end

function RangeBarsFactory.createSliderDisplay(context, settings)
	return RangeBarsFactory.createStatusBar(context, settings)
end

return RangeBarsFactory
