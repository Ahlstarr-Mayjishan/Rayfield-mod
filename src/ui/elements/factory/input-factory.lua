local InputFactory = {}

function InputFactory.create(context)
	context = context or {}
	local Tab = context.Tab
	local TabPage = context.TabPage
	local Settings = context.Settings or {}
	local addExtendedAPI = context.addExtendedAPI
	local registerHoverBinding = context.registerHoverBinding
	local registerElementSync = context.registerElementSync
	local commitElementSync = context.commitElementSync
	local emitUICue = context.emitUICue or function() end
	local InputSettings = context.settings

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
	local self = Tab

				local ctx = self
				InputSettings = InputSettings or {}
				if type(InputSettings.Callback) ~= "function" then
					InputSettings.Callback = function() end
				end
				InputSettings.CurrentValue = tostring(InputSettings.CurrentValue or "")

				local Input = self.Elements.Template.Input:Clone()
				Input.Name = InputSettings.Name
				Input.Title.Text = InputSettings.Name
				Input.Visible = true
				Input.Parent = TabPage
	
				Input.BackgroundTransparency = 1
				Input.UIStroke.Transparency = 1
				Input.Title.TextTransparency = 1

				Input.InputFrame.InputBox.Text = InputSettings.CurrentValue

				self.bindTheme(Input.InputFrame, "BackgroundColor3", "InputBackground")
				self.bindTheme(Input.InputFrame.UIStroke, "Color", "InputStroke")
	
				self.Animation:Create(Input, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Input.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Input.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()	
	
				Input.InputFrame.InputBox.PlaceholderText = InputSettings.PlaceholderText
				local function resizeInputFrame()
					self.Animation:Create(
						Input.InputFrame,
						TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
						{Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)}
					):Play()
				end
				resizeInputFrame()

				local function handleInputCallbackError(response)
					emitUICue("error")
					self.Animation:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					self.Animation:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
					Input.Title.Text = "Callback Error"
					print("Rayfield | "..InputSettings.Name.." Callback Error " ..tostring(response))
					warn('Check docs.sirius.menu for help with Rayfield specific development.')
					task.wait(0.5)
					Input.Title.Text = InputSettings.Name
					self.Animation:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					self.Animation:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				end

				local inputSyncToken = registerElementSync({
					name = InputSettings.Name,
					getState = function()
						return tostring(InputSettings.CurrentValue or "")
					end,
					normalize = function(rawText)
						local normalized = rawText
						if elementSync and elementSync.normalize and elementSync.normalize.text then
							normalized = elementSync.normalize.text(rawText, {
								default = "",
								trim = false
							})
						else
							normalized = tostring(rawText or "")
						end
						return normalized, {
							changed = tostring(InputSettings.CurrentValue or "") ~= normalized
						}
					end,
					applyVisual = function(value)
						InputSettings.CurrentValue = value
						local isFocused = false
						local focusOk, focusState = pcall(function()
							return Input.InputFrame.InputBox:IsFocused()
						end)
						if focusOk and focusState then
							isFocused = true
						end
						if not isFocused then
							Input.InputFrame.InputBox.Text = value
						end
						resizeInputFrame()
					end,
					emitCallback = function(value)
						InputSettings.Callback(value)
					end,
					persist = function()
						ctx.SaveConfiguration()
					end,
					isExt = function()
						return InputSettings.Ext == true
					end,
					isAlive = function()
						return Input ~= nil and Input.Parent ~= nil
					end,
					isVisibleContext = function()
						return Input.Visible and Input:IsDescendantOf(TabPage) and self.Elements.UIPageLayout.CurrentPage == TabPage
					end,
					onCallbackError = handleInputCallbackError
				})

				local function commitInput(rawText, commitOptions)
					local options = commitOptions or {}
					if inputSyncToken then
						return commitElementSync(inputSyncToken, rawText, {
							reason = options.reason or "input_update",
							source = options.source or "unknown",
							emitCallback = options.emitCallback,
							persist = options.persist,
							forceCallback = options.forceCallback
						})
					end

					local normalized = tostring(rawText or "")
					InputSettings.CurrentValue = normalized
					Input.InputFrame.InputBox.Text = normalized
					resizeInputFrame()
					local success, response = pcall(function()
						InputSettings.Callback(normalized)
					end)
					if not success then
						handleInputCallbackError(response)
					elseif not InputSettings.Ext then
						ctx.SaveConfiguration()
					end
					return success, {
						normalized = normalized,
						changed = true,
						fallbackApplied = false,
						callbackOk = success
					}
				end

				Input.InputFrame.InputBox.FocusLost:Connect(function()
					emitUICue("click")
					local callbackOk = commitInput(Input.InputFrame.InputBox.Text, {
						reason = "focus_lost",
						source = "user_input",
						emitCallback = true,
						persist = true,
						forceCallback = true
					})
					if callbackOk == true then
						emitUICue("success")
					end

					if InputSettings.RemoveTextAfterFocusLost then
						Input.InputFrame.InputBox.Text = ""
						resizeInputFrame()
					end
				end)
	
				local inputHoverBindingKey = registerHoverBinding(Input,
					function()
						self.Animation:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
					end,
					function()
						self.Animation:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					end
				)
	
				Input.InputFrame.InputBox:GetPropertyChangedSignal("Text"):Connect(function()
					resizeInputFrame()
				end)
	
				function InputSettings:Set(text)
					commitInput(text, {
						reason = "set",
						source = "api_set",
						emitCallback = true,
						persist = true,
						forceCallback = true
					})
				end
	
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and InputSettings.Flag then
						self.RayfieldLibrary.Flags[InputSettings.Flag] = InputSettings
					end
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Input.InputFrame.BackgroundColor3 = self.getSelectedTheme().InputBackground
					Input.InputFrame.UIStroke.Color = self.getSelectedTheme().InputStroke
				end)
	
				function InputSettings:Destroy()
					Input:Destroy()
				end

				-- Add extended API
				addExtendedAPI(InputSettings, InputSettings.Name, "Input", Input, inputHoverBindingKey, inputSyncToken)

				return InputSettings
end

return InputFactory
