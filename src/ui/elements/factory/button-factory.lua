local ButtonFactory = {}

function ButtonFactory.create(context)
	context = context or {}
	local Tab = context.Tab
	local TabPage = context.TabPage
	local addExtendedAPI = context.addExtendedAPI
	local registerHoverBinding = context.registerHoverBinding
	local emitUICue = context.emitUICue

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
	if type(emitUICue) ~= "function" then
		emitUICue = function() end
	end

	local self = Tab
	local ButtonSettings = context.settings or {}
	ButtonSettings.Name = ButtonSettings.Name or "Button"
	if type(ButtonSettings.Callback) ~= "function" then
		ButtonSettings.Callback = function() end
	end

	local ButtonValue = {}

	local Button = self.Elements.Template.Button:Clone()
	Button.Name = ButtonSettings.Name
	Button.Title.Text = ButtonSettings.Name
	Button.Visible = true
	Button.Parent = TabPage

	Button.BackgroundTransparency = 1
	Button.UIStroke.Transparency = 1
	Button.Title.TextTransparency = 1

	self.Animation:Create(Button, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	self.Animation:Create(Button.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
	self.Animation:Create(Button.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

	Button.Interact.MouseButton1Click:Connect(function()
		emitUICue("click")
		local Success, Response = pcall(ButtonSettings.Callback)
		if self.rayfieldDestroyed and self.rayfieldDestroyed() then
			return
		end
		if not Success then
			emitUICue("error")
			self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
			self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			Button.Title.Text = "Callback Error"
			print("Rayfield | " .. ButtonSettings.Name .. " Callback Error " .. tostring(Response))
			warn("Check docs.sirius.menu for help with Rayfield specific development.")
			task.wait(0.5)
			Button.Title.Text = ButtonSettings.Name
			self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
			self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
			self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
		else
			emitUICue("success")
			if not ButtonSettings.Ext and type(self.SaveConfiguration) == "function" then
				self.SaveConfiguration(ButtonSettings.Name .. "\n")
			end
			self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
			self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			task.wait(0.2)
			self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
			self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
			self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
		end
	end)

	local buttonHoverBindingKey = registerHoverBinding(
		Button,
		function()
			self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
			self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.7}):Play()
		end,
		function()
			self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
			self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
		end
	)

	function ButtonValue:Set(NewButton)
		Button.Title.Text = NewButton
		Button.Name = NewButton
	end

	function ButtonValue:Destroy()
		Button:Destroy()
	end

	addExtendedAPI(ButtonValue, ButtonSettings.Name, "Button", Button, buttonHoverBindingKey)

	return ButtonValue
end

return ButtonFactory
