local Client = {}

local DEFAULT_TIMEOUT = 25
local DEFAULT_RUNTIME_ROOT = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

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

local RuntimeConfig = {
	runtimeRootUrl = DEFAULT_RUNTIME_ROOT,
	httpTimeoutSec = DEFAULT_TIMEOUT,
	httpCancelOnTimeout = nil,
	httpDefaultCancelOnTimeout = true,
	execPolicy = {
		mode = "auto",
		escalateAfter = 2,
		windowSec = 90
	},
	bundleSources = nil,
	bundleBrokenPaths = {}
}

local function normalizeRuntimeConfigPatch(options)
	local patch = {}
	if type(options) ~= "table" then
		return patch
	end

	if type(options.runtimeRootUrl) == "string" and options.runtimeRootUrl ~= "" then
		patch.runtimeRootUrl = options.runtimeRootUrl
	end

	local timeout = tonumber(options.httpTimeoutSec)
	if timeout and timeout > 0 then
		patch.httpTimeoutSec = timeout
	end

	if options.httpCancelOnTimeout ~= nil then
		patch.httpCancelOnTimeout = options.httpCancelOnTimeout == true
	end
	if options.httpDefaultCancelOnTimeout ~= nil then
		patch.httpDefaultCancelOnTimeout = options.httpDefaultCancelOnTimeout == true
	end

	if type(options.execPolicy) == "table" then
		patch.execPolicy = {}
		local mode = tostring(options.execPolicy.mode or RuntimeConfig.execPolicy.mode):lower()
		if mode ~= "auto" and mode ~= "soft" and mode ~= "hard" then
			mode = "auto"
		end
		patch.execPolicy.mode = mode

		local escalateAfter = tonumber(options.execPolicy.escalateAfter)
		if escalateAfter and escalateAfter > 0 then
			patch.execPolicy.escalateAfter = math.max(1, math.floor(escalateAfter))
		end

		local windowSec = tonumber(options.execPolicy.windowSec)
		if windowSec and windowSec > 0 then
			patch.execPolicy.windowSec = windowSec
		end
	end

	if type(options.bundleSources) == "table" then
		patch.bundleSources = options.bundleSources
	end
	if type(options.bundleBrokenPaths) == "table" then
		patch.bundleBrokenPaths = options.bundleBrokenPaths
	end

	return patch
end

function Client.configureRuntime(options)
	local patch = normalizeRuntimeConfigPatch(options)
	if patch.runtimeRootUrl ~= nil then
		RuntimeConfig.runtimeRootUrl = patch.runtimeRootUrl
	end
	if patch.httpTimeoutSec ~= nil then
		RuntimeConfig.httpTimeoutSec = patch.httpTimeoutSec
	end
	if patch.httpCancelOnTimeout ~= nil then
		RuntimeConfig.httpCancelOnTimeout = patch.httpCancelOnTimeout
	end
	if patch.httpDefaultCancelOnTimeout ~= nil then
		RuntimeConfig.httpDefaultCancelOnTimeout = patch.httpDefaultCancelOnTimeout
	end
	if type(patch.execPolicy) == "table" then
		for key, value in pairs(patch.execPolicy) do
			RuntimeConfig.execPolicy[key] = value
		end
	end
	if patch.bundleSources ~= nil then
		RuntimeConfig.bundleSources = patch.bundleSources
	end
	if patch.bundleBrokenPaths ~= nil then
		RuntimeConfig.bundleBrokenPaths = patch.bundleBrokenPaths
	end
	return true
end

function Client.getRuntimeConfig()
	return cloneValue(RuntimeConfig)
end

Client.ConfigureRuntime = Client.configureRuntime
Client.GetRuntimeConfig = Client.getRuntimeConfig

local function resolveDefaultTimeout()
	return RuntimeConfig.httpTimeoutSec or DEFAULT_TIMEOUT
end

