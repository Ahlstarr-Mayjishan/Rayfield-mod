local SettingsUIModule = {}

function SettingsUIModule.attach(self, _options)
	local clamp = function(value, minValue, maxValue)
		local numeric = tonumber(value) or 0
		if numeric < minValue then
			return minValue
		end
		if numeric > maxValue then
			return maxValue
		end
		return numeric
	end

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
				self.pendingShareImportConfirmation = false
			end
			notifyShareCodeResult(success == true, message)
		end

		local function runImportSettings()
			local handlers = self.shareCodeHandlers
			if type(handlers) ~= "table" or type(handlers.importSettings) ~= "function" then
				notifyShareCodeResult(false, "Share code system unavailable.")
				return
			end

			local options = nil
			if self.pendingShareImportConfirmation then
				options = {
					confirmForeignDisplay = true
				}
			end
			local okCall, success, message, meta = pcall(handlers.importSettings, options)
			if not okCall then
				notifyShareCodeResult(false, tostring(success))
				return
			end

			if success ~= true and type(meta) == "table" and meta.confirmRequired == true then
				self.pendingShareImportConfirmation = true
			elseif success == true then
				self.pendingShareImportConfirmation = false
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
									local nextValue
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
				return false, "UI experience system unavailable.", nil, nil, nil
			end
			local handler = experienceHandlers[handlerName]
			if type(handler) ~= "function" then
				return false, "Handler unavailable: " .. tostring(handlerName), nil, nil, nil
			end
			local okCall, resultA, resultB, resultC, resultD = pcall(handler, ...)
			if not okCall then
				return false, tostring(resultA), nil, nil, nil
			end
			if type(resultA) == "boolean" then
				return resultA, resultB, resultC, resultD
			end
			return true, resultA, resultB, resultC
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
		local audioCustomPackDraft

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
				local numeric = clamp((tonumber(value) or 0) / 100, 0, 1)
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

		newTab:CreateSection("Workspaces")
		local workspaceCategory = self.settingsTable.Workspaces or {}
		local selectedWorkspaceName = tostring(self.getSetting("Workspaces", "active") or "")
		local workspaceDropdown = nil

		local function listWorkspaceOptions()
			local options = {"(None)"}
			local okList, workspaces = invokeExperience("listWorkspaces")
			if okList and type(workspaces) == "table" and #workspaces > 0 then
				options = {}
				for _, workspaceName in ipairs(workspaces) do
					table.insert(options, tostring(workspaceName))
				end
			end
			return options
		end

		local function refreshWorkspaceDropdown()
			if not workspaceDropdown then
				return
			end
			local options = listWorkspaceOptions()
			local target = options[1]
			for _, name in ipairs(options) do
				if tostring(name) == selectedWorkspaceName then
					target = name
					break
				end
			end
			if type(workspaceDropdown.Refresh) == "function" then
				workspaceDropdown:Refresh(options)
			end
			if type(workspaceDropdown.Set) == "function" and target then
				workspaceDropdown:Set(target)
			end
		end

		workspaceDropdown = newTab:CreateDropdown({
			Name = "Workspace",
			Options = listWorkspaceOptions(),
			CurrentOption = selectedWorkspaceName ~= "" and selectedWorkspaceName or nil,
			MultipleOptions = false,
			Ext = true,
			Callback = function(selection)
				local value = type(selection) == "table" and selection[1] or selection
				value = tostring(value or "")
				if value == "(None)" then
					value = ""
				end
				selectedWorkspaceName = value
				self.setSettingValue("Workspaces", "active", selectedWorkspaceName, true)
			end
		})
		if workspaceCategory.active then
			workspaceCategory.active.Element = workspaceDropdown
		end

		newTab:CreateButton({
			Name = "Save Current Workspace",
			Ext = true,
			Callback = function()
				local targetName = selectedWorkspaceName
				if targetName == "" then
					targetName = "Workspace-" .. tostring(os.time and os.time() or math.floor(os.clock() * 1000))
				end
				local okSave, message = invokeExperience("saveWorkspace", targetName)
				if okSave then
					selectedWorkspaceName = tostring(targetName)
					self.setSettingValue("Workspaces", "active", selectedWorkspaceName, false)
					refreshWorkspaceDropdown()
					self.saveSettings()
				end
				notifyExperienceResult(okSave, message)
			end
		})

		newTab:CreateButton({
			Name = "Load Selected Workspace",
			Ext = true,
			Callback = function()
				if selectedWorkspaceName == "" then
					notifyExperienceResult(false, "No workspace selected.")
					return
				end
				local okLoad, message = invokeExperience("loadWorkspace", selectedWorkspaceName)
				if okLoad then
					self.setSettingValue("Workspaces", "active", selectedWorkspaceName, true)
				end
				notifyExperienceResult(okLoad, message)
			end
		})

		newTab:CreateButton({
			Name = "Delete Selected Workspace",
			Ext = true,
			Callback = function()
				if selectedWorkspaceName == "" then
					notifyExperienceResult(false, "No workspace selected.")
					return
				end
				local okDelete, message = invokeExperience("deleteWorkspace", selectedWorkspaceName)
				if okDelete then
					selectedWorkspaceName = ""
					self.setSettingValue("Workspaces", "active", "", false)
					refreshWorkspaceDropdown()
					self.saveSettings()
				end
				notifyExperienceResult(okDelete, message)
			end
		})

		newTab:CreateButton({
			Name = "Refresh Workspaces",
			Ext = true,
			Callback = function()
				refreshWorkspaceDropdown()
				notifyExperienceResult(true, "Workspace list refreshed.")
			end
		})

		newTab:CreateSection("Profiles")
		local profileCategory = self.settingsTable.Profiles or {}
		local selectedProfileName = tostring(self.getSetting("Profiles", "active") or "")
		local profileDropdown = nil

		local function listProfileOptions()
			local options = {"(None)"}
			local okList, profiles = invokeExperience("listProfiles")
			if okList and type(profiles) == "table" and #profiles > 0 then
				options = {}
				for _, profileName in ipairs(profiles) do
					table.insert(options, tostring(profileName))
				end
			end
			return options
		end

		local function refreshProfileDropdown()
			if not profileDropdown then
				return
			end
			local options = listProfileOptions()
			local target = options[1]
			for _, name in ipairs(options) do
				if tostring(name) == selectedProfileName then
					target = name
					break
				end
			end
			if type(profileDropdown.Refresh) == "function" then
				profileDropdown:Refresh(options)
			end
			if type(profileDropdown.Set) == "function" and target then
				profileDropdown:Set(target)
			end
		end

		profileDropdown = newTab:CreateDropdown({
			Name = "Profile",
			Options = listProfileOptions(),
			CurrentOption = selectedProfileName ~= "" and selectedProfileName or nil,
			MultipleOptions = false,
			Ext = true,
			Callback = function(selection)
				local value = type(selection) == "table" and selection[1] or selection
				value = tostring(value or "")
				if value == "(None)" then
					value = ""
				end
				selectedProfileName = value
				self.setSettingValue("Profiles", "active", selectedProfileName, true)
			end
		})
		if profileCategory.active then
			profileCategory.active.Element = profileDropdown
		end

		newTab:CreateButton({
			Name = "Save Current Profile",
			Ext = true,
			Callback = function()
				local targetName = selectedProfileName
				if targetName == "" then
					targetName = "Profile-" .. tostring(os.time and os.time() or math.floor(os.clock() * 1000))
				end
				local okSave, message = invokeExperience("saveProfile", targetName)
				if okSave then
					selectedProfileName = tostring(targetName)
					self.setSettingValue("Profiles", "active", selectedProfileName, false)
					refreshProfileDropdown()
					self.saveSettings()
				end
				notifyExperienceResult(okSave, message)
			end
		})

		newTab:CreateButton({
			Name = "Load Selected Profile",
			Ext = true,
			Callback = function()
				if selectedProfileName == "" then
					notifyExperienceResult(false, "No profile selected.")
					return
				end
				local okLoad, message = invokeExperience("loadProfile", selectedProfileName)
				if okLoad then
					self.setSettingValue("Profiles", "active", selectedProfileName, true)
				end
				notifyExperienceResult(okLoad, message)
			end
		})

		newTab:CreateButton({
			Name = "Delete Selected Profile",
			Ext = true,
			Callback = function()
				if selectedProfileName == "" then
					notifyExperienceResult(false, "No profile selected.")
					return
				end
				local okDelete, message = invokeExperience("deleteProfile", selectedProfileName)
				if okDelete then
					selectedProfileName = ""
					self.setSettingValue("Profiles", "active", "", false)
					refreshProfileDropdown()
					self.saveSettings()
				end
				notifyExperienceResult(okDelete, message)
			end
		})

		newTab:CreateButton({
			Name = "Copy Workspace -> Profile",
			Ext = true,
			Callback = function()
				if selectedWorkspaceName == "" then
					notifyExperienceResult(false, "No workspace selected.")
					return
				end
				local targetName = selectedProfileName ~= "" and selectedProfileName or selectedWorkspaceName
				local okCopy, message = invokeExperience("copyWorkspaceToProfile", selectedWorkspaceName, targetName)
				if okCopy then
					selectedProfileName = targetName
					self.setSettingValue("Profiles", "active", selectedProfileName, false)
					refreshProfileDropdown()
					self.saveSettings()
				end
				notifyExperienceResult(okCopy, message)
			end
		})

		newTab:CreateButton({
			Name = "Copy Profile -> Workspace",
			Ext = true,
			Callback = function()
				if selectedProfileName == "" then
					notifyExperienceResult(false, "No profile selected.")
					return
				end
				local targetName = selectedWorkspaceName ~= "" and selectedWorkspaceName or selectedProfileName
				local okCopy, message = invokeExperience("copyProfileToWorkspace", selectedProfileName, targetName)
				if okCopy then
					selectedWorkspaceName = targetName
					self.setSettingValue("Workspaces", "active", selectedWorkspaceName, false)
					refreshWorkspaceDropdown()
					self.saveSettings()
				end
				notifyExperienceResult(okCopy, message)
			end
		})

		newTab:CreateButton({
			Name = "Refresh Profiles",
			Ext = true,
			Callback = function()
				refreshProfileDropdown()
				notifyExperienceResult(true, "Profile list refreshed.")
			end
		})

		newTab:CreateSection("Palette & HUD")
		newTab:CreateDropdown({
			Name = "Command Palette Mode",
			Options = {"auto", "jump", "execute", "ask"},
			CurrentOption = tostring(self.getSetting("UIExperience", "commandPaletteMode") or "auto"),
			MultipleOptions = false,
			Ext = true,
			Callback = function(selection)
				local value = type(selection) == "table" and selection[1] or selection
				value = tostring(value or "auto")
				local okSet, message = invokeExperience("setCommandPaletteExecutionMode", value)
				if okSet then
					self.setSettingValue("UIExperience", "commandPaletteMode", value, true)
				end
				notifyExperienceResult(okSet, message)
			end
		})

		newTab:CreateToggle({
			Name = "Performance HUD",
			CurrentValue = self.getSetting("UIExperience", "performanceHudEnabled") ~= false,
			Ext = true,
			Callback = function(value)
				local boolValue = value == true
				local okToggle, message = invokeExperience(boolValue and "openPerformanceHUD" or "closePerformanceHUD")
				if okToggle then
					self.setSettingValue("UIExperience", "performanceHudEnabled", boolValue, true)
				end
				notifyExperienceResult(okToggle, message)
			end
		})

		newTab:CreateSection("Localization")
		local selectedLocalizationControlId = ""
		local localizationControlLookup = {}
		local localizationControlDropdown = nil
		local localizationLabelInput = nil
		local localizationLanguageInput = nil

		local function listLocalizationControlOptions()
			local options = {"(None)"}
			local lookup = {}
			local okList, controls = invokeExperience("listControls", true)
			if okList and type(controls) == "table" and #controls > 0 then
				options = {}
				for _, control in ipairs(controls) do
					if type(control) == "table" then
						local display = tostring(control.displayName or control.name or control.id or "Control")
						local internalName = tostring(control.internalName or control.name or "")
						local key = tostring(control.localizationKey or control.flag or control.id or "")
						local id = tostring(control.id or key)
						local line = string.format("%s | %s", display, key ~= "" and key or id)
						if internalName ~= "" and internalName ~= display then
							line = string.format("%s (%s) | %s", display, internalName, key ~= "" and key or id)
						end
						table.insert(options, line)
						lookup[line] = id
					end
				end
			end
			return options, lookup
		end

		local function refreshLocalizationStateInputs()
			local okState, state = invokeExperience("getLocalizationState")
			if not okState or type(state) ~= "table" then
				return
			end
			if localizationLanguageInput and type(localizationLanguageInput.Set) == "function" then
				localizationLanguageInput:Set(tostring(state.meta and state.meta.languageTag or "en"))
			end
			self.setSettingValue("Localization", "activeScope", tostring(state.scopeKey or ""), false)
			self.setSettingValue("Localization", "scopeMode", tostring(state.scopeMode or "hybrid_migrate"), false)
			self.setSettingValue("Localization", "lastLanguageTag", tostring(state.meta and state.meta.languageTag or "en"), false)
			self.saveSettings()
		end

		local function refreshLocalizationControls()
			if not localizationControlDropdown then
				return
			end
			local options, lookup = listLocalizationControlOptions()
			localizationControlLookup = lookup
			if #options == 0 then
				options = {"(None)"}
			end
			local target = options[1]
			for _, option in ipairs(options) do
				local id = lookup[option]
				if id and id == selectedLocalizationControlId then
					target = option
					break
				end
			end
			if type(localizationControlDropdown.Refresh) == "function" then
				localizationControlDropdown:Refresh(options)
			end
			if type(localizationControlDropdown.Set) == "function" and target then
				localizationControlDropdown:Set(target)
			end
		end

		localizationControlDropdown = newTab:CreateDropdown({
			Name = "Control",
			Options = {"(None)"},
			CurrentOption = "(None)",
			MultipleOptions = false,
			Ext = true,
			Callback = function(selection)
				local value = type(selection) == "table" and selection[1] or selection
				value = tostring(value or "")
				selectedLocalizationControlId = tostring(localizationControlLookup[value] or "")
				if selectedLocalizationControlId ~= "" then
					local okLabel, currentLabel = invokeExperience("getControlDisplayLabel", selectedLocalizationControlId)
					if okLabel and localizationLabelInput and type(localizationLabelInput.Set) == "function" then
						localizationLabelInput:Set(tostring(currentLabel or ""))
					end
				end
			end
		})

		localizationLabelInput = newTab:CreateInput({
			Name = "Display Label",
			CurrentValue = "",
			PlaceholderText = "Localized display text",
			Ext = true,
			RemoveTextAfterFocusLost = false,
			Callback = function(value)
				local _ = value
			end
		})

		newTab:CreateButton({
			Name = "Apply Label",
			Ext = true,
			Callback = function()
				if selectedLocalizationControlId == "" then
					notifyExperienceResult(false, "No control selected.")
					return
				end
				local label = localizationLabelInput and localizationLabelInput.CurrentValue or ""
				local ok, message = invokeExperience("setControlDisplayLabel", selectedLocalizationControlId, tostring(label or ""))
				if ok then
					refreshLocalizationControls()
				end
				notifyExperienceResult(ok, message)
			end
		})

		newTab:CreateButton({
			Name = "Reset Label",
			Ext = true,
			Callback = function()
				if selectedLocalizationControlId == "" then
					notifyExperienceResult(false, "No control selected.")
					return
				end
				local ok, message = invokeExperience("resetControlDisplayLabel", selectedLocalizationControlId)
				if ok then
					if localizationLabelInput and type(localizationLabelInput.Set) == "function" then
						localizationLabelInput:Set("")
					end
					refreshLocalizationControls()
				end
				notifyExperienceResult(ok, message)
			end
		})

		newTab:CreateButton({
			Name = "Refresh Controls",
			Ext = true,
			Callback = function()
				refreshLocalizationControls()
				notifyExperienceResult(true, "Localization controls refreshed.")
			end
		})

		newTab:CreateButton({
			Name = "Reset To English",
			Ext = true,
			Callback = function()
				local ok, message = invokeExperience("resetDisplayLanguage", { languageTag = "en" })
				if ok then
					if localizationLabelInput and type(localizationLabelInput.Set) == "function" then
						localizationLabelInput:Set("")
					end
					refreshLocalizationControls()
					refreshLocalizationStateInputs()
				end
				notifyExperienceResult(ok, message)
			end
		})

		localizationLanguageInput = newTab:CreateInput({
			Name = "Language Tag",
			CurrentValue = tostring(self.getSetting("Localization", "lastLanguageTag") or "en"),
			PlaceholderText = "en, vi, zh-CN, th, ...",
			Ext = true,
			RemoveTextAfterFocusLost = false,
			Callback = function(value)
				local trimmed = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
				if trimmed == "" then
					trimmed = "en"
				end
				local okSet, languageTag = invokeExperience("setLocalizationLanguageTag", trimmed)
				if okSet then
					self.setSettingValue("Localization", "lastLanguageTag", tostring(languageTag or trimmed), true)
				end
				notifyExperienceResult(okSet, okSet and ("Language tag set: " .. tostring(languageTag or trimmed)) or languageTag)
			end
		})

		self.localizationPackInput = newTab:CreateInput({
			Name = "Localization Pack",
			CurrentValue = tostring(self.localizationPackDraft or ""),
			PlaceholderText = "Paste exported localization JSON",
			Ext = true,
			RemoveTextAfterFocusLost = false,
			Callback = function(value)
				self.localizationPackDraft = tostring(value or "")
			end
		})

		newTab:CreateButton({
			Name = "Export Localization Pack",
			Ext = true,
			Callback = function()
				local okExport, payloadOrErr = invokeExperience("exportLocalization", { asJson = true })
				if okExport and type(payloadOrErr) == "string" and payloadOrErr ~= "" then
					self.localizationPackDraft = payloadOrErr
					if self.localizationPackInput and type(self.localizationPackInput.Set) == "function" then
						self.localizationPackInput:Set(payloadOrErr)
					end
					notifyExperienceResult(true, "Localization pack exported.")
				else
					notifyExperienceResult(false, payloadOrErr)
				end
			end
		})

		newTab:CreateButton({
			Name = "Import Localization Pack",
			Ext = true,
			Callback = function()
				local payload = tostring(self.localizationPackDraft or "")
				if payload == "" then
					notifyExperienceResult(false, "Localization buffer is empty.")
					return
				end
				local okImport, message = invokeExperience("importLocalization", payload, { merge = false })
				if okImport then
					refreshLocalizationControls()
					refreshLocalizationStateInputs()
				end
				notifyExperienceResult(okImport, message)
			end
		})

		refreshLocalizationControls()
		refreshLocalizationStateInputs()

		newTab:CreateSection("Theme Studio")
		local themeCategory = self.settingsTable.ThemeStudio or {}
		local themeColorElements = {}
		local themeBaseDropdown

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
		if type(self.syncShareCodeInputFromHandlers) == "function" then
			self.syncShareCodeInputFromHandlers()
		end
		self.loadSettings()
		self.saveSettings()
	end
end

return SettingsUIModule
