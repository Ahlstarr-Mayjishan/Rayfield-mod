local TooltipEngine = {}

function TooltipEngine.create(options)
	options = options or {}
	local rayfield = options.Rayfield
	local main = options.Main
	local userInputService = options.UserInputService
	local getSelectedTheme = type(options.getSelectedTheme) == "function" and options.getSelectedTheme or function()
		return nil
	end

	local state = {
		frame = nil,
		label = nil,
		text = "",
		activeKey = nil
	}

	local engine = {}

	local function ensureFrame()
		if state.frame and state.frame.Parent then
			return state.frame
		end

		local host = rayfield or main
		if not host then
			return nil
		end

		local frame = Instance.new("Frame")
		frame.Name = "RayfieldTooltip"
		frame.AnchorPoint = Vector2.new(0, 1)
		frame.Position = UDim2.new(0, 0, 0, 0)
		frame.Size = UDim2.new(0, 220, 0, 30)
		frame.BackgroundTransparency = 0.05
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.ZIndex = 500
		frame.Parent = host
		pcall(function()
			frame.Active = false
		end)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Transparency = 0.15
		stroke.Parent = frame

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.Font = Enum.Font.Gotham
		label.TextSize = 12
		label.Position = UDim2.new(0, 8, 0, 6)
		label.Size = UDim2.new(1, -16, 1, -12)
		label.ZIndex = 501
		label.Parent = frame

		state.frame = frame
		state.label = label

		local function applyTheme()
			local theme = getSelectedTheme()
			if not theme then
				return
			end
			frame.BackgroundColor3 = theme.TooltipBackground or theme.SecondaryElementBackground or theme.ElementBackground
			label.TextColor3 = theme.TooltipTextColor or theme.TextColor
			stroke.Color = theme.TooltipStroke or theme.ElementStroke or theme.SecondaryElementStroke
		end
		applyTheme()

		if rayfield and rayfield.Main then
			rayfield.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
				if frame and frame.Parent then
					applyTheme()
				end
			end)
		end

		return frame
	end

	function engine.hide(key)
		if key ~= nil and state.activeKey ~= key then
			return
		end
		state.activeKey = nil
		if state.frame then
			state.frame.Visible = false
		end
	end

	function engine.show(key, guiObject, text)
		local frame = ensureFrame()
		if not frame or not guiObject or not guiObject.Parent then
			return
		end

		local textValue = tostring(text or "")
		if textValue == "" then
			engine.hide(key)
			return
		end

		state.activeKey = key
		state.text = textValue
		if state.label then
			state.label.Text = textValue
		end

		local mousePosition = nil
		local okPos, posValue = pcall(function()
			return userInputService:GetMouseLocation()
		end)
		if okPos then
			mousePosition = posValue
		else
			mousePosition = Vector2.new(guiObject.AbsolutePosition.X, guiObject.AbsolutePosition.Y)
		end

		local width = math.clamp(math.max(160, (#textValue * 6) + 16), 160, 360)
		local lines = math.max(1, math.ceil(#textValue / 38))
		local height = math.max(24, (lines * 14) + 12)
		frame.Size = UDim2.new(0, width, 0, height)

		local hostSize = rayfield and rayfield.AbsoluteSize or Vector2.new(1200, 800)
		local x = mousePosition.X + 14
		local y = mousePosition.Y - 10
		if x + width > hostSize.X then
			x = math.max(8, mousePosition.X - width - 14)
		end
		if y - height < 0 then
			y = mousePosition.Y + height
		end
		frame.Position = UDim2.new(0, x, 0, y)
		frame.Visible = true
	end

	return engine
end

return TooltipEngine
