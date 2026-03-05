local RuntimeConfig = {}

local DEFAULT_RUNTIME_ROOT = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local DEFAULT_HTTP_TIMEOUT_SEC = 25

local function cloneValue(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, child in pairs(value) do
		out[key] = cloneValue(child)
	end
	return out
end

local function mergeInto(target, source)
	if type(target) ~= "table" or type(source) ~= "table" then
		return
	end
	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			mergeInto(target[key], value)
		else
			target[key] = cloneValue(value)
		end
	end
end

local function normalizeRuntimeRoot(url)
	if type(url) ~= "string" or url == "" then
		return DEFAULT_RUNTIME_ROOT
	end
	return url
end

local function normalizeConfigTable(input)
	local output = {
		runtimeRootUrl = DEFAULT_RUNTIME_ROOT,
		httpTimeoutSec = DEFAULT_HTTP_TIMEOUT_SEC,
		httpCancelOnTimeout = nil,
		httpDefaultCancelOnTimeout = true,
		execPolicy = {
			mode = "auto",
			escalateAfter = 2,
			windowSec = 90
		},
		bundleSources = nil,
		bundleBrokenPaths = {},
		compatFlags = {}
	}

	if type(input) ~= "table" then
		return output
	end

	if input.runtimeRootUrl ~= nil then
		output.runtimeRootUrl = normalizeRuntimeRoot(input.runtimeRootUrl)
	end

	local timeout = tonumber(input.httpTimeoutSec)
	if timeout and timeout > 0 then
		output.httpTimeoutSec = timeout
	end

	if input.httpCancelOnTimeout ~= nil then
		output.httpCancelOnTimeout = input.httpCancelOnTimeout == true
	end
	if input.httpDefaultCancelOnTimeout ~= nil then
		output.httpDefaultCancelOnTimeout = input.httpDefaultCancelOnTimeout == true
	end

	if type(input.execPolicy) == "table" then
		mergeInto(output.execPolicy, input.execPolicy)
	end

	if type(input.bundleSources) == "table" then
		output.bundleSources = input.bundleSources
	end
	if type(input.bundleBrokenPaths) == "table" then
		output.bundleBrokenPaths = input.bundleBrokenPaths
	end
	if type(input.compatFlags) == "table" then
		output.compatFlags = input.compatFlags
	end

	return output
end

function RuntimeConfig.fromLegacyGlobals(globalEnv)
	if type(globalEnv) ~= "table" then
		return {
			runtimeRootUrl = DEFAULT_RUNTIME_ROOT
		}
	end

	local output = {
		runtimeRootUrl = normalizeRuntimeRoot(globalEnv.__RAYFIELD_RUNTIME_ROOT_URL),
		httpTimeoutSec = tonumber(globalEnv.__RAYFIELD_HTTP_TIMEOUT_SEC) or DEFAULT_HTTP_TIMEOUT_SEC,
		httpCancelOnTimeout = globalEnv.__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT,
		httpDefaultCancelOnTimeout = globalEnv.__RAYFIELD_HTTP_DEFAULT_CANCEL_ON_TIMEOUT,
		execPolicy = {
			mode = globalEnv.__RAYFIELD_EXEC_POLICY_MODE,
			escalateAfter = tonumber(globalEnv.__RAYFIELD_EXEC_POLICY_ESCALATE_AFTER),
			windowSec = tonumber(globalEnv.__RAYFIELD_EXEC_POLICY_WINDOW_SEC)
		},
		bundleSources = type(globalEnv.__RAYFIELD_BUNDLE_SOURCES) == "table" and globalEnv.__RAYFIELD_BUNDLE_SOURCES or nil,
		bundleBrokenPaths = type(globalEnv.__RAYFIELD_BUNDLE_BROKEN_PATHS) == "table" and globalEnv.__RAYFIELD_BUNDLE_BROKEN_PATHS or {},
		compatFlags = type(globalEnv.__RAYFIELD_COMPAT_FLAGS) == "table" and globalEnv.__RAYFIELD_COMPAT_FLAGS or {}
	}
	return output
end

function RuntimeConfig.create(initial)
	local state = normalizeConfigTable(initial)

	local service = {}

	function service.configure(options)
		if type(options) ~= "table" then
			return false, "Runtime config requires table options."
		end
		local incoming = normalizeConfigTable(options)
		if options.runtimeRootUrl == nil then
			incoming.runtimeRootUrl = state.runtimeRootUrl
		end
		if options.httpTimeoutSec == nil then
			incoming.httpTimeoutSec = state.httpTimeoutSec
		end
		if options.httpCancelOnTimeout == nil then
			incoming.httpCancelOnTimeout = state.httpCancelOnTimeout
		end
		if options.httpDefaultCancelOnTimeout == nil then
			incoming.httpDefaultCancelOnTimeout = state.httpDefaultCancelOnTimeout
		end
		if type(options.execPolicy) ~= "table" then
			incoming.execPolicy = cloneValue(state.execPolicy)
		else
			mergeInto(incoming.execPolicy, options.execPolicy)
		end
		if options.bundleSources == nil then
			incoming.bundleSources = state.bundleSources
		end
		if options.bundleBrokenPaths == nil then
			incoming.bundleBrokenPaths = state.bundleBrokenPaths
		end
		if options.compatFlags == nil then
			incoming.compatFlags = state.compatFlags
		end
		state = incoming
		return true
	end

	function service.get()
		return cloneValue(state)
	end

	function service.getRuntimeRootUrl()
		return state.runtimeRootUrl
	end

	function service.getHttpTimeoutSec()
		return state.httpTimeoutSec
	end

	function service.getHttpCancelOnTimeout()
		return state.httpCancelOnTimeout
	end

	function service.getHttpDefaultCancelOnTimeout()
		return state.httpDefaultCancelOnTimeout
	end

	function service.getExecPolicy()
		return cloneValue(state.execPolicy)
	end

	function service.getBundleSources()
		return state.bundleSources
	end

	function service.getBundleBrokenPaths()
		return state.bundleBrokenPaths
	end

	function service.getCompatFlags()
		return state.compatFlags
	end

	return service
end

return RuntimeConfig
