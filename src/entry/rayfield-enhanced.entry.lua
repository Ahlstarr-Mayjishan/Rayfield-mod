local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local function buildLegacyRuntimeConfig(globalEnv)
	if type(globalEnv) ~= "table" then
		return {}
	end
	return {
		runtimeRootUrl = globalEnv.__RAYFIELD_RUNTIME_ROOT_URL,
		httpTimeoutSec = globalEnv.__RAYFIELD_HTTP_TIMEOUT_SEC,
		httpCancelOnTimeout = globalEnv.__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT,
		httpDefaultCancelOnTimeout = globalEnv.__RAYFIELD_HTTP_DEFAULT_CANCEL_ON_TIMEOUT,
		execPolicy = {
			mode = globalEnv.__RAYFIELD_EXEC_POLICY_MODE,
			escalateAfter = globalEnv.__RAYFIELD_EXEC_POLICY_ESCALATE_AFTER,
			windowSec = globalEnv.__RAYFIELD_EXEC_POLICY_WINDOW_SEC
		},
		bundleSources = type(globalEnv.__RAYFIELD_BUNDLE_SOURCES) == "table" and globalEnv.__RAYFIELD_BUNDLE_SOURCES or nil,
		bundleBrokenPaths = type(globalEnv.__RAYFIELD_BUNDLE_BROKEN_PATHS) == "table" and globalEnv.__RAYFIELD_BUNDLE_BROKEN_PATHS or nil,
		compatFlags = type(globalEnv.__RAYFIELD_COMPAT_FLAGS) == "table" and globalEnv.__RAYFIELD_COMPAT_FLAGS or nil
	}
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local Client = compileString(game:HttpGet(root .. "src/api/client.lua"))()
if type(Client) == "table" and type(Client.configureRuntime) == "function" then
	pcall(Client.configureRuntime, buildLegacyRuntimeConfig(_G))
end
if type(Client) == "table" and type(Client.getRuntimeConfig) == "function" then
	local okRuntimeConfig, runtimeConfig = pcall(Client.getRuntimeConfig)
	if okRuntimeConfig and type(runtimeConfig) == "table" and type(runtimeConfig.runtimeRootUrl) == "string" and runtimeConfig.runtimeRootUrl ~= "" then
		root = runtimeConfig.runtimeRootUrl
		if type(_G) == "table" then
			_G.__RAYFIELD_RUNTIME_ROOT_URL = root
		end
	end
end
if _G then
	_G.__RayfieldApiClient = Client
end
return Client.fetchAndExecute(root .. "src/feature/enhanced/init.lua")
