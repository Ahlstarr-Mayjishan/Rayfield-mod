local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local withUIStateMethod = ctx.withUIStateMethod
	local setSettingValue = ctx.setSettingValue
	local setCommandPaletteExecutionModeInternal = ctx.setCommandPaletteExecutionModeInternal
	local getCommandPaletteExecutionModeInternal = ctx.getCommandPaletteExecutionModeInternal
	local setCommandPalettePolicyInternal = ctx.setCommandPalettePolicyInternal
	local runCommandPaletteItemInternal = ctx.runCommandPaletteItemInternal
	local registerDiscoveryProviderInternal = ctx.registerDiscoveryProviderInternal
	local unregisterDiscoveryProviderInternal = ctx.unregisterDiscoveryProviderInternal
	local queryDiscoveryInternal = ctx.queryDiscoveryInternal
	local executePromptCommandInternal = ctx.executePromptCommandInternal

	function RayfieldLibrary:OpenCommandPalette(seedText)
		return withUIStateMethod("OpenCommandPalette", seedText)
	end

	function RayfieldLibrary:CloseCommandPalette()
		return withUIStateMethod("CloseCommandPalette")
	end

	function RayfieldLibrary:ToggleCommandPalette(seedText)
		return withUIStateMethod("ToggleCommandPalette", seedText)
	end

	function RayfieldLibrary:SetCommandPaletteExecutionMode(mode)
		if type(setCommandPaletteExecutionModeInternal) ~= "function" then
			return false, "Command palette execution mode handler unavailable."
		end
		local okSet, message = setCommandPaletteExecutionModeInternal(mode)
		if okSet and type(setSettingValue) == "function" then
			setSettingValue("UIExperience", "commandPaletteMode", tostring(mode or "auto"), true)
		end
		return okSet, message
	end

	function RayfieldLibrary:GetCommandPaletteExecutionMode()
		if type(getCommandPaletteExecutionModeInternal) == "function" then
			local value = getCommandPaletteExecutionModeInternal()
			return tostring(value or "auto")
		end
		if type(_G) == "table" and type(_G.__RAYFIELD_COMMAND_PALETTE_EXEC_MODE) == "string" then
			return tostring(_G.__RAYFIELD_COMMAND_PALETTE_EXEC_MODE)
		end
		return "auto"
	end

	function RayfieldLibrary:SetCommandPalettePolicy(callback)
		if type(setCommandPalettePolicyInternal) ~= "function" then
			return false, "Command palette policy handler unavailable."
		end
		return setCommandPalettePolicyInternal(callback)
	end

	function RayfieldLibrary:RunCommandPaletteItem(item, mode)
		if type(runCommandPaletteItemInternal) ~= "function" then
			return false, "Command palette executor unavailable."
		end
		return runCommandPaletteItemInternal(item, mode)
	end

	function RayfieldLibrary:OpenActionCenter()
		return withUIStateMethod("OpenActionCenter")
	end

	function RayfieldLibrary:CloseActionCenter()
		return withUIStateMethod("CloseActionCenter")
	end

	function RayfieldLibrary:ToggleActionCenter()
		return withUIStateMethod("ToggleActionCenter")
	end

	function RayfieldLibrary:GetNotificationHistory(limit)
		local okHistory, historyOrErr = withUIStateMethod("GetNotificationHistory", limit)
		if okHistory == false and type(historyOrErr) == "string" then
			return {}
		end
		if type(okHistory) == "table" then
			return okHistory
		end
		if type(historyOrErr) == "table" then
			return historyOrErr
		end
		return {}
	end

	function RayfieldLibrary:ClearNotificationHistory()
		return withUIStateMethod("ClearNotificationHistory")
	end

	function RayfieldLibrary:GetUnreadNotificationCount()
		local okCall, result = withUIStateMethod("GetUnreadNotificationCount")
		if type(okCall) == "number" then
			return okCall
		end
		if okCall == false and type(result) == "string" then
			return 0
		end
		return tonumber(result) or 0
	end

	function RayfieldLibrary:MarkAllNotificationsRead()
		return withUIStateMethod("MarkAllNotificationsRead")
	end

	function RayfieldLibrary:GetNotificationHistoryEx(options)
		local okCall, result = withUIStateMethod("GetNotificationHistoryEx", options)
		if type(okCall) == "table" then
			return okCall
		end
		if okCall == false and type(result) == "string" then
			return {}
		end
		return type(result) == "table" and result or {}
	end

	function RayfieldLibrary:ShowContextMenu(items, anchor)
		return withUIStateMethod("ShowContextMenu", items, anchor)
	end

	function RayfieldLibrary:HideContextMenu()
		return withUIStateMethod("HideContextMenu")
	end

	function RayfieldLibrary:RegisterDiscoveryProvider(id, provider)
		if type(registerDiscoveryProviderInternal) ~= "function" then
			return false, "Discovery registry unavailable."
		end
		return registerDiscoveryProviderInternal(id, provider)
	end

	function RayfieldLibrary:UnregisterDiscoveryProvider(id)
		if type(unregisterDiscoveryProviderInternal) ~= "function" then
			return false, "Discovery registry unavailable."
		end
		return unregisterDiscoveryProviderInternal(id)
	end

	function RayfieldLibrary:QueryDiscovery(query)
		if type(queryDiscoveryInternal) ~= "function" then
			return {}
		end
		local results = queryDiscoveryInternal(query)
		return type(results) == "table" and results or {}
	end

	function RayfieldLibrary:ExecutePromptCommand(rawText)
		if type(executePromptCommandInternal) ~= "function" then
			return false, "Prompt command service unavailable."
		end
		return executePromptCommandInternal(rawText)
	end

	setHandler("setCommandPaletteExecutionMode", function(mode)
		return RayfieldLibrary:SetCommandPaletteExecutionMode(mode)
	end)
	setHandler("getCommandPaletteExecutionMode", function()
		return RayfieldLibrary:GetCommandPaletteExecutionMode()
	end)
	setHandler("setCommandPalettePolicy", function(callback)
		return RayfieldLibrary:SetCommandPalettePolicy(callback)
	end)
	setHandler("runCommandPaletteItem", function(item, mode)
		return RayfieldLibrary:RunCommandPaletteItem(item, mode)
	end)
	setHandler("getUnreadNotificationCount", function()
		return RayfieldLibrary:GetUnreadNotificationCount()
	end)
	setHandler("markAllNotificationsRead", function()
		return RayfieldLibrary:MarkAllNotificationsRead()
	end)
	setHandler("getNotificationHistoryEx", function(options)
		return RayfieldLibrary:GetNotificationHistoryEx(options)
	end)
	setHandler("openActionCenter", function()
		return RayfieldLibrary:OpenActionCenter()
	end)
	setHandler("openCommandPalette", function(seed)
		return RayfieldLibrary:OpenCommandPalette(seed)
	end)
	setHandler("registerDiscoveryProvider", function(id, provider)
		return RayfieldLibrary:RegisterDiscoveryProvider(id, provider)
	end)
	setHandler("unregisterDiscoveryProvider", function(id)
		return RayfieldLibrary:UnregisterDiscoveryProvider(id)
	end)
	setHandler("queryDiscovery", function(query)
		return RayfieldLibrary:QueryDiscovery(query)
	end)
	setHandler("executePromptCommand", function(text)
		return RayfieldLibrary:ExecutePromptCommand(text)
	end)
end

return module
