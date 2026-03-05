local RuntimeBootstrapper = {}

local function loadService(options, path, validatorFn)
	local httpGet = options.httpGet
	local compileString = options.compileString
	local warnFn = type(options.warn) == "function" and options.warn or warn
	local moduleRootUrl = tostring(options.moduleRootUrl or "")
	local fullUrl = moduleRootUrl .. tostring(path or "")

	local okFetch, sourceOrErr = pcall(httpGet, fullUrl)
	if not okFetch then
		warnFn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_FETCH] " .. tostring(path) .. " | " .. tostring(sourceOrErr))
		return nil
	end
	if type(sourceOrErr) ~= "string" or sourceOrErr == "" then
		warnFn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_EMPTY] " .. tostring(path))
		return nil
	end
	local chunk, compileErr = compileString(sourceOrErr)
	if not chunk then
		warnFn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_COMPILE] " .. tostring(path) .. " | " .. tostring(compileErr))
		return nil
	end
	local okExecute, moduleOrErr = pcall(chunk)
	if not okExecute then
		warnFn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_EXECUTE] " .. tostring(path) .. " | " .. tostring(moduleOrErr))
		return nil
	end
	if type(validatorFn) == "function" and not validatorFn(moduleOrErr) then
		warnFn("Rayfield Mod: [W_BOOTSTRAP_SERVICE_CONTRACT] " .. tostring(path))
		return nil
	end
	return moduleOrErr
end

