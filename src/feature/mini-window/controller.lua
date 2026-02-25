-- Custom Mini Window System
-- Creates a small floating widget separate from Rayfield

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local function buildFallbackAnimateFacade()
	local engine = (_G and _G.__RayfieldSharedAnimationEngine) or nil
	if not engine then
		local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
		local okEngineLib, engineLib = pcall(function()
			if _G and _G.__RayfieldApiClient then
				return _G.__RayfieldApiClient.fetchAndExecute(root .. "src/core/animation/engine.lua")
			end
			return nil
		end)
		if okEngineLib and engineLib and type(engineLib.new) == "function" then
			local okEngine, createdEngine = pcall(function()
				return engineLib.new({
					TweenService = TweenService,
					RunService = game:GetService("RunService"),
					mode = "raw"
				})
			end)
			if okEngine then
				engine = createdEngine
			end
		end
	end

	if not engine then
		return {
			Create = function(_, object, tweenInfo, goals)
				local creator = TweenService["Create"]
				if type(creator) == "function" then
					return creator(TweenService, object, tweenInfo, goals)
				end
				return nil
			end
		}
	end

	return {
		Create = function(_, object, tweenInfo, goals)
			return engine:Create(object, tweenInfo, goals)
		end
	}
end

local Animation = (_G and _G.__RayfieldSharedAnimateFacade) or buildFallbackAnimateFacade()

local MiniWindow = {}
MiniWindow.__index = MiniWindow

local function getViewportVirtualization()
	local service = _G and _G.__RayfieldViewportVirtualization
	if type(service) == "table" then
		return service
	end
	return nil
end

function MiniWindow.new(config)
    local self = setmetatable({}, MiniWindow)
    
    config = config or {}
    self.Title = config.Title or "Mini Window"
    self.Size = config.Size or UDim2.new(0, 200, 0, 300)
    self.Position = config.Position or UDim2.new(1, -220, 0.5, -150)
    self.Buttons = {}
    self.Labels = {}
    self.Animation = Animation
    self.Connections = {}
    self.ViewportVirtualization = getViewportVirtualization()
    self.VirtualHostId = "mini:" .. tostring(HttpService:GenerateGUID(false))
    self.VirtualTokens = setmetatable({}, { __mode = "k" })
    
    self:CreateUI()
    
    return self
end

function MiniWindow:_trackConnection(connection)
	if connection then
		table.insert(self.Connections, connection)
	end
	return connection
end

function MiniWindow:_registerVirtualHost()
	local viewport = self.ViewportVirtualization
	if not (viewport and type(viewport.registerHost) == "function") then
		return false
	end
	return pcall(viewport.registerHost, self.VirtualHostId, self.Content, {
		mode = "scrolling"
	})
end

function MiniWindow:_refreshVirtualHost(reason)
	local viewport = self.ViewportVirtualization
	if viewport and type(viewport.refreshHost) == "function" then
		pcall(viewport.refreshHost, self.VirtualHostId, reason or "mini_window_update")
	end
end

function MiniWindow:_registerVirtualElement(guiObject, elementType)
	if not guiObject then
		return nil
	end
	local viewport = self.ViewportVirtualization
	if not (viewport and type(viewport.registerElement) == "function") then
		return nil
	end
	local okToken, token = pcall(viewport.registerElement, self.VirtualHostId, guiObject, {
		meta = {
			elementType = elementType or guiObject.ClassName or "GuiObject",
			miniWindow = true,
			title = self.Title
		}
	})
	if okToken and type(token) == "string" then
		self.VirtualTokens[guiObject] = token
		if guiObject.SetAttribute then
			pcall(guiObject.SetAttribute, guiObject, "RayfieldVirtualToken", token)
		end
		return token
	end
	return nil
end

function MiniWindow:_unregisterVirtualElement(guiObject)
	if not guiObject then
		return
	end
	local viewport = self.ViewportVirtualization
	if not (viewport and type(viewport.unregisterElement) == "function") then
		return
	end
	local token = self.VirtualTokens[guiObject]
	if token then
		pcall(viewport.unregisterElement, token)
		self.VirtualTokens[guiObject] = nil
	else
		pcall(viewport.unregisterElement, guiObject)
	end
	if guiObject.SetAttribute then
		pcall(guiObject.SetAttribute, guiObject, "RayfieldVirtualToken", nil)
	end
end

