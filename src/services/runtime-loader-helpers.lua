local RuntimeLoaderHelpersService = {}

local function formatLoaderError(code, message)
	return string.format("Rayfield Mod: [%s] %s", tostring(code or "E_LOADER"), tostring(message or "Unknown loader error"))
end

function RuntimeLoaderHelpersService.create(options)
	options = options or {}
	local rootUrl = tostring(options.rootUrl or "")
	local apiClient = options.apiClient
	local useStudio = options.useStudio == true
	local getScriptRef = type(options.getScriptRef) == "function" and options.getScriptRef or function()
		return nil
	end
	local warnFn = type(options.warn) == "function" and options.warn or warn
	local globalEnv = type(options.globalEnv) == "table" and options.globalEnv or nil
	local apiLoader = options.apiLoader

	local diagnostics = {
		optionalFailed = {},
		notified = false,
		performanceProfile = nil
	}

	if globalEnv then
		globalEnv.__RAYFIELD_LOADER_DIAGNOSTICS = diagnostics
	end

	local service = {}

	function service.fetchExecuteSafely(path)
		if type(apiClient) ~= "table" or type(apiClient.fetchAndExecute) ~= "function" then
			return false, "ApiClient.fetchAndExecute unavailable"
		end
		local ok, result = pcall(apiClient.fetchAndExecute, rootUrl .. tostring(path or ""))
		if ok then
			return true, result
		end
		return false, tostring(result)
	end

	function service.setApiLoader(loader)
		apiLoader = loader
		return true
	end

	function service.loadModule(moduleName)
		if type(apiLoader) ~= "table" or type(apiLoader.load) ~= "function" then
			return false, "API loader unavailable"
		end
		local opts = {
			tryStudioRequire = useStudio,
			scriptRef = getScriptRef(),
			allowLegacyFallback = true
		}
		if type(apiLoader.tryLoad) == "function" then
			return apiLoader.tryLoad(moduleName, opts)
		end
		local ok, result = pcall(apiLoader.load, moduleName, opts)
		if ok then
			return true, result
		end
		return false, tostring(result)
	end

	function service.requireModule(moduleName, hint)
		local ok, result = service.loadModule(moduleName)
		if ok then
			return result
		end
		local reason = tostring(result)
		if hint then
			reason = tostring(hint) .. "\n" .. reason
		end
		error(formatLoaderError("E_REQUIRED_MODULE", "Failed to load required module '" .. tostring(moduleName) .. "'.\n" .. reason))
	end

	function service.optionalModule(moduleName, fallbackModule, hint)
		local ok, result = service.loadModule(moduleName)
		if ok then
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

	function service.optionalModuleWithContract(moduleName, validatorFn, hint)
		local ok, result = service.loadModule(moduleName)
		if ok and type(validatorFn) == "function" and validatorFn(result) then
			return result
		end
		table.insert(diagnostics.optionalFailed, {
			module = moduleName,
			error = ok and "Invalid module contract" or tostring(result)
		})
		local message = "Optional module '" .. tostring(moduleName) .. "' failed to load. Feature disabled."
		if hint then
			message = message .. " " .. tostring(hint)
		end
		local detail = ok and "Invalid module contract" or tostring(result)
		warnFn(formatLoaderError("W_OPTIONAL_MODULE", message .. " | " .. detail))
		return nil
	end

	function service.maybeNotifyFallback(notifyFn)
		if diagnostics.notified or #diagnostics.optionalFailed == 0 then
			return false
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
				return false
			end
			return true
		end

		warnFn(formatLoaderError("W_OPTIONAL_MODULE", message))
		return false
	end

	function service.getDiagnostics()
		return diagnostics
	end

	return service
end

return RuntimeLoaderHelpersService
