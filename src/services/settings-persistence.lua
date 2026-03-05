local SettingsPersistenceModule = {}

local function splitSettingKey(input)
	local source = tostring(input or "")
	local dotIndex = string.find(source, ".", 1, true)
	if not dotIndex then
		return source, ""
	end
	return string.sub(source, 1, dotIndex - 1), string.sub(source, dotIndex + 1)
end

function SettingsPersistenceModule.attach(self, options)
	options = type(options) == "table" and options or {}
	local warnFn = type(options.warn) == "function" and options.warn or warn

	function self.saveSettings()
		local encoded
		local success = pcall(function()
			encoded = self.HttpService:JSONEncode(self.buildInternalSettingsData())
		end)

		if success then
			if self.useStudio then
				if script.Parent["get.val"] then
					script.Parent["get.val"].Value = encoded
				end
			end
			if type(writefile) ~= "function" then
				return self.useStudio == true
			end
			local writeResult = self.callSafely(writefile, self.RayfieldFolder .. "/settings" .. self.ConfigurationExtension, encoded)
			return writeResult ~= false
		end
		return false
	end

	function self.updateSetting(category, setting, value)
		if not self.settingsInitialized then
			return
		end
		self.settingsTable[category][setting].Value = value
		self.overriddenSettings[category .. "." .. setting] = nil
		self.saveSettings()
	end

	function self.loadSettings()
		local file = nil

		task.spawn(function()
			local ok, err = xpcall(function()
				if self.callSafely(isfolder, self.RayfieldFolder) then
					if self.callSafely(isfile, self.RayfieldFolder .. "/settings" .. self.ConfigurationExtension) then
						file = self.callSafely(readfile, self.RayfieldFolder .. "/settings" .. self.ConfigurationExtension)
					end
				end

				-- for debug in studio
				if self.useStudio then
					file = [[
			{"General":{"rayfieldOpen":{"Value":"K","Type":"bind","Name":"Rayfield Keybind","Element":{"HoldToInteract":false,"Ext":true,"Name":"Rayfield Keybind","Set":null,"CallOnChange":true,"Callback":null,"CurrentKeybind":"K"}}},"System":{"usageAnalytics":{"Value":false,"Type":"toggle","Name":"Anonymised Analytics","Element":{"Ext":true,"Name":"Anonymised Analytics","Set":null,"CurrentValue":false,"Callback":null}}}}
		]]
				end

				if file then
					local success, decodedFile = pcall(function()
						return self.HttpService:JSONDecode(file)
					end)
					if success and type(decodedFile) == "table" then
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

				if type(file) == "table" and next(file) ~= nil then
					for categoryName, settingCategory in pairs(self.settingsTable) do
						if file[categoryName] then
							for settingName, setting in pairs(settingCategory) do
								if file[categoryName][settingName] then
									setting.Value = self.cloneSerializable(file[categoryName][settingName].Value)
									if setting.Element and type(setting.Element.Set) == "function" then
										setting.Element:Set(self.getSetting(categoryName, settingName))
									end
								end
							end
						end
					end
				else
					for settingName, settingValue in pairs(self.overriddenSettings) do
						local categoryName, settingNameOnly = splitSettingKey(settingName)
						assert(categoryName ~= "" and settingNameOnly ~= "", "Rayfield | Invalid overridden setting name: " .. settingName)
						if self.settingsTable[categoryName] and self.settingsTable[categoryName][settingNameOnly] then
							local targetSetting = self.settingsTable[categoryName][settingNameOnly]
							if targetSetting.Element and type(targetSetting.Element.Set) == "function" then
								targetSetting.Element:Set(settingValue)
							else
								targetSetting.Value = self.cloneSerializable(settingValue)
							end
						end
					end
				end
				self.settingsInitialized = true
			end, debug.traceback)
			if not ok then
				warnFn("Rayfield | Failed to load settings: " .. tostring(err))
			end
		end)
	end
end

return SettingsPersistenceModule
