--[[
	Rayfield Settings/Config System Module
	Extracted from rayfield-modified.lua
	
	This module handles:
	- Settings table management
	- Loading/saving settings from/to file
	- Settings UI creation
	- Setting overrides
]]

local SettingsModule = {}

-- Default settings table structure
SettingsModule.defaultSettings = {
	General = {
		rayfieldOpen = {Type = 'bind', Value = 'K', Name = 'Rayfield Keybind'},
	},
	System = {
		usageAnalytics = {Type = 'toggle', Value = true, Name = 'Anonymised Analytics'},
	}
}

-- Initialize module with dependencies
function SettingsModule.init(ctx)
	local self = {}
	
	-- Store dependencies from context
	self.RayfieldFolder = ctx.RayfieldFolder
	self.ConfigurationExtension = ctx.ConfigurationExtension
	self.HttpService = ctx.HttpService
	self.useStudio = ctx.useStudio
	self.callSafely = ctx.callSafely
	self.Topbar = ctx.Topbar
	self.TabList = ctx.TabList
	self.Elements = ctx.Elements
	
	-- State variables
	self.settingsTable = {}
	self.overriddenSettings = {}
	self.cachedSettings = nil
	self.settingsInitialized = false
	self.settingsCreated = false
	
	-- Initialize settings table with defaults
	for category, settings in pairs(SettingsModule.defaultSettings) do
		self.settingsTable[category] = {}
		for name, setting in pairs(settings) do
			self.settingsTable[category][name] = {
				Type = setting.Type,
				Value = setting.Value,
				Name = setting.Name,
				Element = nil
			}
		end
	end
	
	-- Override a setting value
	function self.overrideSetting(category, name, value)
		self.overriddenSettings[category .. "." .. name] = value
	end
	
	-- Get setting value (checks overrides first)
	function self.getSetting(category, name)
		if self.overriddenSettings[category .. "." .. name] ~= nil then
			return self.overriddenSettings[category .. "." .. name]
		elseif self.settingsTable[category][name] ~= nil then
			return self.settingsTable[category][name].Value
		end
	end
	
	-- Save settings to file
	function self.saveSettings()
		local encoded
		local success, err = pcall(function()
			encoded = self.HttpService:JSONEncode(self.settingsTable)
		end)

		if success then
			if self.useStudio then
				if script.Parent['get.val'] then
					script.Parent['get.val'].Value = encoded
				end
			end
			self.callSafely(writefile, self.RayfieldFolder..'/settings'..self.ConfigurationExtension, encoded)
		end
	end
	
	-- Update a setting and save
	function self.updateSetting(category, setting, value)
		if not self.settingsInitialized then
			return
		end
		self.settingsTable[category][setting].Value = value
		self.overriddenSettings[category .. "." .. setting] = nil
		self.saveSettings()
	end
	
	-- Load settings from file
	function self.loadSettings()
		local file = nil

		local success, result = pcall(function()
			task.spawn(function()
				if self.callSafely(isfolder, self.RayfieldFolder) then
					if self.callSafely(isfile, self.RayfieldFolder..'/settings'..self.ConfigurationExtension) then
						file = self.callSafely(readfile, self.RayfieldFolder..'/settings'..self.ConfigurationExtension)
					end
				end

				-- for debug in studio
				if self.useStudio then
					file = [[
			{"General":{"rayfieldOpen":{"Value":"K","Type":"bind","Name":"Rayfield Keybind","Element":{"HoldToInteract":false,"Ext":true,"Name":"Rayfield Keybind","Set":null,"CallOnChange":true,"Callback":null,"CurrentKeybind":"K"}}},"System":{"usageAnalytics":{"Value":false,"Type":"toggle","Name":"Anonymised Analytics","Element":{"Ext":true,"Name":"Anonymised Analytics","Set":null,"CurrentValue":false,"Callback":null}}}}
		]]
				end

				if file then
					local success, decodedFile = pcall(function() return self.HttpService:JSONDecode(file) end)
					if success then
						file = decodedFile
					else
						file = {}
					end
				else
					file = {}
				end

				if not self.settingsCreated then 
					self.cachedSettings = file
					return
				end

				if #file > 0 then
					for categoryName, settingCategory in pairs(self.settingsTable) do
						if file[categoryName] then
							for settingName, setting in pairs(settingCategory) do
								if file[categoryName][settingName] then
									setting.Value = file[categoryName][settingName].Value
									setting.Element:Set(self.getSetting(categoryName, settingName))
								end
							end
						end
					end
				else
					for settingName, settingValue in self.overriddenSettings do
						local split = string.split(settingName, ".")
						assert(#split == 2, "Rayfield | Invalid overridden setting name: " .. settingName)
						local categoryName = split[1]
						local settingNameOnly = split[2]
						if self.settingsTable[categoryName] and self.settingsTable[categoryName][settingNameOnly] then
							self.settingsTable[categoryName][settingNameOnly].Element:Set(settingValue)
						end
					end
				end
				self.settingsInitialized = true
			end)
		end)
	end


	-- Create settings UI tab
	function self.createSettings(window)
		if not (writefile and isfile and readfile and isfolder and makefolder) and not self.useStudio then
			if self.Topbar['Settings'] then self.Topbar.Settings.Visible = false end
			self.Topbar['Search'].Position = UDim2.new(1, -75, 0.5, 0)
			warn('Can\'t create settings as no file-saving functionality is available.')
			return
		end

		local newTab = window:CreateTab('Rayfield Settings', 0, true)

		if self.TabList['Rayfield Settings'] then
			self.TabList['Rayfield Settings'].LayoutOrder = 1000
		end

		if self.Elements['Rayfield Settings'] then
			self.Elements['Rayfield Settings'].LayoutOrder = 1000
		end

		-- Create sections and elements
		for categoryName, settingCategory in pairs(self.settingsTable) do
			newTab:CreateSection(categoryName)

			for settingName, setting in pairs(settingCategory) do
				if setting.Type == 'input' then
					setting.Element = newTab:CreateInput({
						Name = setting.Name,
						CurrentValue = setting.Value,
						PlaceholderText = setting.Placeholder,
						Ext = true,
						RemoveTextAfterFocusLost = setting.ClearOnFocus,
						Callback = function(Value)
							self.updateSetting(categoryName, settingName, Value)
						end,
					})
				elseif setting.Type == 'toggle' then
					setting.Element = newTab:CreateToggle({
						Name = setting.Name,
						CurrentValue = setting.Value,
						Ext = true,
						Callback = function(Value)
							self.updateSetting(categoryName, settingName, Value)
						end,
					})
				elseif setting.Type == 'bind' then
					setting.Element = newTab:CreateKeybind({
						Name = setting.Name,
						CurrentKeybind = setting.Value,
						HoldToInteract = false,
						Ext = true,
						CallOnChange = true,
						Callback = function(Value)
							self.updateSetting(categoryName, settingName, Value)
						end,
					})
				end
			end
		end

		self.settingsCreated = true
		self.loadSettings()
		self.saveSettings()
	end

	return self
end

return SettingsModule
