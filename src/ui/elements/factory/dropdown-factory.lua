local DropdownFactory = {}

function DropdownFactory.create(context)
	context = context or {}
	local Tab = context.Tab
	local TabPage = context.TabPage
	local Settings = context.Settings or {}
	local addExtendedAPI = context.addExtendedAPI
	local registerHoverBinding = context.registerHoverBinding
	local registerElementSync = context.registerElementSync
	local commitElementSync = context.commitElementSync
	local emitUICue = context.emitUICue or function() end
	local DropdownSettings = context.settings

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
				local Dropdown = self.Elements.Template.Dropdown:Clone()
				local dropdownAnimatedOptionLimit = 24
				if type(self.getSetting) == "function" then
					local okLimit, configuredLimit = pcall(self.getSetting, "Performance", "dropdownAnimatedOptionLimit")
					if okLimit and type(configuredLimit) == "number" then
						dropdownAnimatedOptionLimit = math.clamp(math.floor(configuredLimit), 4, 128)
					end
				end
				if self.useMobileSizing then
					dropdownAnimatedOptionLimit = math.min(dropdownAnimatedOptionLimit, 12)
				end
				local function normalizeDropdownOptions(rawOptions)
					local normalized = {}
					if type(rawOptions) ~= "table" then
						if rawOptions ~= nil then
							table.insert(normalized, tostring(rawOptions))
						end
						return normalized
					end
					if #rawOptions > 0 then
						for _, option in ipairs(rawOptions) do
							if option ~= nil then
								table.insert(normalized, tostring(option))
							end
						end
						return normalized
					end
					for _, option in pairs(rawOptions) do
						if option ~= nil then
							table.insert(normalized, tostring(option))
						end
					end
					return normalized
				end

				DropdownSettings.Options = normalizeDropdownOptions(DropdownSettings.Options)
				DropdownSettings.ClearBehavior = tostring(DropdownSettings.ClearBehavior or DropdownSettings.SelectionFallback or "default"):lower()
				if DropdownSettings.ClearBehavior ~= "default" and DropdownSettings.ClearBehavior ~= "none" then
					DropdownSettings.ClearBehavior = "default"
				end
				DropdownSettings.SearchEnabled = DropdownSettings.SearchEnabled == true
				DropdownSettings.SearchPlaceholder = tostring(DropdownSettings.SearchPlaceholder or "Search...")
				DropdownSettings.ResetSearchOnRefresh = DropdownSettings.ResetSearchOnRefresh ~= false
				if type(DropdownSettings.Callback) ~= "function" then
					DropdownSettings.Callback = function() end
				end

				local function containsDropdownOption(optionName)
					for _, option in ipairs(DropdownSettings.Options) do
						if option == optionName then
							return true
						end
					end
					return false
				end

				local function toSelectionArray(rawSelection)
					local normalized = {}
					if rawSelection == nil then
						return normalized
					end

					if type(rawSelection) == "string" then
						table.insert(normalized, rawSelection)
						return normalized
					end

					if type(rawSelection) ~= "table" then
						table.insert(normalized, tostring(rawSelection))
						return normalized
					end

					if #rawSelection > 0 then
						for _, option in ipairs(rawSelection) do
							if option ~= nil then
								table.insert(normalized, tostring(option))
							end
						end
					else
						for _, option in pairs(rawSelection) do
							if option ~= nil then
								table.insert(normalized, tostring(option))
							end
						end
					end

					return normalized
				end

				local function cloneSelection(selection)
					local cloned = {}
					if type(selection) ~= "table" then
						return cloned
					end
					for _, option in ipairs(selection) do
						table.insert(cloned, option)
					end
					return cloned
				end

				local function selectionEquals(leftSelection, rightSelection)
					if type(leftSelection) ~= "table" or type(rightSelection) ~= "table" then
						return false
					end
					if #leftSelection ~= #rightSelection then
						return false
					end
					for index, value in ipairs(leftSelection) do
						if rightSelection[index] ~= value then
							return false
						end
					end
					return true
				end

				local function getDefaultSelection()
					local defaultRaw = DropdownSettings.DefaultSelection
					if defaultRaw == nil then
						defaultRaw = DropdownSettings.DefaultOption
					end

					local defaults = {}
					for _, optionName in ipairs(toSelectionArray(defaultRaw)) do
						if containsDropdownOption(optionName) then
							table.insert(defaults, optionName)
						end
					end

					if not DropdownSettings.MultipleOptions then
						if defaults[1] then
							return { defaults[1] }
						end
						return {}
					end

					return defaults
				end

				local function normalizeSelection(rawSelection, allowDefaultFallback)
					local normalized = {}
					local dedupe = {}

					for _, optionName in ipairs(toSelectionArray(rawSelection)) do
						if containsDropdownOption(optionName) and not dedupe[optionName] then
							dedupe[optionName] = true
							table.insert(normalized, optionName)
						end
					end

					if not DropdownSettings.MultipleOptions and #normalized > 1 then
						normalized = { normalized[1] }
					end

					local fallbackApplied = false
					if allowDefaultFallback and #normalized == 0 and DropdownSettings.ClearBehavior ~= "none" then
						local fallback = getDefaultSelection()
						if #fallback > 0 then
							normalized = fallback
							fallbackApplied = true
						end
					end

					return normalized, fallbackApplied
				end

				local function updateSelectedText()
					if DropdownSettings.MultipleOptions then
						if #DropdownSettings.CurrentOption == 1 then
							Dropdown.Selected.Text = DropdownSettings.CurrentOption[1]
						elseif #DropdownSettings.CurrentOption == 0 then
							Dropdown.Selected.Text = "None"
						else
							Dropdown.Selected.Text = "Various"
						end
					else
						Dropdown.Selected.Text = DropdownSettings.CurrentOption[1] or "None"
					end
				end

				local function updateOptionVisuals(animated)
					local processed = 0
					for _, droption in ipairs(Dropdown.List:GetChildren()) do
						if droption.ClassName == "Frame" and droption.Name ~= "Placeholder" and droption.Name ~= "Template" then
							processed += 1
							local targetColor = table.find(DropdownSettings.CurrentOption, droption.Name) and self.getSelectedTheme().DropdownSelected or self.getSelectedTheme().DropdownUnselected
							if animated and processed <= dropdownAnimatedOptionLimit then
								self.Animation:Create(droption, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundColor3 = targetColor}):Play()
							else
								droption.BackgroundColor3 = targetColor
							end
						end
					end
				end

				local function handleSelectionCallbackError(response)
					emitUICue("error")
					self.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					self.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
					Dropdown.Title.Text = "Callback Error"
					print("Rayfield | "..DropdownSettings.Name.." Callback Error " ..tostring(response))
					warn('Check docs.sirius.menu for help with Rayfield specific development.')
					task.wait(0.5)
					Dropdown.Title.Text = DropdownSettings.Name
					self.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					self.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				end

				local function emitSelectionNormalized(reason, fallbackApplied, changed)
					if type(DropdownSettings.OnSelectionNormalized) == "function" then
						local okMeta, metaErr = pcall(DropdownSettings.OnSelectionNormalized, DropdownSettings.CurrentOption, {
							reason = reason,
							fallbackApplied = fallbackApplied,
							changed = changed
						})
						if not okMeta then
							warn("Rayfield | Dropdown OnSelectionNormalized Error " .. tostring(metaErr))
						end
					end
				end

				local dropdownSyncToken = registerElementSync({
					name = DropdownSettings.Name,
					getState = function()
						return cloneSelection(DropdownSettings.CurrentOption)
					end,
					normalize = function(rawSelection, syncMeta)
						local options = (syncMeta and syncMeta.options) or {}
						local normalizedSelection, fallbackApplied = normalizeSelection(rawSelection, options.allowDefaultFallback ~= false)
						return normalizedSelection, {
							changed = not selectionEquals(DropdownSettings.CurrentOption, normalizedSelection),
							fallbackApplied = fallbackApplied
						}
					end,
					applyVisual = function(normalizedSelection, syncMeta)
						DropdownSettings.CurrentOption = cloneSelection(normalizedSelection)
						local animated = syncMeta and syncMeta.options and syncMeta.options.animatedVisuals == true
						updateSelectedText()
						updateOptionVisuals(animated)
						emitSelectionNormalized(
							(syncMeta and syncMeta.reason) or "unknown",
							syncMeta and syncMeta.fallbackApplied == true,
							syncMeta and syncMeta.changed == true
						)
					end,
					emitCallback = function(normalizedSelection)
						DropdownSettings.Callback(cloneSelection(normalizedSelection))
					end,
					persist = function()
						self.SaveConfiguration()
					end,
					isExt = function()
						return DropdownSettings.Ext == true
					end,
					isAlive = function()
						return Dropdown ~= nil and Dropdown.Parent ~= nil
					end,
					isVisibleContext = function()
						return Dropdown.Visible and Dropdown:IsDescendantOf(TabPage) and self.Elements.UIPageLayout.CurrentPage == TabPage
					end,
					onCallbackError = handleSelectionCallbackError
				})

				local function commitSelection(rawSelection, commitOptions)
					local options = commitOptions or {}
					if dropdownSyncToken then
						local callbackOk, result = commitElementSync(dropdownSyncToken, rawSelection, {
							reason = options.reason or "selection_update",
							source = options.source or "unknown",
							emitCallback = options.emitCallback,
							persist = options.persist,
							forceCallback = options.forceCallback,
							allowDefaultFallback = options.allowDefaultFallback,
							animatedVisuals = options.animatedVisuals
						})
						if type(result) == "table" then
							return result.changed == true, result.fallbackApplied == true, callbackOk
						end
						-- Fail-safe: if element-sync pipeline is unavailable, keep dropdown state/visual consistent locally.
					end

					local previousSelection = cloneSelection(DropdownSettings.CurrentOption)
					local normalizedSelection, fallbackApplied = normalizeSelection(rawSelection, options.allowDefaultFallback ~= false)
					DropdownSettings.CurrentOption = normalizedSelection
					local changed = not selectionEquals(previousSelection, normalizedSelection)
					updateSelectedText()
					updateOptionVisuals(options.animatedVisuals == true)
					emitSelectionNormalized(options.reason or "unknown", fallbackApplied, changed)

					local callbackSuccess, response = pcall(function()
						DropdownSettings.Callback(DropdownSettings.CurrentOption)
					end)
					if not callbackSuccess then
						handleSelectionCallbackError(response)
					elseif not DropdownSettings.Ext and options.persist ~= false then
						self.SaveConfiguration()
					end
					return changed, fallbackApplied, callbackSuccess
				end
				if string.find(DropdownSettings.Name,"closed") then
					Dropdown.Name = "Dropdown"
				else
					Dropdown.Name = DropdownSettings.Name
				end
				Dropdown.Title.Text = DropdownSettings.Name
				Dropdown.Visible = true
				Dropdown.Parent = TabPage
	
				Dropdown.Size = UDim2.new(1, -10, 0, 45)
				Dropdown.List.Visible = false
				Dropdown.List.ScrollBarImageTransparency = 1
				local searchQuery = ""
				local searchFrame = nil
				local searchBox = nil
				local initialSelection = DropdownSettings.CurrentOption
				DropdownSettings.CurrentOption = {}
				commitSelection(initialSelection, {
					emitCallback = false,
					persist = false,
					forceCallback = false,
					reason = "initial"
				})

				self.bindTheme(Dropdown.Toggle, "ImageColor3", "TextColor")

				local dropdownThemeConnection = nil

				local function forEachDropdownOption(callback)
					for _, optionObject in ipairs(Dropdown.List:GetChildren()) do
						if optionObject.ClassName == "Frame" and optionObject.Name ~= "Placeholder" and optionObject.Name ~= "Template" then
							callback(optionObject)
						end
					end
				end

				local function optionMatchesSearch(optionName)
					if not DropdownSettings.SearchEnabled then
						return true
					end
					local needle = string.lower(tostring(searchQuery or ""))
					if needle == "" then
						return true
					end
					return string.find(string.lower(tostring(optionName or "")), needle, 1, true) ~= nil
				end

				local function applyDropdownOptionThemeColors(animated)
					local theme = self.getSelectedTheme()
					forEachDropdownOption(function(droption)
						local isSelected = table.find(DropdownSettings.CurrentOption, droption.Name) ~= nil
						local targetColor = isSelected and theme.DropdownSelected or theme.DropdownUnselected
						if animated then
							self.Animation:Create(droption, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {BackgroundColor3 = targetColor}):Play()
						else
							droption.BackgroundColor3 = targetColor
						end
						if droption:FindFirstChild("UIStroke") then
							droption.UIStroke.Color = theme.ElementStroke
						end
					end)
				end

				local function animateDropdownOptionVisibility(showOptions)
					local processed = 0
					forEachDropdownOption(function(droption)
						if not droption.Visible then
							return
						end
						processed += 1
						local animateOption = processed <= dropdownAnimatedOptionLimit
						local stroke = droption:FindFirstChild("UIStroke")
						local title = droption:FindFirstChild("Title")
						local targetBackgroundTransparency = showOptions and 0 or 1
						local targetStrokeTransparency = showOptions and 0 or 1
						local targetTitleTransparency = showOptions and 0 or 1
						if showOptions and droption.Name == Dropdown.Selected.Text then
							targetStrokeTransparency = 1
						end

						if animateOption then
							self.Animation:Create(droption, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = targetBackgroundTransparency}):Play()
							if stroke then
								self.Animation:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = targetStrokeTransparency}):Play()
							end
							if title then
								self.Animation:Create(title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = targetTitleTransparency}):Play()
							end
						else
							droption.BackgroundTransparency = targetBackgroundTransparency
							if stroke then
								stroke.Transparency = targetStrokeTransparency
							end
							if title then
								title.TextTransparency = targetTitleTransparency
							end
						end
					end)
				end

				local function getVisibleOptionCount()
					local count = 0
					forEachDropdownOption(function(droption)
						if droption.Visible ~= false then
							count += 1
						end
					end)
					return count
				end

				local function applySearchFilter()
					forEachDropdownOption(function(droption)
						droption.Visible = optionMatchesSearch(droption.Name)
					end)
					if Dropdown.List.Visible then
						animateDropdownOptionVisibility(true)
						local visibleCount = getVisibleOptionCount()
						local targetHeight = math.clamp((visibleCount * 30) + (DropdownSettings.SearchEnabled and 70 or 45), 90, 220)
						self.Animation:Create(Dropdown, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, targetHeight)}):Play()
					end
				end
	
				Dropdown.Toggle.Rotation = 180

				if DropdownSettings.SearchEnabled then
					searchFrame = Instance.new("Frame")
					searchFrame.Name = "SearchFrame"
					searchFrame.BackgroundColor3 = self.getSelectedTheme().InputBackground
					searchFrame.BorderSizePixel = 0
					searchFrame.Position = UDim2.new(0, 6, 0, 44)
					searchFrame.Size = UDim2.new(1, -12, 0, 22)
					searchFrame.Visible = false
					searchFrame.Parent = Dropdown

					local searchCorner = Instance.new("UICorner")
					searchCorner.CornerRadius = UDim.new(0, 5)
					searchCorner.Parent = searchFrame

					local searchStroke = Instance.new("UIStroke")
					searchStroke.Color = self.getSelectedTheme().InputStroke
					searchStroke.Transparency = 0.2
					searchStroke.Parent = searchFrame

					searchBox = Instance.new("TextBox")
					searchBox.Name = "SearchBox"
					searchBox.BackgroundTransparency = 1
					searchBox.ClearTextOnFocus = false
					searchBox.Size = UDim2.new(1, -10, 1, 0)
					searchBox.Position = UDim2.new(0, 6, 0, 0)
					searchBox.TextXAlignment = Enum.TextXAlignment.Left
					searchBox.Font = Enum.Font.Gotham
					searchBox.TextSize = 12
					searchBox.PlaceholderText = DropdownSettings.SearchPlaceholder
					searchBox.TextColor3 = self.getSelectedTheme().TextColor
					searchBox.PlaceholderColor3 = self.getSelectedTheme().PlaceholderColor or self.getSelectedTheme().TextColor
					searchBox.Text = ""
					searchBox.Parent = searchFrame

					searchBox:GetPropertyChangedSignal("Text"):Connect(function()
						searchQuery = tostring(searchBox.Text or "")
						applySearchFilter()
					end)
				end

				Dropdown.Interact.MouseButton1Click:Connect(function()
					emitUICue("click")
					self.Animation:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
					self.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
					task.wait(0.1)
					self.Animation:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					self.Animation:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					if self.getDebounce() then return end
					if Dropdown.List.Visible then
						self.setDebounce(true)
						if searchFrame then
							searchFrame.Visible = false
						end
						self.Animation:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 45)}):Play()
						animateDropdownOptionVisibility(false)
						self.Animation:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ScrollBarImageTransparency = 1}):Play()
						self.Animation:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Rotation = 180}):Play()
						task.wait(0.35)
						Dropdown.List.Visible = false
						self.setDebounce(false)
					else
						local visibleCount = math.max(1, getVisibleOptionCount())
						local targetHeight = math.clamp((visibleCount * 30) + (DropdownSettings.SearchEnabled and 70 or 45), 90, 220)
						self.Animation:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, targetHeight)}):Play()
						Dropdown.List.Visible = true
						if searchFrame then
							searchFrame.Visible = true
						end
						self.Animation:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ScrollBarImageTransparency = 0.7}):Play()
						self.Animation:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Rotation = 0}):Play()	
						animateDropdownOptionVisibility(true)
					end
				end)
	
				local dropdownHoverBindingKey = registerHoverBinding(Dropdown,
					function()
						if not Dropdown.List.Visible then
							self.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
						end
					end,
					function()
						self.Animation:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					end
				)
	
				local function SetDropdownOptions()
					local listTemplate = Dropdown.List:FindFirstChild("Template")
					if not listTemplate then
						warn("Rayfield | Dropdown template not found for " .. tostring(DropdownSettings.Name))
						return
					end

					for _, optionObject in ipairs(Dropdown.List:GetChildren()) do
						if optionObject.ClassName == "Frame" and optionObject.Name ~= "Placeholder" and optionObject.Name ~= "Template" then
							optionObject:Destroy()
						end
					end

					for _, Option in ipairs(DropdownSettings.Options) do
						local optionName = tostring(Option)
						local DropdownOption = listTemplate:Clone()
						DropdownOption.Name = optionName
						DropdownOption.Title.Text = optionName
						DropdownOption.Parent = Dropdown.List
						DropdownOption.Visible = true
	
						DropdownOption.BackgroundTransparency = 1
						DropdownOption.UIStroke.Transparency = 1
						DropdownOption.Title.TextTransparency = 1
	
						--local Dropdown = Tab:CreateDropdown({
						--	Name = "Dropdown Example",
						--	Options = {"Option 1","Option 2"},
						--	CurrentOption = {"Option 1"},
						--  MultipleOptions = true,
						--	Flag = "Dropdown1",
						--	Callback = function(TableOfOptions)
	
						--	end,
						--})
	
	
						DropdownOption.Interact.ZIndex = 50
						DropdownOption.Interact.MouseButton1Click:Connect(function()
							emitUICue("click")
							local nextSelection = cloneSelection(DropdownSettings.CurrentOption)
							local selectedIndex = table.find(nextSelection, optionName)
							local wasSelected = selectedIndex ~= nil

							if not DropdownSettings.MultipleOptions and wasSelected then 
								return
							end

							if selectedIndex then
								table.remove(nextSelection, selectedIndex)
							else
								if not DropdownSettings.MultipleOptions then
									table.clear(nextSelection)
								end
								table.insert(nextSelection, optionName)
								self.Animation:Create(DropdownOption.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
								self.Animation:Create(DropdownOption, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().DropdownSelected}):Play()
								self.setDebounce(true)
							end

							local _, _, callbackOk = commitSelection(nextSelection, {
								emitCallback = true,
								persist = true,
								forceCallback = true,
								reason = "option_click",
								animatedVisuals = true
							})
							if callbackOk == true then
								emitUICue("success")
							end

							if not DropdownSettings.MultipleOptions then
								task.wait(0.1)
								if searchFrame then
									searchFrame.Visible = false
								end
								self.Animation:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 45)}):Play()
								animateDropdownOptionVisibility(false)
								self.Animation:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ScrollBarImageTransparency = 1}):Play()
								self.Animation:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Rotation = 180}):Play()
								task.wait(0.35)
								Dropdown.List.Visible = false
							end
							self.setDebounce(false)
						end)

						DropdownOption.Visible = optionMatchesSearch(optionName)

						DropdownOption.BackgroundColor3 = self.getSelectedTheme().DropdownUnselected
						DropdownOption.UIStroke.Color = self.getSelectedTheme().ElementStroke
					end
				end
				SetDropdownOptions()
				applySearchFilter()
				applyDropdownOptionThemeColors(false)

				dropdownThemeConnection = self.Rayfield.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
					if not Dropdown or not Dropdown.Parent then
						if dropdownThemeConnection then
							dropdownThemeConnection:Disconnect()
							dropdownThemeConnection = nil
						end
						return
					end
					Dropdown.Toggle.ImageColor3 = self.getSelectedTheme().TextColor
					if not Dropdown.List.Visible then
						Dropdown.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					end
					if searchFrame then
						searchFrame.BackgroundColor3 = self.getSelectedTheme().InputBackground
						local searchStroke = searchFrame:FindFirstChildOfClass("UIStroke")
						if searchStroke then
							searchStroke.Color = self.getSelectedTheme().InputStroke
						end
						if searchBox then
							searchBox.TextColor3 = self.getSelectedTheme().TextColor
							searchBox.PlaceholderColor3 = self.getSelectedTheme().PlaceholderColor or self.getSelectedTheme().TextColor
						end
					end
					applyDropdownOptionThemeColors(false)
				end)
	
				function DropdownSettings:Set(NewOption)
					commitSelection(NewOption, {
						emitCallback = true,
						persist = true,
						forceCallback = true,
						reason = "set",
						animatedVisuals = false
					})
				end
	
				function DropdownSettings:Refresh(optionsTable) -- updates a dropdown with new options from optionsTable
					DropdownSettings.Options = normalizeDropdownOptions(optionsTable)
					if DropdownSettings.SearchEnabled and DropdownSettings.ResetSearchOnRefresh then
						searchQuery = ""
						if searchBox then
							searchBox.Text = ""
						end
					end
					for _, option in Dropdown.List:GetChildren() do
						if option.ClassName == "Frame" and option.Name ~= "Placeholder" and option.Name ~= "Template" then
							option:Destroy()
						end
					end
					Dropdown.List.Visible = false
					Dropdown.Size = UDim2.new(1, -10, 0, 45)
					Dropdown.Toggle.Rotation = 180
					Dropdown.List.ScrollBarImageTransparency = 1
					SetDropdownOptions()
					applySearchFilter()
					commitSelection(DropdownSettings.CurrentOption, {
						emitCallback = true,
						persist = true,
						forceCallback = false,
						reason = "refresh",
						animatedVisuals = false
					})
				end
	
				function DropdownSettings:Clear()
					commitSelection({}, {
						emitCallback = true,
						persist = true,
						forceCallback = true,
						reason = "clear",
						allowDefaultFallback = true,
						animatedVisuals = false
					})
				end

				function DropdownSettings:SetSearchQuery(text)
					if not DropdownSettings.SearchEnabled then
						return false
					end
					searchQuery = tostring(text or "")
					if searchBox then
						searchBox.Text = searchQuery
					end
					applySearchFilter()
					return true
				end

				function DropdownSettings:GetSearchQuery()
					if not DropdownSettings.SearchEnabled then
						return ""
					end
					return tostring(searchQuery or "")
				end

				function DropdownSettings:ClearSearch()
					if not DropdownSettings.SearchEnabled then
						return false
					end
					searchQuery = ""
					if searchBox then
						searchBox.Text = ""
					end
					applySearchFilter()
					return true
				end

				function DropdownSettings:Destroy()
					if dropdownThemeConnection then
						dropdownThemeConnection:Disconnect()
						dropdownThemeConnection = nil
					end
					Dropdown:Destroy()
				end

				-- Add extended API
				addExtendedAPI(DropdownSettings, DropdownSettings.Name, "Dropdown", Dropdown, dropdownHoverBindingKey, dropdownSyncToken)
	
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and DropdownSettings.Flag then
						self.RayfieldLibrary.Flags[DropdownSettings.Flag] = DropdownSettings
					end
				end
	
				return DropdownSettings
end

return DropdownFactory