local function ensureExecPolicyEngine()
	local state = {
		ops = {},
		history = {}
	}

	local function pushHistory(entry)
		table.insert(state.history, entry)
		if #state.history > 240 then
			table.remove(state.history, 1)
		end
	end

	local function resolveConfig()
		local cfg = RuntimeConfig.execPolicy or {}
		local mode = string.lower(tostring(cfg.mode or "auto"))
		if mode ~= "auto" and mode ~= "soft" and mode ~= "hard" then
			mode = "auto"
		end

		local escalateAfter = tonumber(cfg.escalateAfter) or 2
		escalateAfter = math.max(1, math.floor(escalateAfter))

		local windowSec = tonumber(cfg.windowSec) or 90
		windowSec = math.max(1, windowSec)

		return {
			mode = mode,
			escalateAfter = escalateAfter,
			windowSec = windowSec
		}
	end

	local function ensureOp(opKey)
		local key = tostring(opKey or "default")
		local op = state.ops[key]
		if type(op) ~= "table" then
			op = {
				consecutiveTimeouts = 0,
				lastTimeoutAt = nil,
				lastSuccessAt = nil
			}
			state.ops[key] = op
		end
		return key, op
	end

	local policy = {}

	function policy.decideExecutionMode(opKey, isBlocking, timeoutSeconds, now)
		local cfg = resolveConfig()
		local current = tonumber(now) or os.clock()
		local key, op = ensureOp(opKey)
		local mode = "soft"
		local reason = "default-soft"

		if cfg.mode == "hard" then
			mode = "hard"
			reason = "forced-hard"
		elseif cfg.mode == "soft" then
			mode = "soft"
			reason = "forced-soft"
		else
			local streak = tonumber(op.consecutiveTimeouts) or 0
			local withinWindow = type(op.lastTimeoutAt) == "number" and (current - op.lastTimeoutAt) <= cfg.windowSec
			if streak >= math.max(1, cfg.escalateAfter - 1) and withinWindow then
				mode = "hard"
				reason = string.format("auto-escalated:%d/%d<=%ss", streak + 1, cfg.escalateAfter, tostring(cfg.windowSec))
			elseif streak > 0 and withinWindow then
				mode = "soft"
				reason = string.format("auto-soft-streak:%d/%d", streak, cfg.escalateAfter)
			else
				mode = "soft"
				reason = "auto-soft-reset"
			end
		end

		op.lastDecision = mode
		op.lastReason = reason
		op.lastIsBlocking = isBlocking == true
		op.lastTimeoutSeconds = timeoutSeconds
		op.lastUpdatedAt = current
		state.lastDecision = {
			op = key,
			mode = mode,
			reason = reason,
			at = current,
			isBlocking = isBlocking == true,
			timeoutSeconds = timeoutSeconds
		}
		pushHistory({
			type = "decision",
			op = key,
			mode = mode,
			reason = reason,
			at = current
		})

		return {
			mode = mode,
			cancelOnTimeout = mode == "hard",
			reason = reason
		}
	end

	function policy.markTimeout(opKey, now, meta)
		local cfg = resolveConfig()
		local current = tonumber(now) or os.clock()
		local key, op = ensureOp(opKey)
		local withinWindow = type(op.lastTimeoutAt) == "number" and (current - op.lastTimeoutAt) <= cfg.windowSec
		if withinWindow then
			op.consecutiveTimeouts = (tonumber(op.consecutiveTimeouts) or 0) + 1
		else
			op.consecutiveTimeouts = 1
		end
		op.lastTimeoutAt = current
		op.lastUpdatedAt = current
		state.lastTimeout = {
			op = key,
			at = current,
			consecutive = op.consecutiveTimeouts,
			meta = meta
		}
		pushHistory({
			type = "timeout",
			op = key,
			at = current,
			consecutive = op.consecutiveTimeouts
		})
		return op.consecutiveTimeouts
	end

	function policy.markSuccess(opKey, now, meta)
		local current = tonumber(now) or os.clock()
		local key, op = ensureOp(opKey)
		op.consecutiveTimeouts = 0
		op.lastSuccessAt = current
		op.lastUpdatedAt = current
		state.lastSuccess = {
			op = key,
			at = current,
			meta = meta
		}
		pushHistory({
			type = "success",
			op = key,
			at = current
		})
	end

	function policy.getState()
		return state
	end

	return policy
end

local ExecPolicy = ensureExecPolicyEngine()

local function resolveCancelOverride(opts)
	if opts.cancelOnTimeout ~= nil then
		return opts.cancelOnTimeout == true, "request-override:opts.cancelOnTimeout"
	end
	if RuntimeConfig.httpCancelOnTimeout ~= nil then
		return RuntimeConfig.httpCancelOnTimeout == true, "runtime-config:httpCancelOnTimeout"
	end
	return nil, nil
end

local function shouldDefaultCancelOnTimeout()
	return RuntimeConfig.httpDefaultCancelOnTimeout ~= false
end

local function getBundleTable()
	return type(RuntimeConfig.bundleSources) == "table" and RuntimeConfig.bundleSources or nil
end

local function getBrokenBundleMap()
	if type(RuntimeConfig.bundleBrokenPaths) ~= "table" then
		RuntimeConfig.bundleBrokenPaths = {}
	end
	return RuntimeConfig.bundleBrokenPaths
end

local function sanitizeLuaSource(code)
	if type(code) ~= "string" then
		return code
	end
	code = code:gsub("^\239\187\191", "")
	code = code:gsub("^\0+", "")
	return code
end

local function normalizeUrl(url)
	if type(url) ~= "string" or #url == 0 then
		error("Client.request expected non-empty URL string")
	end
	return url
end

