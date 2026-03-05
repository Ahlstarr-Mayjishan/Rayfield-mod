local ToggleFactory = {}

function ToggleFactory.create(context)
	context = context or {}
	local Tab = context.Tab
	local TabPage = context.TabPage
	local Settings = context.Settings or {}
	local addExtendedAPI = context.addExtendedAPI
	local registerHoverBinding = context.registerHoverBinding
	local registerElementSync = context.registerElementSync
	local commitElementSync = context.commitElementSync
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
	if type(resolveSequenceRuntimeOptions) ~= "function"
		or type(normalizeSequenceBinding) ~= "function"
		or type(parseSequenceInput) ~= "function"
		or type(formatSequenceDisplay) ~= "function" then
		return nil
	end

	local self = Tab
	local ToggleSettings = context.settings

	local ctx = self
	ToggleSettings = ToggleSettings or {}
	ToggleSettings.Name = ToggleSettings.Name or "Toggle"
	if type(ToggleSettings.Callback) ~= "function" then
		ToggleSettings.Callback = function() end
	end
	ToggleSettings.CurrentValue = ToggleSettings.CurrentValue == true

	local toggleKeybindSettings = ToggleSettings.Keybind
	if type(toggleKeybindSettings) ~= "table" then
		toggleKeybindSettings = {}
	end
	if ToggleSettings.EnableKeybind ~= nil and toggleKeybindSettings.Enabled == nil then
		toggleKeybindSettings.Enabled = ToggleSettings.EnableKeybind
	end
	if ToggleSettings.CurrentKeybind and toggleKeybindSettings.CurrentKeybind == nil then
		toggleKeybindSettings.CurrentKeybind = ToggleSettings.CurrentKeybind
	end
	if ToggleSettings.KeybindDisplayFormatter and toggleKeybindSettings.DisplayFormatter == nil then
		toggleKeybindSettings.DisplayFormatter = ToggleSettings.KeybindDisplayFormatter
	end
	if ToggleSettings.KeybindParseInput and toggleKeybindSettings.ParseInput == nil then
		toggleKeybindSettings.ParseInput = ToggleSettings.KeybindParseInput
	end
	if ToggleSettings.KeybindMaxSteps and toggleKeybindSettings.MaxSteps == nil then
		toggleKeybindSettings.MaxSteps = ToggleSettings.KeybindMaxSteps
	end
	if ToggleSettings.KeybindStepTimeoutMs and toggleKeybindSettings.StepTimeoutMs == nil then
		toggleKeybindSettings.StepTimeoutMs = ToggleSettings.KeybindStepTimeoutMs
	end
	ToggleSettings.Keybind = toggleKeybindSettings

	local keybindEnabled = toggleKeybindSettings.Enabled == true
	local toggleKeybindMaxSteps, toggleKeybindTimeoutMs = resolveSequenceRuntimeOptions(toggleKeybindSettings)
	toggleKeybindSettings.MaxSteps = toggleKeybindMaxSteps
	toggleKeybindSettings.StepTimeoutMs = toggleKeybindTimeoutMs
	toggleKeybindSettings.CurrentKeybind = toggleKeybindSettings.CurrentKeybind or "Q"
	ToggleSettings.CurrentKeybind = toggleKeybindSettings.CurrentKeybind

	local toggleKeybindConnection = nil
	local toggleKeybindMatcher = nil
	local toggleKeybindActiveSteps = nil
	local keybindCapturing = false
	local keybindCaptureSteps = {}
	local keybindCaptureToken = 0
	local suppressNextToggleClick = false
	local toggleKeybindFrame = nil
	local toggleKeybindBox = nil
	local toggleKeybindFlagProxy = nil
	
	local Toggle = self.Elements.Template.Toggle:Clone()
	Toggle.Name = ToggleSettings.Name
	Toggle.Title.Text = ToggleSettings.Name
	Toggle.Visible = true
	Toggle.Parent = TabPage
	
	Toggle.BackgroundTransparency = 1
	Toggle.UIStroke.Transparency = 1
	Toggle.Title.TextTransparency = 1
	self.bindTheme(Toggle.Switch, "BackgroundColor3", "ToggleBackground")
	
	if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
		local toggleShadow = Toggle.Switch:FindFirstChild("Shadow")
		if toggleShadow then
			toggleShadow.Visible = false
		end
	end
	
	self.Animation:Create(Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
	self.Animation:Create(Toggle.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()	
	
	local function UpdateToggleColors()
		if ToggleSettings.CurrentValue == true then
			Toggle.Switch.Indicator.UIStroke.Color = self.getSelectedTheme().ToggleEnabledStroke
			Toggle.Switch.Indicator.BackgroundColor3 = self.getSelectedTheme().ToggleEnabled
			Toggle.Switch.UIStroke.Color = self.getSelectedTheme().ToggleEnabledOuterStroke
		else
			Toggle.Switch.Indicator.UIStroke.Color = self.getSelectedTheme().ToggleDisabledStroke
			Toggle.Switch.Indicator.BackgroundColor3 = self.getSelectedTheme().ToggleDisabled
			Toggle.Switch.UIStroke.Color = self.getSelectedTheme().ToggleDisabledOuterStroke
		end
	end

	local function handleToggleCallbackError(response)
		emitUICue("error")
		self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
		self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
		Toggle.Title.Text = "Callback Error"
		print("Rayfield | "..ToggleSettings.Name.." Callback Error " ..tostring(response))
		warn('Check docs.sirius.menu for help with Rayfield specific development.')
		task.wait(0.5)
		Toggle.Title.Text = ToggleSettings.Name
		self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
		self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
	end

	local function applyToggleVisual(nextValue)
		if nextValue == true then
			ToggleSettings.CurrentValue = true
			self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
			self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
			self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
			self.Animation:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = self.getSelectedTheme().ToggleEnabledStroke}):Play()
			self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = self.getSelectedTheme().ToggleEnabled}):Play()
			self.Animation:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = self.getSelectedTheme().ToggleEnabledOuterStroke}):Play()
			self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()
			self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
			self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
		else
			ToggleSettings.CurrentValue = false
			self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
			self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
			self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
			self.Animation:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = self.getSelectedTheme().ToggleDisabledStroke}):Play()
			self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = self.getSelectedTheme().ToggleDisabled}):Play()
			self.Animation:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = self.getSelectedTheme().ToggleDisabledOuterStroke}):Play()
			self.Animation:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()
			self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
			self.Animation:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
		end
	end

	local toggleSyncToken = registerElementSync({
		name = ToggleSettings.Name,
		getState = function()
			return ToggleSettings.CurrentValue == true
		end,
		normalize = function(rawValue)
			local normalized = rawValue == true
			if elementSync and elementSync.normalize and elementSync.normalize.boolean then
				normalized = elementSync.normalize.boolean(rawValue)
			end
			return normalized, {
				changed = (ToggleSettings.CurrentValue == true) ~= normalized
			}
		end,
		applyVisual = function(normalized)
			applyToggleVisual(normalized == true)
		end,
		emitCallback = function(normalized)
			if debugX then warn('Running toggle \''..ToggleSettings.Name..'\' (sync commit)') end
			ToggleSettings.Callback(normalized == true)
		end,
		persist = function()
			ctx.SaveConfiguration()
		end,
		isExt = function()
			return ToggleSettings.Ext == true
		end,
		isAlive = function()
			return Toggle ~= nil and Toggle.Parent ~= nil
		end,
		isVisibleContext = function()
			return Toggle.Visible and Toggle:IsDescendantOf(TabPage) and self.Elements.UIPageLayout.CurrentPage == TabPage
		end,
		onCallbackError = handleToggleCallbackError
	})

	local function commitToggleState(rawValue, commitOptions)
		local options = commitOptions or {}
		if toggleSyncToken then
			local callbackOk = commitElementSync(toggleSyncToken, rawValue, {
				reason = options.reason or "toggle_update",
				source = options.source or "unknown",
				emitCallback = options.emitCallback,
				persist = options.persist,
				forceCallback = options.forceCallback
			})
			return callbackOk
		end

		local normalized = rawValue == true
		applyToggleVisual(normalized)
		local success, response = pcall(function()
			ToggleSettings.Callback(ToggleSettings.CurrentValue)
		end)
		if not success then
			handleToggleCallbackError(response)
		elseif not ToggleSettings.Ext then
			ctx.SaveConfiguration()
		end
		return success
	end

	local function formatToggleKeybindDisplay(canonical, steps)
		return formatSequenceDisplay(canonical, steps, toggleKeybindSettings)
	end

	local function resizeToggleKeybindFrame()
		if not (toggleKeybindFrame and toggleKeybindBox) then
			return
		end
		local targetWidth = math.clamp(toggleKeybindBox.TextBounds.X + 24, 56, 190)
		self.Animation:Create(toggleKeybindFrame, TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, targetWidth, 0, 30)
		}):Play()
	end

	local function applyToggleKeybindBinding(canonical, steps, callOnChange)
		if not canonical then
			return false
		end

		toggleKeybindSettings.CurrentKeybind = canonical
		ToggleSettings.CurrentKeybind = canonical
		toggleKeybindActiveSteps = steps
		if toggleKeybindFlagProxy then
			toggleKeybindFlagProxy.CurrentKeybind = canonical
		end
		if toggleKeybindMatcher then
			toggleKeybindMatcher:setBinding({
				canonical = canonical,
				steps = steps
			})
		end

		if toggleKeybindBox then
			toggleKeybindBox.Text = formatToggleKeybindDisplay(canonical, steps)
			resizeToggleKeybindFrame()
		end

		if callOnChange and toggleKeybindSettings.CallOnChange and type(toggleKeybindSettings.Callback) == "function" then
			pcall(toggleKeybindSettings.Callback, canonical)
		end

		return true
	end

	local function finalizeToggleKeybindCapture(releaseFocus)
		keybindCaptureToken += 1
		if #keybindCaptureSteps <= 0 then
			return false
		end

		local candidateCanonical = table.concat(keybindCaptureSteps, ">")
		keybindCaptureSteps = {}
		local canonical, steps = normalizeSequenceBinding(candidateCanonical, toggleKeybindSettings)
		if canonical then
			applyToggleKeybindBinding(canonical, steps, true)
		elseif toggleKeybindBox then
			toggleKeybindBox.Text = formatToggleKeybindDisplay(toggleKeybindSettings.CurrentKeybind, toggleKeybindActiveSteps)
			resizeToggleKeybindFrame()
		end

		if releaseFocus and toggleKeybindBox and toggleKeybindBox:IsFocused() then
			toggleKeybindBox:ReleaseFocus()
		end

		return canonical ~= nil
	end

	local function scheduleToggleKeybindCaptureFinalize()
		keybindCaptureToken += 1
		local token = keybindCaptureToken
		task.delay(toggleKeybindTimeoutMs / 1000, function()
			if keybindCapturing and token == keybindCaptureToken then
				finalizeToggleKeybindCapture(true)
			end
		end)
	end

	if keybindEnabled then
		local switchWidth = Toggle.Switch.Size.X.Offset
		if switchWidth <= 0 then
			switchWidth = Toggle.Switch.AbsoluteSize.X
		end
		if switchWidth <= 0 then
			switchWidth = 56
		end

		local keybindFrameTemplate = self.Elements.Template.Keybind and self.Elements.Template.Keybind:FindFirstChild("KeybindFrame")
		if keybindFrameTemplate and keybindFrameTemplate:IsA("Frame") then
			toggleKeybindFrame = keybindFrameTemplate:Clone()
		else
			toggleKeybindFrame = Instance.new("Frame")
			toggleKeybindFrame.Name = "ToggleKeybindFrame"
			toggleKeybindFrame.BackgroundTransparency = 0
			local fallbackStroke = Instance.new("UIStroke")
			fallbackStroke.Parent = toggleKeybindFrame
			local fallbackBox = Instance.new("TextBox")
			fallbackBox.Name = "KeybindBox"
			fallbackBox.BackgroundTransparency = 1
			fallbackBox.Size = UDim2.new(1, 0, 1, 0)
			fallbackBox.Parent = toggleKeybindFrame
		end

		toggleKeybindFrame.Name = "ToggleKeybindFrame"
		toggleKeybindFrame.Visible = true
		toggleKeybindFrame.Active = true
		toggleKeybindFrame.Parent = Toggle
		toggleKeybindFrame.AnchorPoint = Vector2.new(1, 0.5)
		toggleKeybindFrame.Position = UDim2.new(1, -(switchWidth + 18), 0.5, 0)
		toggleKeybindFrame.ZIndex = math.max(Toggle.Switch.ZIndex, Toggle.Interact.ZIndex, Toggle.ZIndex) + 2
		self.bindTheme(toggleKeybindFrame, "BackgroundColor3", "InputBackground")

		toggleKeybindBox = toggleKeybindFrame:FindFirstChild("KeybindBox")
		if not (toggleKeybindBox and toggleKeybindBox:IsA("TextBox")) then
			toggleKeybindBox = Instance.new("TextBox")
			toggleKeybindBox.Name = "KeybindBox"
			toggleKeybindBox.BackgroundTransparency = 1
			toggleKeybindBox.Size = UDim2.new(1, 0, 1, 0)
			toggleKeybindBox.Parent = toggleKeybindFrame
		end

		toggleKeybindBox.ClearTextOnFocus = false
		toggleKeybindBox.TextWrapped = false
		toggleKeybindBox.TextXAlignment = Enum.TextXAlignment.Center
		toggleKeybindBox.TextYAlignment = Enum.TextYAlignment.Center
		toggleKeybindBox.ZIndex = toggleKeybindFrame.ZIndex + 1

		local keybindFrameStroke = toggleKeybindFrame:FindFirstChildWhichIsA("UIStroke")
		if keybindFrameStroke then
			self.bindTheme(keybindFrameStroke, "Color", "InputStroke")
		end

		if SequenceLib then
			toggleKeybindMatcher = SequenceLib.newMatcher({
				maxSteps = toggleKeybindMaxSteps,
				stepTimeoutMs = toggleKeybindTimeoutMs
			})
		end

		local initialCanonical, initialSteps = normalizeSequenceBinding(toggleKeybindSettings.CurrentKeybind, toggleKeybindSettings)
		if not initialCanonical then
			initialCanonical, initialSteps = normalizeSequenceBinding("Q", toggleKeybindSettings)
		end
		applyToggleKeybindBinding(initialCanonical, initialSteps, false)

		toggleKeybindFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				suppressNextToggleClick = true
				task.delay(0.2, function()
					suppressNextToggleClick = false
				end)
			end
		end)

		toggleKeybindBox.Focused:Connect(function()
			keybindCapturing = true
			keybindCaptureSteps = {}
			keybindCaptureToken += 1
			toggleKeybindBox.Text = ""
		end)

		toggleKeybindBox.FocusLost:Connect(function()
			local typedText = trim(toggleKeybindBox.Text or "")
			local wasCapturing = keybindCapturing
			keybindCapturing = false
			keybindCaptureToken += 1

			if wasCapturing and #keybindCaptureSteps > 0 then
				finalizeToggleKeybindCapture(false)
				return
			end

			if typedText ~= "" then
				local canonical, steps = parseSequenceInput(typedText, toggleKeybindSettings)
				if canonical then
					applyToggleKeybindBinding(canonical, steps, true)
					return
				end
			end

			toggleKeybindBox.Text = formatToggleKeybindDisplay(toggleKeybindSettings.CurrentKeybind, toggleKeybindActiveSteps)
			resizeToggleKeybindFrame()
		end)

		toggleKeybindBox:GetPropertyChangedSignal("Text"):Connect(function()
			resizeToggleKeybindFrame()
		end)
	end

	-- Reactive Toggle Colors
	local themeValueFolder = self.Main:FindFirstChild("ThemeValues")
	if themeValueFolder then
		local backgroundValue = themeValueFolder:FindFirstChild("Background")
		if backgroundValue then
			backgroundValue.Changed:Connect(UpdateToggleColors)
		end
	end
	
	UpdateToggleColors()
	
	local toggleHoverBindingKey = registerHoverBinding(Toggle,
		function()
			self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
		end,
		function()
			self.Animation:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
		end
	)

	if keybindEnabled then
		toggleKeybindConnection = self.UserInputService.InputBegan:Connect(function(input, processed)
			if keybindCapturing then
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end

				if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
					finalizeToggleKeybindCapture(true)
					return
				end

				local capturedStep = nil
				if SequenceLib then
					capturedStep = select(1, SequenceLib.captureStepFromInput(input, self.UserInputService))
				elseif input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
					capturedStep = input.KeyCode.Name
				end

				if capturedStep then
					if #keybindCaptureSteps < toggleKeybindMaxSteps then
						table.insert(keybindCaptureSteps, capturedStep)
					end

					local previewCanonical = table.concat(keybindCaptureSteps, ">")
					local previewSteps = select(2, normalizeSequenceBinding(previewCanonical, toggleKeybindSettings))
					if toggleKeybindBox then
						toggleKeybindBox.Text = formatToggleKeybindDisplay(previewCanonical, previewSteps)
						resizeToggleKeybindFrame()
					end

					if #keybindCaptureSteps >= toggleKeybindMaxSteps then
						finalizeToggleKeybindCapture(true)
					else
						scheduleToggleKeybindCaptureFinalize()
					end
				end

				return
			end

			if processed then
				return
			end

			local matched = false
			if toggleKeybindMatcher then
				matched = toggleKeybindMatcher:consume(input, {
					canonical = toggleKeybindSettings.CurrentKeybind,
					steps = toggleKeybindActiveSteps
				}, self.UserInputService, processed)
			elseif toggleKeybindSettings.CurrentKeybind and input.KeyCode then
				matched = input.KeyCode == Enum.KeyCode[toggleKeybindSettings.CurrentKeybind]
			end

			if matched then
				ToggleSettings:Set(not ToggleSettings.CurrentValue)
			end
		end)
		table.insert(self.keybindConnections, toggleKeybindConnection)
	end
	local function removeToggleKeybindConnectionFromGlobalList()
		if not toggleKeybindConnection then
			return
		end
		for index = #self.keybindConnections, 1, -1 do
			if self.keybindConnections[index] == toggleKeybindConnection then
				table.remove(self.keybindConnections, index)
			end
		end
	end
	
	Toggle.Interact.MouseButton1Click:Connect(function()
		if suppressNextToggleClick then
			suppressNextToggleClick = false
			return
		end
		emitUICue("click")
		local callbackOk = commitToggleState(not ToggleSettings.CurrentValue, {
			reason = "interact_click",
			source = "ui_click",
			emitCallback = true,
			persist = true,
			forceCallback = true
		})
		if callbackOk == true then
			emitUICue("success")
		end
	end)
	
	function ToggleSettings:Set(NewToggleValue)
		if keybindEnabled and (type(NewToggleValue) == "string" or typeof(NewToggleValue) == "EnumItem") then
			local canonical, steps = normalizeSequenceBinding(NewToggleValue, toggleKeybindSettings)
			if not canonical then
				canonical, steps = parseSequenceInput(tostring(NewToggleValue), toggleKeybindSettings)
			end

			if canonical then
				applyToggleKeybindBinding(canonical, steps, true)
				if not ToggleSettings.Ext then
					ctx.SaveConfiguration()
				end
			elseif toggleKeybindBox then
				toggleKeybindBox.Text = formatToggleKeybindDisplay(toggleKeybindSettings.CurrentKeybind, toggleKeybindActiveSteps)
				resizeToggleKeybindFrame()
			end
			return
		end
		commitToggleState(NewToggleValue == true, {
			reason = "set",
			source = "api_set",
			emitCallback = true,
			persist = true,
			forceCallback = true
		})
	end

	function ToggleSettings:Get()
		return ToggleSettings.CurrentValue
	end

	function ToggleSettings:SetKeybind(NewKeybind)
		if not keybindEnabled then
			return false
		end

		local canonical, steps = normalizeSequenceBinding(NewKeybind, toggleKeybindSettings)
		if not canonical then
			canonical, steps = parseSequenceInput(tostring(NewKeybind or ""), toggleKeybindSettings)
		end

		if canonical then
			local applied = applyToggleKeybindBinding(canonical, steps, true)
			if applied and not ToggleSettings.Ext then
				ctx.SaveConfiguration()
			end
			return applied
		end

		if toggleKeybindBox then
			toggleKeybindBox.Text = formatToggleKeybindDisplay(toggleKeybindSettings.CurrentKeybind, toggleKeybindActiveSteps)
			resizeToggleKeybindFrame()
		end
		return false
	end

	function ToggleSettings:GetKeybind()
		return toggleKeybindSettings.CurrentKeybind
	end

	if keybindEnabled and Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and toggleKeybindSettings.Flag then
		toggleKeybindFlagProxy = {
			Type = "Keybind",
			CurrentKeybind = toggleKeybindSettings.CurrentKeybind,
			Set = function(_, newBinding)
				local canonical, steps = normalizeSequenceBinding(newBinding, toggleKeybindSettings)
				if not canonical then
					canonical, steps = parseSequenceInput(tostring(newBinding or ""), toggleKeybindSettings)
				end
				if canonical then
					applyToggleKeybindBinding(canonical, steps, false)
				end
			end
		}
		self.RayfieldLibrary.Flags[toggleKeybindSettings.Flag] = toggleKeybindFlagProxy
	end
	
	if not ToggleSettings.Ext then
		if Settings.ConfigurationSaving then
			if Settings.ConfigurationSaving.Enabled and ToggleSettings.Flag then
				self.RayfieldLibrary.Flags[ToggleSettings.Flag] = ToggleSettings
			end
		end
	end
	
	
	self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
		Toggle.Switch.BackgroundColor3 = self.getSelectedTheme().ToggleBackground

		if toggleKeybindFrame then
			toggleKeybindFrame.BackgroundColor3 = self.getSelectedTheme().InputBackground
			local frameStroke = toggleKeybindFrame:FindFirstChildWhichIsA("UIStroke")
			if frameStroke then
				frameStroke.Color = self.getSelectedTheme().InputStroke
			end
		end
	
		if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
			local toggleShadow = Toggle.Switch:FindFirstChild("Shadow")
			if toggleShadow then
				toggleShadow.Visible = false
			end
		end
	
		task.wait()
	
		if not ToggleSettings.CurrentValue then
			Toggle.Switch.Indicator.UIStroke.Color = self.getSelectedTheme().ToggleDisabledStroke
			Toggle.Switch.Indicator.BackgroundColor3 = self.getSelectedTheme().ToggleDisabled
			Toggle.Switch.UIStroke.Color = self.getSelectedTheme().ToggleDisabledOuterStroke
		else
			Toggle.Switch.Indicator.UIStroke.Color = self.getSelectedTheme().ToggleEnabledStroke
			Toggle.Switch.Indicator.BackgroundColor3 = self.getSelectedTheme().ToggleEnabled
			Toggle.Switch.UIStroke.Color = self.getSelectedTheme().ToggleEnabledOuterStroke
		end
	end)
	
	function ToggleSettings:Destroy()
		if toggleKeybindConnection then
			toggleKeybindConnection:Disconnect()
			toggleKeybindConnection = nil
		end
		if toggleKeybindSettings.Flag and ctx.RayfieldLibrary and ctx.RayfieldLibrary.Flags then
			if ctx.RayfieldLibrary.Flags[toggleKeybindSettings.Flag] == toggleKeybindFlagProxy then
				ctx.RayfieldLibrary.Flags[toggleKeybindSettings.Flag] = nil
			end
		end
		Toggle:Destroy()
	end
	
	-- Add extended API
	addExtendedAPI(ToggleSettings, ToggleSettings.Name, "Toggle", Toggle, toggleHoverBindingKey, toggleSyncToken)
	local cleanupScopeId = ToggleSettings.GetCleanupScope and ToggleSettings:GetCleanupScope() or ToggleSettings.__CleanupScope
	if cleanupScopeId and toggleKeybindConnection then
		ownershipTrackConnection(toggleKeybindConnection, cleanupScopeId)
		ownershipTrackCleanup(removeToggleKeybindConnectionFromGlobalList, cleanupScopeId)
	end
	
	return ToggleSettings
end

return ToggleFactory


