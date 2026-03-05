local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local setSettingValue = ctx.setSettingValue
	local openPerformanceHUDInternal = ctx.openPerformanceHUDInternal
	local closePerformanceHUDInternal = ctx.closePerformanceHUDInternal
	local togglePerformanceHUDInternal = ctx.togglePerformanceHUDInternal
	local resetPerformanceHUDInternal = ctx.resetPerformanceHUDInternal
	local configurePerformanceHUDInternal = ctx.configurePerformanceHUDInternal
	local getPerformanceHUDStateInternal = ctx.getPerformanceHUDStateInternal
	local registerHUDMetricProviderInternal = ctx.registerHUDMetricProviderInternal
	local unregisterHUDMetricProviderInternal = ctx.unregisterHUDMetricProviderInternal
	local getUsageAnalyticsInternal = ctx.getUsageAnalyticsInternal
	local clearUsageAnalyticsInternal = ctx.clearUsageAnalyticsInternal

	function RayfieldLibrary:OpenPerformanceHUD()
		if type(openPerformanceHUDInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		local okOpen, message = openPerformanceHUDInternal()
		if okOpen and type(setSettingValue) == "function" then
			setSettingValue("UIExperience", "performanceHudEnabled", true, true)
		end
		return okOpen, message
	end

	function RayfieldLibrary:ClosePerformanceHUD()
		if type(closePerformanceHUDInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		local okClose, message = closePerformanceHUDInternal()
		if okClose and type(setSettingValue) == "function" then
			setSettingValue("UIExperience", "performanceHudEnabled", false, true)
		end
		return okClose, message
	end

	function RayfieldLibrary:TogglePerformanceHUD()
		if type(togglePerformanceHUDInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		local okToggle, message = togglePerformanceHUDInternal()
		if okToggle and type(setSettingValue) == "function" then
			local hudState = RayfieldLibrary:GetPerformanceHUDState()
			setSettingValue("UIExperience", "performanceHudEnabled", hudState.visible == true, true)
		end
		return okToggle, message
	end

	function RayfieldLibrary:ResetPerformanceHUDPosition(anchor)
		if type(resetPerformanceHUDInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		return resetPerformanceHUDInternal(anchor)
	end

	function RayfieldLibrary:ConfigurePerformanceHUD(options)
		if type(configurePerformanceHUDInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		return configurePerformanceHUDInternal(options)
	end

	function RayfieldLibrary:GetPerformanceHUDState()
		if type(getPerformanceHUDStateInternal) ~= "function" then
			return {}
		end
		local state = getPerformanceHUDStateInternal()
		return type(state) == "table" and state or {}
	end

	function RayfieldLibrary:RegisterHUDMetricProvider(id, provider, options)
		if type(registerHUDMetricProviderInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		return registerHUDMetricProviderInternal(id, provider, options)
	end

	function RayfieldLibrary:UnregisterHUDMetricProvider(id)
		if type(unregisterHUDMetricProviderInternal) ~= "function" then
			return false, "Performance HUD unavailable."
		end
		return unregisterHUDMetricProviderInternal(id)
	end

	function RayfieldLibrary:GetUsageAnalytics(limit)
		if type(getUsageAnalyticsInternal) ~= "function" then
			return {}
		end
		local snapshot = getUsageAnalyticsInternal(limit)
		if type(snapshot) ~= "table" then
			return {}
		end
		return snapshot
	end

	function RayfieldLibrary:ClearUsageAnalytics()
		if type(clearUsageAnalyticsInternal) ~= "function" then
			return false, "Usage analytics unavailable."
		end
		return clearUsageAnalyticsInternal()
	end

	setHandler("openPerformanceHUD", function()
		return RayfieldLibrary:OpenPerformanceHUD()
	end)
	setHandler("closePerformanceHUD", function()
		return RayfieldLibrary:ClosePerformanceHUD()
	end)
	setHandler("togglePerformanceHUD", function()
		return RayfieldLibrary:TogglePerformanceHUD()
	end)
	setHandler("resetPerformanceHUDPosition", function(anchor)
		return RayfieldLibrary:ResetPerformanceHUDPosition(anchor)
	end)
	setHandler("configurePerformanceHUD", function(options)
		return RayfieldLibrary:ConfigurePerformanceHUD(options)
	end)
	setHandler("getPerformanceHUDState", function()
		return RayfieldLibrary:GetPerformanceHUDState()
	end)
	setHandler("registerHUDMetricProvider", function(id, provider, options)
		return RayfieldLibrary:RegisterHUDMetricProvider(id, provider, options)
	end)
	setHandler("unregisterHUDMetricProvider", function(id)
		return RayfieldLibrary:UnregisterHUDMetricProvider(id)
	end)
	setHandler("getUsageAnalytics", function(limit)
		return RayfieldLibrary:GetUsageAnalytics(limit)
	end)
	setHandler("clearUsageAnalytics", function()
		return RayfieldLibrary:ClearUsageAnalytics()
	end)
end

return module
