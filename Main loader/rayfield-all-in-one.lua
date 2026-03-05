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
local legacyRuntimeConfig = buildLegacyRuntimeConfig(_G)

if type(_G) == "table" then
	_G.__RAYFIELD_BUNDLE_MODE = _G.__RAYFIELD_BUNDLE_MODE or "bundle_auto"
end

local function configureApiRuntime()
	local clientSource = nil
	if type(_G) == "table" and type(_G.__RAYFIELD_BUNDLE_SOURCES) == "table" then
		clientSource = _G.__RAYFIELD_BUNDLE_SOURCES["src/api/client.lua"]
	end
	if type(clientSource) ~= "string" or clientSource == "" then
		local okFetch, source = pcall(game.HttpGet, game, root .. "src/api/client.lua")
		if okFetch and type(source) == "string" and source ~= "" then
			clientSource = source
		end
	end
	if type(clientSource) ~= "string" or clientSource == "" then
		return
	end
	local client = compileChunk(clientSource, "src/api/client.lua")()
	if type(client) == "table" and type(client.configureRuntime) == "function" then
		pcall(client.configureRuntime, legacyRuntimeConfig)
	end
	if type(client) == "table" and type(client.getRuntimeConfig) == "function" then
		local okConfig, runtimeConfig = pcall(client.getRuntimeConfig)
		if okConfig and type(runtimeConfig) == "table" and type(runtimeConfig.runtimeRootUrl) == "string" and runtimeConfig.runtimeRootUrl ~= "" then
			root = runtimeConfig.runtimeRootUrl
			if type(_G) == "table" then
				_G.__RAYFIELD_RUNTIME_ROOT_URL = root
			end
		end
	end
	if type(_G) == "table" then
		_G.__RayfieldApiClient = client
	end
end

configureApiRuntime()

local function tryLoadBundle(path)
	local okFetch, source = pcall(game.HttpGet, game, root .. path)
	if not okFetch or type(source) ~= "string" or source == "" then
		return false
	end
	local okCompile, bundleOrErr = pcall(function()
		return compileChunk(source, path)()
	end)
	if not okCompile then
		warn("Rayfield Mod: bundle preload failed (" .. tostring(path) .. "): " .. tostring(bundleOrErr))
		return false
	end
	return type(bundleOrErr) == "table"
end

local function preloadBundlesIfEnabled()
	if type(_G) ~= "table" then
		return
	end
	local shouldPreload = _G.__RAYFIELD_AUTO_PRELOAD_BUNDLES
	if shouldPreload == nil then
		shouldPreload = true
	end
	if shouldPreload ~= true then
		return
	end
	if _G.__RAYFIELD_BUNDLE_PRELOAD_ATTEMPTED then
		return
	end
	_G.__RAYFIELD_BUNDLE_PRELOAD_ATTEMPTED = true
	local coreOk = tryLoadBundle("dist/rayfield-runtime-core.bundle.lua")
	local uiOk = tryLoadBundle("dist/rayfield-runtime-ui.bundle.lua")
	_G.__RAYFIELD_BUNDLE_PRELOADED = coreOk or uiOk
end

local function fetchSource(path, label)
	if type(_G) == "table" and type(_G.__RAYFIELD_BUNDLE_SOURCES) == "table" then
		local bundled = _G.__RAYFIELD_BUNDLE_SOURCES[path]
		if type(bundled) == "string" and bundled ~= "" then
			return bundled
		end
	end

	local okFetch, source = pcall(game.HttpGet, game, root .. path)
	if not okFetch then
		error("Failed to fetch " .. tostring(label or path) .. ": " .. tostring(source))
	end
	if type(source) ~= "string" or source == "" then
		error("Empty source for " .. tostring(label or path))
	end
	return source
end

preloadBundlesIfEnabled()

local forwardSource = fetchSource("src/legacy/forward.lua", "src/legacy/forward.lua")
local Forward = compileChunk(forwardSource, "src/legacy/forward.lua")()
return Forward.module("allInOne")
