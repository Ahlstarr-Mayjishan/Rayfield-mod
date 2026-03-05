local AnalyticsReporterService = {}

local function shouldReportExecution(cachedSettings)
	if type(cachedSettings) == "table" then
		return (next(cachedSettings) == nil)
			or (cachedSettings.System and cachedSettings.System.usageAnalytics and cachedSettings.System.usageAnalytics.Value)
	end
	return cachedSettings == nil
end

function AnalyticsReporterService.create(options)
	options = options or {}
	local requestsDisabled = options.requestsDisabled == true
	local useStudio = options.useStudio == true
	local debug = options.debug == true
	local release = tostring(options.release or "")
	local interfaceBuild = tostring(options.interfaceBuild or "")
	local loadWithTimeout = options.loadWithTimeout
	local warnFn = type(options.warn) == "function" and options.warn or warn
	local printFn = type(options.print) == "function" and options.print or print
	local analyticsUrl = tostring(options.analyticsUrl or "https://analytics.sirius.menu/script")
	local defaultScriptName = tostring(options.scriptName or "Rayfield")
	local getCachedSettings = type(options.getCachedSettings) == "function"
		and options.getCachedSettings
		or function()
			return nil
		end

	local analyticsLib = nil
	local initAttempted = false

	local service = {}

	local function reporterLoaded()
		return type(analyticsLib) == "table"
			and type(analyticsLib.isLoaded) == "function"
			and analyticsLib:isLoaded()
	end

	function service.sendReport(eventName, scriptName)
		if not reporterLoaded() then
			warnFn("Analytics library not loaded")
			return false
		end
		if useStudio then
			printFn("Sending Analytics")
			return true
		end

		if debug then
			warnFn("Reporting Analytics")
		end

		local okReport, reportErr = pcall(analyticsLib.report, analyticsLib, {
			name = eventName,
			script = {
				name = scriptName or defaultScriptName,
				version = release
			}
		}, {
			version = interfaceBuild
		})
		if not okReport then
			warnFn("Analytics report failed: " .. tostring(reportErr))
			return false
		end

		if debug then
			warnFn("Finished Report")
		end
		return true
	end

	function service.init()
		if initAttempted then
			return reporterLoaded()
		end
		initAttempted = true

		if requestsDisabled then
			return false
		end
		if type(loadWithTimeout) ~= "function" then
			warnFn("Analytics reporter unavailable: loadWithTimeout missing")
			return false
		end

		if debug then
			warnFn("Querying Settings for Reporter Information")
		end
		analyticsLib = loadWithTimeout(analyticsUrl)
		if not analyticsLib then
			warnFn("Failed to load analytics reporter")
			return false
		end
		if type(analyticsLib.load) == "function" then
			local okLoad, loadErr = pcall(analyticsLib.load, analyticsLib)
			if not okLoad then
				warnFn("Analytics reporter load failed: " .. tostring(loadErr))
				analyticsLib = nil
				return false
			end
		else
			warnFn("Analytics library loaded but missing load function")
			analyticsLib = nil
			return false
		end

		if shouldReportExecution(getCachedSettings()) then
			service.sendReport("execution", defaultScriptName)
		end
		return true
	end

	function service.isLoaded()
		return reporterLoaded()
	end

	return service
end

return AnalyticsReporterService