function RuntimeBootstrapper.create(options)
	options = type(options) == "table" and options or {}
	local compileString = options.compileString
	local httpGet = options.httpGet
	if type(compileString) ~= "function" or type(httpGet) ~= "function" then
		return nil
	end

	local warnFn = type(options.warn) == "function" and options.warn or warn
	local taskLib = options.taskLib or task
	local clockFn = type(options.clock) == "function" and options.clock or os.clock
	local globalEnv = type(options.globalEnv) == "table" and options.globalEnv or nil

	local serviceLoadContext = {
		compileString = compileString,
		httpGet = httpGet,
		moduleRootUrl = options.moduleRootUrl,
		warn = warnFn
	}

	local ExecutionPolicyServiceLib = loadService(serviceLoadContext, "src/services/execution-policy.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.ensure) == "function"
	end)
	local HttpLoaderServiceLib = loadService(serviceLoadContext, "src/services/http-loader.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
	local AnalyticsReporterServiceLib = loadService(serviceLoadContext, "src/services/analytics-reporter.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
	local AnalyticsProviderServiceLib = loadService(serviceLoadContext, "src/services/analytics/analytics-provider.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
	local AnalyticsManagerServiceLib = loadService(serviceLoadContext, "src/services/analytics-manager.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
	local RuntimeLoaderHelpersServiceLib = loadService(serviceLoadContext, "src/services/runtime-loader-helpers.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)
	local LoaderHelpersFallbackServiceLib = loadService(serviceLoadContext, "src/services/loader-helpers.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.createFallback) == "function"
	end)
	local CompatibilityInitServiceLib = loadService(serviceLoadContext, "src/services/compatibility-init.lua", function(moduleValue)
		return type(moduleValue) == "table" and type(moduleValue.create) == "function"
	end)

	local ExecPolicy = nil
	if type(ExecutionPolicyServiceLib) == "table" and type(ExecutionPolicyServiceLib.ensure) == "function" then
		ExecPolicy = ExecutionPolicyServiceLib.ensure(globalEnv)
	end
	if type(ExecPolicy) ~= "table" then
		warnFn("Rayfield Mod: [W_EXEC_POLICY] Using fallback execution policy.")
		ExecPolicy = {
			decideExecutionMode = function()
				return {
					mode = "soft",
					cancelOnTimeout = false,
					reason = "fallback"
				}
			end,
			markTimeout = function()
				return 0
			end,
			markSuccess = function()
				return
			end,
			getState = function()
				return {}
			end
		}
	end

	local HttpLoaderService = nil
	if type(HttpLoaderServiceLib) == "table" and type(HttpLoaderServiceLib.create) == "function" then
		HttpLoaderService = HttpLoaderServiceLib.create({
			compileString = compileString,
			execPolicy = ExecPolicy,
			httpGet = httpGet,
			warn = warnFn,
			taskLib = taskLib,
			clock = clockFn
		})
	end

	local function loadWithTimeout(url, timeout)
		if type(HttpLoaderService) == "table" and type(HttpLoaderService.loadWithTimeout) == "function" then
			return HttpLoaderService.loadWithTimeout(url, timeout)
		end
		local okFetch, sourceOrErr = pcall(httpGet, tostring(url))
		if not okFetch or type(sourceOrErr) ~= "string" or sourceOrErr == "" then
			warnFn("Rayfield Mod: [W_HTTP_LOADER_FALLBACK] " .. tostring(sourceOrErr))
			return nil
		end
		local chunk, compileErr = compileString(sourceOrErr)
		if not chunk then
			warnFn("Rayfield Mod: [W_HTTP_LOADER_FALLBACK] " .. tostring(compileErr))
			return nil
		end
		local okRun, runResult = pcall(chunk)
		if not okRun then
			warnFn("Rayfield Mod: [W_HTTP_LOADER_FALLBACK] " .. tostring(runResult))
			return nil
		end
		return runResult
	end

	local function createAnalyticsSender(analyticsOptions)
		analyticsOptions = type(analyticsOptions) == "table" and analyticsOptions or {}
		local provider = nil
		if type(AnalyticsProviderServiceLib) == "table" and type(AnalyticsProviderServiceLib.create) == "function" then
			provider = AnalyticsProviderServiceLib.create({
				reporterModule = AnalyticsReporterServiceLib,
				requestsDisabled = analyticsOptions.requestsDisabled,
				useStudio = analyticsOptions.useStudio,
				debug = analyticsOptions.debug,
				release = analyticsOptions.release,
				interfaceBuild = analyticsOptions.interfaceBuild,
				loadWithTimeout = loadWithTimeout,
				scriptName = analyticsOptions.scriptName,
				warn = analyticsOptions.warn,
				print = analyticsOptions.print,
				getCachedSettings = analyticsOptions.getCachedSettings
			})
		elseif type(AnalyticsReporterServiceLib) == "table" and type(AnalyticsReporterServiceLib.create) == "function" then
			provider = AnalyticsReporterServiceLib.create({
				requestsDisabled = analyticsOptions.requestsDisabled,
				useStudio = analyticsOptions.useStudio,
				debug = analyticsOptions.debug,
				release = analyticsOptions.release,
				interfaceBuild = analyticsOptions.interfaceBuild,
				loadWithTimeout = loadWithTimeout,
				scriptName = analyticsOptions.scriptName,
				warn = analyticsOptions.warn,
				print = analyticsOptions.print,
				getCachedSettings = analyticsOptions.getCachedSettings
			})
		end

		if type(provider) == "table" and type(provider.init) == "function" then
			pcall(provider.init)
		end
		if type(provider) == "table" and type(provider.sendReport) == "function" then
			return function(eventName, scriptName)
				local okReport, reportErr = pcall(provider.sendReport, eventName, scriptName)
				if not okReport then
					warnFn("Analytics report error: " .. tostring(reportErr))
					return false
				end
				return reportErr ~= false
			end
		end
		return function()
			return false
		end
	end

	return {
		ExecutionPolicyServiceLib = ExecutionPolicyServiceLib,
		HttpLoaderServiceLib = HttpLoaderServiceLib,
		AnalyticsReporterServiceLib = AnalyticsReporterServiceLib,
		AnalyticsProviderServiceLib = AnalyticsProviderServiceLib,
		AnalyticsManagerServiceLib = AnalyticsManagerServiceLib,
		RuntimeLoaderHelpersServiceLib = RuntimeLoaderHelpersServiceLib,
		LoaderHelpersFallbackServiceLib = LoaderHelpersFallbackServiceLib,
		CompatibilityInitServiceLib = CompatibilityInitServiceLib,
		ExecPolicy = ExecPolicy,
		HttpLoaderService = HttpLoaderService,
		loadWithTimeout = loadWithTimeout,
		createAnalyticsSender = createAnalyticsSender
	}
end

return RuntimeBootstrapper
