local SliderFactory = {}

function SliderFactory.create(context)
	context = context or {}
	local Tab = context.Tab
	local TabPage = context.TabPage
	local Settings = context.Settings or {}
	local addExtendedAPI = context.addExtendedAPI
	local registerHoverBinding = context.registerHoverBinding
	local registerElementSync = context.registerElementSync
	local commitElementSync = context.commitElementSync
	local elementSync = context.elementSync

	if type(Tab) ~= "table" or not TabPage then
		return nil
	end
	if type(addExtendedAPI) ~= "function" then
		return nil
	end
	if type(registerHoverBinding) ~= "function" then
		registerHoverBinding = function()
			return nil
		end
	end
	if type(registerElementSync) ~= "function" then
		registerElementSync = function()
			return nil
		end
	end
	if type(commitElementSync) ~= "function" then
		commitElementSync = function()
			return false
		end
	end

	local self = Tab
	local SliderSettings = context.settings

	local ctx = self
	local SLDragging = false
	SliderSettings = SliderSettings or {}
	if type(SliderSettings.Callback) ~= "function" then
		SliderSettings.Callback = function() end
	end
	SliderSettings.Range = SliderSettings.Range or {0, 100}
	local sliderMin = tonumber(SliderSettings.Range[1]) or 0
	local sliderMax = tonumber(SliderSettings.Range[2]) or 100
	if sliderMax <= sliderMin then
		sliderMax = sliderMin + 1
	end
	SliderSettings.Range = {sliderMin, sliderMax}
	SliderSettings.Increment = tonumber(SliderSettings.Increment) or 1
	if SliderSettings.Increment <= 0 then
		SliderSettings.Increment = 1
	end
	SliderSettings.CurrentValue = math.clamp(tonumber(SliderSettings.CurrentValue) or sliderMin, sliderMin, sliderMax)

	local Slider = self.Elements.Template.Slider:Clone()
	Slider.Name = SliderSettings.Name
	Slider.Title.Text = SliderSettings.Name
	Slider.Visible = true
	Slider.Parent = TabPage
	
	Slider.BackgroundTransparency = 1
	Slider.UIStroke.Transparency = 1
	Slider.Title.TextTransparency = 1
	
	if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
		Slider.Main.Shadow.Visible = false
	end
	
	self.bindTheme(Slider.Main, "BackgroundColor3", "SliderBackground")
	self.bindTheme(Slider.Main.UIStroke, "Color", "SliderStroke")
	self.bindTheme(Slider.Main.Progress.UIStroke, "Color", "SliderStroke")
	self.bindTheme(Slider.Main.Progress, "BackgroundColor3", "SliderProgress")
	
	self.Animation:Create(Slider, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	self.Animation:Create(Slider.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
	self.Animation:Create(Slider.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()	

	local function normalizeSliderValue(rawValue)
		local normalized = tonumber(rawValue)
		if normalized == nil then
			normalized = sliderMin
		end
		if elementSync and elementSync.normalize and elementSync.normalize.numberRange then
			normalized = elementSync.normalize.numberRange(normalized, {
				min = sliderMin,
				max = sliderMax,
				increment = SliderSettings.Increment,
				default = sliderMin
			})
		else
			normalized = math.clamp(normalized, sliderMin, sliderMax)
			normalized = math.floor((normalized / SliderSettings.Increment) + 0.5) * SliderSettings.Increment
			normalized = math.floor((normalized * 10000000) + 0.5) / 10000000
			normalized = math.clamp(normalized, sliderMin, sliderMax)
		end
		return normalized
	end

	local function sliderValueToWidth(value)
		local width = Slider.Main.AbsoluteSize.X
		if width <= 0 then
			return 5
		end
		local ratio = math.clamp((value - sliderMin) / (sliderMax - sliderMin), 0, 1)
		local target = width * ratio
		if ratio > 0 and target < 5 then
			target = 5
		end
		return target
	end

	local function formatSliderValue(value)
		if not SliderSettings.Suffix then
			return tostring(value)
		end
		return tostring(value) .. " " .. SliderSettings.Suffix
	end

	local function handleSliderCallbackError(response)
		self.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
		self.Animation:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
		Slider.Title.Text = "Callback Error"
		print("Rayfield | "..SliderSettings.Name.." Callback Error " ..tostring(response))
		warn('Check docs.sirius.menu for help with Rayfield specific development.')
		task.wait(0.5)
		Slider.Title.Text = SliderSettings.Name
		self.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
		self.Animation:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
	end

	local function applySliderVisual(value, animate)
		local targetWidth = sliderValueToWidth(value)
		if animate then
			self.Animation:Create(Slider.Main.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, targetWidth, 1, 0)}):Play()
		else
			Slider.Main.Progress.Size = UDim2.new(0, targetWidth, 1, 0)
		end
		Slider.Main.Information.Text = formatSliderValue(value)
		SliderSettings.CurrentValue = value
	end

	local sliderSyncToken = registerElementSync({
		name = SliderSettings.Name,
		getState = function()
			return SliderSettings.CurrentValue
		end,
		normalize = function(rawValue)
			local normalized = normalizeSliderValue(rawValue)
			return normalized, {
				changed = SliderSettings.CurrentValue ~= normalized
			}
		end,
		applyVisual = function(normalized, syncMeta)
			local animate = true
			if syncMeta and syncMeta.options and syncMeta.options.animate == false then
				animate = false
			end
			applySliderVisual(normalized, animate)
		end,
		emitCallback = function(normalized)
			SliderSettings.Callback(normalized)
		end,
		persist = function()
			ctx.SaveConfiguration()
		end,
		isExt = function()
			return SliderSettings.Ext == true
		end,
		isAlive = function()
			return Slider ~= nil and Slider.Parent ~= nil
		end,
		isVisibleContext = function()
			return Slider.Visible and Slider:IsDescendantOf(TabPage) and self.Elements.UIPageLayout.CurrentPage == TabPage
		end,
		onCallbackError = handleSliderCallbackError
	})

	local function commitSliderValue(rawValue, commitOptions)
		local options = commitOptions or {}
		if sliderSyncToken then
			return commitElementSync(sliderSyncToken, rawValue, {
				reason = options.reason or "slider_update",
				source = options.source or "unknown",
				emitCallback = options.emitCallback,
				persist = options.persist,
				forceCallback = options.forceCallback,
				animate = options.animate
			})
		end

		local normalized = normalizeSliderValue(rawValue)
		applySliderVisual(normalized, options.animate ~= false)
		local success, response = pcall(function()
			SliderSettings.Callback(normalized)
		end)
		if not success then
			handleSliderCallbackError(response)
		elseif not SliderSettings.Ext then
			ctx.SaveConfiguration()
		end
		return success
	end

	applySliderVisual(SliderSettings.CurrentValue, false)
	
	local sliderHoverBindingKey = registerHoverBinding(Slider,
		function()
			self.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
		end,
		function()
			self.Animation:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
		end
	)
	
	Slider.Main.Interact.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then 
			self.Animation:Create(Slider.Main.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			self.Animation:Create(Slider.Main.Progress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			SLDragging = true 
		end 
	end)
	
	Slider.Main.Interact.InputEnded:Connect(function(Input) 
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then 
			self.Animation:Create(Slider.Main.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
			self.Animation:Create(Slider.Main.Progress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.3}):Play()
			SLDragging = false 
		end 
	end)
	
	Slider.Main.Interact.MouseButton1Down:Connect(function(X)
		local Current = Slider.Main.Progress.AbsolutePosition.X + Slider.Main.Progress.AbsoluteSize.X
		local Start = Current
		local Location = X
		local sliderProgressTween = nil
		local sliderProgressTweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
		local Loop; Loop = self.RunService.Stepped:Connect(function()
			if SLDragging then
				Location = self.UserInputService:GetMouseLocation().X
				Current = Current + 0.025 * (Location - Start)
	
				if Location < Slider.Main.AbsolutePosition.X then
					Location = Slider.Main.AbsolutePosition.X
				elseif Location > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
					Location = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
				end
	
				if Current < Slider.Main.AbsolutePosition.X + 5 then
					Current = Slider.Main.AbsolutePosition.X + 5
				elseif Current > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
					Current = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
				end
	
				if Current <= Location and (Location - Start) < 0 then
					Start = Location
				elseif Current >= Location and (Location - Start) > 0 then
					Start = Location
				end
				if sliderProgressTween then
					sliderProgressTween:Cancel()
				end
				sliderProgressTween = self.Animation:Create(Slider.Main.Progress, sliderProgressTweenInfo, {Size = UDim2.new(0, Current - Slider.Main.AbsolutePosition.X, 1, 0)})
				sliderProgressTween:Play()
				local NewValue = SliderSettings.Range[1] + (Location - Slider.Main.AbsolutePosition.X) / Slider.Main.AbsoluteSize.X * (SliderSettings.Range[2] - SliderSettings.Range[1])
				NewValue = normalizeSliderValue(NewValue)
				commitSliderValue(NewValue, {
					reason = "drag",
					source = "ui_drag",
					emitCallback = true,
					persist = true,
					forceCallback = false,
					animate = false
				})
			else
				self.Animation:Create(Slider.Main.Progress, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, Location - Slider.Main.AbsolutePosition.X > 5 and Location - Slider.Main.AbsolutePosition.X or 5, 1, 0)}):Play()
				Loop:Disconnect()
			end
		end)
	end)
	
	function SliderSettings:Set(NewVal)
		commitSliderValue(NewVal, {
			reason = "set",
			source = "api_set",
			emitCallback = true,
			persist = true,
			forceCallback = true,
			animate = true
		})
	end
	
	if Settings.ConfigurationSaving then
		if Settings.ConfigurationSaving.Enabled and SliderSettings.Flag then
			self.RayfieldLibrary.Flags[SliderSettings.Flag] = SliderSettings
		end
	end
	
	self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
		if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
			Slider.Main.Shadow.Visible = false
		end
	
		Slider.Main.BackgroundColor3 = self.getSelectedTheme().SliderBackground
		Slider.Main.UIStroke.Color = self.getSelectedTheme().SliderStroke
		Slider.Main.Progress.UIStroke.Color = self.getSelectedTheme().SliderStroke
		Slider.Main.Progress.BackgroundColor3 = self.getSelectedTheme().SliderProgress
	end)
	
	function SliderSettings:Destroy()
		Slider:Destroy()
	end

	-- Add extended API
	addExtendedAPI(SliderSettings, SliderSettings.Name, "Slider", Slider, sliderHoverBindingKey, sliderSyncToken)

	return SliderSettings
end

return SliderFactory


