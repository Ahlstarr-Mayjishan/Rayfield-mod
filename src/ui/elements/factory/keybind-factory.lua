local KeybindFactory = {}

function KeybindFactory.create(context)
	context = context or {}
	local Tab = context.Tab
	local TabPage = context.TabPage
	local Settings = context.Settings or {}
	local addExtendedAPI = context.addExtendedAPI
	local registerHoverBinding = context.registerHoverBinding
	local ownershipTrackConnection = context.ownershipTrackConnection or function() end
	local ownershipTrackCleanup = context.ownershipTrackCleanup or function() end
	local resolveSequenceRuntimeOptions = context.resolveSequenceRuntimeOptions
	local normalizeSequenceBinding = context.normalizeSequenceBinding
	local parseSequenceInput = context.parseSequenceInput
	local formatSequenceDisplay = context.formatSequenceDisplay
	local trim = context.trim or function(value)
		if type(value) ~= "string" then
			return ""
		end
		local out = value:gsub("^%s+", "")
		out = out:gsub("%s+$", "")
		return out
	end
	local emitUICue = context.emitUICue or function() end
	local SequenceLib = context.SequenceLib

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
	if type(resolveSequenceRuntimeOptions) ~= "function"
		or type(normalizeSequenceBinding) ~= "function"
		or type(parseSequenceInput) ~= "function"
		or type(formatSequenceDisplay) ~= "function" then
		return nil
	end

	local self = Tab
	local KeybindSettings = context.settings

	local ctx = self
	local CheckingForKey = false
	local captureSteps = {}
	local captureToken = 0
	local maxSteps, stepTimeoutMs = resolveSequenceRuntimeOptions(KeybindSettings)
	local sequenceMatcher = SequenceLib and SequenceLib.newMatcher({
		maxSteps = maxSteps,
		stepTimeoutMs = stepTimeoutMs
	}) or nil
	local Keybind = self.Elements.Template.Keybind:Clone()
	Keybind.Name = KeybindSettings.Name
	Keybind.Title.Text = KeybindSettings.Name
	Keybind.Visible = true
	Keybind.Parent = TabPage
	
	Keybind.BackgroundTransparency = 1
	Keybind.UIStroke.Transparency = 1
	Keybind.Title.TextTransparency = 1
	
	Keybind.KeybindFrame.BackgroundColor3 = self.getSelectedTheme().InputBackground
	Keybind.KeybindFrame.UIStroke.Color = self.getSelectedTheme().InputStroke
	
	self.Animation:Create(Keybind, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	self.Animation:Create(Keybind.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
	self.Animation:Create(Keybind.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()	

	if type(KeybindSettings.Callback) ~= "function" then
		KeybindSettings.Callback = function() end
	end

	KeybindSettings.MaxSteps = maxSteps
	KeybindSettings.StepTimeoutMs = stepTimeoutMs

	local activeSteps = nil
	local activeCanonical, parsedSteps = normalizeSequenceBinding(KeybindSettings.CurrentKeybind or "Q", KeybindSettings)
	if not activeCanonical then
		activeCanonical, parsedSteps = normalizeSequenceBinding("Q", KeybindSettings)
	end
	activeSteps = parsedSteps
	KeybindSettings.CurrentKeybind = activeCanonical or "Q"

	local function resizeKeybindFrameToText()
		self.Animation:Create(Keybind.KeybindFrame, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)
		}):Play()
	end

	local function applyBinding(canonical, steps, callOnChange)
		if not canonical then
			return false
		end

		KeybindSettings.CurrentKeybind = canonical
		activeSteps = steps
		Keybind.KeybindFrame.KeybindBox.Text = formatSequenceDisplay(canonical, steps, KeybindSettings)
		resizeKeybindFrameToText()

		if sequenceMatcher then
			sequenceMatcher:setBinding({
				canonical = canonical,
				steps = activeSteps
			})
		end

		if not KeybindSettings.Ext then
			self.SaveConfiguration()
		end

		if callOnChange and KeybindSettings.CallOnChange then
			KeybindSettings.Callback(canonical)
		end
		return true
	end

	local function finalizeCapture(releaseFocus)
		captureToken += 1
		if #captureSteps <= 0 then
			return false
		end

		local candidateCanonical = table.concat(captureSteps, ">")
		captureSteps = {}

		local canonical, steps = normalizeSequenceBinding(candidateCanonical, KeybindSettings)
		if canonical then
			applyBinding(canonical, steps, true)
		else
			Keybind.KeybindFrame.KeybindBox.Text = formatSequenceDisplay(KeybindSettings.CurrentKeybind, activeSteps, KeybindSettings)
			resizeKeybindFrameToText()
		end

		if releaseFocus and Keybind.KeybindFrame.KeybindBox:IsFocused() then
			Keybind.KeybindFrame.KeybindBox:ReleaseFocus()
		end

		return canonical ~= nil
	end

	local function scheduleCaptureFinalize()
		captureToken += 1
		local token = captureToken
		task.delay(stepTimeoutMs / 1000, function()
			if CheckingForKey and token == captureToken then
				finalizeCapture(true)
			end
		end)
	end

	applyBinding(KeybindSettings.CurrentKeybind, activeSteps, false)

	Keybind.KeybindFrame.KeybindBox.Focused:Connect(function()
		CheckingForKey = true
		Keybind.KeybindFrame.KeybindBox.Text = ""
		captureSteps = {}
		captureToken += 1
	end)
	Keybind.KeybindFrame.KeybindBox.FocusLost:Connect(function()
		local typedText = trim(Keybind.KeybindFrame.KeybindBox.Text or "")
		local captureWasActive = CheckingForKey
		CheckingForKey = false
		captureToken += 1

		if captureWasActive and #captureSteps > 0 then
			finalizeCapture(false)
			return
		end

		if typedText ~= "" then
			local canonical, steps = parseSequenceInput(typedText, KeybindSettings)
			if canonical then
				applyBinding(canonical, steps, true)
				return
			end
		end

		Keybind.KeybindFrame.KeybindBox.Text = formatSequenceDisplay(KeybindSettings.CurrentKeybind, activeSteps, KeybindSettings)
		resizeKeybindFrameToText()
	end)
	
	local keybindHoverBindingKey = registerHoverBinding(Keybind,
		function()
			self.Animation:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
		end,
		function()
			self.Animation:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
		end
	)
	
	local connection = self.UserInputService.InputBegan:Connect(function(input, processed)
		if CheckingForKey then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end

			if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
				finalizeCapture(true)
				return
			end

			local capturedStep = nil
			if SequenceLib then
				capturedStep = select(1, SequenceLib.captureStepFromInput(input, self.UserInputService))
			elseif input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
				capturedStep = input.KeyCode.Name
			end

			if capturedStep then
				if #captureSteps < maxSteps then
					table.insert(captureSteps, capturedStep)
				end

				local previewCanonical = table.concat(captureSteps, ">")
				local previewSteps = select(2, normalizeSequenceBinding(previewCanonical, KeybindSettings))
				Keybind.KeybindFrame.KeybindBox.Text = formatSequenceDisplay(previewCanonical, previewSteps, KeybindSettings)
				resizeKeybindFrameToText()

				if #captureSteps >= maxSteps then
					finalizeCapture(true)
				else
					scheduleCaptureFinalize()
				end
			end
		elseif not KeybindSettings.CallOnChange then
			local matched = false
			if sequenceMatcher then
				matched = sequenceMatcher:consume(input, {
					canonical = KeybindSettings.CurrentKeybind,
					steps = activeSteps
				}, self.UserInputService, processed)
			elseif KeybindSettings.CurrentKeybind and not processed then
				matched = input.KeyCode == Enum.KeyCode[KeybindSettings.CurrentKeybind]
			end

			if not matched then
				return
			end

			local Held = true
			local Connection
			Connection = input.Changed:Connect(function(prop)
				if prop == "UserInputState" then
					Connection:Disconnect()
					Held = false
				end
			end)
	
			if not KeybindSettings.HoldToInteract then
				emitUICue("click")
				local Success, Response = pcall(KeybindSettings.Callback)
				if not Success then
					emitUICue("error")
					self.Animation:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					self.Animation:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
					Keybind.Title.Text = "Callback Error"
					print("Rayfield | "..KeybindSettings.Name.." Callback Error " ..tostring(Response))
					warn('Check docs.sirius.menu for help with Rayfield specific development.')
					task.wait(0.5)
					Keybind.Title.Text = KeybindSettings.Name
					self.Animation:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					self.Animation:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				else
					emitUICue("success")
				end
			else
				task.wait(0.25)
				if Held then
					local Loop; Loop = self.RunService.Stepped:Connect(function()
						if not Held then
							KeybindSettings.Callback(false) -- maybe pcall this
							Loop:Disconnect()
						else
							KeybindSettings.Callback(true) -- maybe pcall this
						end
					end)
				end
			end
		end
	end)
	table.insert(self.keybindConnections, connection)
	local function removeConnectionFromGlobalList()
		for index = #self.keybindConnections, 1, -1 do
			if self.keybindConnections[index] == connection then
				table.remove(self.keybindConnections, index)
			end
		end
	end

	Keybind.KeybindFrame.KeybindBox:GetPropertyChangedSignal("Text"):Connect(function()
		resizeKeybindFrameToText()
	end)
	
	function KeybindSettings:Set(NewKeybind)
		local canonical, steps = normalizeSequenceBinding(NewKeybind, KeybindSettings)
		if not canonical then
			canonical, steps = parseSequenceInput(tostring(NewKeybind or ""), KeybindSettings)
		end

		if canonical then
			applyBinding(canonical, steps, true)
		else
			Keybind.KeybindFrame.KeybindBox.Text = formatSequenceDisplay(KeybindSettings.CurrentKeybind, activeSteps, KeybindSettings)
			resizeKeybindFrameToText()
		end
	end
	
	if Settings.ConfigurationSaving then
		if Settings.ConfigurationSaving.Enabled and KeybindSettings.Flag then
			self.RayfieldLibrary.Flags[KeybindSettings.Flag] = KeybindSettings
		end
	end
	
	self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
		Keybind.KeybindFrame.BackgroundColor3 = self.getSelectedTheme().InputBackground
		Keybind.KeybindFrame.UIStroke.Color = self.getSelectedTheme().InputStroke
	end)
	
	function KeybindSettings:Destroy()
		Keybind:Destroy()
	end
	
	-- Add extended API
	addExtendedAPI(KeybindSettings, KeybindSettings.Name, "Keybind", Keybind, keybindHoverBindingKey)
	local cleanupScopeId = KeybindSettings.GetCleanupScope and KeybindSettings:GetCleanupScope() or KeybindSettings.__CleanupScope
	if cleanupScopeId then
		ownershipTrackConnection(connection, cleanupScopeId)
		ownershipTrackCleanup(removeConnectionFromGlobalList, cleanupScopeId)
	end
	
	return KeybindSettings
end

return KeybindFactory


