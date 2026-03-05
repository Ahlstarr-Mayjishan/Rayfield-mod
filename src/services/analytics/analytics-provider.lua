local AnalyticsProvider = {}

function AnalyticsProvider.create(options)
	options = type(options) == "table" and options or {}
	local moduleValue = options.reporterModule
	if type(moduleValue) == "table" and type(moduleValue.create) == "function" then
		return moduleValue.create(options)
	end

	local warnFn = type(options.warn) == "function" and options.warn or warn
	warnFn("Rayfield Mod: [W_ANALYTICS_PROVIDER] Reporter module unavailable.")
	return {
		init = function()
			return false
		end,
		isLoaded = function()
			return false
		end,
		sendReport = function()
			return false
		end
	}
end

return AnalyticsProvider
