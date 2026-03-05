-- Canonical entry orchestrator for Rayfield modified runtime

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

local legacyRuntimeConfig = buildLegacyRuntimeConfig(_G)

local client = _G and _G.__RayfieldApiClient
if not client then
	local compileString = loadstring or load
	if not compileString then
		error("No Lua compiler function available (loadstring/load)")
	end

	local function compileChunk(source, label)
		if type(source) ~= "string" then
			error("Invalid Lua source for " .. tostring(label) .. ": " .. type(source))
		end
		source = source:gsub("^\239\187\191", "")
		source = source:gsub("^\0+", "")
		local chunk, err = compileString(source)
		if not chunk then
			error("Failed to compile " .. tostring(label) .. ": " .. tostring(err))
		end
		return chunk
	end

	local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
	local clientSource = game:HttpGet(root .. "src/api/client.lua")
	client = compileChunk(clientSource, "src/api/client.lua")()
	if _G then
		_G.__RayfieldApiClient = client
	end
end

if type(client) == "table" and type(client.configureRuntime) == "function" then
	pcall(client.configureRuntime, legacyRuntimeConfig)
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
if type(client) == "table" and type(client.getRuntimeConfig) == "function" then
	local okRuntimeConfig, runtimeConfig = pcall(client.getRuntimeConfig)
	if okRuntimeConfig and type(runtimeConfig) == "table" and type(runtimeConfig.runtimeRootUrl) == "string" and runtimeConfig.runtimeRootUrl ~= "" then
		root = runtimeConfig.runtimeRootUrl
		if type(_G) == "table" then
			_G.__RAYFIELD_RUNTIME_ROOT_URL = root
		end
	end
end

-- Force fresh module graph per bootstrap run to avoid stale API module cache
-- when users rerun scripts in the same executor session.
pcall(function()
	local cache = client.fetchAndExecute(root .. "src/api/cache.lua")
	if cache and type(cache.clear) == "function" then
		cache.clear()
	end
end)

local RuntimeEnv = client.fetchAndExecute(root .. "src/core/runtime-env.lua")
local WindowController = client.fetchAndExecute(root .. "src/core/window-controller.lua")

-- Initialize UI orchestration modules so they are part of the canonical graph.
-- The runtime implementation still lives in rayfield-modified.runtime.lua for full compatibility.
local WindowUi = client.fetchAndExecute(root .. "src/ui/window/init.lua")
local TopbarUi = client.fetchAndExecute(root .. "src/ui/topbar/init.lua")
local TabsUi = client.fetchAndExecute(root .. "src/ui/tabs/init.lua")
local NotificationsUi = client.fetchAndExecute(root .. "src/ui/notifications/init.lua")

local runtime = RuntimeEnv.create({
	runtimeConfig = type(client) == "table" and type(client.getRuntimeConfig) == "function" and client.getRuntimeConfig() or legacyRuntimeConfig,
	apiClient = client
})
WindowUi.init(runtime)
TopbarUi.init(runtime)
TabsUi.init(runtime)
NotificationsUi.init(runtime)

return WindowController.run(runtime)
