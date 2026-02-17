-- Rayfield Configuration Management Module
-- Handles configuration save/load and color packing

local ConfigModule = {}

function ConfigModule.init(ctx)
	local self = {}
	
	-- Inject dependencies
	self.HttpService = ctx.HttpService
	self.RayfieldLibrary = ctx.RayfieldLibrary
	self.callSafely = ctx.callSafely
	self.ConfigurationFolder = ctx.ConfigurationFolder
	self.ConfigurationExtension = ctx.ConfigurationExtension
	self.getCFileName = ctx.getCFileName
	self.getCEnabled = ctx.getCEnabled
	self.getGlobalLoaded = ctx.getGlobalLoaded
	self.useStudio = ctx.useStudio
	self.debugX = ctx.debugX
	
	-- Color packing/unpacking utilities
	local function PackColor(Color)
		return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
	end
	
	local function UnpackColor(Color)
		return Color3.fromRGB(Color.R, Color.G, Color.B)
	end
	
	-- Load configuration from JSON string
	local function LoadConfiguration(Configuration)
		local success, Data = pcall(function() return self.HttpService:JSONDecode(Configuration) end)
		local changed
		
		if not success then 
			warn('Rayfield had an issue decoding the configuration file, please try delete the file and reopen Rayfield.') 
			return 
		end
		
		-- Iterate through current UI elements' flags
		for FlagName, Flag in pairs(self.RayfieldLibrary.Flags) do
			local FlagValue = Data[FlagName]
			
			if (typeof(FlagValue) == 'boolean' and FlagValue == false) or FlagValue then
				task.spawn(function()
					if Flag.Type == "ColorPicker" then
						changed = true
						Flag:Set(UnpackColor(FlagValue))
					else
						if (Flag.CurrentValue or Flag.CurrentKeybind or Flag.CurrentOption or Flag.Color) ~= FlagValue then 
							changed = true
							Flag:Set(FlagValue) 	
						end
					end
				end)
			else
				warn("Rayfield | Unable to find '"..FlagName.. "' in the save file.")
				print("The error above may not be an issue if new elements have been added or not been set values.")
			end
		end
		
		return changed
	end
	
	-- Save configuration to file
	local function SaveConfiguration()
		if not self.getCEnabled() or not self.getGlobalLoaded() then return end
		
		if self.debugX then
			print('Saving')
		end
		
		local Data = {}
		for i, v in pairs(self.RayfieldLibrary.Flags) do
			if v.Type == "ColorPicker" then
				Data[i] = PackColor(v.Color)
			else
				if typeof(v.CurrentValue) == 'boolean' then
					if v.CurrentValue == false then
						Data[i] = false
					else
						Data[i] = v.CurrentValue or v.CurrentKeybind or v.CurrentOption or v.Color
					end
				else
					Data[i] = v.CurrentValue or v.CurrentKeybind or v.CurrentOption or v.Color
				end
			end
		end
		
		if self.useStudio then
			if script.Parent:FindFirstChild('configuration') then 
				script.Parent.configuration:Destroy() 
			end
			
			local ScreenGui = Instance.new("ScreenGui")
			ScreenGui.Parent = script.Parent
			ScreenGui.Name = 'configuration'
			
			local TextBox = Instance.new("TextBox")
			TextBox.Parent = ScreenGui
			TextBox.Size = UDim2.new(0, 800, 0, 50)
			TextBox.AnchorPoint = Vector2.new(0.5, 0)
			TextBox.Position = UDim2.new(0.5, 0, 0, 30)
			TextBox.Text = self.HttpService:JSONEncode(Data)
			TextBox.ClearTextOnFocus = false
		end
		
		if self.debugX then
			warn(self.HttpService:JSONEncode(Data))
		end
		
		self.callSafely(writefile, self.ConfigurationFolder .. "/" .. self.getCFileName() .. self.ConfigurationExtension, tostring(self.HttpService:JSONEncode(Data)))
	end
	
	-- Export functions
	self.PackColor = PackColor
	self.UnpackColor = UnpackColor
	self.LoadConfiguration = LoadConfiguration
	self.SaveConfiguration = SaveConfiguration
	
	return self
end

return ConfigModule

