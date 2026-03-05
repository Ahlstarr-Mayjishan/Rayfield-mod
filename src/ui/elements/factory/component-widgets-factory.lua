local ComponentWidgetsFactory = {}

local function resolvePlayers(context)
	if type(context) == "table" and context.Players then
		return context.Players
	end
	local okPlayers, serviceOrErr = pcall(function()
		return game:GetService("Players")
	end)
	if okPlayers then
		return serviceOrErr
	end
	return nil
end

local function createMethods(context)
	context = type(context) == "table" and context or {}
	local self = context.self
	local TabPage = context.TabPage
	local Settings = context.Settings
	local addExtendedAPI = context.addExtendedAPI
	local registerHoverBinding = context.registerHoverBinding
	local connectThemeRefresh = context.connectThemeRefresh
	local resolveElementParentFromSettings = context.resolveElementParentFromSettings
	local cloneSerializable = context.cloneSerializable
	local clampNumber = context.clampNumber
	local roundToPrecision = context.roundToPrecision
	local emitUICue = context.emitUICue
	local Players = resolvePlayers(context)

	if type(self) ~= "table" or typeof(TabPage) ~= "Instance" then
		return nil, "Invalid component widget context."
	end

	local Tab = {}
			function Tab:CreateColorPicker(ColorPickerSettings) -- by Throit
				ColorPickerSettings.Type = "ColorPicker"
				local ColorPicker = self.Elements.Template.ColorPicker:Clone()
				local Background = ColorPicker.CPBackground
				local Display = Background.Display
				local Main = Background.MainCP
				local Slider = ColorPicker.ColorSlider
				ColorPicker.ClipsDescendants = true
				ColorPicker.Name = ColorPickerSettings.Name
				ColorPicker.Title.Text = ColorPickerSettings.Name
				ColorPicker.Visible = true
				ColorPicker.Parent = TabPage
				ColorPicker.Size = UDim2.new(1, -10, 0, 45)
				Background.Size = UDim2.new(0, 39, 0, 22)
				Display.BackgroundTransparency = 0
				self.Main.MainPoint.ImageTransparency = 1
				ColorPicker.Interact.Size = UDim2.new(1, 0, 1, 0)
				ColorPicker.Interact.Position = UDim2.new(0.5, 0, 0.5, 0)
				ColorPicker.RGB.Position = UDim2.new(0, 17, 0, 70)
				ColorPicker.HexInput.Position = UDim2.new(0, 17, 0, 90)
				self.Main.ImageTransparency = 1
				Background.BackgroundTransparency = 1
	
				for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren()) do
					if rgbinput:IsA("Frame") then
						rgbinput.BackgroundColor3 = self.getSelectedTheme().InputBackground
						rgbinput.UIStroke.Color = self.getSelectedTheme().InputStroke
					end
				end
	
				ColorPicker.HexInput.BackgroundColor3 = self.getSelectedTheme().InputBackground
				ColorPicker.HexInput.UIStroke.Color = self.getSelectedTheme().InputStroke
	
				local opened = false 
				local mouse = Players.LocalPlayer:GetMouse()
				self.Main.Image = "http://www.roblox.com/asset/?id=11415645739"
				local mainDragging = false 
				local sliderDragging = false 
				ColorPicker.Interact.MouseButton1Down:Connect(function()
					task.spawn(function()
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
						self.Animation:Create(ColorPicker.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						task.wait(0.2)
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(ColorPicker.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end)
	
					if not opened then
						opened = true 
						self.Animation:Create(Background, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 18, 0, 15)}):Play()
						task.wait(0.1)
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 120)}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 173, 0, 86)}):Play()
						self.Animation:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.289, 0, 0.5, 0)}):Play()
						self.Animation:Create(ColorPicker.RGB, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 40)}):Play()
						self.Animation:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 73)}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0.574, 0, 1, 0)}):Play()
						self.Animation:Create(self.Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
						self.Animation:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default and 0.25 or 0.1}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
					else
						opened = false
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 45)}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 39, 0, 22)}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 1, 0)}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
						self.Animation:Create(ColorPicker.RGB, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 70)}):Play()
						self.Animation:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 90)}):Play()
						self.Animation:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
						self.Animation:Create(self.Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
						self.Animation:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
					end
	
				end)
	
				self.UserInputService.InputEnded:Connect(function(input, gameProcessed) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						local wasDragging = mainDragging or sliderDragging
						mainDragging = false
						sliderDragging = false
						if wasDragging and not ColorPickerSettings.Ext then
							self.SaveConfiguration()
						end
					end end)
				self.Main.MouseButton1Down:Connect(function()
					if opened then
						mainDragging = true 
					end
				end)
				self.Main.MainPoint.MouseButton1Down:Connect(function()
					if opened then
						mainDragging = true 
					end
				end)
				Slider.MouseButton1Down:Connect(function()
					sliderDragging = true 
				end)
				Slider.SliderPoint.MouseButton1Down:Connect(function()
					sliderDragging = true 
				end)
				local h,s,v = ColorPickerSettings.Color:ToHSV()
				local color = Color3.fromHSV(h,s,v) 
				local hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
				ColorPicker.HexInput.InputBox.Text = hex
				local function setDisplay()
					--Main
					self.Main.MainPoint.Position = UDim2.new(s,-self.Main.MainPoint.AbsoluteSize.X/2,1-v,-self.Main.MainPoint.AbsoluteSize.Y/2)
					self.Main.MainPoint.ImageColor3 = Color3.fromHSV(h,s,v)
					Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
					Display.BackgroundColor3 = Color3.fromHSV(h,s,v)
					--Slider 
					local x = h * Slider.AbsoluteSize.X
					Slider.SliderPoint.Position = UDim2.new(0,x-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
					Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h,1,1)
					local color = Color3.fromHSV(h,s,v) 
					local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
					ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
					ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
					hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
					ColorPicker.HexInput.InputBox.Text = hex
				end
				setDisplay()
				ColorPicker.HexInput.InputBox.FocusLost:Connect(function()
					if not pcall(function()
							local r, g, b = string.match(ColorPicker.HexInput.InputBox.Text, "^#?(%w%w)(%w%w)(%w%w)$")
							local rgbColor = Color3.fromRGB(tonumber(r, 16),tonumber(g, 16), tonumber(b, 16))
							h,s,v = rgbColor:ToHSV()
							hex = ColorPicker.HexInput.InputBox.Text
							setDisplay()
							ColorPickerSettings.Color = rgbColor
						end) 
					then 
						ColorPicker.HexInput.InputBox.Text = hex 
					end
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
					local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					if not ColorPickerSettings.Ext then
						self.SaveConfiguration()
					end
				end)
				--RGB
				local function rgbBoxes(box,toChange)
					local value = tonumber(box.Text) 
					local color = Color3.fromHSV(h,s,v) 
					local oldR,oldG,oldB = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					local save 
					if toChange == "R" then save = oldR;oldR = value elseif toChange == "G" then save = oldG;oldG = value else save = oldB;oldB = value end
					if value then 
						value = math.clamp(value,0,255)
						h,s,v = Color3.fromRGB(oldR,oldG,oldB):ToHSV()
	
						setDisplay()
					else 
						box.Text = tostring(save)
					end
					local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					if not ColorPickerSettings.Ext then
						self.SaveConfiguration(ColorPickerSettings.Flag..'\n'..tostring(ColorPickerSettings.Color))
					end
				end
				ColorPicker.RGB.RInput.InputBox.FocusLost:connect(function()
					rgbBoxes(ColorPicker.RGB.RInput.InputBox,"R")
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				end)
				ColorPicker.RGB.GInput.InputBox.FocusLost:connect(function()
					rgbBoxes(ColorPicker.RGB.GInput.InputBox,"G")
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				end)
				ColorPicker.RGB.BInput.InputBox.FocusLost:connect(function()
					rgbBoxes(ColorPicker.RGB.BInput.InputBox,"B")
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				end)
	
				local prevH, prevS, prevV = h, s, v
				self.RunService.RenderStepped:connect(function()
					if mainDragging then
						local localX = math.clamp(mouse.X-self.Main.AbsolutePosition.X,0,self.Main.AbsoluteSize.X)
						local localY = math.clamp(mouse.Y-self.Main.AbsolutePosition.Y,0,self.Main.AbsoluteSize.Y)
						self.Main.MainPoint.Position = UDim2.new(0,localX-self.Main.MainPoint.AbsoluteSize.X/2,0,localY-self.Main.MainPoint.AbsoluteSize.Y/2)
						s = localX / self.Main.AbsoluteSize.X
						v = 1 - (localY / self.Main.AbsoluteSize.Y)
						local color = Color3.fromHSV(h,s,v)
						Display.BackgroundColor3 = color
						self.Main.MainPoint.ImageColor3 = color
						Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
						local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
						ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
						ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
						ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
						ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
						ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
						if h ~= prevH or s ~= prevS or v ~= prevV then
							prevH, prevS, prevV = h, s, v
							pcall(ColorPickerSettings.Callback, color)
						end
					end
					if sliderDragging then
						local localX = math.clamp(mouse.X-Slider.AbsolutePosition.X,0,Slider.AbsoluteSize.X)
						h = localX / Slider.AbsoluteSize.X
						local color = Color3.fromHSV(h,s,v)
						local hueColor = Color3.fromHSV(h,1,1)
						Display.BackgroundColor3 = color
						Slider.SliderPoint.Position = UDim2.new(0,localX-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
						Slider.SliderPoint.ImageColor3 = hueColor
						Background.BackgroundColor3 = hueColor
						self.Main.MainPoint.ImageColor3 = color
						local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
						ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
						ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
						ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
						ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
						ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
						if h ~= prevH or s ~= prevS or v ~= prevV then
							prevH, prevS, prevV = h, s, v
							pcall(ColorPickerSettings.Callback, color)
						end
					end
				end)
	
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and ColorPickerSettings.Flag then
						self.RayfieldLibrary.Flags[ColorPickerSettings.Flag] = ColorPickerSettings
					end
				end
	
				function ColorPickerSettings:Set(RGBColor)
					ColorPickerSettings.Color = RGBColor
					h,s,v = ColorPickerSettings.Color:ToHSV()
					color = Color3.fromHSV(h,s,v)
					setDisplay()
				end
	
				local colorPickerHoverBindingKey = registerHoverBinding(ColorPicker,
					function()
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
					end,
					function()
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					end
				)
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren()) do
						if rgbinput:IsA("Frame") then
							rgbinput.BackgroundColor3 = self.getSelectedTheme().InputBackground
							rgbinput.UIStroke.Color = self.getSelectedTheme().InputStroke
						end
					end
	
					ColorPicker.HexInput.BackgroundColor3 = self.getSelectedTheme().InputBackground
					ColorPicker.HexInput.UIStroke.Color = self.getSelectedTheme().InputStroke
				end)
	
				function ColorPickerSettings:Destroy()
					ColorPicker:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(ColorPickerSettings, ColorPickerSettings.Name, "ColorPicker", ColorPicker, colorPickerHoverBindingKey)
	
				return ColorPickerSettings
			end
	
			-- Section

			function Tab:CreateNumberStepper(stepperSettings)
				local settingsValue = stepperSettings or {}
				local stepper = {}
				stepper.Name = tostring(settingsValue.Name or "Number Stepper")
				stepper.Flag = settingsValue.Flag
				stepper.CurrentValue = clampNumber(settingsValue.CurrentValue, settingsValue.Min, settingsValue.Max, 0)

				local minValue = tonumber(settingsValue.Min)
				local maxValue = tonumber(settingsValue.Max)
				local stepValue = math.max(0.0001, tonumber(settingsValue.Step) or 1)
				local precision = math.max(0, math.floor(tonumber(settingsValue.Precision) or 2))
				local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end

				local root = Instance.new("Frame")
				root.Name = stepper.Name
				root.Size = UDim2.new(1, -10, 0, 45)
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
				title.Size = UDim2.new(0.45, -8, 1, 0)
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.Font = Enum.Font.GothamMedium
				title.TextSize = 13
				title.Text = stepper.Name
				title.TextColor3 = self.getSelectedTheme().TextColor
				title.Parent = root

				local minus = Instance.new("TextButton")
				minus.Name = "Minus"
				minus.AnchorPoint = Vector2.new(1, 0.5)
				minus.Position = UDim2.new(1, -78, 0.5, 0)
				minus.Size = UDim2.new(0, 22, 0, 22)
				minus.Text = "-"
				minus.Font = Enum.Font.GothamBold
				minus.TextSize = 16
				minus.TextColor3 = self.getSelectedTheme().TextColor
				minus.BackgroundColor3 = self.getSelectedTheme().InputBackground
				minus.BorderSizePixel = 0
				minus.Parent = root

				local valueBox = Instance.new("TextBox")
				valueBox.Name = "Value"
				valueBox.AnchorPoint = Vector2.new(1, 0.5)
				valueBox.Position = UDim2.new(1, -50, 0.5, 0)
				valueBox.Size = UDim2.new(0, 56, 0, 22)
				valueBox.ClearTextOnFocus = false
				valueBox.Font = Enum.Font.Gotham
				valueBox.TextSize = 13
				valueBox.TextColor3 = self.getSelectedTheme().TextColor
				valueBox.PlaceholderText = "0"
				valueBox.BackgroundColor3 = self.getSelectedTheme().InputBackground
				valueBox.BorderSizePixel = 0
				valueBox.Parent = root

				local plus = Instance.new("TextButton")
				plus.Name = "Plus"
				plus.AnchorPoint = Vector2.new(1, 0.5)
				plus.Position = UDim2.new(1, -22, 0.5, 0)
				plus.Size = UDim2.new(0, 22, 0, 22)
				plus.Text = "+"
				plus.Font = Enum.Font.GothamBold
				plus.TextSize = 16
				plus.TextColor3 = self.getSelectedTheme().TextColor
				plus.BackgroundColor3 = self.getSelectedTheme().InputBackground
				plus.BorderSizePixel = 0
				plus.Parent = root

				local function formatValue(numberValue)
					local template = "%." .. tostring(precision) .. "f"
					return string.format(template, numberValue)
				end

				local function commitValue(nextValue, options)
					options = options or {}
					local normalized = roundToPrecision(clampNumber(nextValue, minValue, maxValue, stepper.CurrentValue), precision)
					if normalized == stepper.CurrentValue and options.force ~= true then
						valueBox.Text = formatValue(stepper.CurrentValue)
						return
					end
					stepper.CurrentValue = normalized
					valueBox.Text = formatValue(normalized)
					local okCallback, callbackErr = pcall(callback, normalized)
					if not okCallback then
						warn("Rayfield | NumberStepper callback failed: " .. tostring(callbackErr))
					end
					if settingsValue.Ext ~= true and options.persist ~= false then
						self.SaveConfiguration()
					end
				end

				minus.MouseButton1Click:Connect(function()
					commitValue(stepper.CurrentValue - stepValue, {persist = true})
				end)
				plus.MouseButton1Click:Connect(function()
					commitValue(stepper.CurrentValue + stepValue, {persist = true})
				end)
				valueBox.FocusLost:Connect(function()
					commitValue(valueBox.Text, {persist = true, force = true})
				end)

				function stepper:Set(nextValue)
					commitValue(nextValue, {persist = true, force = true})
				end

				function stepper:Get()
					return stepper.CurrentValue
				end

				function stepper:Increment()
					commitValue(stepper.CurrentValue + stepValue, {persist = true})
				end

				function stepper:Decrement()
					commitValue(stepper.CurrentValue - stepValue, {persist = true})
				end

				function stepper:Destroy()
					root:Destroy()
				end

				connectThemeRefresh(function()
					root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					stroke.Color = self.getSelectedTheme().ElementStroke
					title.TextColor3 = self.getSelectedTheme().TextColor
					minus.TextColor3 = self.getSelectedTheme().TextColor
					minus.BackgroundColor3 = self.getSelectedTheme().InputBackground
					plus.TextColor3 = self.getSelectedTheme().TextColor
					plus.BackgroundColor3 = self.getSelectedTheme().InputBackground
					valueBox.TextColor3 = self.getSelectedTheme().TextColor
					valueBox.BackgroundColor3 = self.getSelectedTheme().InputBackground
				end)

				resolveElementParentFromSettings(stepper, settingsValue)
				commitValue(stepper.CurrentValue, {persist = false, force = true})
				addExtendedAPI(stepper, stepper.Name, "NumberStepper", root)

				if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and stepper.Flag then
					self.RayfieldLibrary.Flags[stepper.Flag] = stepper
				end

				return stepper
			end

			function Tab:CreateConfirmButton(confirmSettings)
				local settingsValue = confirmSettings or {}
				local element = {}
				element.Name = tostring(settingsValue.Name or "Confirm Button")
				element.Flag = settingsValue.Flag
				element.Ext = settingsValue.Ext

				local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
				local mode = tostring(settingsValue.ConfirmMode or "hold"):lower()
				local holdDuration = clampNumber(settingsValue.HoldDuration, 0.05, 6, 1.2)
				local doubleWindow = clampNumber(settingsValue.DoubleWindow, 0.05, 4, 0.4)
				local timeout = clampNumber(settingsValue.Timeout, 0.2, 12, 2)
				local armed = false
				local armedToken = 0
				local lastClickTime = 0
				local holdActive = false
				local holdToken = 0

				local root = Instance.new("Frame")
				root.Name = element.Name
				root.Size = UDim2.new(1, -10, 0, 45)
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

				local button = Instance.new("TextButton")
				button.Name = "Interact"
				button.Size = UDim2.new(1, 0, 1, 0)
				button.BackgroundTransparency = 1
				button.Text = element.Name
				button.Font = Enum.Font.GothamSemibold
				button.TextSize = 13
				button.TextColor3 = self.getSelectedTheme().TextColor
				button.Parent = root

				local function setArmedVisual(value)
					armed = value == true
					if armed then
						root.BackgroundColor3 = self.getSelectedTheme().ConfirmArmed or self.getSelectedTheme().ElementBackgroundHover
					else
						root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					end
				end

				local function fireConfirmed()
					setArmedVisual(false)
					emitUICue("click")
					local okCallback, callbackErr = pcall(callback)
					if not okCallback then
						emitUICue("error")
						warn("Rayfield | ConfirmButton callback failed: " .. tostring(callbackErr))
					else
						emitUICue("success")
					end
					if settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				local function armWithTimeout()
					armedToken += 1
					local localToken = armedToken
					setArmedVisual(true)
					task.delay(timeout, function()
						if armed and armedToken == localToken then
							setArmedVisual(false)
						end
					end)
				end

				local function isModeEnabled(modeName)
					return mode == modeName or mode == "either"
				end

				button.MouseButton1Click:Connect(function()
					local now = os.clock()
					if isModeEnabled("double") then
						if armed and (now - lastClickTime) <= doubleWindow then
							fireConfirmed()
							lastClickTime = 0
							return
						end
						lastClickTime = now
						armWithTimeout()
						return
					end
					if not isModeEnabled("hold") then
						fireConfirmed()
					end
				end)

				button.InputBegan:Connect(function(input)
					if not isModeEnabled("hold") then
						return
					end
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
						return
					end
					holdActive = true
					holdToken += 1
					local localToken = holdToken
					setArmedVisual(true)
					task.delay(holdDuration, function()
						if holdActive and holdToken == localToken then
							fireConfirmed()
						end
					end)
				end)

				button.InputEnded:Connect(function(input)
					if not isModeEnabled("hold") then
						return
					end
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
						return
					end
					holdActive = false
					if armed then
						setArmedVisual(false)
					end
				end)

				function element:Arm()
					armWithTimeout()
					return true, "armed"
				end

				function element:Cancel()
					holdActive = false
					setArmedVisual(false)
					return true, "cancelled"
				end

				function element:SetMode(nextMode)
					local normalized = tostring(nextMode or "hold"):lower()
					if normalized ~= "hold" and normalized ~= "double" and normalized ~= "either" then
						return false, "Invalid mode."
					end
					mode = normalized
					return true, "ok"
				end

				function element:SetHoldDuration(nextDuration)
					holdDuration = clampNumber(nextDuration, 0.05, 6, holdDuration)
					return true, "ok"
				end

				function element:SetDoubleWindow(nextWindow)
					doubleWindow = clampNumber(nextWindow, 0.05, 4, doubleWindow)
					return true, "ok"
				end

				function element:Destroy()
					root:Destroy()
				end

				connectThemeRefresh(function()
					button.TextColor3 = self.getSelectedTheme().TextColor
					stroke.Color = self.getSelectedTheme().ElementStroke
					setArmedVisual(armed)
				end)

				resolveElementParentFromSettings(element, settingsValue)
				addExtendedAPI(element, element.Name, "ConfirmButton", root)
				return element
			end

			local function resolveImageSourceUri(source)
				local valueType = typeof(source)
				if valueType == "nil" then
					return "rbxassetid://0", nil
				end
				if valueType == "number" then
					return "rbxassetid://" .. tostring(math.floor(source)), nil
				end
				if valueType ~= "string" then
					return "rbxassetid://0", "Image source must be a number or string."
				end
				local normalized = tostring(source)
				if normalized == "" then
					return "rbxassetid://0", "Image source is empty."
				end
				if normalized:match("^rbxassetid://") then
					return normalized, nil
				end
				if normalized:match("^https?://") then
					local hasBridge = type(getcustomasset) == "function" or type(getsynasset) == "function"
					if not hasBridge then
						return "rbxassetid://0", "URL image source unsupported in this executor (no asset bridge)."
					end
					return normalized, nil
				end
				if tonumber(normalized) then
					return "rbxassetid://" .. tostring(math.floor(tonumber(normalized))), nil
				end
				return normalized, nil
			end

			function Tab:CreateImage(imageSettings)
				local settingsValue = imageSettings or {}
				local imageElement = {}
				imageElement.Name = tostring(settingsValue.Name or "Image")
				imageElement.Flag = settingsValue.Flag
				local initialSource, initialWarning = resolveImageSourceUri(settingsValue.Source)
				imageElement.CurrentValue = {
					source = initialSource,
					fitMode = tostring(settingsValue.FitMode or "fill"):lower(),
					caption = tostring(settingsValue.Caption or "")
				}
				if initialWarning then
					warn("Rayfield | Image source warning: " .. tostring(initialWarning))
				end

				local root = Instance.new("Frame")
				root.Name = imageElement.Name
				root.Size = UDim2.new(1, -10, 0, clampNumber(settingsValue.Height, 60, 360, 130))
				root.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
				root.BorderSizePixel = 0
				root.Visible = true
				root.Parent = TabPage

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, clampNumber(settingsValue.CornerRadius, 0, 24, 8))
				corner.Parent = root

				local stroke = Instance.new("UIStroke")
				stroke.Color = self.getSelectedTheme().SecondaryElementStroke
				stroke.Parent = root

				local image = Instance.new("ImageLabel")
				image.Name = "Image"
				image.BackgroundTransparency = 1
				image.Position = UDim2.new(0, 0, 0, 0)
				image.Size = UDim2.new(1, 0, 1, -24)
				image.Image = imageElement.CurrentValue.source
				image.ScaleType = imageElement.CurrentValue.fitMode == "fit" and Enum.ScaleType.Fit or Enum.ScaleType.Crop
				image.Parent = root

				local caption = Instance.new("TextLabel")
				caption.Name = "Caption"
				caption.BackgroundTransparency = 1
				caption.AnchorPoint = Vector2.new(0.5, 1)
				caption.Position = UDim2.new(0.5, 0, 1, -4)
				caption.Size = UDim2.new(1, -12, 0, 18)
				caption.Font = Enum.Font.Gotham
				caption.TextSize = 12
				caption.TextXAlignment = Enum.TextXAlignment.Left
				caption.TextColor3 = self.getSelectedTheme().TextColor
				caption.Text = imageElement.CurrentValue.caption
				caption.Visible = imageElement.CurrentValue.caption ~= ""
				caption.Parent = root

				local function persistImageState()
					if settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				function imageElement:SetSource(nextSource)
					local resolved, warningMessage = resolveImageSourceUri(nextSource)
					imageElement.CurrentValue.source = resolved
					image.Image = imageElement.CurrentValue.source
					persistImageState()
					if warningMessage then
						warn("Rayfield | Image source warning: " .. tostring(warningMessage))
						return false, warningMessage
					end
					return true, "ok"
				end

				function imageElement:GetSource()
					return imageElement.CurrentValue.source
				end

				function imageElement:SetFitMode(nextMode)
					local normalized = tostring(nextMode or "fill"):lower()
					if normalized ~= "fill" and normalized ~= "fit" then
						normalized = "fill"
					end
					imageElement.CurrentValue.fitMode = normalized
					image.ScaleType = normalized == "fit" and Enum.ScaleType.Fit or Enum.ScaleType.Crop
					persistImageState()
				end

				function imageElement:SetCaption(nextCaption)
					imageElement.CurrentValue.caption = tostring(nextCaption or "")
					caption.Text = imageElement.CurrentValue.caption
					caption.Visible = imageElement.CurrentValue.caption ~= ""
					persistImageState()
				end

				function imageElement:GetPersistValue()
					return cloneSerializable(imageElement.CurrentValue)
				end

				function imageElement:Set(value)
					if type(value) == "table" then
						if value.source ~= nil then
							imageElement:SetSource(value.source)
						end
						if value.fitMode ~= nil then
							imageElement:SetFitMode(value.fitMode)
						end
						if value.caption ~= nil then
							imageElement:SetCaption(value.caption)
						end
					else
						imageElement:SetSource(value)
					end
				end

				function imageElement:Destroy()
					root:Destroy()
				end

				connectThemeRefresh(function()
					root.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
					stroke.Color = self.getSelectedTheme().SecondaryElementStroke
					caption.TextColor3 = self.getSelectedTheme().TextColor
				end)

				resolveElementParentFromSettings(imageElement, settingsValue)
				addExtendedAPI(imageElement, imageElement.Name, "Image", root)
				if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and imageElement.Flag then
					self.RayfieldLibrary.Flags[imageElement.Flag] = imageElement
				end
				return imageElement
			end

			function Tab:CreateGallery(gallerySettings)
				local settingsValue = gallerySettings or {}
				local gallery = {}
				gallery.Name = tostring(settingsValue.Name or "Gallery")
				gallery.Flag = settingsValue.Flag
				local selectionMode = tostring(settingsValue.SelectionMode or "single"):lower()
				if selectionMode ~= "single" and selectionMode ~= "multi" then
					selectionMode = "single"
				end
				local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
				local columns = settingsValue.Columns or "auto"
				local items = {}
				local selected = {}

				local root = Instance.new("Frame")
				root.Name = gallery.Name
				root.Size = UDim2.new(1, -10, 0, clampNumber(settingsValue.Height, 140, 520, 220))
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
				title.Size = UDim2.new(1, -12, 0, 22)
				title.Font = Enum.Font.GothamSemibold
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextSize = 13
				title.TextColor3 = self.getSelectedTheme().TextColor
				title.Text = gallery.Name
				title.Parent = root

				local list = Instance.new("ScrollingFrame")
				list.Name = "List"
				list.BackgroundTransparency = 1
				list.BorderSizePixel = 0
				list.Position = UDim2.new(0, 6, 0, 24)
				list.Size = UDim2.new(1, -12, 1, -30)
				list.CanvasSize = UDim2.new(0, 0, 0, 0)
				list.ScrollBarImageTransparency = 0.5
				list.Parent = root

				local grid = Instance.new("UIGridLayout")
				grid.CellPadding = UDim2.new(0, 8, 0, 8)
				grid.SortOrder = Enum.SortOrder.LayoutOrder
				grid.Parent = list

				local function applyGridSizing()
					local targetColumns = 2
					if type(columns) == "number" then
						targetColumns = math.max(1, math.floor(columns))
					else
						targetColumns = math.max(1, math.floor((list.AbsoluteSize.X + 8) / 116))
					end
					local width = math.max(70, math.floor((list.AbsoluteSize.X - ((targetColumns - 1) * 8)) / targetColumns))
					grid.CellSize = UDim2.new(0, width, 0, 92)
				end

				local function snapshotSelection()
					if selectionMode == "single" then
						for id in pairs(selected) do
							return id
						end
						return nil
					end
					local out = {}
					for id in pairs(selected) do
						table.insert(out, id)
					end
					table.sort(out)
					return out
				end

				local function emitSelection()
					local okCallback, callbackErr = pcall(callback, snapshotSelection())
					if not okCallback then
						warn("Rayfield | Gallery callback failed: " .. tostring(callbackErr))
					end
					if settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				local cardById = {}

				local function applyCardSelectionVisual(itemId)
					local card = cardById[itemId]
					if not card then
						return
					end
					local active = selected[itemId] == true
					card.BackgroundColor3 = active and (self.getSelectedTheme().DropdownSelected or self.getSelectedTheme().ElementBackgroundHover) or self.getSelectedTheme().SecondaryElementBackground
				end

				local function renderItems()
					for _, child in ipairs(list:GetChildren()) do
						if child:IsA("Frame") then
							child:Destroy()
						end
					end
					cardById = {}

					for index, item in ipairs(items) do
						local itemId = tostring(item.id or item.Id or index)
						local card = Instance.new("Frame")
						card.Name = "Item_" .. itemId
						card.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
						card.BorderSizePixel = 0
						card.LayoutOrder = index
						card.Parent = list

						local cardCorner = Instance.new("UICorner")
						cardCorner.CornerRadius = UDim.new(0, 6)
						cardCorner.Parent = card

						local image = Instance.new("ImageLabel")
						image.BackgroundTransparency = 1
						image.Position = UDim2.new(0, 6, 0, 6)
						image.Size = UDim2.new(1, -12, 1, -30)
						image.ScaleType = Enum.ScaleType.Crop
						image.Image = resolveImageSourceUri(item.image or item.Image or item.source or item.Source)
						image.Parent = card

						local label = Instance.new("TextLabel")
						label.BackgroundTransparency = 1
						label.Position = UDim2.new(0, 6, 1, -22)
						label.Size = UDim2.new(1, -12, 0, 16)
						label.Font = Enum.Font.Gotham
						label.TextSize = 11
						label.TextXAlignment = Enum.TextXAlignment.Left
						label.TextColor3 = self.getSelectedTheme().TextColor
						label.Text = tostring(item.name or item.Name or itemId)
						label.Parent = card

						local interact = Instance.new("TextButton")
						interact.BackgroundTransparency = 1
						interact.Size = UDim2.new(1, 0, 1, 0)
						interact.Text = ""
						interact.Parent = card
						interact.MouseButton1Click:Connect(function()
							if selectionMode == "single" then
								selected = {}
								selected[itemId] = true
							else
								if selected[itemId] then
									selected[itemId] = nil
								else
									selected[itemId] = true
								end
							end
							for id in pairs(cardById) do
								applyCardSelectionVisual(id)
							end
							emitSelection()
						end)

						cardById[itemId] = card
						applyCardSelectionVisual(itemId)
					end

					task.defer(function()
						applyGridSizing()
						list.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 8)
					end)
				end

				list:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					applyGridSizing()
					list.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 8)
				end)
				grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					list.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 8)
				end)

				function gallery:SetItems(nextItems)
					items = {}
					if type(nextItems) == "table" then
						for _, item in ipairs(nextItems) do
							table.insert(items, cloneSerializable(item))
						end
					end
					renderItems()
				end

				function gallery:AddItem(item)
					if type(item) ~= "table" then
						return
					end
					table.insert(items, cloneSerializable(item))
					renderItems()
				end

				function gallery:RemoveItem(itemId)
					local key = tostring(itemId or "")
					for index, item in ipairs(items) do
						local id = tostring(item.id or item.Id or index)
						if id == key then
							table.remove(items, index)
							selected[key] = nil
							break
						end
					end
					renderItems()
					emitSelection()
				end

				function gallery:Select(itemId)
					local key = tostring(itemId or "")
					if selectionMode == "single" then
						selected = {}
					end
					selected[key] = true
					applyCardSelectionVisual(key)
					emitSelection()
				end

				function gallery:Deselect(itemId)
					local key = tostring(itemId or "")
					selected[key] = nil
					applyCardSelectionVisual(key)
					emitSelection()
				end

				function gallery:ClearSelection()
					selected = {}
					for id in pairs(cardById) do
						applyCardSelectionVisual(id)
					end
					emitSelection()
				end

				function gallery:SetSelection(nextSelection)
					selected = {}
					if selectionMode == "single" then
						local value = type(nextSelection) == "table" and nextSelection[1] or nextSelection
						if value ~= nil then
							selected[tostring(value)] = true
						end
					else
						if type(nextSelection) == "table" then
							for _, value in ipairs(nextSelection) do
								selected[tostring(value)] = true
							end
						elseif nextSelection ~= nil then
							selected[tostring(nextSelection)] = true
						end
					end
					for id in pairs(cardById) do
						applyCardSelectionVisual(id)
					end
					emitSelection()
				end

				function gallery:GetSelection()
					return snapshotSelection()
				end

				function gallery:GetPersistValue()
					return cloneSerializable(snapshotSelection())
				end

				function gallery:Set(value)
					gallery:SetSelection(value)
				end

				function gallery:Destroy()
					root:Destroy()
				end

				connectThemeRefresh(function()
					root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					stroke.Color = self.getSelectedTheme().ElementStroke
					title.TextColor3 = self.getSelectedTheme().TextColor
					for id in pairs(cardById) do
						local card = cardById[id]
						if card then
							local label = card:FindFirstChildOfClass("TextLabel")
							if label then
								label.TextColor3 = self.getSelectedTheme().TextColor
							end
						end
						applyCardSelectionVisual(id)
					end
				end)

				resolveElementParentFromSettings(gallery, settingsValue)
				gallery:SetItems(settingsValue.Items or {})
				addExtendedAPI(gallery, gallery.Name, "Gallery", root)
				if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and gallery.Flag then
					self.RayfieldLibrary.Flags[gallery.Flag] = gallery
				end
				return gallery
			end


			function Tab:CreateDivider()
				local DividerValue = {}
	
				local Divider = self.Elements.Template.Divider:Clone()
				Divider.Visible = true
				Divider.Parent = TabPage
	
				Divider.Divider.BackgroundTransparency = 1
				self.Animation:Create(Divider.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.85}):Play()
	
				function DividerValue:Set(Value)
					Divider.Visible = Value
				end
	
				function DividerValue:Destroy()
					Divider:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(DividerValue, "Divider", "Divider", Divider)
	
				return DividerValue
			end
	
			-- Label
			function Tab:CreateLabel(LabelText, Icon, Color, IgnoreTheme)
				local LabelValue = {}
	
				local Label = self.Elements.Template.Label:Clone()
				Label.Title.Text = LabelText
				Label.Visible = true
				Label.Parent = TabPage
	
				Label.BackgroundColor3 = Color or self.getSelectedTheme().SecondaryElementBackground
				Label.UIStroke.Color = Color or self.getSelectedTheme().SecondaryElementStroke
	
				if Icon then
					if typeof(Icon) == 'string' and self.Icons then
						local asset = self.getIcon(Icon)
	
						Label.Icon.Image = 'rbxassetid://'..asset.id
						Label.Icon.ImageRectOffset = asset.imageRectOffset
						Label.Icon.ImageRectSize = asset.imageRectSize
					else
						Label.Icon.Image = self.getAssetUri(Icon)
					end
				else
					Label.Icon.Image = "rbxassetid://" .. 0
				end
	
				if Icon and Label:FindFirstChild('Icon') then
					Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
					Label.Title.Size = UDim2.new(1, -100, 0, 14)
	
					if Icon then
						if typeof(Icon) == 'string' and self.Icons then
							local asset = self.getIcon(Icon)
	
							Label.Icon.Image = 'rbxassetid://'..asset.id
							Label.Icon.ImageRectOffset = asset.imageRectOffset
							Label.Icon.ImageRectSize = asset.imageRectSize
						else
							Label.Icon.Image = self.getAssetUri(Icon)
						end
					else
						Label.Icon.Image = "rbxassetid://" .. 0
					end
	
					Label.Icon.Visible = true
				end
	
				Label.Icon.ImageTransparency = 1
				Label.BackgroundTransparency = 1
				Label.UIStroke.Transparency = 1
				Label.Title.TextTransparency = 1
	
				self.Animation:Create(Label, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = Color and 0.8 or 0}):Play()
				self.Animation:Create(Label.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = Color and 0.7 or 0}):Play()
				self.Animation:Create(Label.Icon, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
				self.Animation:Create(Label.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = Color and 0.2 or 0}):Play()	
	
				function LabelValue:Set(NewLabel, Icon, Color)
					Label.Title.Text = NewLabel
	
					if Color then
						Label.BackgroundColor3 = Color or self.getSelectedTheme().SecondaryElementBackground
						Label.UIStroke.Color = Color or self.getSelectedTheme().SecondaryElementStroke
					end
	
					if Icon and Label:FindFirstChild('Icon') then
						Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
						Label.Title.Size = UDim2.new(1, -100, 0, 14)
	
						if Icon then
							if typeof(Icon) == 'string' and self.Icons then
								local asset = self.getIcon(Icon)
	
								Label.Icon.Image = 'rbxassetid://'..asset.id
								Label.Icon.ImageRectOffset = asset.imageRectOffset
								Label.Icon.ImageRectSize = asset.imageRectSize
							else
								Label.Icon.Image = self.getAssetUri(Icon)
							end
						else
							Label.Icon.Image = "rbxassetid://" .. 0
						end
	
						Label.Icon.Visible = true
					end
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Label.BackgroundColor3 = IgnoreTheme and (Color or Label.BackgroundColor3) or self.getSelectedTheme().SecondaryElementBackground
					Label.UIStroke.Color = IgnoreTheme and (Color or Label.BackgroundColor3) or self.getSelectedTheme().SecondaryElementStroke
				end)
	
				function LabelValue:Destroy()
					Label:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(LabelValue, LabelText, "Label", Label)
	
				return LabelValue
			end
	
			-- Paragraph
			function Tab:CreateParagraph(ParagraphSettings)
				local ParagraphValue = {}
	
				local Paragraph = self.Elements.Template.Paragraph:Clone()
				Paragraph.Title.Text = ParagraphSettings.Title
				Paragraph.Content.Text = ParagraphSettings.Content
				Paragraph.Visible = true
				Paragraph.Parent = TabPage
	
				Paragraph.BackgroundTransparency = 1
				Paragraph.UIStroke.Transparency = 1
				Paragraph.Title.TextTransparency = 1
				Paragraph.Content.TextTransparency = 1
	
				Paragraph.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
				Paragraph.UIStroke.Color = self.getSelectedTheme().SecondaryElementStroke
	
				self.Animation:Create(Paragraph, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Paragraph.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Paragraph.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
				self.Animation:Create(Paragraph.Content, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	
				function ParagraphValue:Set(NewParagraphSettings)
					Paragraph.Title.Text = NewParagraphSettings.Title
					Paragraph.Content.Text = NewParagraphSettings.Content
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Paragraph.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
					Paragraph.UIStroke.Color = self.getSelectedTheme().SecondaryElementStroke
				end)
	
				function ParagraphValue:Destroy()
					Paragraph:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(ParagraphValue, ParagraphSettings.Title, "Paragraph", Paragraph)
	
				return ParagraphValue
			end
	
			-- Input
			-- Input

	return Tab
end

function ComponentWidgetsFactory.createColorPicker(context, settings)
	local Tab, err = createMethods(context)
	if not Tab then
		warn("Rayfield | " .. tostring(err))
		return nil
	end
	return Tab:CreateColorPicker(settings)
end

function ComponentWidgetsFactory.createNumberStepper(context, settings)
	local Tab, err = createMethods(context)
	if not Tab then
		warn("Rayfield | " .. tostring(err))
		return nil
	end
	return Tab:CreateNumberStepper(settings)
end

function ComponentWidgetsFactory.createConfirmButton(context, settings)
	local Tab, err = createMethods(context)
	if not Tab then
		warn("Rayfield | " .. tostring(err))
		return nil
	end
	return Tab:CreateConfirmButton(settings)
end

function ComponentWidgetsFactory.createImage(context, settings)
	local Tab, err = createMethods(context)
	if not Tab then
		warn("Rayfield | " .. tostring(err))
		return nil
	end
	return Tab:CreateImage(settings)
end

function ComponentWidgetsFactory.createGallery(context, settings)
	local Tab, err = createMethods(context)
	if not Tab then
		warn("Rayfield | " .. tostring(err))
		return nil
	end
	return Tab:CreateGallery(settings)
end

function ComponentWidgetsFactory.createDivider(context)
	local Tab, err = createMethods(context)
	if not Tab then
		warn("Rayfield | " .. tostring(err))
		return nil
	end
	return Tab:CreateDivider()
end

function ComponentWidgetsFactory.createLabel(context, labelText, icon, color, ignoreTheme)
	local Tab, err = createMethods(context)
	if not Tab then
		warn("Rayfield | " .. tostring(err))
		return nil
	end
	return Tab:CreateLabel(labelText, icon, color, ignoreTheme)
end

function ComponentWidgetsFactory.createParagraph(context, paragraphSettings)
	local Tab, err = createMethods(context)
	if not Tab then
		warn("Rayfield | " .. tostring(err))
		return nil
	end
	return Tab:CreateParagraph(paragraphSettings)
end

return ComponentWidgetsFactory