function MiniWindow:CreateUI()
    -- Create ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "MiniWindow"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main Frame
    self.Frame = Instance.new("Frame")
    self.Frame.Name = "MainFrame"
    self.Frame.Size = self.Size
    self.Frame.Position = self.Position
    self.Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    self.Frame.BorderSizePixel = 0
    self.Frame.Parent = self.ScreenGui
    
    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.Frame
    
    -- Stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 80)
    stroke.Thickness = 2
    stroke.Parent = self.Frame
    
    -- Title Bar
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 30)
    self.TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    self.TitleBar.BorderSizePixel = 0
    self.TitleBar.Parent = self.Frame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = self.TitleBar
    
    -- Title Text
    self.TitleLabel = Instance.new("TextLabel")
    self.TitleLabel.Name = "Title"
    self.TitleLabel.Size = UDim2.new(1, -40, 1, 0)
    self.TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    self.TitleLabel.BackgroundTransparency = 1
    self.TitleLabel.Text = self.Title
    self.TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.TitleLabel.TextSize = 14
    self.TitleLabel.Font = Enum.Font.GothamBold
    self.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.TitleLabel.Parent = self.TitleBar
    
    -- Close Button
    self.CloseButton = Instance.new("TextButton")
    self.CloseButton.Name = "Close"
    self.CloseButton.Size = UDim2.new(0, 20, 0, 20)
    self.CloseButton.Position = UDim2.new(1, -25, 0.5, -10)
    self.CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    self.CloseButton.Text = "×"
    self.CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.CloseButton.TextSize = 16
    self.CloseButton.Font = Enum.Font.GothamBold
    self.CloseButton.BorderSizePixel = 0
    self.CloseButton.Parent = self.TitleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(1, 0)
    closeCorner.Parent = self.CloseButton
    
    self:_trackConnection(self.CloseButton.MouseButton1Click:Connect(function()
        self:Toggle()
    end))
    
    -- Content Frame
    self.Content = Instance.new("ScrollingFrame")
    self.Content.Name = "Content"
    self.Content.Size = UDim2.new(1, -10, 1, -40)
    self.Content.Position = UDim2.new(0, 5, 0, 35)
    self.Content.BackgroundTransparency = 1
    self.Content.BorderSizePixel = 0
    self.Content.ScrollBarThickness = 4
    self.Content.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
    self.Content.Parent = self.Frame
    
    -- Layout
    self.Layout = Instance.new("UIListLayout")
    self.Layout.Padding = UDim.new(0, 5)
    self.Layout.SortOrder = Enum.SortOrder.LayoutOrder
    self.Layout.Parent = self.Content
    
    -- Make draggable
    self:MakeDraggable()
    
    -- Parent to PlayerGui
    self.ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self:_registerVirtualHost()
    self:_trackConnection(self.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
        if self.ViewportVirtualization and type(self.ViewportVirtualization.setHostSuppressed) == "function" then
            pcall(self.ViewportVirtualization.setHostSuppressed, self.VirtualHostId, not self.Frame.Visible)
        end
        self:_refreshVirtualHost("mini_visibility")
    end))
    self:_refreshVirtualHost("mini_window_created")
end

function MiniWindow:MakeDraggable()
    local dragging = false
    local dragInput, mousePos, framePos
    
    self:_trackConnection(self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = self.Frame.Position
            
            self:_trackConnection(input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end))
        end
    end))
    
    self:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - mousePos
            self.Frame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end))
end

function MiniWindow:AddButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(1, -10, 0, 30)
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 12
    button.Font = Enum.Font.Gotham
    button.BorderSizePixel = 0
    button.Parent = self.Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    self:_trackConnection(button.MouseButton1Click:Connect(callback))
    
    self:_trackConnection(button.MouseEnter:Connect(function()
        Animation:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 80)}):Play()
    end))
    
    self:_trackConnection(button.MouseLeave:Connect(function()
        Animation:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 45, 60)}):Play()
    end))
    
    table.insert(self.Buttons, button)
    self:_registerVirtualElement(button, "Button")
    self:UpdateContentSize()
    
    return button
end

function MiniWindow:AddLabel(text)
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -10, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = self.Content
    
    table.insert(self.Labels, label)
    self:_registerVirtualElement(label, "Label")
    self:UpdateContentSize()
    
    return label
end

function MiniWindow:UpdateContentSize()
    local contentSize = self.Layout.AbsoluteContentSize
    self.Content.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
    self:_refreshVirtualHost("content_size")
end

