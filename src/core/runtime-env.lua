local RuntimeEnv = {}

local DEFAULT_RUNTIME_ROOT = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local function resolveRuntimeRoot(runtimeConfig, explicitRoot)
	if type(explicitRoot) == "string" and explicitRoot ~= "" then
		return explicitRoot
	end
	if type(runtimeConfig) == "table" and type(runtimeConfig.getRuntimeRootUrl) == "function" then
		local configured = runtimeConfig.getRuntimeRootUrl()
		if type(configured) == "string" and configured ~= "" then
			return configured
		end
	end
	if type(runtimeConfig) == "table" and type(runtimeConfig.runtimeRootUrl) == "string" and runtimeConfig.runtimeRootUrl ~= "" then
		return runtimeConfig.runtimeRootUrl
	end
	return DEFAULT_RUNTIME_ROOT
end

local function resolveCompatibility(runtimeConfig, apiClient)
	if type(_G) == "table" and type(_G.__RayfieldCompatibility) == "table" then
		return _G.__RayfieldCompatibility
	end

	local client = apiClient
	if type(client) ~= "table" and type(_G) == "table" then
		client = _G.__RayfieldApiClient
	end
	if type(client) ~= "table" or type(client.fetchAndExecute) ~= "function" then
		return nil
	end

	local root = resolveRuntimeRoot(runtimeConfig)
	local ok, compat = pcall(client.fetchAndExecute, root .. "src/services/compatibility.lua")
	if ok and type(compat) == "table" then
		if type(compat.configureRuntime) == "function" and type(runtimeConfig) == "table" then
			pcall(compat.configureRuntime, runtimeConfig)
		end
		return compat
	end

	return nil
end

local function fallbackGetService(name)
	local ok, service = pcall(function()
		return game:GetService(name)
	end)
	if ok and service then
		return service
	end
	return nil
end

function RuntimeEnv.create(overrides)
	overrides = overrides or {}
	local runtimeConfig = overrides.runtimeConfig
	local compatibility = overrides.compatibility or resolveCompatibility(runtimeConfig, overrides.apiClient)
	local getService = fallbackGetService
	if compatibility and type(compatibility.getService) == "function" then
		getService = compatibility.getService
	end

	local runService = overrides.runService or getService("RunService")
	local useStudio = overrides.useStudio
	if useStudio == nil and runService then
		local okStudio, studio = pcall(function()
			return runService:IsStudio()
		end)
		useStudio = okStudio and studio or false
	end
	if useStudio == nil then
		useStudio = false
	end

	return {
		useStudio = useStudio,
		runtimeRootUrl = resolveRuntimeRoot(runtimeConfig, overrides.runtimeRootUrl),
		runtimeConfig = runtimeConfig,
		compatibility = compatibility,
		services = {
			RunService = runService,
			UserInputService = overrides.userInputService or getService("UserInputService"),
			TweenService = overrides.tweenService or getService("TweenService"),
			HttpService = overrides.httpService or getService("HttpService")
		}
	}
end

return RuntimeEnv
