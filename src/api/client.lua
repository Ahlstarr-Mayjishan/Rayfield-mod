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

local DEFAULT_STARTUP_TARGET_MS = 2000
local MAX_STARTUP_TRACE_HISTORY = 5

local StartupTraceState = {
	current = nil,
	history = {}
}

local function getGlobalEnv()
	return type(_G) == "table" and _G or nil
end

local function normalizeStartupMode(mode)
	local normalized = string.lower(tostring(mode or "auto"))
	if normalized ~= "auto" and normalized ~= "full" and normalized ~= "fast" then
		normalized = "auto"
	end
	return normalized
end

local function normalizeStartupTargetMs(value)
	local target = tonumber(value) or DEFAULT_STARTUP_TARGET_MS
	target = math.floor(target + 0.5)
	return math.max(250, target)
end

local function mergeMeta(baseMeta, extraMeta)
	local merged = {}
	if type(baseMeta) == "table" then
		for key, value in pairs(baseMeta) do
			merged[key] = cloneValue(value)
		end
	end
	if type(extraMeta) == "table" then
		for key, value in pairs(extraMeta) do
			merged[key] = cloneValue(value)
		end
	end
	return merged
end

local function resolveSessionTotalMs(session, nowClock)
	if type(session) ~= "table" then
		return 0
	end
	local startClock = tonumber(session.sessionStartClock) or tonumber(nowClock) or os.clock()
	local endClock = tonumber(session.sessionEndClock) or tonumber(nowClock) or os.clock()
	return math.max(0, math.floor(((endClock - startClock) * 1000) + 0.5))
end

