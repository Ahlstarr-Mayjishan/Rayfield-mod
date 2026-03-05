local LoaderHelpersService = {}

local function createDiagnostics(globalEnv)
	local diagnostics = {
		optionalFailed = {},
		notified = false,
		performanceProfile = nil,
		startup = nil
	}
	if type(globalEnv) == "table" then
		globalEnv.__RAYFIELD_LOADER_DIAGNOSTICS = diagnostics
	end
	return diagnostics
end

local function formatLoaderError(code, message)
	return string.format("Rayfield Mod: [%s] %s", tostring(code or "E_LOADER"), tostring(message or "Unknown loader error"))
end

function LoaderHelpersService.createFallback(options)
	options = type(options) == "table" and options or {}
	local apiClient = options.apiClient
	local rootUrl = tostring(options.rootUrl or "")
	local useStudio = options.useStudio == true
	local getScriptRef = type(options.getScriptRef) == "function" and options.getScriptRef or function()
		return nil
	end
	local warnFn = type(options.warn) == "function" and options.warn or warn
	local globalEnv = options.globalEnv
	local clockFn = type(options.clock) == "function" and options.clock or os.clock
	local startupTraceApi = type(globalEnv) == "table" and globalEnv.__RAYFIELD_STARTUP_TRACE_API or nil

	local diagnostics = createDiagnostics(globalEnv)
	local apiLoaderFallback = nil

	local function syncStartupDiagnostics()
		if type(startupTraceApi) == "table" and type(startupTraceApi.getCurrentSummary) == "function" then
			local okCurrent, summary = pcall(startupTraceApi.getCurrentSummary)
			if okCurrent and type(summary) == "table" then
				diagnostics.startup = summary
				return
			end
		end
		if type(startupTraceApi) == "table" and type(startupTraceApi.getLastSummary) == "function" then
			local okLast, summary = pcall(startupTraceApi.getLastSummary)
			if okLast and type(summary) == "table" then
				diagnostics.startup = summary
				return
			end
		end
		if type(globalEnv) == "table" and type(globalEnv.__RAYFIELD_STARTUP_LAST_SUMMARY) == "table" then
			diagnostics.startup = globalEnv.__RAYFIELD_STARTUP_LAST_SUMMARY
		end
	end

	local function startModuleStage(moduleName, meta)
		if type(startupTraceApi) == "table" and type(startupTraceApi.startStage) == "function" then
			local okStage, stage = pcall(startupTraceApi.startStage, "module_load:" .. tostring(moduleName), "module", meta)
			if okStage and type(stage) == "table" then
				return stage
			end
		end
		return {
			__fallback = true,
			startClock = clockFn(),
			name = "module_load:" .. tostring(moduleName),
			source = "module",
			meta = meta
		}
	end

	local function finishModuleStage(stageHandle, status, meta)
		if type(stageHandle) ~= "table" then
			return
		end
		if stageHandle.__fallback ~= true
			and type(startupTraceApi) == "table"
			and type(startupTraceApi.finishStage) == "function" then
			pcall(startupTraceApi.finishStage, stageHandle, status, meta)
			syncStartupDiagnostics()
			return
		end
		local endClock = clockFn()
		local durationMs = math.max(0, math.floor(((endClock - (tonumber(stageHandle.startClock) or endClock)) * 1000) + 0.5))
		diagnostics.startup = diagnostics.startup or {
			mode = "auto",
			targetMs = 2000,
			totalMs = 0,
			bundle = { attempted = false, used = false, hitRate = 0 },
			stages = {},
			hotspots = {}
		}
		local startupStages = diagnostics.startup.stages
		if type(startupStages) ~= "table" then
			startupStages = {}
			diagnostics.startup.stages = startupStages
		end
		table.insert(startupStages, {
			name = tostring(stageHandle.name or "module_load"),
			durationMs = durationMs,
			status = tostring(status or "ok"),
			source = tostring(stageHandle.source or "module")
		})
	end

	local function loadModuleFallback(moduleName)
		local stageHandle = startModuleStage(moduleName, {
			tryStudioRequire = useStudio
		})
		if type(apiLoaderFallback) ~= "table" or type(apiLoaderFallback.load) ~= "function" then
			finishModuleStage(stageHandle, "error", { error = "API loader unavailable" })
			return false, "API loader unavailable"
		end
		local opts = {
			tryStudioRequire = useStudio,
			scriptRef = getScriptRef(),
			allowLegacyFallback = true
		}
		if type(apiLoaderFallback.tryLoad) == "function" then
			local okTryLoad, loadedOrErr = apiLoaderFallback.tryLoad(moduleName, opts)
			finishModuleStage(stageHandle, okTryLoad and "ok" or "error", {
				error = okTryLoad and nil or tostring(loadedOrErr)
			})
			return okTryLoad, loadedOrErr
		end
		local okLoad, result = pcall(apiLoaderFallback.load, moduleName, opts)
		if okLoad then
			finishModuleStage(stageHandle, "ok")
			return true, result
		end
		finishModuleStage(stageHandle, "error", { error = tostring(result) })
		return false, tostring(result)
	end

	local helpers = {}

	function helpers.fetchExecuteSafely(path)
		if type(apiClient) ~= "table" or type(apiClient.fetchAndExecute) ~= "function" then
			return false, "ApiClient unavailable"
		end
		local ok, result = pcall(apiClient.fetchAndExecute, rootUrl .. tostring(path))
		if ok then
			return true, result
		end
		return false, tostring(result)
	end

	function helpers.setApiLoader(loader)
		apiLoaderFallback = loader
		return true
	end

	function helpers.requireModule(moduleName, hint)
		local okLoad, result = loadModuleFallback(moduleName)
		if okLoad then
			return result
		end
		local reason = tostring(result)
		if hint then
			reason = tostring(hint) .. "\n" .. reason
		end
		error(formatLoaderError("E_REQUIRED_MODULE", "Failed to load required module '" .. tostring(moduleName) .. "'.\n" .. reason))
	end

	function helpers.optionalModule(moduleName, fallbackModule, hint)
		local okLoad, result = loadModuleFallback(moduleName)
		if okLoad then
			return result
		end
		table.insert(diagnostics.optionalFailed, {
			module = moduleName,
			error = tostring(result)
		})
		local message = "Optional module '" .. tostring(moduleName) .. "' failed to load. Using fallback."
		if hint then
			message = message .. " " .. tostring(hint)
		end
		warnFn(formatLoaderError("W_OPTIONAL_MODULE", message .. " | " .. tostring(result)))
		return fallbackModule
	end

	function helpers.optionalModuleWithContract(moduleName, validatorFn, hint)
		local okLoad, result = loadModuleFallback(moduleName)
		if okLoad and type(validatorFn) == "function" and validatorFn(result) then
			return result
		end
		table.insert(diagnostics.optionalFailed, {
			module = moduleName,
			error = okLoad and "Invalid module contract" or tostring(result)
		})
		local message = "Optional module '" .. tostring(moduleName) .. "' failed to load. Feature disabled."
		if hint then
			message = message .. " " .. tostring(hint)
		end
		local detail = okLoad and "Invalid module contract" or tostring(result)
		warnFn(formatLoaderError("W_OPTIONAL_MODULE", message .. " | " .. detail))
		return nil
	end

	function helpers.maybeNotifyFallback(notifyFn)
		if diagnostics.notified or #diagnostics.optionalFailed == 0 then
			return
		end
		diagnostics.notified = true
		local moduleNames = {}
		for _, item in ipairs(diagnostics.optionalFailed) do
			table.insert(moduleNames, tostring(item.module))
		end
		local message = "Loaded with fallback modules: " .. table.concat(moduleNames, ", ")
		if type(notifyFn) == "function" then
			local okNotify, notifyErr = pcall(notifyFn, message)
			if not okNotify then
				warnFn(formatLoaderError("W_OPTIONAL_MODULE", message .. " | notify failed: " .. tostring(notifyErr)))
			end
			return
		end
		warnFn(formatLoaderError("W_OPTIONAL_MODULE", message))
	end

	function helpers.getDiagnostics()
		return diagnostics
	end

	return helpers
end

return LoaderHelpersService
