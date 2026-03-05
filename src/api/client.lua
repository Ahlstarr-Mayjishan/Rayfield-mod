local Client = {}

local DEFAULT_TIMEOUT = 25

local function resolveDefaultTimeout()
	local configured = type(_G) == "table" and tonumber(_G.__RAYFIELD_HTTP_TIMEOUT_SEC) or nil
	if configured and configured > 0 then
		return configured
	end
	return DEFAULT_TIMEOUT
end

local function ensureExecPolicyEngine()
	local globalEnv = type(_G) == "table" and _G or nil
	local policyVersion = 2
	if globalEnv
		and tonumber(globalEnv.__RAYFIELD_EXEC_POLICY_VERSION) == policyVersion
		and type(globalEnv.__RAYFIELD_EXEC_POLICY) == "table"
		and type(globalEnv.__RAYFIELD_EXEC_POLICY.decideExecutionMode) == "function"
		and type(globalEnv.__RAYFIELD_EXEC_POLICY.markTimeout) == "function"
		and type(globalEnv.__RAYFIELD_EXEC_POLICY.markSuccess) == "function" then
		return globalEnv.__RAYFIELD_EXEC_POLICY
	end

	local state = globalEnv and globalEnv.__RAYFIELD_EXEC_POLICY_STATE or nil
	if type(state) ~= "table" then
		state = {}
	end
	if type(state.ops) ~= "table" then
		state.ops = {}
	end
	if type(state.history) ~= "table" then
		state.history = {}
	end

	local function pushHistory(entry)
		table.insert(state.history, entry)
		if #state.history > 240 then
			table.remove(state.history, 1)
		end
	end

	local function resolveConfig()
		local configTable = globalEnv and globalEnv.__RAYFIELD_EXEC_POLICY_CONFIG or nil
		if type(configTable) ~= "table" then
			configTable = {}
		end

		local mode = globalEnv and globalEnv.__RAYFIELD_EXEC_POLICY_MODE or configTable.mode or "auto"
		mode = string.lower(tostring(mode))
		if mode ~= "auto" and mode ~= "soft" and mode ~= "hard" then
			mode = "auto"
		end

		local escalateAfter = globalEnv and tonumber(globalEnv.__RAYFIELD_EXEC_POLICY_ESCALATE_AFTER)
			or tonumber(configTable.escalateAfter)
			or tonumber(configTable.escalate_after)
			or 2
		escalateAfter = math.max(1, math.floor(escalateAfter))

		local windowSec = globalEnv and tonumber(globalEnv.__RAYFIELD_EXEC_POLICY_WINDOW_SEC)
			or tonumber(configTable.windowSec)
			or tonumber(configTable.window_sec)
			or tonumber(configTable.timeoutWindowSec)
			or 90
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
	policy.version = policyVersion

	if globalEnv then
		globalEnv.__RAYFIELD_EXEC_POLICY_STATE = state
		globalEnv.__RAYFIELD_EXEC_POLICY = policy
		globalEnv.__RAYFIELD_EXEC_POLICY_VERSION = policyVersion
	end
	return policy
end

local ExecPolicy = ensureExecPolicyEngine()

local function resolveCancelOverride(opts)
	if opts.cancelOnTimeout ~= nil then
		return opts.cancelOnTimeout == true, "request-override:opts.cancelOnTimeout"
	end
	if type(_G) == "table" and _G.__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT ~= nil then
		return _G.__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT == true, "legacy-override:__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT"
	end
	return nil, nil
end

local function shouldDefaultCancelOnTimeout()
	if type(_G) == "table" and _G.__RAYFIELD_HTTP_DEFAULT_CANCEL_ON_TIMEOUT ~= nil then
		return _G.__RAYFIELD_HTTP_DEFAULT_CANCEL_ON_TIMEOUT == true
	end
	return true
end

local function getBundleTable()
	if type(_G) ~= "table" or type(_G.__RAYFIELD_BUNDLE_SOURCES) ~= "table" then
		return nil
	end
	return _G.__RAYFIELD_BUNDLE_SOURCES
end

local function getBrokenBundleMap()
	if type(_G) ~= "table" then
		return nil
	end
	if type(_G.__RAYFIELD_BUNDLE_BROKEN_PATHS) ~= "table" then
		_G.__RAYFIELD_BUNDLE_BROKEN_PATHS = {}
	end
	return _G.__RAYFIELD_BUNDLE_BROKEN_PATHS
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

	local runtimeRoot = nil
	if type(_G) == "table" and type(_G.__RAYFIELD_RUNTIME_ROOT_URL) == "string" and _G.__RAYFIELD_RUNTIME_ROOT_URL ~= "" then
		runtimeRoot = _G.__RAYFIELD_RUNTIME_ROOT_URL
	end
	if runtimeRoot and url:sub(1, #runtimeRoot) == runtimeRoot then
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
		policyReason = "default-override:__RAYFIELD_HTTP_DEFAULT_CANCEL_ON_TIMEOUT"
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