local function resolveBundlePath(url)
	local function urlDecode(value)
		return (value:gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end))
	end

	local runtimeRoot = RuntimeConfig.runtimeRootUrl
	if type(runtimeRoot) == "string" and runtimeRoot ~= "" and url:sub(1, #runtimeRoot) == runtimeRoot then
		return urlDecode(url:sub(#runtimeRoot + 1))
	end

	local githubPath = url:match("^https?://raw%.githubusercontent%.com/[^/]+/[^/]+/[^/]+/(.+)$")
	if githubPath then
		return urlDecode(githubPath)
	end

	return nil
end

local function tryGetBundledSource(url, opts)
	opts = opts or {}
	if opts.noBundle then
		return nil, nil
	end

	local bundle = getBundleTable()
	if not bundle then
		return nil, nil
	end

	local path = resolveBundlePath(url)
	local broken = getBrokenBundleMap()
	if path and broken and broken[path] then
		return nil, path
	end
	if broken and broken[url] then
		return nil, path
	end

	if path then
		local byPath = bundle[path]
		if type(byPath) == "string" and #byPath > 0 then
			return byPath, path
		end
	end

	local byUrl = bundle[url]
	if type(byUrl) == "string" and #byUrl > 0 then
		return byUrl, path
	end

	return nil, path
end

local function resolveSource(url, opts)
	opts = opts or {}
	local bundledSource, bundledPath = tryGetBundledSource(url, opts)
	if bundledSource then
		return bundledSource, true, bundledPath
	end

	local ok, payload = Client.request(url, opts)
	if not ok then
		error(tostring(payload))
	end
	if type(payload) ~= "string" then
		error("Client.fetch expected string payload, got " .. type(payload))
	end
	return payload, false, bundledPath
end

function Client.request(url, opts)
	url = normalizeUrl(url)
	opts = opts or {}
	local timeout = tonumber(opts.timeout)
	if not timeout or timeout <= 0 then
		timeout = resolveDefaultTimeout()
	end
	local opKey = "http:" .. tostring(url)
	local decision = ExecPolicy.decideExecutionMode(opKey, false, timeout, os.clock())
	local cancelOnTimeout = decision.cancelOnTimeout == true
	local policyMode = decision.mode
	local policyReason = decision.reason
	local overrideCancel, overrideReason = resolveCancelOverride(opts)
	if overrideCancel ~= nil then
		cancelOnTimeout = overrideCancel
		policyMode = cancelOnTimeout and "hard" or "soft"
		policyReason = overrideReason
	elseif cancelOnTimeout ~= true and shouldDefaultCancelOnTimeout() then
		cancelOnTimeout = true
		policyMode = "hard"
		policyReason = "runtime-config:httpDefaultCancelOnTimeout"
	end
	local completed = false
	local okResult = false
	local payload = nil

	local worker = task.spawn(function()
		local ok, result = pcall(game.HttpGet, game, url)
		if completed then
			return
		end
		okResult = ok
		payload = result
		completed = true
	end)

	local timeoutThread = task.delay(timeout, function()
		if completed then
			return
		end
		completed = true
		okResult = false
		payload = "Request timed out after " .. tostring(timeout) .. " seconds"
			.. " | policy=" .. tostring(policyMode)
			.. " | reason=" .. tostring(policyReason)
		ExecPolicy.markTimeout(opKey, os.clock(), {
			mode = policyMode,
			reason = policyReason,
			timeoutSeconds = timeout,
			canceled = cancelOnTimeout,
			isBlocking = false
		})
		if cancelOnTimeout then
			pcall(task.cancel, worker)
		end
	end)

	while not completed do
		task.wait()
	end

	pcall(task.cancel, timeoutThread)
	if okResult == true then
		ExecPolicy.markSuccess(opKey, os.clock(), {
			mode = policyMode,
			reason = policyReason,
			timeoutSeconds = timeout,
			isBlocking = false
		})
	end
	return okResult, payload
end

function Client.fetch(url, opts)
	local source = resolveSource(url, opts)
	return source
end

function Client.compile(code)
	if type(code) ~= "string" or #code == 0 then
		error("Client.compile expected non-empty Lua source string")
	end
	code = sanitizeLuaSource(code)
	local compileString = loadstring or load
	if not compileString then
		error("No Lua compiler function available (loadstring/load)")
	end
	local chunk, compileError = compileString(code)
	if not chunk then
		error("Client.compile failed: " .. tostring(compileError))
	end
	return chunk
end

function Client.execute(code)
	return Client.compile(code)()
end

function Client.fetchAndExecute(url, opts)
	opts = opts or {}
	local code, fromBundle, bundlePath = resolveSource(url, opts)
	local okExecute, result = pcall(Client.execute, code)
	if okExecute then
		return result
	end

	if fromBundle then
		local broken = getBrokenBundleMap()
		if broken then
			if bundlePath then
				broken[bundlePath] = true
			end
			broken[url] = true
		end
		local retryOpts = {}
		for key, value in pairs(opts) do
			retryOpts[key] = value
		end
		retryOpts.noBundle = true
		local retryCode = Client.fetch(url, retryOpts)
		return Client.execute(retryCode)
	end

	error(result)
end

if _G then
	_G.__RayfieldApiClient = Client
end

return Client
