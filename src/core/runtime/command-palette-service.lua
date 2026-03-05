local CommandPaletteService = {}

local function shallowCopy(input)
	local out = {}
	for key, value in pairs(input or {}) do
		out[key] = value
	end
	return out
end

local function lowerText(value)
	return string.lower(tostring(value or ""))
end

local function normalizeMode(mode, fallback)
	local value = lowerText(mode or fallback or "auto")
	if value ~= "auto" and value ~= "jump" and value ~= "execute" and value ~= "ask" then
		return lowerText(fallback or "auto")
	end
	return value
end

function CommandPaletteService.create(ctx)
	ctx = ctx or {}
	local usageAnalytics = type(ctx.usageAnalytics) == "table" and ctx.usageAnalytics or nil
	local maxResults = tonumber(type(_G) == "table" and _G.__RAYFIELD_COMMAND_PALETTE_MAX_RESULTS or ctx.maxResults or 80) or 80
	maxResults = math.max(20, math.floor(maxResults))
	local queryDiscovery = type(ctx.queryDiscovery) == "function" and ctx.queryDiscovery or nil
	local parsePromptCommand = type(ctx.parsePromptCommand) == "function" and ctx.parsePromptCommand or nil
	local executePromptCommand = type(ctx.executePromptCommand) == "function" and ctx.executePromptCommand or nil
	local selectDiscoveryItem = type(ctx.selectDiscoveryItem) == "function" and ctx.selectDiscoveryItem or nil
	local searchAlgorithms = type(ctx.searchAlgorithms) == "table" and ctx.searchAlgorithms or nil
	if type(searchAlgorithms) ~= "table" then
		error("CommandPaletteService.create missing searchAlgorithms")
	end
	if type(searchAlgorithms.lowerText) ~= "function"
		or type(searchAlgorithms.computeMatchScore) ~= "function"
		or type(searchAlgorithms.applySuggested) ~= "function"
		or type(searchAlgorithms.sortAndLimit) ~= "function" then
		error("CommandPaletteService.create invalid searchAlgorithms module")
	end
	local localize = type(ctx.localize) == "function" and ctx.localize or function(_, fallback)
		return tostring(fallback or "")
	end
	local function L(key, fallback)
		local okValue, value = pcall(localize, key, fallback)
		if okValue and type(value) == "string" and value ~= "" then
			return value
		end
		return tostring(fallback or key or "")
	end
	local searchLowerText = searchAlgorithms.lowerText
	local computeMatchScore = searchAlgorithms.computeMatchScore
	local applySuggested = searchAlgorithms.applySuggested
	local sortAndLimit = searchAlgorithms.sortAndLimit

	local executionMode = normalizeMode(type(_G) == "table" and _G.__RAYFIELD_COMMAND_PALETTE_EXEC_MODE or ctx.executionMode or "auto", "auto")
	local executionPolicy = nil
	if type(_G) == "table" and type(_G.__RAYFIELD_COMMAND_PALETTE_POLICY) == "function" then
		executionPolicy = _G.__RAYFIELD_COMMAND_PALETTE_POLICY
	elseif type(ctx.executionPolicy) == "function" then
		executionPolicy = ctx.executionPolicy
	end

	local function syncGlobalExecutionState()
		if type(_G) ~= "table" then
			return
		end
		_G.__RAYFIELD_COMMAND_PALETTE_EXEC_MODE = executionMode
		_G.__RAYFIELD_COMMAND_PALETTE_POLICY = executionPolicy
	end

	local function getElementsSystem()
		if type(ctx.getElementsSystem) == "function" then
			return ctx.getElementsSystem()
		end
		return nil
	end

	local function trackCommandUsage(actionId, displayName)
		if usageAnalytics and type(usageAnalytics.trackCommandUsage) == "function" then
			pcall(usageAnalytics.trackCommandUsage, {
				action = tostring(actionId or ""),
				name = tostring(displayName or actionId or "")
			})
		end
	end

	local function trackControlUsage(item)
		if usageAnalytics and type(usageAnalytics.trackControlUsage) == "function" and type(item) == "table" then
			pcall(usageAnalytics.trackControlUsage, {
				id = tostring(item.controlId or item.id or ""),
				tabId = tostring(item.tabId or ""),
				name = tostring(item.name or ""),
				type = tostring(item.type or "control"),
				action = "palette_select"
			})
		end
	end

	local function usageBoost(item)
		if not usageAnalytics or type(usageAnalytics.getUsageCount) ~= "function" then
			return 0
		end
		if item.action == "control" then
			local controlCount = tonumber(usageAnalytics.getUsageCount("control", item.controlId)) or 0
			return math.min(180, controlCount * 12)
		end
		local commandCount = tonumber(usageAnalytics.getUsageCount("command", item.action)) or 0
		return math.min(180, commandCount * 12)
	end

	local function recordMacroStep(step)
		if type(ctx.recordMacroStep) == "function" then
			pcall(ctx.recordMacroStep, step)
		end
	end

	local function openSettingsTab()
		local settingsPage = type(ctx.getSettingsPage) == "function" and ctx.getSettingsPage() or nil
		if settingsPage and type(ctx.jumpToSettingsPage) == "function" then
			ctx.jumpToSettingsPage(settingsPage)
			return true, "Settings tab opened."
		end
		return false, "Settings tab unavailable."
	end

	local function toggleAudioFeedback()
		local state = type(ctx.getExperienceState) == "function" and ctx.getExperienceState() or nil
		local enabled = state and state.audioState and state.audioState.enabled == true
		if type(ctx.setAudioFeedbackEnabled) ~= "function" then
			return false, "Audio handler unavailable."
		end
		return ctx.setAudioFeedbackEnabled(not enabled, true)
	end

	local function getPinBadgesVisible()
		local elementsSystem = getElementsSystem()
		if elementsSystem and type(elementsSystem.getPinBadgesVisible) == "function" then
			local okValue, value = pcall(elementsSystem.getPinBadgesVisible)
			if okValue then
				return value == true
			end
		end
		if type(ctx.getSetting) == "function" then
			return ctx.getSetting("Favorites", "showPinBadges") ~= false
		end
		return true
	end

	local function togglePinBadges()
		local nextValue = not getPinBadgesVisible()
		local elementsSystem = getElementsSystem()
		if elementsSystem and type(elementsSystem.setPinBadgesVisible) == "function" then
			elementsSystem.setPinBadgesVisible(nextValue)
		end
		if type(ctx.setSettingValue) == "function" then
			ctx.setSettingValue("Favorites", "showPinBadges", nextValue, true)
		end
		return true, nextValue and "Pin badges enabled." or "Pin badges disabled."
	end

	local function toggleVisibility()
		if type(ctx.setVisibility) ~= "function" then
			return false, "Visibility handler unavailable."
		end
		local isHidden = type(ctx.getHidden) == "function" and ctx.getHidden() == true
		local useMobileSizing = type(ctx.getUseMobileSizing) == "function" and ctx.getUseMobileSizing() == true
		ctx.setVisibility(isHidden, not useMobileSizing)
		local hiddenAfter = type(ctx.getHidden) == "function" and ctx.getHidden() == true
		return true, hiddenAfter and "Interface hidden." or "Interface shown."
	end

	local function queryControls(queryLower)
		local items = {}
		local elementsSystem = getElementsSystem()
		local controls = elementsSystem and elementsSystem.listControlsForFavorites and elementsSystem.listControlsForFavorites(true) or {}
		for _, control in ipairs(type(controls) == "table" and controls or {}) do
			local controlName = tostring(control.displayName or control.name or control.id or "Control")
			local internalName = tostring(control.internalName or control.name or control.id or "Control")
			local controlType = tostring(control.type or "Element")
			local tabId = tostring(control.tabId or "")
			local flag = tostring(control.flag or "")
			local localizationKey = tostring(control.localizationKey or "")
			local searchText = searchLowerText(controlName .. " " .. internalName .. " " .. controlType .. " " .. tabId .. " " .. flag .. " " .. localizationKey)
			local entry = {
				id = "control:" .. tostring(control.id or ""),
				action = "control",
				controlId = tostring(control.id or ""),
				tabId = tabId,
				type = "control",
				name = controlName,
				description = string.format("%s - %s", tabId, controlType),
				searchText = searchText,
				shortcuts = L("palette.shortcuts.default", "Enter auto | Shift+Enter execute | Alt+Enter ask")
			}
			local matchScore = computeMatchScore(queryLower, searchText, usageBoost(entry))
			if matchScore ~= nil then
				entry.matchScore = matchScore
				table.insert(items, entry)
			end
		end
		return items
	end

	local function commandDefinitions()
		return {
			{ id = "cmd:open_settings", action = "open_settings", type = "command", name = L("palette.cmd.open_settings.name", "Open Settings"), search = "open settings preferences", description = L("palette.cmd.open_settings.desc", "Jump to Settings tab") },
			{ id = "cmd:open_favorites", action = "open_favorites", type = "command", name = L("palette.cmd.open_favorites.name", "Open Favorites"), search = "open favorites pinned controls", description = L("palette.cmd.open_favorites.desc", "Jump to Favorites tab") },
			{ id = "cmd:export_settings", action = "export_settings", type = "command", name = L("palette.cmd.export_settings.name", "Export Settings Code"), search = "export settings share code", description = L("palette.cmd.export_settings.desc", "Generate share code") },
			{ id = "cmd:import_settings", action = "import_settings", type = "command", name = L("palette.cmd.import_settings.name", "Import Active Settings"), search = "import active settings share code", description = L("palette.cmd.import_settings.desc", "Import active settings") },
			{ id = "cmd:toggle_visibility", action = "toggle_visibility", type = "command", name = L("palette.cmd.toggle_visibility.name", "Toggle Interface"), search = "toggle interface hide show", description = L("palette.cmd.toggle_visibility.desc", "Hide/show interface") },
			{ id = "cmd:open_action_center", action = "open_action_center", type = "command", name = L("palette.cmd.open_action_center.name", "Open Action Center"), search = "open action center notifications", description = L("palette.cmd.open_action_center.desc", "Open notification center") },
			{ id = "cmd:open_perf_hud", action = "open_performance_hud", type = "command", name = L("palette.cmd.open_performance_hud.name", "Open Performance HUD"), search = "open performance hud overlay", description = L("palette.cmd.open_performance_hud.desc", "Show overlay HUD") },
			{ id = "cmd:close_perf_hud", action = "close_performance_hud", type = "command", name = L("palette.cmd.close_performance_hud.name", "Close Performance HUD"), search = "close performance hud overlay", description = L("palette.cmd.close_performance_hud.desc", "Hide overlay HUD") },
			{ id = "cmd:toggle_perf_hud", action = "toggle_performance_hud", type = "command", name = L("palette.cmd.toggle_performance_hud.name", "Toggle Performance HUD"), search = "toggle performance hud overlay metrics", description = L("palette.cmd.toggle_performance_hud.desc", "Toggle overlay HUD") },
			{ id = "cmd:reset_perf_hud_pos", action = "reset_performance_hud_position", type = "command", name = L("palette.cmd.reset_performance_hud_position.name", "Reset HUD Position"), search = "reset hud position dock top left", description = L("palette.cmd.reset_performance_hud_position.desc", "Reset HUD docking position") },
			{ id = "cmd:toggle_element_inspector", action = "toggle_element_inspector", type = "command", name = L("palette.cmd.toggle_element_inspector.name", "Toggle Element Inspector"), search = "inspect visual inspector debug element info", description = L("palette.cmd.toggle_element_inspector.desc", "Toggle inspector mode") },
			{ id = "cmd:open_live_theme_editor", action = "open_live_theme_editor", type = "command", name = L("palette.cmd.open_live_theme_editor.name", "Open Live Theme Editor"), search = "live theme editor preview style colors", description = L("palette.cmd.open_live_theme_editor.desc", "Start live theme editor") },
			{ id = "cmd:export_live_theme_lua", action = "export_live_theme_lua", type = "command", name = L("palette.cmd.export_live_theme_lua.name", "Export Theme Lua"), search = "export live theme lua table", description = L("palette.cmd.export_live_theme_lua.desc", "Export Lua theme snippet") },
			{ id = "cmd:start_macro_recording", action = "start_macro_recording", type = "command", name = L("palette.cmd.start_macro_recording.name", "Start Macro Recording"), search = "macro record start input sequence", description = L("palette.cmd.start_macro_recording.desc", "Start recording macro") },
			{ id = "cmd:stop_macro_recording", action = "stop_macro_recording", type = "command", name = L("palette.cmd.stop_macro_recording.name", "Stop Macro Recording"), search = "macro record stop save input sequence", description = L("palette.cmd.stop_macro_recording.desc", "Stop recording macro") },
			{ id = "cmd:show_hub_metadata", action = "show_hub_metadata", type = "command", name = L("palette.cmd.show_hub_metadata.name", "Show Hub Metadata"), search = "hub metadata author version changelog discord", description = L("palette.cmd.show_hub_metadata.desc", "Show hub metadata") },
			{ id = "cmd:bridge_start_polling", action = "bridge_start_polling", type = "command", name = L("palette.cmd.bridge_start_polling.name", "Start Bridge Polling"), search = "bridge multi instance polling start", description = L("palette.cmd.bridge_start_polling.desc", "Start bridge polling") },
			{ id = "cmd:bridge_stop_polling", action = "bridge_stop_polling", type = "command", name = L("palette.cmd.bridge_stop_polling.name", "Stop Bridge Polling"), search = "bridge multi instance polling stop", description = L("palette.cmd.bridge_stop_polling.desc", "Stop bridge polling") },
			{ id = "cmd:bridge_send_ping", action = "bridge_send_ping", type = "command", name = L("palette.cmd.bridge_send_ping.name", "Send Global Signal Ping"), search = "bridge global signal ping all instances", description = L("palette.cmd.bridge_send_ping.desc", "Send ping signal") },
			{ id = "cmd:bridge_send_status", action = "bridge_send_status", type = "command", name = L("palette.cmd.bridge_send_status.name", "Send Internal Chat Status"), search = "bridge internal chat status message", description = L("palette.cmd.bridge_send_status.desc", "Send status message") },
			{ id = "cmd:automation_list_scheduled", action = "automation_list_scheduled", type = "command", name = L("palette.cmd.automation_list_scheduled.name", "List Scheduled Actions"), search = "automation scheduler list actions tasks", description = L("palette.cmd.automation_list_scheduled.desc", "Show scheduled actions") },
			{ id = "cmd:automation_list_rules", action = "automation_list_rules", type = "command", name = L("palette.cmd.automation_list_rules.name", "List Automation Rules"), search = "automation logic rules list", description = L("palette.cmd.automation_list_rules.desc", "Show automation rules") },
			{ id = "cmd:automation_schedule_macro_quick", action = "automation_schedule_macro_quick", type = "command", name = L("palette.cmd.automation_schedule_macro_quick.name", "Schedule First Macro (5s)"), search = "automation schedule macro in 5 seconds", description = L("palette.cmd.automation_schedule_macro_quick.desc", "Schedule first macro") }
		}
	end

	local function queryCommands(queryLower)
		local out = {}
		for _, item in ipairs(commandDefinitions()) do
			local entry = {
				id = item.id,
				action = item.action,
				type = item.type,
				name = item.name,
				description = item.description,
				searchText = item.search,
				shortcuts = L("palette.shortcuts.default", "Enter auto | Shift+Enter execute | Alt+Enter ask")
			}
			local score = computeMatchScore(queryLower, entry.searchText, usageBoost(entry))
			if score ~= nil then
				entry.matchScore = score
				table.insert(out, entry)
			end
		end
		if type(ctx.listMacros) == "function" then
			local names = ctx.listMacros()
			for _, macroName in ipairs(type(names) == "table" and names or {}) do
				local macroEntry = {
					id = "macro:" .. tostring(macroName),
					action = "run_macro",
					type = "macro",
					name = string.format(L("palette.cmd.run_macro.name", "Run Macro: %s"), tostring(macroName)),
					description = L("palette.cmd.run_macro.desc", "Execute recorded macro"),
					macroName = tostring(macroName),
					searchText = "macro run execute " .. tostring(macroName),
					shortcuts = L("palette.shortcuts.default", "Enter auto | Shift+Enter execute | Alt+Enter ask")
				}
				local score = computeMatchScore(queryLower, macroEntry.searchText, usageBoost(macroEntry))
				if score ~= nil then
					macroEntry.matchScore = score
					table.insert(out, macroEntry)
				end
			end
		end
		return out
	end

	local function resolveMode(item, requestedMode, trigger)
		local mode = normalizeMode(requestedMode, executionMode)
		if mode ~= "auto" then
			return mode, "explicit:" .. mode
		end
		local policy = executionPolicy
		if not policy and type(ctx.getCommandPalettePolicy) == "function" then
			policy = ctx.getCommandPalettePolicy()
		end
		if type(policy) == "function" then
			local okCall, result = pcall(policy, item, {
				currentMode = executionMode,
				trigger = trigger
			})
			if okCall then
				local policyMode = normalizeMode(result, "auto")
				if policyMode ~= "auto" then
					return policyMode, "policy:" .. policyMode
				end
			end
		end
		local action = tostring(item and item.action or "")
		if action == "control" then
			return "jump", "auto-control-jump"
		end
		if action == "discovery_item" and tostring(item and item.controlId or "") ~= "" then
			return "jump", "auto-discovery-jump"
		end
		return "execute", "auto-default-execute"
	end

	local function selectControl(item)
		local controlId = tostring(item.controlId or "")
		if controlId == "" then
			return false, "Control id is missing."
		end
		local elementsSystem = getElementsSystem()
		if elementsSystem and type(elementsSystem.activateTabByPersistenceId) == "function" then
			elementsSystem.activateTabByPersistenceId(item.tabId, true, "command_palette")
		end
		if elementsSystem and type(elementsSystem.getControlRecordById) == "function" and type(ctx.highlightFavoriteControl) == "function" then
			local record = elementsSystem.getControlRecordById(controlId)
			ctx.highlightFavoriteControl(record)
		end
		trackControlUsage(item)
		recordMacroStep({
			action = "control",
			controlId = controlId,
			tabId = item.tabId,
			name = item.name
		})
		return true, "Opened control: " .. tostring(item.name or controlId)
	end

	local function runAction(item)
		local action = tostring(item.action or "")
		if action == "control" then
			return selectControl(item)
		elseif action == "open_settings" then
			return openSettingsTab()
		elseif action == "open_favorites" then
			if type(ctx.openFavoritesTab) == "function" then
				return ctx.openFavoritesTab(type(ctx.getFavoritesTabWindow) == "function" and ctx.getFavoritesTabWindow() or nil)
			end
			return false, "Favorites handler unavailable."
		elseif action == "export_settings" then
			if type(ctx.exportSettings) ~= "function" then
				return false, "Export handler unavailable."
			end
			local code, status = ctx.exportSettings()
			if type(code) ~= "string" or code == "" then
				return false, tostring(status or "Export failed.")
			end
			if type(ctx.setShareCodeInputValue) == "function" then
				pcall(ctx.setShareCodeInputValue, code)
			end
			return true, "Exported settings code."
		elseif action == "import_settings" then
			if type(ctx.importSettings) == "function" then
				return ctx.importSettings()
			end
			return false, "Import handler unavailable."
		elseif action == "toggle_visibility" then
			return toggleVisibility()
		elseif action == "open_action_center" then
			if type(ctx.openActionCenter) == "function" then
				return ctx.openActionCenter()
			end
			return false, "Action Center handler unavailable."
		elseif action == "open_performance_hud" then
			if type(ctx.openPerformanceHUD) == "function" then
				return ctx.openPerformanceHUD()
			end
			return false, "Performance HUD handler unavailable."
		elseif action == "close_performance_hud" then
			if type(ctx.closePerformanceHUD) == "function" then
				return ctx.closePerformanceHUD()
			end
			return false, "Performance HUD handler unavailable."
		elseif action == "toggle_performance_hud" then
			if type(ctx.togglePerformanceHUD) == "function" then
				return ctx.togglePerformanceHUD()
			end
			return false, "Performance HUD handler unavailable."
		elseif action == "reset_performance_hud_position" then
			if type(ctx.resetPerformanceHUDPosition) == "function" then
				return ctx.resetPerformanceHUDPosition("top_left")
			end
			return false, "Performance HUD reset handler unavailable."
		elseif action == "toggle_element_inspector" then
			if type(ctx.toggleElementInspector) == "function" then
				return ctx.toggleElementInspector()
			end
			return false, "Element inspector handler unavailable."
		elseif action == "open_live_theme_editor" then
			if type(ctx.openLiveThemeEditor) == "function" then
				return ctx.openLiveThemeEditor()
			end
			return false, "Live Theme Editor handler unavailable."
		elseif action == "export_live_theme_lua" then
			if type(ctx.exportLiveThemeLua) == "function" then
				return ctx.exportLiveThemeLua()
			end
			return false, "Live Theme export handler unavailable."
		elseif action == "start_macro_recording" then
			if type(ctx.startMacroRecording) ~= "function" then
				return false, "Macro recorder unavailable."
			end
			local autoName = "macro-" .. tostring(type(os.time) == "function" and os.time() or math.floor(os.clock() * 1000))
			return ctx.startMacroRecording(autoName)
		elseif action == "stop_macro_recording" then
			if type(ctx.stopMacroRecording) == "function" then
				return ctx.stopMacroRecording(true)
			end
			return false, "Macro recorder unavailable."
		elseif action == "show_hub_metadata" then
			if type(ctx.showHubMetadata) == "function" then
				return ctx.showHubMetadata()
			end
			return false, "Hub metadata unavailable."
		elseif action == "run_macro" then
			if type(ctx.executeMacro) == "function" then
				return ctx.executeMacro(item.macroName)
			end
			return false, "Macro executor unavailable."
		elseif action == "prompt_command" then
			if type(executePromptCommand) == "function" then
				return executePromptCommand(item.searchText or item.name, item)
			end
			return false, "Prompt command handler unavailable."
		elseif action == "discovery_item" then
			if type(selectDiscoveryItem) == "function" then
				return selectDiscoveryItem(item)
			end
			if tostring(item.controlId or "") ~= "" then
				return selectControl({
					controlId = tostring(item.controlId),
					tabId = tostring(item.tabId or ""),
					name = tostring(item.name or item.controlId)
				})
			end
			return false, "Discovery selection handler unavailable."
		elseif action == "bridge_start_polling" then
			if type(ctx.startBridgePolling) == "function" then
				return ctx.startBridgePolling()
			end
			return false, "Bridge polling handler unavailable."
		elseif action == "bridge_stop_polling" then
			if type(ctx.stopBridgePolling) == "function" then
				return ctx.stopBridgePolling()
			end
			return false, "Bridge polling handler unavailable."
		elseif action == "bridge_send_ping" then
			if type(ctx.sendGlobalSignal) == "function" then
				return ctx.sendGlobalSignal("ping", { from = "command_palette" })
			end
			return false, "Bridge signal handler unavailable."
		elseif action == "bridge_send_status" then
			if type(ctx.sendInternalChat) == "function" then
				return ctx.sendInternalChat("Status OK from command palette.")
			end
			return false, "Bridge chat handler unavailable."
		elseif action == "automation_list_scheduled" then
			if type(ctx.listScheduledActions) ~= "function" then
				return false, "Automation scheduler unavailable."
			end
			local list = ctx.listScheduledActions()
			return true, string.format("Scheduled actions: %d", type(list) == "table" and #list or 0)
		elseif action == "automation_list_rules" then
			if type(ctx.listAutomationRules) ~= "function" then
				return false, "Automation rules unavailable."
			end
			local list = ctx.listAutomationRules()
			return true, string.format("Automation rules: %d", type(list) == "table" and #list or 0)
		elseif action == "automation_schedule_macro_quick" then
			if type(ctx.scheduleMacro) ~= "function" or type(ctx.listMacros) ~= "function" then
				return false, "Automation scheduler unavailable."
			end
			local macroNames = ctx.listMacros()
			local firstMacro = type(macroNames) == "table" and macroNames[1] or nil
			if type(firstMacro) ~= "string" or firstMacro == "" then
				return false, "No macro available to schedule."
			end
			return ctx.scheduleMacro(firstMacro, 5, { respectDelay = false })
		end
		return false, "Unknown command."
	end

	local function runJump(item)
		local action = tostring(item.action or "")
		if action == "control" then
			return selectControl(item)
		end
		if action == "open_settings" then
			return openSettingsTab()
		end
		if action == "open_action_center" and type(ctx.openActionCenter) == "function" then
			return ctx.openActionCenter()
		end
		if action == "open_performance_hud" and type(ctx.openPerformanceHUD) == "function" then
			return ctx.openPerformanceHUD()
		end
		if action == "discovery_item" and tostring(item.controlId or "") ~= "" then
			return selectControl({
				controlId = tostring(item.controlId),
				tabId = tostring(item.tabId or ""),
				name = tostring(item.name or item.controlId)
			})
		end
		return false, "Jump mode unsupported for this item."
	end

	local function runItem(item, mode, options)
		if type(item) ~= "table" then
			return false, "Invalid command palette item.", { mode = "execute", keepPaletteOpen = true }
		end
		local resolvedMode, reason = resolveMode(item, mode, options and options.trigger or nil)

		if resolvedMode == "ask" then
			local confirmHandler = type(ctx.confirmCommandPaletteItem) == "function" and ctx.confirmCommandPaletteItem or nil
			if not confirmHandler then
				return false, "Confirmation requested. Press Shift+Enter to execute.", {
					mode = "ask",
					reason = reason,
					keepPaletteOpen = true
				}
			end
			local okConfirm, confirmResult = pcall(confirmHandler, item, resolvedMode, options)
			if not okConfirm then
				return false, tostring(confirmResult), {
					mode = "ask",
					reason = reason,
					keepPaletteOpen = true
				}
			end
			if confirmResult ~= true then
				return false, type(confirmResult) == "string" and confirmResult or "Action canceled.", {
					mode = "ask",
					reason = reason,
					keepPaletteOpen = true
				}
			end
			resolvedMode = "execute"
		end

		local okAction, message = nil, nil
		if resolvedMode == "jump" then
			okAction, message = runJump(item)
			if okAction ~= true then
				okAction, message = runAction(item)
			end
		else
			okAction, message = runAction(item)
		end

		if okAction == true then
			local action = tostring(item.action or "")
			if action ~= "control" then
				trackCommandUsage(action, item.name)
			end
			if action ~= "start_macro_recording" and action ~= "stop_macro_recording" then
				recordMacroStep({
					action = action,
					name = item.name
				})
			end
		end

		return okAction == true, message, {
			mode = resolvedMode,
			reason = reason,
			keepPaletteOpen = false
		}
	end

	local function query(queryText)
		local queryLower = searchLowerText(queryText)
		local items = {}

		if type(parsePromptCommand) == "function" then
			local promptItem = parsePromptCommand(queryText)
			if type(promptItem) == "table" then
				local entry = shallowCopy(promptItem)
				entry.id = tostring(entry.id or "prompt:item")
				entry.action = tostring(entry.action or "prompt_command")
				entry.type = tostring(entry.type or "prompt")
				entry.description = tostring(entry.description or "Natural language command")
				entry.searchText = tostring(entry.searchText or queryText)
				entry.shortcuts = L("palette.shortcuts.default", "Enter auto | Shift+Enter execute | Alt+Enter ask")
				entry.matchScore = (tonumber(entry.matchScore) or 900) + usageBoost(entry)
				table.insert(items, entry)
			end
		end

		for _, item in ipairs(queryControls(queryLower)) do
			table.insert(items, item)
		end
		for _, item in ipairs(queryCommands(queryLower)) do
			table.insert(items, item)
		end

		if type(queryDiscovery) == "function" then
			local discoveryItems = queryDiscovery(queryText)
			for _, rawItem in ipairs(type(discoveryItems) == "table" and discoveryItems or {}) do
				if type(rawItem) == "table" then
					local entry = shallowCopy(rawItem)
					entry.id = tostring(entry.id or ("discovery:" .. tostring(entry.name or "item")))
					entry.action = tostring(entry.action or "discovery_item")
					entry.type = tostring(entry.type or "discovery")
					entry.searchText = tostring(entry.searchText or entry.name or entry.id)
					entry.description = tostring(entry.description or "Discovery result")
					entry.shortcuts = L("palette.shortcuts.default", "Enter auto | Shift+Enter execute | Alt+Enter ask")
					local score = computeMatchScore(queryLower, entry.searchText, usageBoost(entry) + (tonumber(entry.matchScore) or 0))
					if score ~= nil then
						entry.matchScore = score
						table.insert(items, entry)
					end
				end
			end
		end

		items = applySuggested(items, queryLower, usageAnalytics)
		items = sortAndLimit(items, maxResults)
		return items
	end

	local function setExecutionMode(mode)
		local raw = lowerText(mode)
		if raw ~= "auto" and raw ~= "jump" and raw ~= "execute" and raw ~= "ask" then
			return false, "Invalid command palette mode."
		end
		executionMode = raw
		syncGlobalExecutionState()
		return true, "Command palette mode set to " .. executionMode .. "."
	end

	local function getExecutionMode()
		return executionMode
	end

	local function setPolicy(callback)
		if callback ~= nil and type(callback) ~= "function" then
			return false, "Policy callback must be a function."
		end
		executionPolicy = callback
		syncGlobalExecutionState()
		return true, executionPolicy and "Command palette policy installed." or "Command palette policy cleared."
	end

	syncGlobalExecutionState()

	return {
		openSettingsTab = openSettingsTab,
		toggleAudioFeedback = toggleAudioFeedback,
		getPinBadgesVisible = getPinBadgesVisible,
		togglePinBadges = togglePinBadges,
		toggleVisibility = toggleVisibility,
		query = query,
		select = runItem,
		runItem = runItem,
		setExecutionMode = setExecutionMode,
		getExecutionMode = getExecutionMode,
		setPolicy = setPolicy
	}
end

return CommandPaletteService