function MiniWindow:Toggle()
    self.Frame.Visible = not self.Frame.Visible
    if self.ViewportVirtualization and type(self.ViewportVirtualization.setHostSuppressed) == "function" then
        pcall(self.ViewportVirtualization.setHostSuppressed, self.VirtualHostId, not self.Frame.Visible)
    end
    self:_refreshVirtualHost("mini_toggle")
end

function MiniWindow:Show()
    self.Frame.Visible = true
    if self.ViewportVirtualization and type(self.ViewportVirtualization.setHostSuppressed) == "function" then
        pcall(self.ViewportVirtualization.setHostSuppressed, self.VirtualHostId, false)
    end
    self:_refreshVirtualHost("mini_show")
end

function MiniWindow:Hide()
    self.Frame.Visible = false
    if self.ViewportVirtualization and type(self.ViewportVirtualization.setHostSuppressed) == "function" then
        pcall(self.ViewportVirtualization.setHostSuppressed, self.VirtualHostId, true)
    end
    self:_refreshVirtualHost("mini_hide")
end

function MiniWindow:AddToggle(name, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Name = name
    container.Size = UDim2.new(1, -10, 0, 30)
    container.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    container.BorderSizePixel = 0
    container.Parent = self.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 40, 0, 20)
    toggle.Position = UDim2.new(1, -45, 0.5, -10)
    toggle.BackgroundColor3 = defaultValue and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(80, 80, 90)
    toggle.Text = defaultValue and "ON" or "OFF"
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.TextSize = 10
    toggle.Font = Enum.Font.GothamBold
    toggle.BorderSizePixel = 0
    toggle.Parent = container

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 10)
    toggleCorner.Parent = toggle

    local state = defaultValue

    self:_trackConnection(toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.Text = state and "ON" or "OFF"
        Animation:Create(toggle, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(80, 80, 90)
        }):Play()
        callback(state)
    end))

    self:_registerVirtualElement(container, "Toggle")
    self:UpdateContentSize()

    return {
        Container = container,
        Toggle = toggle,
        SetValue = function(value)
            state = value
            toggle.Text = state and "ON" or "OFF"
            toggle.BackgroundColor3 = state and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(80, 80, 90)
        end,
        GetValue = function()
            return state
        end
    }
end

function MiniWindow:AddSlider(name, min, max, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Name = name
    container.Size = UDim2.new(1, -10, 0, 50)
    container.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    container.BorderSizePixel = 0
    container.Parent = self.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. defaultValue
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -20, 0, 6)
    sliderBg.Position = UDim2.new(0, 10, 1, -15)
    sliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = container

    local sliderBgCorner = Instance.new("UICorner")
    sliderBgCorner.CornerRadius = UDim.new(1, 0)
    sliderBgCorner.Parent = sliderBg

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((defaultValue - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg

    local sliderFillCorner = Instance.new("UICorner")
    sliderFillCorner.CornerRadius = UDim.new(1, 0)
    sliderFillCorner.Parent = sliderFill

    local currentValue = defaultValue
    local dragging = false

    local function updateSlider(input)
        local pos = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
        pos = math.clamp(pos, 0, 1)
        currentValue = math.floor(min + (max - min) * pos)
        sliderFill.Size = UDim2.new(pos, 0, 1, 0)
        label.Text = name .. ": " .. currentValue
        callback(currentValue)
    end

    self:_trackConnection(sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input)
        end
    end))

    self:_trackConnection(sliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    self:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input)
        end
    end))

    self:_registerVirtualElement(container, "Slider")
    self:UpdateContentSize()

    return {
        Container = container,
        SetValue = function(value)
            currentValue = math.clamp(value, min, max)
            local pos = (currentValue - min) / (max - min)
            sliderFill.Size = UDim2.new(pos, 0, 1, 0)
            label.Text = name .. ": " .. currentValue
        end,
        GetValue = function()
            return currentValue
        end
    }
end

function MiniWindow:Destroy()
    local tokenObjects = {}
    for guiObject in pairs(self.VirtualTokens) do
        table.insert(tokenObjects, guiObject)
    end
    for _, guiObject in ipairs(tokenObjects) do
        self:_unregisterVirtualElement(guiObject)
    end
    local viewport = self.ViewportVirtualization
    if viewport and type(viewport.unregisterHost) == "function" then
        pcall(viewport.unregisterHost, self.VirtualHostId)
    end
    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.Connections = {}
    self.ScreenGui:Destroy()
end

return MiniWindow

