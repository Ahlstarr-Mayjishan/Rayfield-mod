local AnalyticsManager = {}

local function createFallbackSender(warnFn)
	return function()
		if type(warnFn) == "function" then
			warnFn("Failed to load report function")
		end
	end
end

function AnalyticsManager.create(options)
	options = type(options) == "table" and options or {}

	local runtimeBootstrap = options.runtimeBootstrap
	local analyticsProviderServiceLib = options.analyticsProviderServiceLib
	local analyticsReporterServiceLib = options.analyticsReporterServiceLib
	local requestsDisabled = options.requestsDisabled == true
	local useStudio = options.useStudio == true
	local debug = options.debug == true
	local release = tostring(options.release or "")
	local interfaceBuild = tostring(options.interfaceBuild or "")
	local scriptName = tostring(options.scriptName or "Rayfield")
	local warnFn = type(options.warn) == "function" and options.warn or warn
	local printFn = type(options.print) == "function" and options.print or print
	local loadWithTimeout = type(options.loadWithTimeout) == "function" and options.loadWithTimeout or nil

	local manager = {}
	local sendReport = createFallbackSender(warnFn)

	if type(runtimeBootstrap) == "table" and type(runtimeBootstrap.createAnalyticsSender) == "function" then
		sendReport = runtimeBootstrap.createAnalyticsSender({
			requestsDisabled = requestsDisabled,
			useStudio = useStudio,
			debug = debug,
			release = release,
			interfaceBuild = interfaceBuild,
			scriptName = scriptName,
			warn = warnFn,
			print = printFn
		})
	elseif type(analyticsProviderServiceLib) == "table" and type(analyticsProviderServiceLib.create) == "function" then
		local analyticsProvider = analyticsProviderServiceLib.create({
			reporterModule = analyticsReporterServiceLib,
			requestsDisabled = requestsDisabled,
			useStudio = useStudio,
			debug = debug,
			release = release,
			interfaceBuild = interfaceBuild,
			loadWithTimeout = loadWithTimeout,
			scriptName = scriptName,
			warn = warnFn,
			print = printFn
		})
		if type(analyticsProvider) == "table" then
			if type(analyticsProvider.init) == "function" then
				pcall(analyticsProvider.init)
			end
			if type(analyticsProvider.sendReport) == "function" then
				sendReport = function(ev_n, sc_n)
					local okReport, reportErr = pcall(analyticsProvider.sendReport, ev_n, sc_n)
					if not okReport and type(warnFn) == "function" then
						warnFn("Analytics report error: " .. tostring(reportErr))
					end
				end
			end
		end
	elseif type(analyticsReporterServiceLib) == "table" and type(analyticsReporterServiceLib.create) == "function" then
		local analyticsReporter = analyticsReporterServiceLib.create({
			requestsDisabled = requestsDisabled,
			useStudio = useStudio,
			debug = debug,
			release = release,
			interfaceBuild = interfaceBuild,
			loadWithTimeout = loadWithTimeout,
			scriptName = scriptName,
			warn = warnFn,
			print = printFn
		})
		if type(analyticsReporter) == "table" then
			if type(analyticsReporter.init) == "function" then
				pcall(analyticsReporter.init)
			end
			if type(analyticsReporter.sendReport) == "function" then
				sendReport = function(ev_n, sc_n)
					local okReport, reportErr = pcall(analyticsReporter.sendReport, ev_n, sc_n)
					if not okReport and type(warnFn) == "function" then
						warnFn("Analytics report error: " .. tostring(reportErr))
					end
				end
			end
		end
	elseif not requestsDisabled and type(warnFn) == "function" then
		warnFn("Rayfield Mod: [W_ANALYTICS_SERVICE] Analytics reporter service unavailable.")
	end

	manager.sendReport = sendReport
	return manager
end

return AnalyticsManager
