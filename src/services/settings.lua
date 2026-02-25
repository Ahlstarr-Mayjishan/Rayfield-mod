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
	},
	Appearance = {
		uiPreset = {
			Type = "dropdown",
			Value = "Comfort",
			Name = "UI Preset",
			Options = {"Compact", "Comfort", "Focus", "Cripware"}
		},
		transitionProfile = {
			Type = "dropdown",
			Value = "Smooth",
			Name = "Transition Profile",
			Options = {"Minimal", "Smooth", "Snappy", "Off"}
		}
	},
	Favorites = {
		showPinBadges = {Type = "toggle", Value = true, Name = "Show Pin Badges"},
		pinnedIds = {Type = "hidden", Value = {}, Name = "Pinned Control IDs"}
	},
	Onboarding = {
		suppressed = {Type = "hidden", Value = false, Name = "Onboarding Suppressed"}
	},
	ThemeStudio = {
		baseTheme = {Type = "hidden", Value = "Default", Name = "Base Theme"},
		useCustom = {Type = "toggle", Value = false, Name = "Use Custom Theme"},
		customThemePacked = {Type = "hidden", Value = {}, Name = "Custom Theme Colors"}
	},
	Audio = {
		enabled = {Type = "toggle", Value = false, Name = "Enable Audio Feedback"},
		pack = {
			Type = "dropdown",
			Value = "Mute",
			Name = "Audio Pack",
			Options = {"Mute", "Custom"}
		},
		volume = {Type = "hidden", Value = 0.45, Name = "Audio Volume"},
		customPack = {Type = "hidden", Value = {}, Name = "Custom Audio Pack"}
	},
	Glass = {
		mode = {
			Type = "dropdown",
			Value = "auto",
			Name = "Glass Mode",
			Options = {"auto", "off", "canvas", "fallback"}
		},
		intensity = {Type = "hidden", Value = 0.32, Name = "Glass Intensity"}
	},
	Layout = {
		collapsedSections = {Type = "hidden", Value = {}, Name = "Collapsed Sections"}
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
	self.shareCodeHandlers = {}
	self.shareCodeDraft = ""
	self.shareCodeInput = nil
	self.experienceHandlers = {}

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
	
	-- Initialize settings table with defaults
	for category, settings in pairs(SettingsModule.defaultSettings) do
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
	
	-- Override a setting value
	function self.overrideSetting(category, name, value)
		self.overriddenSettings[category .. "." .. name] = value
	end
	
	-- Get setting value (checks overrides first)
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
			local okSet = pcall(function()
				setting.Element:Set(nextValue)
			end)
			if not okSet then
				-- Keep in-memory value even if UI element fails.
			end
		end

		if persist ~= false then
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
								warn("Rayfield | Failed to apply internal setting '" .. categoryName .. "." .. settingName .. "': " .. tostring(errSet))
							end
						end
						appliedCount += 1
					end
				end
			end
		end

		return true, appliedCount
	end

	function self.getShareCodeInputValue()
		return tostring(self.shareCodeDraft or "")
	end

	function self.setShareCodeInputValue(value)
		self.shareCodeDraft = tostring(value or "")
		if self.shareCodeInput and type(self.shareCodeInput.Set) == "function" then
			pcall(function()
				self.shareCodeInput:Set(self.shareCodeDraft)
			end)
		end
		return self.shareCodeDraft
	end

	local function syncShareCodeInputFromHandlers()
		local handlers = self.shareCodeHandlers
		if type(handlers) ~= "table" then
			return
		end
		if type(handlers.getActiveShareCode) ~= "function" then
			return
		end

		local okGet, code = pcall(handlers.getActiveShareCode)
		if okGet and type(code) == "string" then
			self.setShareCodeInputValue(code)
		end
	end

	function self.setShareCodeHandlers(handlers)
		if type(handlers) == "table" then
			self.shareCodeHandlers = handlers
		else
			self.shareCodeHandlers = {}
		end
		syncShareCodeInputFromHandlers()
	end

	function self.setExperienceHandlers(handlers)
		if type(handlers) == "table" then
			self.experienceHandlers = handlers
		else
			self.experienceHandlers = {}
		end
	end
	
	-- Save settings to file
	function self.saveSettings()
		local encoded
		local success, err = pcall(function()
			encoded = self.HttpService:JSONEncode(buildInternalSettingsData())
		end)

		if success then
			if self.useStudio then
				if script.Parent['get.val'] then
					script.Parent['get.val'].Value = encoded
				end
			end
			if type(writefile) ~= "function" then
				return self.useStudio == true
			end
			local writeResult = self.callSafely(writefile, self.RayfieldFolder..'/settings'..self.ConfigurationExtension, encoded)
			return writeResult ~= false
		end
		return false
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

		task.spawn(function()
			local ok, err = xpcall(function()
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
									setting.Value = cloneSerializable(file[categoryName][settingName].Value)
									if setting.Element and type(setting.Element.Set) == "function" then
										setting.Element:Set(self.getSetting(categoryName, settingName))
									end
								end
							end
						end
					end
				else
					for settingName, settingValue in pairs(self.overriddenSettings) do
						local split = string.split(settingName, ".")
						assert(#split == 2, "Rayfield | Invalid overridden setting name: " .. settingName)
						local categoryName = split[1]
						local settingNameOnly = split[2]
						if self.settingsTable[categoryName] and self.settingsTable[categoryName][settingNameOnly] then
							local targetSetting = self.settingsTable[categoryName][settingNameOnly]
							if targetSetting.Element and type(targetSetting.Element.Set) == "function" then
								targetSetting.Element:Set(settingValue)
							else
								targetSetting.Value = cloneSerializable(settingValue)
							end
						end
					end
				end
				self.settingsInitialized = true
			end, debug.traceback)
			if not ok then
				warn("Rayfield | Failed to load settings: " .. tostring(err))
			end
		end)
	end


	-- Create settings UI tab
	function self.createSettings(window)
		local hasFilePersistence = type(writefile) == "function"
			and type(isfile) == "function"
			and type(readfile) == "function"
			and type(isfolder) == "function"
			and type(makefolder) == "function"

		local newTab = window:CreateTab('Rayfield Settings', 0, true)

		if self.TabList['Rayfield Settings'] then
			self.TabList['Rayfield Settings'].LayoutOrder = 1000
		end

		if self.Elements['Rayfield Settings'] then
			self.Elements['Rayfield Settings'].LayoutOrder = 1000
		end

		if not hasFilePersistence and not self.useStudio then
			warn("Rayfield | File APIs are unavailable. Settings, Theme Studio, and Share Code will run in session-only mode.")
			newTab:CreateSection("Session")
			newTab:CreateParagraph({
				Title = "Session-only settings",
				Content = "File APIs are not available. Export/import code and UI customization still work, but local file persistence is disabled for this session."
			})
		end

		local function notifyShareCodeResult(success, message)
			local handlers = self.shareCodeHandlers
			if type(handlers) == "table" and type(handlers.notify) == "function" then
				local okNotify = pcall(handlers.notify, success == true, tostring(message or ""))
				if okNotify then
					return
				end
			end
			if success ~= true then
				warn("Rayfield | " .. tostring(message or "Share code operation failed."))
			end
		end

		local function runImportCode()
			local handlers = self.shareCodeHandlers
			if type(handlers) ~= "table" or type(handlers.importCode) ~= "function" then
				notifyShareCodeResult(false, "Share code system unavailable.")
				return
			end

			local okCall, success, message = pcall(handlers.importCode, tostring(self.shareCodeDraft or ""))
			if not okCall then
				notifyShareCodeResult(false, tostring(success))
				return
			end

			if success == true and type(handlers.getActiveShareCode) == "function" then
				local okGet, code = pcall(handlers.getActiveShareCode)
				if okGet and type(code) == "string" then
					self.setShareCodeInputValue(code)
				end
			end
			notifyShareCodeResult(success == true, message)
		end

		local function runImportSettings()
			local handlers = self.shareCodeHandlers
			if type(handlers) ~= "table" or type(handlers.importSettings) ~= "function" then
				notifyShareCodeResult(false, "Share code system unavailable.")
				return
			end

			local okCall, success, message = pcall(handlers.importSettings)
			if not okCall then
				notifyShareCodeResult(false, tostring(success))
				return
			end

			if type(handlers.getActiveShareCode) == "function" then
				local okGet, code = pcall(handlers.getActiveShareCode)
				if okGet and type(code) == "string" then
					self.setShareCodeInputValue(code)
				end
			end
			notifyShareCodeResult(success == true, message)
		end

		local function runExportSettings()
			local handlers = self.shareCodeHandlers
			if type(handlers) ~= "table" or type(handlers.exportSettings) ~= "function" then
				notifyShareCodeResult(false, "Share code system unavailable.")
				return
			end

			local okCall, exportedCode, message = pcall(handlers.exportSettings)
			if not okCall then
				notifyShareCodeResult(false, tostring(exportedCode))
				return
			end

			local success = type(exportedCode) == "string" and exportedCode ~= ""
			if success then
				self.setShareCodeInputValue(exportedCode)
			elseif type(handlers.getActiveShareCode) == "function" then
				local okGet, code = pcall(handlers.getActiveShareCode)
				if okGet and type(code) == "string" then
					self.setShareCodeInputValue(code)
				end
			end
			notifyShareCodeResult(success, message)
		end

		local function runCopyShareCode()
			local handlers = self.shareCodeHandlers
			if type(handlers) ~= "table" or type(handlers.copyShareCode) ~= "function" then
				notifyShareCodeResult(false, "Share code system unavailable.")
				return
			end

			local okCall, success, message = pcall(handlers.copyShareCode)
			if not okCall then
				notifyShareCodeResult(false, tostring(success))
				return
			end

			if type(handlers.getActiveShareCode) == "function" then
				local okGet, code = pcall(handlers.getActiveShareCode)
				if okGet and type(code) == "string" then
					self.setShareCodeInputValue(code)
				end
			end
			notifyShareCodeResult(success == true, message)
		end

		local function notifyExperienceResult(success, message)
			local handlers = self.experienceHandlers
			if type(handlers) == "table" and type(handlers.notify) == "function" then
				local okNotify = pcall(handlers.notify, success == true, tostring(message or ""))
				if okNotify then
					return
				end
			end
			if success ~= true then
				warn("Rayfield | " .. tostring(message or "UI experience operation failed."))
			end
		end

		local genericSkipCategories = {
			Appearance = true,
			Favorites = true,
			ThemeStudio = true,
			Onboarding = true,
			Audio = true,
			Glass = true
		}

		-- Create generic sections and elements
		for categoryName, settingCategory in pairs(self.settingsTable) do
			if not genericSkipCategories[categoryName] then
				local sectionCreated = false
				for settingName, setting in pairs(settingCategory) do
					if setting.Type ~= "hidden" then
						if not sectionCreated then
							newTab:CreateSection(categoryName)
							sectionCreated = true
						end

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
						elseif setting.Type == "dropdown" then
							setting.Element = newTab:CreateDropdown({
								Name = setting.Name,
								Options = setting.Options or {},
								CurrentOption = setting.Value,
								MultipleOptions = false,
								Ext = true,
								Callback = function(selection)
									local nextValue = nil
									if type(selection) == "table" then
										nextValue = selection[1]
									else
										nextValue = selection
									end
									self.updateSetting(categoryName, settingName, tostring(nextValue or ""))
								end
							})
						end
					end
				end
			end
		end

		local function invokeExperience(handlerName, ...)
			local experienceHandlers = self.experienceHandlers
			if type(experienceHandlers) ~= "table" then
				return false, "UI experience system unavailable.", nil
			end
			local handler = experienceHandlers[handlerName]
			if type(handler) ~= "function" then
				return false, "Handler unavailable: " .. tostring(handlerName), nil
			end
			local okCall, resultA, resultB = pcall(handler, ...)
			if not okCall then
				return false, tostring(resultA), nil
			end
			if type(resultA) == "boolean" then
				return resultA, resultB, nil
			end
			return true, resultA, resultB
		end

		newTab:CreateSection("Experience")
		local appearanceCategory = self.settingsTable.Appearance or {}
		local uiPresetSetting = appearanceCategory.uiPreset
		local transitionSetting = appearanceCategory.transitionProfile

		if uiPresetSetting then
			uiPresetSetting.Element = newTab:CreateDropdown({
				Name = uiPresetSetting.Name or "UI Preset",
				Options = uiPresetSetting.Options or {"Compact", "Comfort", "Focus", "Cripware"},
				CurrentOption = self.getSetting("Appearance", "uiPreset") or uiPresetSetting.Value,
				MultipleOptions = false,
				Ext = true,
				Callback = function(selection)
					local value = type(selection) == "table" and selection[1] or selection
					value = tostring(value or "")
					local ok, message = invokeExperience("setUIPreset", value)
					if ok then
						self.updateSetting("Appearance", "uiPreset", value)
					end
					notifyExperienceResult(ok, message)
				end
			})
		end

		if transitionSetting then
			transitionSetting.Element = newTab:CreateDropdown({
				Name = transitionSetting.Name or "Transition Profile",
				Options = transitionSetting.Options or {"Minimal", "Smooth", "Snappy", "Off"},
				CurrentOption = self.getSetting("Appearance", "transitionProfile") or transitionSetting.Value,
				MultipleOptions = false,
				Ext = true,
				Callback = function(selection)
					local value = type(selection) == "table" and selection[1] or selection
					value = tostring(value or "")
					local ok, message = invokeExperience("setTransitionProfile", value)
					if ok then
						self.updateSetting("Appearance", "transitionProfile", value)
					end
					notifyExperienceResult(ok, message)
				end
			})
		end

		newTab:CreateButton({
			Name = "Replay Onboarding",
			Ext = true,
			Callback = function()
				local ok, message = invokeExperience("showOnboarding", true)
				notifyExperienceResult(ok, message)
			end
		})

		newTab:CreateSection("Premium UX")
		local audioCategory = self.settingsTable.Audio or {}
		local glassCategory = self.settingsTable.Glass or {}
		local audioCustomPackDraft = ""

		local function encodeJsonSafe(value, fallback)
			local okEncode, encoded = pcall(self.HttpService.JSONEncode, self.HttpService, value)
			if okEncode and type(encoded) == "string" then
				return encoded
			end
			return tostring(fallback or "{}")
		end

		local audioEnabledSetting = audioCategory.enabled
		if audioEnabledSetting then
			audioEnabledSetting.Element = newTab:CreateToggle({
				Name = audioEnabledSetting.Name or "Enable Audio Feedback",
				CurrentValue = self.getSetting("Audio", "enabled") == true,
				Ext = true,
				Callback = function(value)
					local boolValue = value == true
					local ok, message = invokeExperience("setAudioEnabled", boolValue)
					if ok then
						self.setSettingValue("Audio", "enabled", boolValue, true)
					end
					notifyExperienceResult(ok, message)
				end
			})
		end

		local audioPackSetting = audioCategory.pack
		if audioPackSetting then
			audioPackSetting.Element = newTab:CreateDropdown({
				Name = audioPackSetting.Name or "Audio Pack",
				Options = audioPackSetting.Options or {"Mute", "Custom"},
				CurrentOption = self.getSetting("Audio", "pack") or audioPackSetting.Value or "Mute",
				MultipleOptions = false,
				Ext = true,
				Callback = function(selection)
					local value = type(selection) == "table" and selection[1] or selection
					value = tostring(value or "Mute")
					local ok, message = invokeExperience("setAudioPack", value)
					if ok then
						self.setSettingValue("Audio", "pack", value, true)
					end
					notifyExperienceResult(ok, message)
				end
			})
		end

		local storedCustomPack = self.getSetting("Audio", "customPack")
		if type(storedCustomPack) ~= "table" then
			storedCustomPack = {}
		end
		audioCustomPackDraft = encodeJsonSafe(storedCustomPack, "{}")

		local audioPackInput = newTab:CreateInput({
			Name = "Custom Audio Pack (JSON)",
			CurrentValue = audioCustomPackDraft,
			PlaceholderText = "{\"click\":\"rbxassetid://...\"}",
			Ext = true,
			RemoveTextAfterFocusLost = false,
			Callback = function(value)
				audioCustomPackDraft = tostring(value or "")
			end
		})

		newTab:CreateButton({
			Name = "Apply Custom Audio Pack",
			Ext = true,
			Callback = function()
				if audioCustomPackDraft == "" then
					notifyExperienceResult(false, "Custom audio pack JSON is empty.")
					return
				end
				local okApply, message, normalizedPack = invokeExperience("setAudioPackJson", audioCustomPackDraft)
				if okApply then
					if type(normalizedPack) == "table" then
						self.setSettingValue("Audio", "customPack", normalizedPack, false)
						audioCustomPackDraft = encodeJsonSafe(normalizedPack, audioCustomPackDraft)
						if audioPackInput and type(audioPackInput.Set) == "function" then
							audioPackInput:Set(audioCustomPackDraft)
						end
					end
					self.setSettingValue("Audio", "pack", "Custom", true)
					if audioPackSetting and audioPackSetting.Element and type(audioPackSetting.Element.Set) == "function" then
						audioPackSetting.Element:Set("Custom")
					end
				end
				notifyExperienceResult(okApply, message)
			end
		})

		local glassModeSetting = glassCategory.mode
		if glassModeSetting then
			glassModeSetting.Element = newTab:CreateDropdown({
				Name = glassModeSetting.Name or "Glass Mode",
				Options = glassModeSetting.Options or {"auto", "off", "canvas", "fallback"},
				CurrentOption = self.getSetting("Glass", "mode") or glassModeSetting.Value or "auto",
				MultipleOptions = false,
				Ext = true,
				Callback = function(selection)
					local value = type(selection) == "table" and selection[1] or selection
					value = string.lower(tostring(value or "auto"))
					local ok, message = invokeExperience("setGlassMode", value)
					if ok then
						self.setSettingValue("Glass", "mode", value, true)
					end
					notifyExperienceResult(ok, message)
				end
			})
		end

		newTab:CreateSlider({
			Name = "Glass Intensity",
			Range = {0, 100},
			Increment = 1,
			CurrentValue = math.floor((tonumber(self.getSetting("Glass", "intensity")) or 0.32) * 100 + 0.5),
			Ext = true,
			Callback = function(value)
				local numeric = math.clamp((tonumber(value) or 0) / 100, 0, 1)
				local ok, message = invokeExperience("setGlassIntensity", numeric)
				if ok then
					self.setSettingValue("Glass", "intensity", numeric, true)
				else
					notifyExperienceResult(false, message)
				end
			end
		})

		newTab:CreateButton({
			Name = "Replay Guided Tour",
			Ext = true,
			Callback = function()
				local ok, message = invokeExperience("showOnboarding", true)
				notifyExperienceResult(ok, message)
			end
		})

		newTab:CreateSection("Favorites Manager")
		local favoritesCategory = self.settingsTable.Favorites or {}
		local selectedFavoriteId = ""
		local favoritesOptionMap = {}
		local favoritesOptionOrder = {}
		local favoritesDropdownElement = nil

		local function listFavoriteControlOptions()
			favoritesOptionMap = {}
			favoritesOptionOrder = {}
			local fallback = "(No controls found)"
			local options = { fallback }
			favoritesOptionMap[fallback] = nil

			local controls = nil
			local okList, listOrMessage = invokeExperience("listControls", true)
			if okList and type(listOrMessage) == "table" and #listOrMessage > 0 then
				controls = listOrMessage
			end
			if type(controls) == "table" and #controls > 0 then
				options = {}
				for _, control in ipairs(controls) do
					local controlId = tostring(control.id or "")
					if controlId ~= "" then
						local label = string.format("[%s] %s (%s)", tostring(control.type or "Element"), tostring(control.name or controlId), controlId)
						table.insert(options, label)
						favoritesOptionMap[label] = controlId
						table.insert(favoritesOptionOrder, controlId)
					end
				end
			end

			return options
		end

		local function refreshFavoritesDropdown()
			local options = listFavoriteControlOptions()
			local targetLabel = options[1]
			for _, label in ipairs(options) do
				if favoritesOptionMap[label] == selectedFavoriteId then
					targetLabel = label
					break
				end
			end

			if favoritesDropdownElement and type(favoritesDropdownElement.Refresh) == "function" then
				favoritesDropdownElement:Refresh(options)
				if type(favoritesDropdownElement.Set) == "function" and targetLabel then
					favoritesDropdownElement:Set(targetLabel)
				end
			end
		end

		favoritesDropdownElement = newTab:CreateDropdown({
			Name = "Control",
			Options = listFavoriteControlOptions(),
			CurrentOption = nil,
			MultipleOptions = false,
			Ext = true,
			Callback = function(selection)
				local label = type(selection) == "table" and selection[1] or selection
				selectedFavoriteId = favoritesOptionMap[tostring(label or "")] or ""
			end
		})

		local showPinBadgesSetting = favoritesCategory.showPinBadges
		if showPinBadgesSetting then
			showPinBadgesSetting.Element = newTab:CreateToggle({
				Name = showPinBadgesSetting.Name or "Show Pin Badges",
				CurrentValue = self.getSetting("Favorites", "showPinBadges"),
				Ext = true,
				Callback = function(value)
					self.updateSetting("Favorites", "showPinBadges", value == true)
					local okPin, message = invokeExperience("setPinBadgesVisible", value == true)
					notifyExperienceResult(okPin, message)
				end
			})
			local okInit, message = invokeExperience("setPinBadgesVisible", self.getSetting("Favorites", "showPinBadges") ~= false)
			if not okInit then
				notifyExperienceResult(false, message)
			end
		end

		newTab:CreateButton({
			Name = "Pin Selected",
			Ext = true,
			Callback = function()
				if selectedFavoriteId == "" then
					notifyExperienceResult(false, "No control selected.")
					return
				end
				local ok, message = invokeExperience("pinControl", selectedFavoriteId)
				notifyExperienceResult(ok, message)
				refreshFavoritesDropdown()
			end
		})

		newTab:CreateButton({
			Name = "Unpin Selected",
			Ext = true,
			Callback = function()
				if selectedFavoriteId == "" then
					notifyExperienceResult(false, "No control selected.")
					return
				end
				local ok, message = invokeExperience("unpinControl", selectedFavoriteId)
				notifyExperienceResult(ok, message)
				refreshFavoritesDropdown()
			end
		})

		newTab:CreateButton({
			Name = "Refresh Controls",
			Ext = true,
			Callback = function()
				refreshFavoritesDropdown()
				notifyExperienceResult(true, "Control list refreshed.")
			end
		})

		newTab:CreateButton({
			Name = "Open Favorites Tab",
			Ext = true,
			Callback = function()
				local ok, message = invokeExperience("openFavoritesTab")
				notifyExperienceResult(ok, message)
			end
		})

		newTab:CreateSection("Theme Studio")
		local themeCategory = self.settingsTable.ThemeStudio or {}
		local themeColorElements = {}
		local themeBaseDropdown = nil

		local function listThemeNames()
			local okNames, names = invokeExperience("getThemeNames")
			if okNames and type(names) == "table" and #names > 0 then
				return names
			end
			return {"Default"}
		end

		local function getThemeColorValue(themeKey)
			local okColor, color = invokeExperience("getThemeStudioColor", themeKey)
			if okColor and typeof(color) == "Color3" then
				return color
			end
			return Color3.fromRGB(255, 255, 255)
		end

		local baseThemeSetting = themeCategory.baseTheme
		themeBaseDropdown = newTab:CreateDropdown({
			Name = "Base Theme",
			Options = listThemeNames(),
			CurrentOption = self.getSetting("ThemeStudio", "baseTheme") or "Default",
			MultipleOptions = false,
			Ext = true,
				Callback = function(selection)
					local value = type(selection) == "table" and selection[1] or selection
					value = tostring(value or "Default")
					local ok, message = invokeExperience("setThemeStudioBaseTheme", value)
					if ok then
						self.setSettingValue("ThemeStudio", "baseTheme", value, true)
					end
				notifyExperienceResult(ok, message)
			end
		})
		if baseThemeSetting then
			baseThemeSetting.Element = themeBaseDropdown
		end

		local useCustomSetting = themeCategory.useCustom
		if useCustomSetting then
			useCustomSetting.Element = newTab:CreateToggle({
				Name = useCustomSetting.Name or "Use Custom Theme",
				CurrentValue = self.getSetting("ThemeStudio", "useCustom") == true,
				Ext = true,
				Callback = function(value)
					local boolValue = value == true
					local ok, message = invokeExperience("setThemeStudioUseCustom", boolValue)
					if ok then
						self.setSettingValue("ThemeStudio", "useCustom", boolValue, true)
					end
					notifyExperienceResult(ok, message)
				end
			})
		end

		local themeKeys = {}
		local okThemeKeys, resolvedThemeKeys = invokeExperience("getThemeStudioKeys")
		if okThemeKeys and type(resolvedThemeKeys) == "table" then
			themeKeys = resolvedThemeKeys
		end
		for _, themeKey in ipairs(themeKeys) do
			local keyName = tostring(themeKey)
			themeColorElements[keyName] = newTab:CreateColorPicker({
				Name = keyName,
				Color = getThemeColorValue(keyName),
				Ext = true,
				Callback = function(color)
					local okColor, message = invokeExperience("setThemeStudioColor", keyName, color)
					if okColor then
						self.setSettingValue("ThemeStudio", "useCustom", true, false)
						local packedSetting = self.getSetting("ThemeStudio", "customThemePacked")
						if type(packedSetting) ~= "table" then
							packedSetting = {}
						end
						packedSetting[keyName] = {
							R = math.floor(color.R * 255 + 0.5),
							G = math.floor(color.G * 255 + 0.5),
							B = math.floor(color.B * 255 + 0.5)
						}
						self.setSettingValue("ThemeStudio", "customThemePacked", packedSetting, false)
					end
					notifyExperienceResult(okColor, message)
				end
			})
		end

		newTab:CreateButton({
			Name = "Apply Draft",
			Ext = true,
			Callback = function()
				local ok, message = invokeExperience("applyThemeStudioDraft")
				notifyExperienceResult(ok, message)
			end
		})

		newTab:CreateButton({
			Name = "Reset To Base",
			Ext = true,
			Callback = function()
				local ok, message = invokeExperience("resetThemeStudio")
				if ok then
					self.setSettingValue("ThemeStudio", "useCustom", false, false)
					self.setSettingValue("ThemeStudio", "customThemePacked", {}, false)
					if useCustomSetting and useCustomSetting.Element and type(useCustomSetting.Element.Set) == "function" then
						useCustomSetting.Element:Set(false)
					end
					if themeBaseDropdown and type(themeBaseDropdown.Set) == "function" then
						local nextBase = self.getSetting("ThemeStudio", "baseTheme") or "Default"
						themeBaseDropdown:Set(nextBase)
					end
					for keyName, colorElement in pairs(themeColorElements) do
						if colorElement and type(colorElement.Set) == "function" then
							colorElement:Set(getThemeColorValue(keyName))
						end
					end
					self.saveSettings()
				end
				notifyExperienceResult(ok, message)
			end
		})

		newTab:CreateSection("Share Code")

		self.shareCodeInput = newTab:CreateInput({
			Name = "Share Code",
			CurrentValue = self.getShareCodeInputValue(),
			PlaceholderText = "Paste RFSC1 share code here",
			Ext = true,
			RemoveTextAfterFocusLost = false,
			Callback = function(value)
				self.shareCodeDraft = tostring(value or "")
			end,
		})

		newTab:CreateButton({
			Name = "Import Code",
			Ext = true,
			Callback = runImportCode,
		})

		newTab:CreateButton({
			Name = "Import Settings",
			Ext = true,
			Callback = runImportSettings,
		})

		newTab:CreateButton({
			Name = "Export Settings",
			Ext = true,
			Callback = runExportSettings,
		})

		newTab:CreateButton({
			Name = "Copy Share code",
			Ext = true,
			Callback = runCopyShareCode,
		})

		self.settingsCreated = true
		syncShareCodeInputFromHandlers()
		self.loadSettings()
		self.saveSettings()
	end

	return self
end

return SettingsModule
