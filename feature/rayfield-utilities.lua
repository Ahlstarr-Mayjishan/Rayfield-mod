-- Rayfield Utilities & Lifecycle Module
-- Handles utility functions, dragging, visibility, and lifecycle management

local UtilitiesModule = {}

function UtilitiesModule.init(ctx)
	local self = {}
	
	-- Inject dependencies
	self.TweenService = ctx.TweenService
	self.RunService = ctx.RunService
	self.UserInputService = ctx.UserInputService
	self.getService = ctx.getService
	self.Main = ctx.Main
	self.Rayfield = ctx.Rayfield
	self.dragBar = ctx.dragBar
	self.dragBarCosmetic = ctx.dragBarCosmetic
	self.getHidden = ctx.getHidden
	self.useMobileSizing = ctx.useMobileSizing
	self.Hide = ctx.Hide
	self.Unhide = ctx.Unhide
	self.getDebounce = ctx.getDebounce
	self.setRayfieldDestroyed = ctx.setRayfieldDestroyed
	self.keybindConnections = ctx.keybindConnections
	
	-- Utility: Get asset URI from ID or icon name
	local function getAssetUri(id, Icons)
		local assetUri = "rbxassetid://0" -- Default to empty image
		if type(id) == "number" then
			assetUri = "rbxassetid://" .. id
		elseif type(id) == "string" and not Icons then
			warn("Rayfield | Cannot use Lucide icons as icons library is not loaded")
		else
			warn("Rayfield | The icon argument must either be an icon ID (number) or a Lucide icon name (string)")
		end
		return assetUri
	end
	
	-- Make a GUI object draggable
	local function makeDraggable(object, dragObject, enableTaptic, tapticOffset)
		local dragging = false
		local relative = nil
		local activeInput = nil
		local pointerPosition = nil
		
		local offset = Vector2.zero
		local screenGui = object:FindFirstAncestorWhichIsA("ScreenGui")
		if screenGui and screenGui.IgnoreGuiInset then
			offset += self.getService('GuiService'):GetGuiInset()
		end
		
		if dragObject:IsA("GuiObject") then
			dragObject.Active = true
		end
		
		local function updatePointerFromInput(input)
			if input and input.Position then
				pointerPosition = Vector2.new(input.Position.X, input.Position.Y)
			end
		end
		
		local function getPointerPosition()
			if pointerPosition then
				return pointerPosition
			end
			return self.UserInputService:GetMouseLocation()
		end
		
		local function connectFunctions()
			if self.dragBar and enableTaptic then
				self.dragBar.MouseEnter:Connect(function()
					if not dragging and not self.getHidden() then
						self.TweenService:Create(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5, Size = UDim2.new(0, 120, 0, 4)}):Play()
					end
				end)
				
				self.dragBar.MouseLeave:Connect(function()
					if not dragging and not self.getHidden() then
						self.TweenService:Create(self.dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7, Size = UDim2.new(0, 100, 0, 4)}):Play()
					end
				end)
			end
		end
		
		connectFunctions()
		
		dragObject.InputBegan:Connect(function(input, processed)
			local inputType = input.UserInputType
			
			if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
				dragging = true
				activeInput = input
				updatePointerFromInput(input)
				
				relative = object.AbsolutePosition + object.AbsoluteSize * object.AnchorPoint - getPointerPosition()
				if enableTaptic and not self.getHidden() then
					self.TweenService:Create(self.dragBarCosmetic, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 110, 0, 4), BackgroundTransparency = 0}):Play()
				end
			end
		end)
		
		local inputChanged = self.UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			
			if activeInput and input == activeInput then
				updatePointerFromInput(input)
			elseif activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement then
				updatePointerFromInput(input)
			end
		end)
		
		local inputEnded = self.UserInputService.InputEnded:Connect(function(input)
			if not dragging then return end
			
			local inputType = input.UserInputType
			local touchEnded = activeInput and activeInput.UserInputType == Enum.UserInputType.Touch and input == activeInput
			if inputType == Enum.UserInputType.MouseButton1 or touchEnded then
				dragging = false
				activeInput = nil
				pointerPosition = nil
				
				connectFunctions()
				
				if enableTaptic and not self.getHidden() then
					self.TweenService:Create(self.dragBarCosmetic, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 100, 0, 4), BackgroundTransparency = 0.7}):Play()
				end
			end
		end)
		
		local renderStepped = self.RunService.RenderStepped:Connect(function(deltaTime)
			if dragging and not self.getHidden() then
				local position = getPointerPosition() + relative + offset
				if enableTaptic and tapticOffset then
					local tapticY = (self.useMobileSizing and tapticOffset[2]) or tapticOffset[1]
					-- Lerp-based follow instead of creating new tweens every frame
					local objAlpha = math.clamp(1 - math.exp(-deltaTime * 7), 0, 1)
					local objCur = object.Position
					local objNext = objCur:Lerp(UDim2.fromOffset(position.X, position.Y), objAlpha)
					object.Position = objNext
					local barParent = dragObject.Parent
					local barAlpha = math.clamp(1 - math.exp(-deltaTime * 50), 0, 1)
					local barCur = barParent.Position
					barParent.Position = barCur:Lerp(UDim2.fromOffset(position.X, position.Y + tapticY), barAlpha)
				else
					if self.dragBar and tapticOffset then
						self.dragBar.Position = UDim2.fromOffset(position.X, position.Y + ((self.useMobileSizing and tapticOffset[2]) or tapticOffset[1]))
					end
					object.Position = UDim2.fromOffset(position.X, position.Y)
				end
			end
		end)
		
		object.Destroying:Connect(function()
			if inputChanged then inputChanged:Disconnect() end
			if inputEnded then inputEnded:Disconnect() end
			if renderStepped then renderStepped:Disconnect() end
		end)
	end
	
	-- Set visibility with optional notification
	local function setVisibility(visibility, notify)
		if self.getDebounce() then return end
		if visibility then
			self.Unhide()
		else
			self.Hide(notify)
		end
	end
	
	-- Destroy Rayfield and cleanup
	local function destroy(hideHotkeyConnection)
		self.setRayfieldDestroyed(true)
		if hideHotkeyConnection then
			hideHotkeyConnection:Disconnect()
		end
		for _, connection in self.keybindConnections do
			connection:Disconnect()
		end
		self.Rayfield:Destroy()
	end
	
	-- Export functions
	self.getAssetUri = getAssetUri
	self.makeDraggable = makeDraggable
	self.setVisibility = setVisibility
	self.destroy = destroy
	
	return self
end

return UtilitiesModule
