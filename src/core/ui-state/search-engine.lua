local SearchEngine = {}

function SearchEngine.create(ctx)
	ctx = type(ctx) == "table" and ctx or {}

	local manager = {}
	local Main = ctx.Main
	local Animation = ctx.Animation
	local UserInputService = ctx.UserInputService
	local onCommandPaletteQuery = type(ctx.onCommandPaletteQuery) == "function" and ctx.onCommandPaletteQuery or function()
		return {}
	end
	local onCommandPaletteSelect = type(ctx.onCommandPaletteSelect) == "function" and ctx.onCommandPaletteSelect or function()
		return false, "Command palette action unavailable."
	end
	local localize = type(ctx.localize) == "function" and ctx.localize or function(_, fallback)
		return tostring(fallback or "")
	end
	local notify = type(ctx.notify) == "function" and ctx.notify or function() end
	local animateTabButtonsHidden = type(ctx.animateTabButtonsHidden) == "function" and ctx.animateTabButtonsHidden or function() end
	local animateTabButtonsByCurrentPage = type(ctx.animateTabButtonsByCurrentPage) == "function" and ctx.animateTabButtonsByCurrentPage or function() end
	local getThemeValueOrDefault = type(ctx.getThemeValueOrDefault) == "function" and ctx.getThemeValueOrDefault or function(_, fallback)
		return fallback
	end
	local playTween = type(ctx.playTween) == "function" and ctx.playTween or function(instance, tweenInfo, properties)
		if instance and Animation then
			Animation:Create(instance, tweenInfo, properties):Play()
		end
	end

	local searchOpen = false
	local commandPaletteOpen = false
	local commandPaletteSelectionIndex = 1
	local commandPaletteResults = {}
	local commandPaletteConnections = {}
	local commandPaletteRefs = {}
	local commandPaletteKeybind = tostring(type(_G) == "table" and _G.__RAYFIELD_COMMAND_PALETTE_KEY or "LeftControl+K")

	local function L(key, fallback)
		local okValue, value = pcall(localize, key, fallback)
		if okValue and type(value) == "string" and value ~= "" then
			return value
		end
		return tostring(fallback or key or "")
	end

	local function disconnectConnections(store)
		if type(store) ~= "table" then
			return
		end
		for index = #store, 1, -1 do
			local connection = store[index]
			if connection then
				pcall(function()
					connection:Disconnect()
				end)
			end
			store[index] = nil
		end
	end

	local function parsePaletteKeybind(binding)
		local tokens = {}
		for token in tostring(binding or ""):gmatch("[^%+]+") do
			local trimmed = token:gsub("^%s+", ""):gsub("%s+$", "")
			if trimmed ~= "" then
				table.insert(tokens, trimmed)
			end
		end

		local spec = {
			key = Enum.KeyCode.K,
			ctrl = false,
			shift = false,
			alt = false
		}

		for _, rawToken in ipairs(tokens) do
			local tokenLower = string.lower(rawToken)
			if tokenLower == "leftcontrol" or tokenLower == "rightcontrol" or tokenLower == "ctrl" or tokenLower == "control" then
				spec.ctrl = true
			elseif tokenLower == "leftshift" or tokenLower == "rightshift" or tokenLower == "shift" then
				spec.shift = true
			elseif tokenLower == "leftalt" or tokenLower == "rightalt" or tokenLower == "alt" then
				spec.alt = true
			else
				local enumKey = Enum.KeyCode[rawToken]
				if enumKey then
					spec.key = enumKey
				else
					local upperKey = Enum.KeyCode[string.upper(rawToken)]
					if upperKey then
						spec.key = upperKey
					end
				end
			end
		end
		return spec
	end

	local paletteKeySpec = parsePaletteKeybind(commandPaletteKeybind)

	local function isModifierDown(modifierName)
		if not UserInputService then
			return false
		end
		if modifierName == "ctrl" then
			return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		elseif modifierName == "shift" then
			return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		elseif modifierName == "alt" then
			return UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
		end
		return false
	end

	local function isPaletteKeyMatch(input)
		if not input or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return false
		end
		if input.KeyCode ~= paletteKeySpec.key then
			return false
		end
		if paletteKeySpec.ctrl and not isModifierDown("ctrl") then
			return false
		end
		if paletteKeySpec.shift and not isModifierDown("shift") then
			return false
		end
		if paletteKeySpec.alt and not isModifierDown("alt") then
			return false
		end
		return true
	end

	local function ensureCommandPaletteOverlay()
		if commandPaletteRefs.Overlay and commandPaletteRefs.Overlay.Parent then
			return commandPaletteRefs
		end
		if not Main then
			return commandPaletteRefs
		end

		local overlay = Instance.new("Frame")
		overlay.Name = "CommandPaletteOverlay"
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.42
		overlay.BorderSizePixel = 0
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.Visible = false
		overlay.ZIndex = 60
		overlay.Parent = Main

		local card = Instance.new("Frame")
		card.Name = "Card"
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, 54)
		card.Size = UDim2.new(0, 430, 0, 300)
		card.BackgroundTransparency = 0.06
		card.BorderSizePixel = 0
		card.ZIndex = 61
		card.Parent = overlay

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Thickness = 1
		cardStroke.Transparency = 0.2
		cardStroke.Parent = card

		local input = Instance.new("TextBox")
		input.Name = "Input"
		input.BackgroundTransparency = 0.1
		input.BorderSizePixel = 0
		input.Position = UDim2.new(0, 10, 0, 10)
		input.Size = UDim2.new(1, -20, 0, 34)
		input.Text = ""
		input.PlaceholderText = L("command_palette.placeholder", "Type command or control name...")
		input.Font = Enum.Font.Gotham
		input.TextSize = 14
		input.ClearTextOnFocus = false
		input.TextXAlignment = Enum.TextXAlignment.Left
		input.ZIndex = 62
		input.Parent = card

		local inputCorner = Instance.new("UICorner")
		inputCorner.CornerRadius = UDim.new(0, 7)
		inputCorner.Parent = input

		local resultList = Instance.new("ScrollingFrame")
		resultList.Name = "Results"
		resultList.BackgroundTransparency = 1
		resultList.Position = UDim2.new(0, 10, 0, 50)
		resultList.Size = UDim2.new(1, -20, 1, -60)
		resultList.BorderSizePixel = 0
		resultList.ScrollBarThickness = 4
		resultList.CanvasSize = UDim2.fromOffset(0, 0)
		resultList.ZIndex = 62
		resultList.Parent = card

		local resultLayout = Instance.new("UIListLayout")
		resultLayout.Padding = UDim.new(0, 4)
		resultLayout.Parent = resultList

		commandPaletteRefs = {
			Overlay = overlay,
			Card = card,
			CardStroke = cardStroke,
			Input = input,
			Results = resultList,
			ResultsLayout = resultLayout
		}
		return commandPaletteRefs
	end

	local function renderCommandPaletteResults()
		local refs = ensureCommandPaletteOverlay()
		if not refs.Results then
			return
		end
		for _, child in ipairs(refs.Results:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		if commandPaletteSelectionIndex < 1 then
			commandPaletteSelectionIndex = 1
		end
		if commandPaletteSelectionIndex > #commandPaletteResults then
			commandPaletteSelectionIndex = #commandPaletteResults
		end

		for index, item in ipairs(commandPaletteResults) do
			local marker = item.suggested == true and "[Suggested] " or ""
			local typeName = tostring(item.type or "command")
			local subtitle = tostring(item.description or item.tabId or "")
			local shortcuts = tostring(item.shortcuts or "Enter auto | Shift+Enter execute | Alt+Enter ask")
			local usageSuffix = tonumber(item.usageCount) and tonumber(item.usageCount) > 0 and (" x" .. tostring(item.usageCount)) or ""
			local row = Instance.new("TextButton")
			row.Name = "Result" .. tostring(index)
			row.Size = UDim2.new(1, -2, 0, 48)
			row.BackgroundTransparency = commandPaletteSelectionIndex == index and 0.05 or 0.35
			row.BorderSizePixel = 0
			row.AutoButtonColor = true
			row.Font = Enum.Font.Gotham
			row.TextSize = 11
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextYAlignment = Enum.TextYAlignment.Top
			row.TextWrapped = true
			row.Text = string.format(
				"  %s%s [%s%s]\n  %s | %s",
				marker,
				tostring(item.name or item.title or "Unnamed"),
				typeName,
				usageSuffix,
				subtitle,
				shortcuts
			)
			row.ZIndex = 63
			row.Parent = refs.Results

			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 6)
			rowCorner.Parent = row

			row.MouseButton1Click:Connect(function()
				local okAction, message, meta = onCommandPaletteSelect(item, nil, {
					trigger = "mouse"
				})
				if not okAction then
					notify({
						Title = L("command_palette.title", "Command Palette"),
						Content = tostring(message or "Command failed."),
						Duration = 3,
						Image = 4384402990
					})
				end
				if not (type(meta) == "table" and meta.keepPaletteOpen == true) then
					manager.closeCommandPalette()
				end
			end)
		end

		local listHeight = refs.ResultsLayout.AbsoluteContentSize.Y
		refs.Results.CanvasSize = UDim2.fromOffset(0, math.max(listHeight + 4, refs.Results.AbsoluteSize.Y))

		local bg = getThemeValueOrDefault("Background", Color3.fromRGB(24, 24, 28))
		local textColor = getThemeValueOrDefault("TextColor", Color3.fromRGB(255, 255, 255))
		refs.Card.BackgroundColor3 = bg
		refs.Input.BackgroundColor3 = getThemeValueOrDefault("InputBackground", Color3.fromRGB(40, 40, 45))
		refs.Input.TextColor3 = textColor
		refs.Input.PlaceholderColor3 = textColor:Lerp(Color3.fromRGB(80, 80, 80), 0.55)
		if refs.CardStroke then
			refs.CardStroke.Color = getThemeValueOrDefault("ElementStroke", Color3.fromRGB(95, 95, 100))
		end
		for _, child in ipairs(refs.Results:GetChildren()) do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = getThemeValueOrDefault("ElementBackground", Color3.fromRGB(35, 35, 40))
				child.TextColor3 = textColor
			end
		end
	end

	local function scorePaletteItem(item, queryLower)
		if type(item) == "table" and tonumber(item.matchScore) then
			return tonumber(item.matchScore)
		end
		local text = string.lower(tostring(item.searchText or item.name or item.title or ""))
		if queryLower == "" then
			return tonumber(item.score) or 0
		end
		if text:sub(1, #queryLower) == queryLower then
			return 200
		end
		if string.find(text, queryLower, 1, true) then
			return 100
		end
		return tonumber(item.score) or 0
	end

	local function refreshCommandPaletteQuery()
		local refs = ensureCommandPaletteOverlay()
		if not refs.Input then
			return
		end
		local query = tostring(refs.Input.Text or "")
		local results = onCommandPaletteQuery(query)
		if type(results) ~= "table" then
			results = {}
		end
		local queryLower = string.lower(query)
		table.sort(results, function(a, b)
			local scoreA = scorePaletteItem(a, queryLower)
			local scoreB = scorePaletteItem(b, queryLower)
			if scoreA ~= scoreB then
				return scoreA > scoreB
			end
			if (a.suggested == true) ~= (b.suggested == true) then
				return a.suggested == true
			end
			local tabA = string.lower(tostring(a.tabId or ""))
			local tabB = string.lower(tostring(b.tabId or ""))
			if tabA ~= tabB then
				return tabA < tabB
			end
			local nameA = string.lower(tostring(a.name or a.title or ""))
			local nameB = string.lower(tostring(b.name or b.title or ""))
			if nameA ~= nameB then
				return nameA < nameB
			end
			local idA = string.lower(tostring(a.id or ""))
			local idB = string.lower(tostring(b.id or ""))
			if idA ~= idB then
				return idA < idB
			end
			return false
		end)
		commandPaletteResults = results
		commandPaletteSelectionIndex = #commandPaletteResults > 0 and 1 or 0
		renderCommandPaletteResults()
	end

	local function bindCommandPaletteUiSignals()
		local refs = ensureCommandPaletteOverlay()
		if not refs.Input then
			return
		end
		table.insert(commandPaletteConnections, refs.Input:GetPropertyChangedSignal("Text"):Connect(function()
			if commandPaletteOpen then
				refreshCommandPaletteQuery()
			end
		end))
		table.insert(commandPaletteConnections, refs.Input.FocusLost:Connect(function()
			if not commandPaletteOpen then
				return
			end
			task.delay(0.05, function()
				if commandPaletteOpen and refs.Input and (refs.Input.Text == "" or refs.Input:IsFocused() == false) then
					-- Keep palette open when user clicks result list.
				end
			end)
		end))
		if UserInputService then
			table.insert(commandPaletteConnections, UserInputService.InputBegan:Connect(function(input, processed)
				if processed or not commandPaletteOpen then
					return
				end
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end
				if input.KeyCode == Enum.KeyCode.Escape then
					manager.closeCommandPalette()
					return
				end
				if input.KeyCode == Enum.KeyCode.Down then
					if #commandPaletteResults > 0 then
						commandPaletteSelectionIndex = math.min(#commandPaletteResults, commandPaletteSelectionIndex + 1)
						renderCommandPaletteResults()
					end
					return
				end
				if input.KeyCode == Enum.KeyCode.Up then
					if #commandPaletteResults > 0 then
						commandPaletteSelectionIndex = math.max(1, commandPaletteSelectionIndex - 1)
						renderCommandPaletteResults()
					end
					return
				end
				if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
					local selected = commandPaletteResults[commandPaletteSelectionIndex] or commandPaletteResults[1]
					if selected then
						local forcedMode = nil
						if isModifierDown("shift") then
							forcedMode = "execute"
						elseif isModifierDown("alt") then
							forcedMode = "ask"
						end
						local okAction, message, meta = onCommandPaletteSelect(selected, forcedMode, {
							trigger = "keyboard"
						})
						if not okAction then
							notify({
								Title = L("command_palette.title", "Command Palette"),
								Content = tostring(message or "Command failed."),
								Duration = 3,
								Image = 4384402990
							})
						end
						if type(meta) == "table" and meta.keepPaletteOpen == true then
							return
						end
					end
					manager.closeCommandPalette()
				end
			end))
		end
	end

	local function bindPaletteHotkey()
		if not UserInputService then
			return
		end
		table.insert(commandPaletteConnections, UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if isPaletteKeyMatch(input) then
				manager.toggleCommandPalette()
			end
		end))
	end

	local function openSearch()
		if not (Main and Main.Search) then
			return
		end

		searchOpen = true

		Main.Search.BackgroundTransparency = 1
		Main.Search.Shadow.ImageTransparency = 1
		Main.Search.Input.TextTransparency = 1
		Main.Search.Search.ImageTransparency = 1
		Main.Search.UIStroke.Transparency = 1
		Main.Search.Size = UDim2.new(1, 0, 0, 80)
		Main.Search.Position = UDim2.new(0.5, 0, 0, 70)
		Main.Search.Input.Interactable = true
		Main.Search.Visible = true

		animateTabButtonsHidden(false)

		Main.Search.Input:CaptureFocus()
		playTween(Main.Search.Shadow, TweenInfo.new(0.05, Enum.EasingStyle.Quint), {ImageTransparency = 0.95})
		playTween(Main.Search, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {
			Position = UDim2.new(0.5, 0, 0, 57),
			BackgroundTransparency = 0.9
		})
		playTween(Main.Search.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {Transparency = 0.8})
		playTween(Main.Search.Input, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {TextTransparency = 0.2})
		playTween(Main.Search.Search, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5})
		playTween(Main.Search, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -35, 0, 35)})
	end

	local function closeSearch()
		if not (Main and Main.Search) then
			searchOpen = false
			return
		end

		searchOpen = false

		playTween(Main.Search, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -55, 0, 30)
		})
		playTween(Main.Search.Search, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1})
		playTween(Main.Search.Shadow, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {ImageTransparency = 1})
		playTween(Main.Search.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Transparency = 1})
		playTween(Main.Search.Input, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {TextTransparency = 1})

		animateTabButtonsByCurrentPage(true)

		Main.Search.Input.Text = ""
		Main.Search.Input.Interactable = false
	end

	local function openCommandPalette(seedText)
		local refs = ensureCommandPaletteOverlay()
		if not refs.Overlay then
			return false, "Command palette unavailable."
		end
		refs.Overlay.Visible = true
		commandPaletteOpen = true
		local text = seedText ~= nil and tostring(seedText) or ""
		refs.Input.Text = text
		refreshCommandPaletteQuery()
		task.defer(function()
			if refs.Input and refs.Input.Parent and commandPaletteOpen then
				refs.Input:CaptureFocus()
			end
		end)
		return true, "Command palette opened."
	end

	local function closeCommandPalette()
		local refs = ensureCommandPaletteOverlay()
		if not refs.Overlay then
			return false, "Command palette unavailable."
		end
		commandPaletteOpen = false
		refs.Overlay.Visible = false
		commandPaletteResults = {}
		commandPaletteSelectionIndex = 0
		if refs.Input then
			refs.Input.Text = ""
		end
		return true, "Command palette closed."
	end

	local function toggleCommandPalette(seedText)
		if commandPaletteOpen then
			return closeCommandPalette()
		end
		return openCommandPalette(seedText)
	end

	function manager.initialize()
		ensureCommandPaletteOverlay()
		bindCommandPaletteUiSignals()
		bindPaletteHotkey()
	end

	function manager.onThemeChanged()
		renderCommandPaletteResults()
	end

	manager.openSearch = openSearch
	manager.closeSearch = closeSearch
	manager.getSearchOpen = function()
		return searchOpen
	end

	manager.openCommandPalette = openCommandPalette
	manager.closeCommandPalette = closeCommandPalette
	manager.toggleCommandPalette = toggleCommandPalette

	function manager.destroy()
		disconnectConnections(commandPaletteConnections)
	end

	return manager
end

return SearchEngine
