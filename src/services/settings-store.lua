local SettingsStoreModule = {}

local function cloneSerializable(value)
	local valueType = type(value)
	if valueType == "function" or valueType == "userdata" or valueType == "thread" then
		return nil
	end
	if valueType ~= "table" then
		return value
	end

	local out = {}
	for key, nestedValue in pairs(value) do
		if key ~= "Element" then
			local keyType = type(key)
			if keyType ~= "function" and keyType ~= "userdata" and keyType ~= "thread" then
				local cloned = cloneSerializable(nestedValue)
				if cloned ~= nil then
					out[key] = cloned
				end
			end
		end
	end
	return out
end

local function valuesEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return false
	end

	for key, valueA in pairs(a) do
		if not valuesEqual(valueA, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function SettingsStoreModule.attach(self, options)
	options = type(options) == "table" and options or {}
	local defaultSettings = type(options.defaultSettings) == "table" and options.defaultSettings or {}
	local warnFn = type(options.warn) == "function" and options.warn or warn

	local function buildInternalSettingsData()
		local out = {}
		for categoryName, settingCategory in pairs(self.settingsTable) do
			out[categoryName] = {}
			for settingName, setting in pairs(settingCategory) do
				out[categoryName][settingName] = {
					Type = setting.Type,
					Value = cloneSerializable(setting.Value),
					Name = setting.Name
				}
			end
		end
		return out
	end

	self.cloneSerializable = cloneSerializable
	self.valuesEqual = valuesEqual
	self.buildInternalSettingsData = buildInternalSettingsData

	for category, settings in pairs(defaultSettings) do
		self.settingsTable[category] = {}
		for name, setting in pairs(settings) do
			self.settingsTable[category][name] = {
				Type = setting.Type,
				Value = cloneSerializable(setting.Value),
				Name = setting.Name,
				Options = cloneSerializable(setting.Options),
				Element = nil
			}
		end
	end

	function self.overrideSetting(category, name, value)
		self.overriddenSettings[category .. "." .. name] = value
	end

	function self.getSetting(category, name)
		local key = tostring(category or "") .. "." .. tostring(name or "")
		if self.overriddenSettings[key] ~= nil then
			return self.overriddenSettings[key]
		end
		if self.settingsTable[category] and self.settingsTable[category][name] ~= nil then
			return self.settingsTable[category][name].Value
		end
		return nil
	end

	function self.setSettingValue(category, name, value, persist)
		if not (self.settingsTable[category] and self.settingsTable[category][name]) then
			return false, "Unknown setting."
		end

		local setting = self.settingsTable[category][name]
		local previousValue = setting.Value
		local nextValue = cloneSerializable(value)
		local changed = not valuesEqual(previousValue, nextValue)
		setting.Value = nextValue
		self.overriddenSettings[tostring(category) .. "." .. tostring(name)] = nil

		if changed and setting.Element and type(setting.Element.Set) == "function" then
			pcall(function()
				setting.Element:Set(nextValue)
			end)
		end

		if persist ~= false and type(self.saveSettings) == "function" then
			self.saveSettings()
		end
		return true, "ok"
	end

	function self.ExportInternalSettingsData()
		return buildInternalSettingsData()
	end

	function self.ImportInternalSettingsData(dataTable)
		if type(dataTable) ~= "table" then
			return false, "Internal settings data must be a table."
		end

		local appliedCount = 0
		for categoryName, settingCategory in pairs(self.settingsTable) do
			local incomingCategory = dataTable[categoryName]
			if type(incomingCategory) == "table" then
				for settingName, setting in pairs(settingCategory) do
					local incomingSetting = incomingCategory[settingName]
					if type(incomingSetting) == "table" and incomingSetting.Value ~= nil then
						local nextValue = cloneSerializable(incomingSetting.Value)
						setting.Value = nextValue
						self.overriddenSettings[categoryName .. "." .. settingName] = nil
						if setting.Element and type(setting.Element.Set) == "function" then
							local okSet, errSet = pcall(function()
								setting.Element:Set(nextValue)
							end)
							if not okSet then
								warnFn("Rayfield | Failed to apply internal setting '" .. categoryName .. "." .. settingName .. "': " .. tostring(errSet))
							end
						end
						appliedCount = appliedCount + 1
					end
				end
			end
		end

		return true, appliedCount
	end
end

return SettingsStoreModule