local function buildStartupHotspots(stages, totalMs)
	local sorted = {}
	if type(stages) == "table" then
		for _, stage in ipairs(stages) do
			if type(stage) == "table" then
				table.insert(sorted, {
					name = tostring(stage.name or "unknown"),
					durationMs = tonumber(stage.durationMs) or 0
				})
			end
		end
	end
	table.sort(sorted, function(a, b)
		return (a.durationMs or 0) > (b.durationMs or 0)
	end)
	local hotspots = {}
	local safeTotal = math.max(1, tonumber(totalMs) or 0)
	for index = 1, math.min(5, #sorted) do
		local item = sorted[index]
		local percent = math.floor((((tonumber(item.durationMs) or 0) / safeTotal) * 1000) + 0.5) / 10
		table.insert(hotspots, {
			name = tostring(item.name),
			durationMs = tonumber(item.durationMs) or 0,
			percent = percent
		})
	end
	return hotspots
end

local function buildStartupSummary(session, nowClock)
	if type(session) ~= "table" then
		return nil
	end
	local summary = {
		mode = normalizeStartupMode(session.mode),
		resolvedMode = normalizeStartupMode(session.resolvedMode or session.mode),
		targetMs = normalizeStartupTargetMs(session.targetMs),
		sessionStart = tonumber(session.sessionStartClock) or tonumber(nowClock) or os.clock(),
		sessionStartedAt = session.sessionStartedAt,
		totalMs = resolveSessionTotalMs(session, nowClock),
		stages = {},
		hotspots = {},
		bundle = {
			attempted = false,
			used = false,
			hitRate = 0
		}
	}

	local stages = type(session.stages) == "table" and session.stages or {}
	for _, stage in ipairs(stages) do
		if type(stage) == "table" then
			table.insert(summary.stages, {
				name = tostring(stage.name or "unknown"),
				durationMs = tonumber(stage.durationMs) or 0,
				status = tostring(stage.status or "ok"),
				source = tostring(stage.source or "runtime")
			})
		end
	end

	summary.hotspots = buildStartupHotspots(summary.stages, summary.totalMs)

	local bundleStats = type(session.bundleStats) == "table" and session.bundleStats or {}
	local attemptedCount = math.max(0, math.floor(tonumber(bundleStats.attemptedCount) or 0))
	local usedCount = math.max(0, math.floor(tonumber(bundleStats.usedCount) or 0))
	summary.bundle.attempted = attemptedCount > 0
	summary.bundle.used = usedCount > 0
	if attemptedCount > 0 then
		summary.bundle.hitRate = math.floor(((usedCount / attemptedCount) * 1000) + 0.5) / 10
	end
	return summary
end

local function syncStartupGlobals(summary)
	local globalEnv = getGlobalEnv()
	if not globalEnv then
		return
	end
	globalEnv.__RAYFIELD_STARTUP_TRACE_CURRENT = StartupTraceState.current
	globalEnv.__RAYFIELD_STARTUP_TRACE_HISTORY = StartupTraceState.history
	if type(summary) == "table" then
		globalEnv.__RAYFIELD_STARTUP_LAST_SUMMARY = summary
		if type(globalEnv.__RAYFIELD_LOADER_DIAGNOSTICS) == "table" then
			globalEnv.__RAYFIELD_LOADER_DIAGNOSTICS.startup = cloneValue(summary)
		end
	end
end

local function publishCurrentStartupSummary()
	local session = StartupTraceState.current
	if type(session) ~= "table" then
		return nil
	end
	local summary = buildStartupSummary(session, os.clock())
	syncStartupGlobals(summary)
	return summary
end

local function ensureStartupSession(options)
	if type(StartupTraceState.current) == "table" then
		return StartupTraceState.current
	end
	options = type(options) == "table" and options or {}
	local nowClock = os.clock()
	local session = {
		id = tostring(math.floor(nowClock * 1000000)) .. "-" .. tostring(math.random(1000, 9999)),
		mode = normalizeStartupMode(options.mode),
		resolvedMode = normalizeStartupMode(options.resolvedMode or options.mode),
		targetMs = normalizeStartupTargetMs(options.targetMs),
		sessionStartClock = nowClock,
		sessionStartedAt = type(os.date) == "function" and os.date("%Y-%m-%d %H:%M:%S") or tostring(nowClock),
		source = tostring(options.source or "runtime"),
		windowName = options.windowName and tostring(options.windowName) or nil,
		stages = {},
		bundleStats = {
			attemptedCount = 0,
			usedCount = 0,
			fallbackCount = 0
		}
	}
	StartupTraceState.current = session
	syncStartupGlobals()
	return session
end

local function beginStartupSession(options)
	options = type(options) == "table" and options or {}
	StartupTraceState.current = nil
	return ensureStartupSession(options)
end

local function startStartupStage(name, source, meta)
	local session = ensureStartupSession({
		mode = "auto",
		targetMs = DEFAULT_STARTUP_TARGET_MS,
		source = "implicit"
	})
	return {
		session = session,
		name = tostring(name or "unknown"),
		source = tostring(source or "runtime"),
		meta = type(meta) == "table" and cloneValue(meta) or nil,
		startClock = os.clock()
	}
end

local function finishStartupStage(handle, status, extraMeta)
	if type(handle) ~= "table" or type(handle.session) ~= "table" then
		return nil
	end
	local endClock = os.clock()
	local startClock = tonumber(handle.startClock) or endClock
	local stage = {
		name = tostring(handle.name or "unknown"),
		source = tostring(handle.source or "runtime"),
		status = tostring(status or "ok"),
		startClock = startClock,
		endClock = endClock,
		durationMs = math.max(0, math.floor(((endClock - startClock) * 1000) + 0.5)),
		meta = mergeMeta(handle.meta, extraMeta)
	}
	table.insert(handle.session.stages, stage)
	publishCurrentStartupSummary()
	return stage
end

local function markBundleAttempt()
	local session = ensureStartupSession({
		mode = "auto",
		targetMs = DEFAULT_STARTUP_TARGET_MS,
		source = "bundle"
	})
	session.bundleStats = type(session.bundleStats) == "table" and session.bundleStats or {
		attemptedCount = 0,
		usedCount = 0,
		fallbackCount = 0
	}
	session.bundleStats.attemptedCount = math.max(0, math.floor(tonumber(session.bundleStats.attemptedCount) or 0)) + 1
	publishCurrentStartupSummary()
end

local function markBundleUsed()
	local session = ensureStartupSession({
		mode = "auto",
		targetMs = DEFAULT_STARTUP_TARGET_MS,
		source = "bundle"
	})
	session.bundleStats = type(session.bundleStats) == "table" and session.bundleStats or {
		attemptedCount = 0,
		usedCount = 0,
		fallbackCount = 0
	}
	session.bundleStats.usedCount = math.max(0, math.floor(tonumber(session.bundleStats.usedCount) or 0)) + 1
	publishCurrentStartupSummary()
end

local function markBundleFallback()
	local session = ensureStartupSession({
		mode = "auto",
		targetMs = DEFAULT_STARTUP_TARGET_MS,
		source = "bundle"
	})
	session.bundleStats = type(session.bundleStats) == "table" and session.bundleStats or {
		attemptedCount = 0,
		usedCount = 0,
		fallbackCount = 0
	}
	session.bundleStats.fallbackCount = math.max(0, math.floor(tonumber(session.bundleStats.fallbackCount) or 0)) + 1
	publishCurrentStartupSummary()
end

local function finalizeStartupSession(options)
	options = type(options) == "table" and options or {}
	local session = StartupTraceState.current
	if type(session) ~= "table" then
		return nil
	end
	if options.mode ~= nil then
		session.mode = normalizeStartupMode(options.mode)
	end
	if options.resolvedMode ~= nil then
		session.resolvedMode = normalizeStartupMode(options.resolvedMode)
	end
	if options.targetMs ~= nil then
		session.targetMs = normalizeStartupTargetMs(options.targetMs)
	end
	session.sessionEndClock = os.clock()
	session.status = tostring(options.status or "ok")

	local summary = buildStartupSummary(session, session.sessionEndClock)
	StartupTraceState.current = nil
	table.insert(StartupTraceState.history, cloneValue(summary))
	while #StartupTraceState.history > MAX_STARTUP_TRACE_HISTORY do
		table.remove(StartupTraceState.history, 1)
	end
	syncStartupGlobals(summary)
	return summary
end

local function getCurrentStartupSummary()
	return publishCurrentStartupSummary()
end

local function getLastStartupSummary()
	if #StartupTraceState.history > 0 then
		return cloneValue(StartupTraceState.history[#StartupTraceState.history])
	end
	local globalEnv = getGlobalEnv()
	if globalEnv and type(globalEnv.__RAYFIELD_STARTUP_LAST_SUMMARY) == "table" then
		return cloneValue(globalEnv.__RAYFIELD_STARTUP_LAST_SUMMARY)
	end
	return nil
end

local StartupTraceApi = {
	beginSession = beginStartupSession,
	startStage = startStartupStage,
	finishStage = finishStartupStage,
	finalizeSession = finalizeStartupSession,
	getCurrentSummary = getCurrentStartupSummary,
	getLastSummary = getLastStartupSummary,
	markBundleAttempt = markBundleAttempt,
	markBundleUsed = markBundleUsed,
	markBundleFallback = markBundleFallback
}

do
	local globalEnv = getGlobalEnv()
	if globalEnv and type(globalEnv.__RAYFIELD_STARTUP_TRACE_HISTORY) == "table" then
		StartupTraceState.history = globalEnv.__RAYFIELD_STARTUP_TRACE_HISTORY
	end
	if globalEnv and type(globalEnv.__RAYFIELD_STARTUP_TRACE_CURRENT) == "table" then
		StartupTraceState.current = globalEnv.__RAYFIELD_STARTUP_TRACE_CURRENT
	end
	if globalEnv then
		globalEnv.__RAYFIELD_STARTUP_TRACE_API = StartupTraceApi
	end
	syncStartupGlobals(globalEnv and globalEnv.__RAYFIELD_STARTUP_LAST_SUMMARY or nil)
end

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
	local requestStage = startStartupStage("http_get", "http", {
		url = url,
		timeoutSec = timeout,
		policy = policyMode,
		reason = policyReason
	})

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
	local requestStatus = "error"
	if okResult == true then
		requestStatus = "ok"
	elseif type(payload) == "string" and string.find(payload, "timed out", 1, true) then
		requestStatus = "timeout"
	end
	finishStartupStage(requestStage, requestStatus, {
		cancelOnTimeout = cancelOnTimeout
	})
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
	local sourceType = fromBundle and "bundle" or "http"

	local function compileAndExecute(codeToRun, executeSource, executeMeta)
		local compileStage = startStartupStage("compile", executeSource, executeMeta)
		local okCompile, chunkOrErr = pcall(Client.compile, codeToRun)
		finishStartupStage(compileStage, okCompile and "ok" or "error", {
			error = okCompile and nil or tostring(chunkOrErr)
		})
		if not okCompile then
			return false, chunkOrErr
		end

		local executeStage = startStartupStage("execute", executeSource, executeMeta)
		local okExecute, executeResult = pcall(chunkOrErr)
		finishStartupStage(executeStage, okExecute and "ok" or "error", {
			error = okExecute and nil or tostring(executeResult)
		})
		if not okExecute then
			return false, executeResult
		end
		return true, executeResult
	end

	if fromBundle then
		markBundleAttempt()
	end

	local okExecute, result = compileAndExecute(code, sourceType, {
		url = url,
		bundlePath = bundlePath
	})
	if okExecute then
		if fromBundle then
			markBundleUsed()
		end
		return result
	end

	if fromBundle then
		markBundleFallback()
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
		local okRetry, retryResult = compileAndExecute(retryCode, "http", {
			url = url,
			retry = true,
			bundlePath = bundlePath
		})
		if okRetry then
			return retryResult
		end
		error(retryResult)
	end

	error(result)
end

if _G then
	_G.__RayfieldApiClient = Client
	_G.__RAYFIELD_STARTUP_TRACE_API = StartupTraceApi
end

return Client
