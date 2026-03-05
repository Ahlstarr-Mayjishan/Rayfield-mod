local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

-- [[ EXECUTION POLICY ENGINE ]] --
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

-- [[ SHOWCASE LOGGER ]] --
local function createShowcaseLogger()
	local logger = {
		enabled = true,
		fileEnabled = false,
		folder = "Rayfield/Logs",
		activeFolder = nil,
		path = nil,
		latestPath = nil,
		diagnosticPath = nil,
		latestDiagnosticPath = nil,
		reason = "init"
	}

	if type(_G) == "table" then
		if _G.__RAYFIELD_SHOWCASE_FILE_LOG == false then
			logger.enabled = false
		end
		if type(_G.__RAYFIELD_SHOWCASE_LOG_FOLDER) == "string" and _G.__RAYFIELD_SHOWCASE_LOG_FOLDER ~= "" then
			logger.folder = _G.__RAYFIELD_SHOWCASE_LOG_FOLDER
		end
	end

	local appendFn = type(appendfile) == "function" and appendfile or nil
	local writeFn = type(writefile) == "function" and writefile or nil
	local isFolderFn = type(isfolder) == "function" and isfolder or nil
	local makeFolderFn = type(makefolder) == "function" and makefolder or nil
	local ring = {}
	local runTime = type(os.time) == "function" and os.time() or math.floor(os.clock() * 1000)
	local runId = tostring(runTime) .. "-" .. tostring(math.random(1000, 9999))

	local function setTargets(folderPath)
		local fileName = "elements-showcase-" .. runId .. ".log"
		local latestName = "elements-showcase-latest.log"
		local diagnosticName = "elements-showcase-diagnostic-" .. runId .. ".log"
		local diagnosticLatestName = "elements-showcase-diagnostic-latest.log"
		if type(folderPath) == "string" and folderPath ~= "" then
			logger.activeFolder = folderPath
			logger.path = folderPath .. "/" .. fileName
			logger.latestPath = folderPath .. "/" .. latestName
			logger.diagnosticPath = folderPath .. "/" .. diagnosticName
			logger.latestDiagnosticPath = folderPath .. "/" .. diagnosticLatestName
		else
			logger.activeFolder = nil
			logger.path = fileName
			logger.latestPath = latestName
			logger.diagnosticPath = diagnosticName
			logger.latestDiagnosticPath = diagnosticLatestName
		end
	end

	setTargets(logger.folder)

	local function ensureFolderPath(path)
		if type(path) ~= "string" or path == "" then
			return true, nil
		end
		if not makeFolderFn then
			return false, "makefolder_unavailable"
		end

		local normalized = string.gsub(path, "\\", "/")
		local current = ""
		for part in string.gmatch(normalized, "[^/]+") do
			current = current == "" and part or (current .. "/" .. part)
			local exists = false
			if isFolderFn then
				local okExists, result = pcall(isFolderFn, current)
				exists = okExists and result == true
			end
			if not exists then
				local okMake = pcall(makeFolderFn, current)
				if not okMake then
					if isFolderFn then
						local okExistsAfter, resultAfter = pcall(isFolderFn, current)
						if not (okExistsAfter and resultAfter == true) then
							return false, "makefolder_failed:" .. tostring(current)
						end
					else
						return false, "makefolder_failed:" .. tostring(current)
					end
				end
			end
		end
		return true, nil
	end

	local function flushWholeFile(path)
		if not writeFn then
			return false
		end
		local okWrite = pcall(writeFn, path, table.concat(ring, "\n") .. "\n")
		return okWrite == true
	end

	local function appendLine(path, lineText)
		if appendFn then
			local okAppend = pcall(appendFn, path, lineText .. "\n")
			if okAppend then
				return true
			end
			if writeFn then
				return flushWholeFile(path)
			end
			return false
		end
		if writeFn then
			return flushWholeFile(path)
		end
		return false
	end

	if logger.enabled and (appendFn or writeFn) then
		local folderOk, folderErr = ensureFolderPath(logger.folder)
		if folderOk then
			logger.fileEnabled = true
			logger.reason = "folder_ready"
		else
			setTargets(nil)
			logger.fileEnabled = true
			logger.reason = "root_fallback:" .. tostring(folderErr)
		end
	else
		logger.reason = logger.enabled and "file_api_unavailable" or "file_log_disabled"
	end

	function logger.log(level, message)
		local stamp = type(os.date) == "function" and os.date("%Y-%m-%d %H:%M:%S") or tostring(os.clock())
		local line = string.format("[%s][%s] %s", stamp, tostring(level or "INFO"), tostring(message or ""))
		table.insert(ring, line)
		if #ring > 1200 then
			table.remove(ring, 1)
		end
		
		if type(_G) == "table" then
			_G.__RAYFIELD_SHOWCASE_LOG_BUFFER = ring
			_G.__RAYFIELD_SHOWCASE_LOG_FILE = logger.path
			_G.__RAYFIELD_SHOWCASE_LOG_INFO = {
				enabled = logger.enabled,
				fileEnabled = logger.fileEnabled,
				requestedFolder = logger.folder,
				activeFolder = logger.activeFolder,
				path = logger.path,
				latestPath = logger.latestPath,
				diagnosticPath = logger.diagnosticPath,
				latestDiagnosticPath = logger.latestDiagnosticPath,
				reason = logger.reason
			}
		end
		
		if not logger.fileEnabled then
			return
		end
		
		local okWrite = appendLine(logger.path, line)
		if not okWrite and logger.activeFolder ~= nil then
			setTargets(nil)
			logger.reason = "runtime_root_fallback"
			if type(_G) == "table" then
				_G.__RAYFIELD_SHOWCASE_LOG_FILE = logger.path
			end
			okWrite = appendLine(logger.path, line)
		end
		if not okWrite then
			logger.fileEnabled = false
			logger.reason = "write_failed_all_targets"
			return
		end
		if writeFn and logger.latestPath then
			flushWholeFile(logger.latestPath)
		end
	end

	function logger.getBuffer()
		return ring
	end

	function logger.writeDiagnosticReport(reportText, tag)
		local stampTag = tostring(tag or "diag")
		stampTag = string.gsub(stampTag, "[^%w%-_]", "_")
		local reportBody = tostring(reportText or "")
		if reportBody == "" then
			reportBody = "No diagnostic payload."
		end

		local targetPath = logger.diagnosticPath
		if type(logger.activeFolder) == "string" and logger.activeFolder ~= "" then
			targetPath = logger.activeFolder .. "/elements-showcase-diagnostic-" .. stampTag .. "-" .. runId .. ".log"
		else
			targetPath = "elements-showcase-diagnostic-" .. stampTag .. "-" .. runId .. ".log"
		end

		local wrote = false
		if writeFn then
			wrote = pcall(writeFn, targetPath, reportBody .. "\n")
			if logger.latestDiagnosticPath then
				pcall(writeFn, logger.latestDiagnosticPath, reportBody .. "\n")
			end
		elseif appendFn then
			wrote = pcall(appendFn, targetPath, reportBody .. "\n")
		end
		if wrote and type(_G) == "table" then
			_G.__RAYFIELD_SHOWCASE_DIAGNOSTIC_FILE = targetPath
		end
		return wrote, targetPath
	end

	function logger.getInfo()
		return {
			enabled = logger.enabled,
			fileEnabled = logger.fileEnabled,
			requestedFolder = logger.folder,
			activeFolder = logger.activeFolder,
			path = logger.path,
			latestPath = logger.latestPath,
			diagnosticPath = logger.diagnosticPath,
			latestDiagnosticPath = logger.latestDiagnosticPath,
			reason = logger.reason
		}
	end

	return logger
end

local ShowcaseLogger = createShowcaseLogger()

local function logLine(level, message)
	ShowcaseLogger.log(level, message)
end

logLine("BOOT", "showcase loader start")

-- [[ COMPILATION & FETCH ]] --
local function compileChunk(source, label)
	if type(source) ~= "string" then
		local message = "Invalid Lua source for " .. tostring(label) .. ": " .. type(source)
		logLine("ERROR", message)
		error(message)
	end
	source = source:gsub("^\239\187\191", "")
	source = source:gsub("^\0+", "")
	local chunk, err = compileString(source)
	if not chunk then
		local message = "Failed to compile " .. tostring(label) .. ": " .. tostring(err)
		logLine("ERROR", message)
		error(message)
	end
	return chunk
end

local function fetchAndRun(url, label)
	logLine("FETCH", "HttpGet " .. tostring(url))
	local ok, source = pcall(game.HttpGet, game, url)
	if not ok then
		logLine("ERROR", "HttpGet Failed: " .. tostring(source))
		error("Network error: " .. tostring(source))
	end
	logLine("FETCH", "HttpGet OK " .. tostring(label or url) .. " | bytes=" .. tostring(type(source) == "string" and #source or 0))
	return compileChunk(source, label or url)()
end

local function getBootTimeoutSeconds()
	local configured = type(_G) == "table" and tonumber(_G.__RAYFIELD_SHOWCASE_BOOT_TIMEOUT_SEC) or nil
	if configured and configured > 0 then
		return configured
	end
	return 45
end

local function getQuickSetupTimeoutSeconds()
	local configured = type(_G) == "table" and tonumber(_G.__RAYFIELD_SHOWCASE_QUICKSETUP_TIMEOUT_SEC) or nil
	if configured and configured > 0 then
		return configured
	end
	local bootTimeout = getBootTimeoutSeconds()
	return math.max(60, bootTimeout * 3)
end

local function callWithTimeout(timeoutSeconds, workFn, options)
	options = options or {}
	local opKey = tostring(options.opKey or "showcase:unknown")
	local isBlocking = options.isBlocking == true
	local decision = ExecPolicy.decideExecutionMode(opKey, isBlocking, timeoutSeconds, os.clock())
	local cancelOnTimeout = decision.cancelOnTimeout == true
	
	if options.cancelOnTimeout ~= nil then
		cancelOnTimeout = options.cancelOnTimeout == true
		decision = {
			mode = cancelOnTimeout and "hard" or "soft",
			cancelOnTimeout = cancelOnTimeout,
			reason = "override:options.cancelOnTimeout"
		}
	end
	
	if type(options.onPolicyDecision) == "function" then
		pcall(options.onPolicyDecision, decision, opKey, isBlocking, timeoutSeconds)
	end

	local finished = false
	local ok = false
	local resultOrErr = nil
	local worker = task.spawn(function()
		ok, resultOrErr = pcall(workFn)
		finished = true
	end)

	local startedAt = os.clock()
	while not finished and (os.clock() - startedAt) < timeoutSeconds do
		task.wait()
	end

	if not finished then
		if cancelOnTimeout then
			pcall(task.cancel, worker)
		end
		ExecPolicy.markTimeout(opKey, os.clock(), {
			mode = decision.mode,
			reason = decision.reason,
			isBlocking = isBlocking,
			timeoutSeconds = timeoutSeconds,
			canceled = cancelOnTimeout
		})
		return false, "timeout after " .. tostring(timeoutSeconds) .. "s", "timeout", decision
	end
	
	if not ok then
		return false, resultOrErr, "error", decision
	end
	
	ExecPolicy.markSuccess(opKey, os.clock(), {
		mode = decision.mode,
		reason = decision.reason,
		isBlocking = isBlocking,
		timeoutSeconds = timeoutSeconds
	})
	return true, resultOrErr, "ok", decision
end

local function tryFetchAndRun(url, label)
	local timeoutSeconds = getBootTimeoutSeconds()
	logLine("BOOT", "tryFetchAndRun start | label=" .. tostring(label) .. " | timeout=" .. tostring(timeoutSeconds) .. "s")
	local opKey = "showcase:fetch:" .. tostring(label or url)
	local okCall, resultOrErr, status = callWithTimeout(timeoutSeconds, function()
		return fetchAndRun(url, label)
	end, {
		opKey = opKey,
		isBlocking = false,
		cancelOnTimeout = true,
		onPolicyDecision = function(policyDecision, resolvedOpKey)
			logLine("POLICY", "op=" .. tostring(resolvedOpKey) .. " policy=" .. tostring(policyDecision.mode) .. " reason=" .. tostring(policyDecision.reason))
		end
	})
	
	if not okCall then
		if status == "timeout" then
			local timeoutMsg = "timeout after " .. tostring(timeoutSeconds) .. "s"
			logLine("ERROR", "tryFetchAndRun timeout | label=" .. tostring(label) .. " | url=" .. tostring(url))
			return false, timeoutMsg
		end
		logLine("ERROR", "tryFetchAndRun failed | label=" .. tostring(label) .. " | error=" .. tostring(resultOrErr))
		return false, resultOrErr
	end
	logLine("BOOT", "tryFetchAndRun success | label=" .. tostring(label) .. " | resultType=" .. tostring(type(resultOrErr)))
	return true, resultOrErr
end

-- [[ BOOTSTRAP UTILS ]] --
local function isReadyUI(candidate)
	if type(candidate) ~= "table" or type(candidate.Rayfield) ~= "table" then
		return false
	end
	if type(candidate.Rayfield.IsDestroyed) == "function" then
		local okDestroyed, destroyed = pcall(candidate.Rayfield.IsDestroyed, candidate.Rayfield)
		if okDestroyed and destroyed then
			return false
		end
	end
	return true
end

local function isReadyRayfield(candidate)
	if type(candidate) ~= "table" or type(candidate.CreateWindow) ~= "function" then
		return false
	end
	if type(candidate.IsDestroyed) == "function" then
		local okDestroyed, destroyed = pcall(candidate.IsDestroyed, candidate)
		if okDestroyed and destroyed then
			return false
		end
	end
	return true
end

local function firstOption(value)
	if type(value) == "table" then
		return tostring(value[1] or "")
	end
	return tostring(value or "")
end

local function sortedThemeNames(rayfield)
	local names = {}
	local seen = {}
	if type(rayfield) == "table" and type(rayfield.Theme) == "table" then
		for name in pairs(rayfield.Theme) do
			if type(name) == "string" and name ~= "" and not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end
	table.sort(names)
	if #names == 0 then
		names = { "Default" }
	end
	return names
end

local function ensureTrailingSlash(url)
	if type(url) ~= "string" or url == "" then
		return nil
	end
	if string.sub(url, -1) ~= "/" then
		return url .. "/"
	end
	return url
end

local function resolveRuntimeRoots()
	local roots = {}
	local seen = {}
	local function add(url)
		local normalized = ensureTrailingSlash(url)
		if normalized and not seen[normalized] then
			seen[normalized] = true
			table.insert(roots, normalized)
		end
	end

	if type(_G) == "table" then
		add(_G.__RAYFIELD_RUNTIME_ROOT_URL)
	end

	add("https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Rayfield-mod@main/")
	add("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/")
	return roots
end

local function shouldRetryMirrorsOnTimeout()
	if type(_G) == "table" and _G.__RAYFIELD_SHOWCASE_RETRY_MIRRORS_ON_TIMEOUT ~= nil then
		return _G.__RAYFIELD_SHOWCASE_RETRY_MIRRORS_ON_TIMEOUT == true
	end
	return true
end

local function allowBaseAfterAioTimeout()
	if type(_G) == "table" and _G.__RAYFIELD_SHOWCASE_ALLOW_BASE_AFTER_AIO_TIMEOUT ~= nil then
		return _G.__RAYFIELD_SHOWCASE_ALLOW_BASE_AFTER_AIO_TIMEOUT == true
	end
	return true
end

local runtimeRoots = resolveRuntimeRoots()
local root = runtimeRoots[1] or "https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Rayfield-mod@main/"

local diagnosticState = {
	startedAt = os.clock(),
	fetchAttempts = {},
	bootstrap = {
		order = nil,
		reasons = {},
		mode = nil,
		selectedRoot = nil
	},
	issues = {},
	lastReport = nil
}

local function copyArray(source)
	local output = {}
	if type(source) ~= "table" then
		return output
	end
	for index, value in ipairs(source) do
		output[index] = value
	end
	return output
end

if type(_G) == "table" then
	_G.__RAYFIELD_RUNTIME_ROOT_URL = root
end

logLine("BOOT", "runtime root seed = " .. tostring(root))
logLine("BOOT", "file log path = " .. tostring(ShowcaseLogger.path))

local DEBUG_BOOT = type(_G) == "table" and _G.__RAYFIELD_SHOWCASE_DEBUG == true
local function bootLog(message)
	logLine("BOOT", message)
	if DEBUG_BOOT and type(warn) == "function" then
		warn("[Elements-Showcase][Boot] " .. tostring(message))
	end
end

local function tryFetchAndRunPath(path, label)
	local lastErr = nil
	for _, candidateRoot in ipairs(runtimeRoots) do
		local fullUrl = candidateRoot .. path
		local ok, resultOrErr = tryFetchAndRun(fullUrl, label)
		table.insert(diagnosticState.fetchAttempts, {
			path = path,
			label = label,
			root = candidateRoot,
			ok = ok == true,
			error = ok and nil or tostring(resultOrErr),
			at = os.clock()
		})
		if ok then
			bootLog("Loaded " .. tostring(path) .. " from " .. tostring(candidateRoot))
			return true, resultOrErr, candidateRoot
		end
		lastErr = resultOrErr
		bootLog("Failed " .. tostring(path) .. " from " .. tostring(candidateRoot) .. " => " .. tostring(resultOrErr))
		if type(resultOrErr) == "string" and string.find(resultOrErr, "^timeout", 1, false) then
			if shouldRetryMirrorsOnTimeout() then
				bootLog("Timeout detected, continue mirror retries for " .. tostring(path))
			else
				bootLog("Timeout detected, skip mirror retries for " .. tostring(path))
				break
			end
		end
	end
	return false, lastErr, nil
end

local function wrapRayfieldAsUI(rayfield, mode)
	return {
		Rayfield = rayfield,
		mode = mode or "base"
	}
end

-- [[ BOOTSTRAP ]] --
local function tryBootstrapFromBase(reasons)
	local okBase, baseOrErr, selectedRoot = tryFetchAndRunPath(
		"Main%20loader/rayfield-modified.lua",
		"Main loader/rayfield-modified.lua"
	)
	if okBase and isReadyRayfield(baseOrErr) then
		root = selectedRoot or root
		diagnosticState.bootstrap.selectedRoot = root
		diagnosticState.bootstrap.mode = "base"
		if type(_G) == "table" then
			_G.__RAYFIELD_RUNTIME_ROOT_URL = root
		end
		return wrapRayfieldAsUI(baseOrErr, "base")
	end
	table.insert(reasons, "base loader failed: " .. tostring(baseOrErr))
	return nil
end

local function tryBootstrapFromAllInOne(reasons)
	if type(_G) == "table" then
		_G.__RAYFIELD_AIO_AUTO_EXECUTE = false
		_G.__RAYFIELD_AIO_AUTO_EXECUTE_RETURN = "loader"
	end

	local okAllInOne, loadedOrErr, selectedRoot = tryFetchAndRunPath(
		"Main%20loader/rayfield-all-in-one.lua",
		"Main loader/rayfield-all-in-one.lua"
	)

	if not okAllInOne then
		table.insert(reasons, "all-in-one fetch/execute failed: " .. tostring(loadedOrErr))
		return nil
	end
	
	root = selectedRoot or root
	diagnosticState.bootstrap.selectedRoot = root
	if type(_G) == "table" then
		_G.__RAYFIELD_RUNTIME_ROOT_URL = root
	end

	if isReadyUI(loadedOrErr) then
		diagnosticState.bootstrap.mode = tostring(loadedOrErr.mode or "all-in-one")
		return loadedOrErr
	end

	if isReadyUI(_G and _G.RayfieldUI) then
		diagnosticState.bootstrap.mode = tostring((_G.RayfieldUI and _G.RayfieldUI.mode) or "global-ui")
		return _G.RayfieldUI
	end

	if type(loadedOrErr) == "table" and type(loadedOrErr.quickSetup) == "function" then
		bootLog("all-in-one returned loader table; entering quickSetup path")
		if type(loadedOrErr.configure) == "function" then
			pcall(loadedOrErr.configure, {
				autoReload = false,
				autoReloadEnabled = false
			})
		end

		local requestedMode = type(_G) == "table" and tostring(_G.__RAYFIELD_SHOWCASE_QUICKSETUP_MODE or "enhanced") or "enhanced"
		requestedMode = string.lower(requestedMode)
		if requestedMode ~= "base" and requestedMode ~= "enhanced" and requestedMode ~= "advanced" then
			requestedMode = "enhanced"
		end

		local function runQuickSetup(forceReload)
			local timeoutSeconds = getQuickSetupTimeoutSeconds()
			bootLog("quickSetup start | forceReload=" .. tostring(forceReload) .. " | timeout=" .. tostring(timeoutSeconds) .. "s")
			local opKey = "showcase:quickSetup:" .. tostring(forceReload)
			local okQuick, uiOrErr, quickStatus = callWithTimeout(timeoutSeconds, function()
				return loadedOrErr.quickSetup({
					mode = requestedMode,
					errorThreshold = 5,
					rateLimit = 10,
					autoCleanup = true,
					forceReload = forceReload
				})
			end, {
				opKey = opKey,
				isBlocking = true,
				cancelOnTimeout = true,
				onPolicyDecision = function(policyDecision, resolvedOpKey)
					logLine("POLICY", "op=" .. tostring(resolvedOpKey) .. " policy=" .. tostring(policyDecision.mode) .. " reason=" .. tostring(policyDecision.reason))
				end
			})
			
			if okQuick and isReadyUI(uiOrErr) then
				bootLog("quickSetup success | forceReload=" .. tostring(forceReload))
				return true, uiOrErr, "ok"
			end
			if isReadyUI(_G and _G.RayfieldUI) then
				bootLog("quickSetup produced global _G.RayfieldUI")
				return true, _G.RayfieldUI, "ok"
			end
			if isReadyRayfield(_G and _G.Rayfield) then
				bootLog("quickSetup produced global _G.Rayfield")
				return true, wrapRayfieldAsUI(_G.Rayfield, "global"), "ok"
			end
			
			local reason = "quickSetup failed: " .. tostring(uiOrErr)
			return false, reason, quickStatus
		end

		local okQuick, uiOrReason, quickStatus = runQuickSetup(false)
		if okQuick then
			return uiOrReason
		end
		table.insert(reasons, tostring(uiOrReason))

		if quickStatus ~= "timeout" then
			okQuick, uiOrReason, quickStatus = runQuickSetup(true)
			if okQuick then
				diagnosticState.bootstrap.mode = tostring(uiOrReason and uiOrReason.mode or "quickSetup")
				return uiOrReason
			end
			table.insert(reasons, tostring(uiOrReason))
		end
		return nil
	end

	table.insert(reasons, "all-in-one return type unsupported: " .. tostring(type(loadedOrErr)))
	return nil
end

local function bootstrapUI()
	local reasons = {}
	bootLog("bootstrapUI begin")

	if isReadyUI(_G and _G.RayfieldUI) then
		bootLog("Using existing _G.RayfieldUI")
		diagnosticState.bootstrap.mode = tostring((_G.RayfieldUI and _G.RayfieldUI.mode) or "global-ui")
		return _G.RayfieldUI
	end

	if isReadyRayfield(_G and _G.Rayfield) then
		bootLog("Using existing _G.Rayfield")
		diagnosticState.bootstrap.mode = "global-rayfield"
		return wrapRayfieldAsUI(_G.Rayfield, "global")
	end

	local preferAllInOne = true
	if type(_G) == "table" and _G.__RAYFIELD_SHOWCASE_PREFER_AIO == false then
		preferAllInOne = false
	end
	
	local ui = nil
	local function hasTimeoutReason()
		for _, reason in ipairs(reasons) do
			if type(reason) == "string" and string.find(string.lower(reason), "timeout") then
				return true
			end
		end
		return false
	end

	if preferAllInOne then
		bootLog("Bootstrap order: all-in-one -> base")
		diagnosticState.bootstrap.order = "all-in-one->base"
		ui = tryBootstrapFromAllInOne(reasons)
		if isReadyUI(ui) then
			diagnosticState.bootstrap.reasons = copyArray(reasons)
			return ui
		end
		
		local allowBaseFallbackAfterTimeout = allowBaseAfterAioTimeout()
		if not hasTimeoutReason() or allowBaseFallbackAfterTimeout then
			ui = tryBootstrapFromBase(reasons)
			if isReadyUI(ui) then
				diagnosticState.bootstrap.reasons = copyArray(reasons)
				return ui
			end
		end
	else
		bootLog("Bootstrap order: base -> all-in-one")
		diagnosticState.bootstrap.order = "base->all-in-one"
		ui = tryBootstrapFromBase(reasons)
		if isReadyUI(ui) then
			diagnosticState.bootstrap.reasons = copyArray(reasons)
			return ui
		end
		ui = tryBootstrapFromAllInOne(reasons)
		if isReadyUI(ui) then
			diagnosticState.bootstrap.reasons = copyArray(reasons)
			return ui
		end
	end

	diagnosticState.bootstrap.reasons = copyArray(reasons)

	local message = "UI bootstrap failed | " .. table.concat(reasons, " | ")
	logLine("ERROR", message)
	error(message)
end

local function writeCrashSnapshot(stage, detail)
	local lines = {
		"=== Rayfield Showcase Crash Snapshot ===",
		"stage: " .. tostring(stage),
		"detail: " .. tostring(detail),
		"time: " .. tostring(type(os.date) == "function" and os.date("%Y-%m-%d %H:%M:%S") or os.clock()),
		"runtimeRoot: " .. tostring(root),
		"bootstrapOrder: " .. tostring(diagnosticState.bootstrap.order),
		"bootstrapMode: " .. tostring(diagnosticState.bootstrap.mode),
		"selectedRoot: " .. tostring(diagnosticState.bootstrap.selectedRoot),
		"loggerReason: " .. tostring(ShowcaseLogger.reason),
		"loggerFileEnabled: " .. tostring(ShowcaseLogger.fileEnabled)
	}
	if type(diagnosticState.bootstrap.reasons) == "table" and #diagnosticState.bootstrap.reasons > 0 then
		table.insert(lines, "bootstrapReasons:")
		for _, reason in ipairs(diagnosticState.bootstrap.reasons) do
			table.insert(lines, " - " .. tostring(reason))
		end
	end
	if type(ShowcaseLogger.getBuffer) == "function" then
		local buffer = ShowcaseLogger.getBuffer()
		table.insert(lines, "recentLogTail:")
		local startIndex = math.max(1, #buffer - 20)
		for index = startIndex, #buffer do
			table.insert(lines, " > " .. tostring(buffer[index]))
		end
	end
	local reportText = table.concat(lines, "\n")
	logLine("DIAG", "Crash snapshot generated | stage=" .. tostring(stage))
	if type(ShowcaseLogger.writeDiagnosticReport) == "function" then
		local okWrite, path = ShowcaseLogger.writeDiagnosticReport(reportText, "fatal-" .. tostring(stage))
		if okWrite then
			logLine("DIAG", "Crash report written: " .. tostring(path))
		end
	end
	if type(_G) == "table" then
		_G.__RAYFIELD_SHOWCASE_LAST_CRASH = {
			stage = stage,
			detail = tostring(detail),
			report = reportText
		}
	end
end

-- [[ MAIN EXECUTION ]] --
local okBootstrapUI, UIOrErr = pcall(bootstrapUI)
if not okBootstrapUI then
	writeCrashSnapshot("bootstrap", UIOrErr)
	error(UIOrErr)
end
local UI = UIOrErr
logLine("BOOT", "bootstrapUI success | mode=" .. tostring(UI and UI.mode or "unknown"))

local Rayfield = UI.Rayfield
local windowName = "Rayfield Mod | Elements Showcase"

-- Cleanup old window if it exists to avoid UI stacking
if Rayfield and type(Rayfield.Destroy) == "function" then
    -- Some Rayfield versions support searching for windows
    pcall(function()
        if _G.__RAYFIELD_SHOWCASE_WINDOW then
             _G.__RAYFIELD_SHOWCASE_WINDOW:Destroy()
        end
    end)
end

local checkState = {
	pass = 0,
	fail = 0,
	logs = {}
}

local function report(pass, name, message)
	local line = pass and ("[PASS] " .. tostring(name)) or ("[FAIL] " .. tostring(name) .. " -> " .. tostring(message or "unknown"))
	if pass then checkState.pass = checkState.pass + 1 else checkState.fail = checkState.fail + 1 end
	table.insert(checkState.logs, line)
	logLine("CHECK", line)
end

local function runCheck(name, checkFn)
	local ok, resultOrErr = pcall(checkFn)
	if not ok then report(false, name, resultOrErr) return false end
	if resultOrErr == false then report(false, name, "condition returned false") return false end
	report(true, name)
	return true
end

local runtimeState = {
	buttonClicks = 0,
	toggle = false,
	slider = 50,
	input = "",
	dropdown = "Alpha",
	keybind = "Q",
	color = Color3.fromRGB(255, 170, 0)
}

local settingsState = {
	uiPreset = "Comfort",
	transitionProfile = "Smooth",
	onboardingSuppressed = false,
	themeBase = "Default",
	themeAccent = Color3.fromRGB(0, 170, 255),
	importCode = "",
	lastExportCode = nil,
	statusPreview = 35,
	trackPreview = 35
}

-- Fetch current states if available
pcall(function()
	local okPreset, preset = pcall(Rayfield.GetUIPreset, Rayfield)
	if okPreset and type(preset) == "string" and preset ~= "" then settingsState.uiPreset = preset end
	
    local okTransition, transition = pcall(Rayfield.GetTransitionProfile, Rayfield)
	if okTransition and type(transition) == "string" and transition ~= "" then settingsState.transitionProfile = transition end
	
    local okSuppressed, suppressed = pcall(Rayfield.IsOnboardingSuppressed, Rayfield)
	if okSuppressed then settingsState.onboardingSuppressed = suppressed == true end
	
    local okThemeState, themeState = pcall(Rayfield.GetThemeStudioState, Rayfield)
	if okThemeState and type(themeState) == "table" and type(themeState.baseTheme) == "string" then settingsState.themeBase = themeState.baseTheme end
end)

local okWindow, windowOrErr = pcall(Rayfield.CreateWindow, Rayfield, {
	Name = windowName,
	LoadingTitle = "Rayfield Mod Bundle",
	LoadingSubtitle = "Stable Element Showcase",
	ConfigurationSaving = { Enabled = false },
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true
})

if not okWindow then
	local message = "CreateWindow failed: " .. tostring(windowOrErr)
	logLine("ERROR", message)
	writeCrashSnapshot("create-window", message)
	error(message)
end

local window = windowOrErr
_G.__RAYFIELD_SHOWCASE_WINDOW = window
logLine("BOOT", "CreateWindow success")

-- [[ TAB CREATION ]] --
local tabCore = window:CreateTab("Basic Elements", 4483362458)
local tabAdvanced = window:CreateTab("Advanced Elements", 4483362458)
local tabSettings = window:CreateTab("Experience & Theme", 4483362458)
local tabSystem = window:CreateTab("Share & Diagnostics", 4483362458)

local sampleLogConsole = nil
local function sampleLog(level, message)
	local safeLevel = string.lower(tostring(level or "info"))
	local safeMessage = tostring(message or "")
	logLine("LOG/" .. string.upper(safeLevel), safeMessage)
	print("[Elements-Showcase][" .. safeLevel .. "] " .. safeMessage)
	if sampleLogConsole then
		pcall(function()
			if safeLevel == "warn" and type(sampleLogConsole.Warn) == "function" then
				sampleLogConsole:Warn(safeMessage)
			elseif safeLevel == "error" and type(sampleLogConsole.Error) == "function" then
				sampleLogConsole:Error(safeMessage)
			elseif type(sampleLogConsole.Info) == "function" then
				sampleLogConsole:Info(safeMessage)
			end
		end)
	end
end

-- Core tab
tabCore:CreateParagraph({
	Title = "Basic Element Pack",
	Content = "Foundational controls: button, toggle, slider, input, dropdown, keybind, color picker."
})

local elButton = tabCore:CreateButton({
	Name = "Standard Button",
	Callback = function()
		runtimeState.buttonClicks = runtimeState.buttonClicks + 1
		Rayfield:Notify({
			Title = "Rayfield Sample",
			Content = "Button clicked " .. tostring(runtimeState.buttonClicks) .. " times",
			Duration = 2
		})
	end
})

local elToggle = tabCore:CreateToggle({
	Name = "Feature Toggle",
	CurrentValue = false,
	Callback = function(value) runtimeState.toggle = value == true end
})

local elToggleWithKeybind = tabCore:CreateToggle({
	Name = "Toggle + Embedded Keybind",
	CurrentValue = false,
	Keybind = { Enabled = true, CurrentKeybind = "LeftControl+T" },
	Callback = function(value) sampleLog("info", "Embedded keybind toggle => " .. tostring(value)) end
})

local elSlider = tabCore:CreateSlider({
	Name = "Value Adjuster",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = 50,
	Callback = function(value) runtimeState.slider = tonumber(value) or 0 end
})

local elInput = tabCore:CreateInput({
	Name = "Data Input",
	PlaceholderText = "Input data here...",
	RemoveTextAfterFocusLost = false,
	Callback = function(value) runtimeState.input = tostring(value or "") end
})

local elDropdown = tabCore:CreateDropdown({
	Name = "Choice Dropdown",
	Options = { "Alpha", "Beta", "Gamma", "Delta" },
	CurrentOption = "Alpha",
	Callback = function(value) runtimeState.dropdown = firstOption(value) end
})

tabCore:CreateDivider()

local elKeybind = tabCore:CreateKeybind({
	Name = "Trigger Keybind",
	CurrentKeybind = "Q",
	CallOnChange = true,
	Callback = function(value) runtimeState.keybind = tostring(value or "") end
})

local elColor = tabCore:CreateColorPicker({
	Name = "Theme Picker",
	Color = Color3.fromRGB(255, 170, 0),
	Callback = function(value) runtimeState.color = value end
})

-- Advanced tab
tabAdvanced:CreateParagraph({
	Title = "Advanced Element Pack",
	Content = "Expansion widgets, loading controls, gallery, chart, and log widgets."
})

local elLabel = tabAdvanced:CreateLabel("Static Information Label")
local elSection = tabAdvanced:CreateSection("Advanced Widgets")

local advancedSection = tabAdvanced:CreateCollapsibleSection({
	Name = "Interactive Widgets",
	Collapsed = false
})

local statusPreview = tabAdvanced:CreateStatusBar({
	Name = "Status Preview",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = settingsState.statusPreview,
	TextFormatter = function(current, max, percent) return string.format("Load %.0f%% (%d/%d)", percent, current, max) end,
	Callback = function(value) settingsState.statusPreview = tonumber(value) or 0 end,
	ParentSection = advancedSection
})

local trackPreview = tabAdvanced:CreateTrackBar({
	Name = "Track Preview",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = settingsState.trackPreview,
	Callback = function(value) settingsState.trackPreview = tonumber(value) or 0 end,
	ParentSection = advancedSection
})

-- Handle optional aliases with safety
local function safeAlias(methodName, config)
    if type(tabAdvanced[methodName]) == "function" then
        return tabAdvanced[methodName](tabAdvanced, config)
    end
    return nil
end

local dragBarAlias = safeAlias("CreateDragBar", { Name = "DragBar Alias", Range = { 0, 100 }, CurrentValue = 35, ParentSection = advancedSection })
local sliderLiteAlias = safeAlias("CreateSliderLite", { Name = "SliderLite Alias", Range = { 0, 100 }, CurrentValue = 35, ParentSection = advancedSection })
local infoBarAlias = safeAlias("CreateInfoBar", { Name = "InfoBar Alias", Range = { 0, 100 }, CurrentValue = 35, ParentSection = advancedSection })
local sliderDisplayAlias = safeAlias("CreateSliderDisplay", { Name = "SliderDisplay Alias", Range = { 0, 100 }, CurrentValue = 35, ParentSection = advancedSection })

local stepper = tabAdvanced:CreateNumberStepper({
	Name = "Value Stepper",
	CurrentValue = 35,
	Min = 0, Max = 100, Step = 1,
	ParentSection = advancedSection,
	Callback = function(value)
		local numeric = tonumber(value) or 0
		pcall(function()
			if statusPreview and statusPreview.Set then statusPreview:Set(numeric) end
			if trackPreview and trackPreview.Set then trackPreview:Set(numeric) end
			if dragBarAlias and dragBarAlias.Set then dragBarAlias:Set(numeric) end
			if sliderLiteAlias and sliderLiteAlias.Set then sliderLiteAlias:Set(numeric) end
			if infoBarAlias and infoBarAlias.Set then infoBarAlias:Set(numeric) end
			if sliderDisplayAlias and sliderDisplayAlias.Set then sliderDisplayAlias:Set(numeric) end
		end)
	end
})

tabAdvanced:CreateConfirmButton({
	Name = "Confirm Theme Reset",
	ConfirmMode = "either",
	Callback = function()
		local okReset, status = Rayfield:ResetThemeStudio()
		sampleLog(okReset and "info" or "error", "ResetThemeStudio => " .. tostring(status))
	end,
	ParentSection = advancedSection
})

local wrapperToggle = safeAlias("CreateToggleBind", { Name = "ToggleBind Example", Keybind = { CurrentKeybind = "LeftControl+1" }, ParentSection = advancedSection })
local hotToggle = safeAlias("CreateHotToggle", { Name = "HotToggle Example", Keybind = { CurrentKeybind = "LeftControl+2" }, ParentSection = advancedSection })
local keybindToggle = safeAlias("CreateKeybindToggle", { Name = "KeybindToggle Example", Keybind = { CurrentKeybind = "LeftControl+3" }, ParentSection = advancedSection })

local loadingSpinner = safeAlias("CreateLoadingSpinner", { Name = "Loading Spinner", AutoStart = true, ParentSection = advancedSection })
local loadingBar = safeAlias("CreateLoadingBar", { Name = "Loading Bar", Mode = "indeterminate", AutoStart = true, ParentSection = advancedSection })

local settingsImage = safeAlias("CreateImage", { Name = "Preview Image", Source = "rbxassetid://4483362458", Height = 110, Caption = "Rayfield Icon" })

local settingsGallery = safeAlias("CreateGallery", {
	Name = "Sample Gallery",
	Items = {
		{ id = "a", name = "Item A", image = "rbxassetid://4483362458" },
		{ id = "b", name = "Item B", image = "rbxassetid://4483362458" }
	},
	Callback = function(selection) sampleLog("info", "Gallery selection: " .. tostring(#(selection or {}))) end
})

local settingsChart = safeAlias("CreateChart", { Name = "Sample Chart", MaxPoints = 60, Preset = "fps" })
if settingsChart and settingsChart.AddPoint then
    settingsChart:AddPoint(35); settingsChart:AddPoint(45); settingsChart:AddPoint(55)
end

local settingsDataGrid = nil
if type(tabAdvanced.CreateDataGrid) == "function" then
	settingsDataGrid = tabAdvanced:CreateDataGrid({
		Name = "Sample Data Grid",
		Columns = {
			{ Key = "id", Title = "ID", Sortable = true },
			{ Key = "player", Title = "Player", Sortable = true },
			{ Key = "score", Title = "Score", Sortable = true }
		},
		Rows = {
			{ id = "r1", player = "Alpha", score = 72 },
			{ id = "r2", player = "Beta", score = 35 },
			{ id = "r3", player = "Gamma", score = 91 }
		},
		Callback = function(row)
			sampleLog("info", "DataGrid selected => " .. tostring(row and row.id))
		end
	})
	if settingsDataGrid and settingsDataGrid.SortBy then
		pcall(function()
			settingsDataGrid:SortBy("score", "desc")
		end)
	end
end

if type(tabAdvanced.CreateLogConsole) == "function" then
	sampleLogConsole = tabAdvanced:CreateLogConsole({ Name = "Sample Logs", CaptureMode = "manual" })
	sampleLog("info", "Advanced elements tab initialized.")
end

tabCore:CreateButton({
    Name = "Trigger Notification",
    Callback = function()
        Rayfield:Notify({
            Title = "Showcase Notification",
            Content = "This is a standard notification from the showcase script.",
            Duration = 3,
            Image = 4483362458,
            Actions = {
                Ignore = {
                    Name = "Okay!",
                    Callback = function()
                        print("The user tapped Okay!")
                    end
                },
            },
        })
    end,
})

local elContextLabel = tabCore:CreateLabel("Right Click Me!")

-- Some elements support context menus or right click
-- Add tooltips
tabAdvanced:CreateButton({
    Name = "Hover over me for Tooltip!",
    Tooltip = "This is an example tooltip that appears when observing the element.",
    Callback = function()
        print("Tooltip button clicked!")
    end
})

-- Settings tab
local themeNames = sortedThemeNames(Rayfield)
tabSettings:CreateDropdown({
	Name = "UI Preset",
	Options = { "Comfort", "Compact", "Focus" },
	CurrentOption = settingsState.uiPreset,
	Callback = function(value)
		local selected = firstOption(value)
		if selected ~= "" then
			local okSet, status = Rayfield:SetUIPreset(selected)
			sampleLog(okSet and "info" or "error", "SetUIPreset(" .. selected .. ") => " .. tostring(status))
		end
	end
})

tabSettings:CreateDropdown({
	Name = "Transition Profile",
	Options = { "Smooth", "Snappy", "Minimal", "Off" },
	CurrentOption = settingsState.transitionProfile,
	Callback = function(value)
		local selected = firstOption(value)
		if selected ~= "" then
			local okSet, status = Rayfield:SetTransitionProfile(selected)
			sampleLog(okSet and "info" or "error", "SetTransitionProfile(" .. selected .. ") => " .. tostring(status))
		end
	end
})

tabSettings:CreateToggle({
	Name = "Suppress Onboarding",
	CurrentValue = settingsState.onboardingSuppressed,
	Callback = function(value)
		local okSet, status = Rayfield:SetOnboardingSuppressed(value == true)
		sampleLog(okSet and "info" or "error", "SetOnboardingSuppressed => " .. tostring(status))
	end
})

tabSettings:CreateDropdown({
	Name = "Theme Base",
	Options = themeNames,
	CurrentOption = settingsState.themeBase,
	Callback = function(value)
		local selected = firstOption(value)
		if selected ~= "" then
			local okTheme, status = Rayfield:ApplyThemeStudioTheme(selected)
			sampleLog(okTheme and "info" or "error", "ApplyThemeStudioTheme => " .. tostring(status))
		end
	end
})

tabSettings:CreateColorPicker({
	Name = "Accent Color",
	Color = settingsState.themeAccent,
	Callback = function(accent)
		pcall(Rayfield.ApplyThemeStudioTheme, Rayfield, {
			SliderBackground = accent, SliderProgress = accent,
			ToggleEnabled = accent, TabBackgroundSelected = accent
		})
	end
})

-- System tab
local importCodeInput = tabSystem:CreateInput({
	Name = "Settings Code Buffer",
	PlaceholderText = "RFSC1:....",
	Callback = function(text) settingsState.importCode = tostring(text or "") end
})

tabSystem:CreateButton({
	Name = "Export Settings Code",
	Callback = function()
		local code, status = Rayfield:ExportSettings()
		if type(code) == "string" and code ~= "" then
			settingsState.lastExportCode = code
			importCodeInput:Set(code)
			sampleLog("info", "ExportSettings Success")
		else
			sampleLog("error", "ExportSettings Failed: " .. tostring(status))
		end
	end
})

tabSystem:CreateButton({
	Name = "Import From Buffer",
	Callback = function()
		if settingsState.importCode == "" then return sampleLog("warn", "Buffer empty.") end
		local okImport, status = Rayfield:ImportCode(settingsState.importCode)
		sampleLog(okImport and "info" or "error", "ImportCode => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Open Command Palette",
	Callback = function()
		local okOpen, status = Rayfield:OpenCommandPalette("open")
		sampleLog(okOpen and "info" or "error", "OpenCommandPalette => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Open Action Center",
	Callback = function()
		local okOpen, status = Rayfield:OpenActionCenter()
		sampleLog(okOpen and "info" or "error", "OpenActionCenter => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Save Workspace",
	Callback = function()
		local okSave, status = Rayfield:SaveWorkspace("showcase-workspace")
		sampleLog(okSave and "info" or "error", "SaveWorkspace => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Load Workspace",
	Callback = function()
		local okLoad, status = Rayfield:LoadWorkspace("showcase-workspace")
		sampleLog(okLoad and "info" or "error", "LoadWorkspace => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Save Profile",
	Callback = function()
		if type(Rayfield.SaveProfile) ~= "function" then
			sampleLog("warn", "SaveProfile unavailable.")
			return
		end
		local okSave, status = Rayfield:SaveProfile("showcase-profile")
		sampleLog(okSave and "info" or "error", "SaveProfile => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Load Profile",
	Callback = function()
		if type(Rayfield.LoadProfile) ~= "function" then
			sampleLog("warn", "LoadProfile unavailable.")
			return
		end
		local okLoad, status = Rayfield:LoadProfile("showcase-profile")
		sampleLog(okLoad and "info" or "error", "LoadProfile => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Palette Mode Auto",
	Callback = function()
		if type(Rayfield.SetCommandPaletteExecutionMode) ~= "function" then
			sampleLog("warn", "SetCommandPaletteExecutionMode unavailable.")
			return
		end
		local okSet, status = Rayfield:SetCommandPaletteExecutionMode("auto")
		sampleLog(okSet and "info" or "error", "SetCommandPaletteExecutionMode(auto) => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Toggle Performance HUD",
	Callback = function()
		if type(Rayfield.TogglePerformanceHUD) ~= "function" then
			sampleLog("warn", "TogglePerformanceHUD unavailable.")
			return
		end
		local okToggle, status = Rayfield:TogglePerformanceHUD()
		sampleLog(okToggle and "info" or "error", "TogglePerformanceHUD => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Reset HUD Position",
	Callback = function()
		if type(Rayfield.ResetPerformanceHUDPosition) ~= "function" then
			sampleLog("warn", "ResetPerformanceHUDPosition unavailable.")
			return
		end
		local okReset, status = Rayfield:ResetPerformanceHUDPosition("top_left")
		sampleLog(okReset and "info" or "error", "ResetPerformanceHUDPosition => " .. tostring(status))
	end
})

local showcaseMacroName = "showcase-macro"

tabSystem:CreateButton({
	Name = "Show Usage Analytics",
	Callback = function()
		if type(Rayfield.GetUsageAnalytics) ~= "function" then
			sampleLog("warn", "GetUsageAnalytics unavailable.")
			return
		end
		local snapshot = Rayfield:GetUsageAnalytics(8)
		local commandCount = type(snapshot) == "table" and type(snapshot.topCommands) == "table" and #snapshot.topCommands or 0
		sampleLog("info", "UsageAnalytics topCommands => " .. tostring(commandCount))
	end
})

tabSystem:CreateButton({
	Name = "Start Macro Recording",
	Callback = function()
		if type(Rayfield.StartMacroRecording) ~= "function" then
			sampleLog("warn", "StartMacroRecording unavailable.")
			return
		end
		local okStart, status = Rayfield:StartMacroRecording(showcaseMacroName)
		sampleLog(okStart and "info" or "error", "StartMacroRecording => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Stop Macro Recording",
	Callback = function()
		if type(Rayfield.StopMacroRecording) ~= "function" then
			sampleLog("warn", "StopMacroRecording unavailable.")
			return
		end
		local okStop, status = Rayfield:StopMacroRecording(true)
		sampleLog(okStop and "info" or "error", "StopMacroRecording => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Execute Macro",
	Callback = function()
		if type(Rayfield.ExecuteMacro) ~= "function" then
			sampleLog("warn", "ExecuteMacro unavailable.")
			return
		end
		local okExec, status = Rayfield:ExecuteMacro(showcaseMacroName)
		sampleLog(okExec and "info" or "error", "ExecuteMacro => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Toggle Element Inspector",
	Callback = function()
		if type(Rayfield.ToggleElementInspector) ~= "function" then
			sampleLog("warn", "ToggleElementInspector unavailable.")
			return
		end
		local okToggle, status = Rayfield:ToggleElementInspector()
		sampleLog(okToggle and "info" or "error", "ToggleElementInspector => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Open Live Theme Editor",
	Callback = function()
		if type(Rayfield.OpenLiveThemeEditor) ~= "function" then
			sampleLog("warn", "OpenLiveThemeEditor unavailable.")
			return
		end
		local okOpen, status = Rayfield:OpenLiveThemeEditor()
		sampleLog(okOpen and "info" or "error", "OpenLiveThemeEditor => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Export Live Theme Lua",
	Callback = function()
		if type(Rayfield.ExportLiveThemeDraftLua) ~= "function" then
			sampleLog("warn", "ExportLiveThemeDraftLua unavailable.")
			return
		end
		local okExport, statusOrLua = Rayfield:ExportLiveThemeDraftLua()
		local preview = type(statusOrLua) == "string" and statusOrLua:sub(1, 56) or tostring(statusOrLua)
		sampleLog(okExport and "info" or "error", "ExportLiveThemeDraftLua => " .. tostring(preview))
	end
})

tabSystem:CreateButton({
	Name = "Register Hub Metadata",
	Callback = function()
		if type(Rayfield.RegisterHubMetadata) ~= "function" then
			sampleLog("warn", "RegisterHubMetadata unavailable.")
			return
		end
		local okRegister, status = Rayfield:RegisterHubMetadata({
			Name = "Elements Showcase",
			Author = "Rayfield Mod",
			Version = "P0-UI-DX",
			UpdateLog = "Fuzzy search, analytics, macro, inspector, live theme draft",
			Discord = "discord.gg/example"
		})
		sampleLog(okRegister and "info" or "error", "RegisterHubMetadata => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Export Grid CSV",
	Callback = function()
		if type(settingsDataGrid) ~= "table" or type(settingsDataGrid.ExportCSV) ~= "function" then
			sampleLog("warn", "DataGrid CSV export unavailable.")
			return
		end
		local okExport, result = settingsDataGrid:ExportCSV()
		sampleLog(okExport and "info" or "error", "DataGrid ExportCSV => " .. tostring(result))
	end
})

tabSystem:CreateButton({
	Name = "Export Grid JSON",
	Callback = function()
		if type(settingsDataGrid) ~= "table" or type(settingsDataGrid.ExportJSON) ~= "function" then
			sampleLog("warn", "DataGrid JSON export unavailable.")
			return
		end
		local okExport, result = settingsDataGrid:ExportJSON()
		sampleLog(okExport and "info" or "error", "DataGrid ExportJSON => " .. tostring(result))
	end
})

local function collectAutoDiagnostics(trigger)
	local report = {
		trigger = tostring(trigger or "unknown"),
		generatedAt = type(os.date) == "function" and os.date("%Y-%m-%d %H:%M:%S") or tostring(os.clock()),
		issueCount = 0,
		issues = {},
		hints = {}
	}

	local function addIssue(code, severity, message)
		report.issueCount = report.issueCount + 1
		table.insert(report.issues, {
			code = tostring(code or "unknown"),
			severity = tostring(severity or "warn"),
			message = tostring(message or "")
		})
	end

	local function addHint(message)
		table.insert(report.hints, tostring(message or ""))
	end

	local bootstrapReasons = diagnosticState.bootstrap.reasons or {}
	local sawQuickSetupTimeout = false
	local sawBaseTimeout = false
	if #bootstrapReasons > 0 then
		addIssue("bootstrap_warnings", "warn", "Bootstrap had fallback/errors before success.")
		for _, reason in ipairs(bootstrapReasons) do
			local reasonText = tostring(reason)
			local normalizedReason = string.lower(reasonText)
			if string.find(normalizedReason, "quicksetup failed", 1, true)
				and string.find(normalizedReason, "timeout", 1, true) then
				sawQuickSetupTimeout = true
			end
			if string.find(normalizedReason, "base loader failed", 1, true)
				and string.find(normalizedReason, "timeout", 1, true) then
				sawBaseTimeout = true
			end
			addHint("Bootstrap reason: " .. reasonText)
		end
	end
	if sawQuickSetupTimeout and sawBaseTimeout then
		addIssue("bootstrap_execution_timeout", "error", "QuickSetup and base loader both timed out after fetch.")
		addHint("Execution likely stalled after source download; this is not an HttpGet fetch failure.")
		addHint("Try _G.__RAYFIELD_SHOWCASE_PREFER_AIO = false to skip quickSetup path.")
		addHint("Increase _G.__RAYFIELD_SHOWCASE_BOOT_TIMEOUT_SEC (for example 120 or 180).")
		addHint("Point _G.__RAYFIELD_RUNTIME_ROOT_URL to your updated branch to avoid stale remote runtime.")
	end

	local fetchAttempts = diagnosticState.fetchAttempts or {}
	local failedAttempts = 0
	for _, attempt in ipairs(fetchAttempts) do
		if attempt.ok ~= true then
			failedAttempts = failedAttempts + 1
		end
	end
	if failedAttempts > 0 then
		addIssue("fetch_failures", "warn", "Detected failed remote fetch attempts: " .. tostring(failedAttempts))
		addHint("Check CDN/raw GitHub reachability and executor HttpGet permissions.")
	end

	if checkState.fail > 0 then
		addIssue("check_fail", "error", "Runtime checks failed: " .. tostring(checkState.fail))
	end

	local loggerInfo = type(ShowcaseLogger.getInfo) == "function" and ShowcaseLogger.getInfo() or nil
	if type(loggerInfo) == "table" then
		if loggerInfo.fileEnabled ~= true then
			addIssue("file_log_disabled", "warn", "File log is unavailable: " .. tostring(loggerInfo.reason))
			addHint("Enable writefile/appendfile APIs or set a writable log folder.")
		end
	end

	local policyState = type(ExecPolicy) == "table" and type(ExecPolicy.getState) == "function" and ExecPolicy.getState() or nil
	if type(policyState) == "table" and type(policyState.ops) == "table" then
		for opKey, opState in pairs(policyState.ops) do
			local streak = tonumber(opState and opState.consecutiveTimeouts) or 0
			if streak > 0 then
				addIssue("timeout_streak", "warn", "Timeout streak on op '" .. tostring(opKey) .. "': " .. tostring(streak))
				addHint("Operation '" .. tostring(opKey) .. "' is timing out; increase timeout or inspect upstream loader.")
			end
		end
	end

	local logBuffer = type(ShowcaseLogger.getBuffer) == "function" and ShowcaseLogger.getBuffer() or {}
	local function scanPattern(pattern, plain)
		for _, line in ipairs(logBuffer) do
			if string.find(string.lower(tostring(line)), pattern, 1, plain == true) then
				return true
			end
		end
		return false
	end

	if scanPattern("httpget failed", true) then
		addIssue("network_httpget_failed", "error", "HttpGet failed while loading remote modules.")
		addHint("If running in executor, ensure HTTP requests are enabled and not blocked.")
	end
	if scanPattern("timeout after", true) then
		addIssue("operation_timeout", "warn", "At least one operation timed out during bootstrap/load.")
	end
	if scanPattern("ui bootstrap failed", true) then
		addIssue("ui_bootstrap_failed", "error", "UI bootstrap reported failure.")
	end
	if scanPattern("createwindow failed", true) then
		addIssue("create_window_failed", "error", "Rayfield.CreateWindow failed.")
		addHint("Inspect runtime compatibility and module contracts for CreateWindow dependencies.")
	end

	if report.issueCount == 0 then
		addHint("No critical issue pattern detected from current run.")
	end

	return report
end

local function renderDiagnosticReport(report)
	local lines = {
		"=== Rayfield Showcase Auto Diagnostics ===",
		"trigger: " .. tostring(report.trigger),
		"generatedAt: " .. tostring(report.generatedAt),
		"runtimeRoot: " .. tostring(root),
		"bootstrapOrder: " .. tostring(diagnosticState.bootstrap.order),
		"bootstrapMode: " .. tostring(diagnosticState.bootstrap.mode),
		"selectedRoot: " .. tostring(diagnosticState.bootstrap.selectedRoot),
		"checkPass: " .. tostring(checkState.pass),
		"checkFail: " .. tostring(checkState.fail),
		"issues: " .. tostring(report.issueCount)
	}

	table.insert(lines, "--- issue-list ---")
	if #report.issues == 0 then
		table.insert(lines, "none")
	else
		for _, issue in ipairs(report.issues) do
			table.insert(lines, string.format("[%s][%s] %s", tostring(issue.severity), tostring(issue.code), tostring(issue.message)))
		end
	end

	table.insert(lines, "--- hints ---")
	if #report.hints == 0 then
		table.insert(lines, "none")
	else
		for _, hint in ipairs(report.hints) do
			table.insert(lines, "- " .. tostring(hint))
		end
	end

	return table.concat(lines, "\n")
end

local function runAutoDiagnostics(trigger)
	local report = collectAutoDiagnostics(trigger)
	local payload = renderDiagnosticReport(report)
	local okWrite, path = false, nil
	if type(ShowcaseLogger.writeDiagnosticReport) == "function" then
		okWrite, path = ShowcaseLogger.writeDiagnosticReport(payload, "auto")
	end
	report.path = path
	diagnosticState.lastReport = report

	if report.issueCount > 0 then
		logLine("DIAG", "Auto diagnostics detected issues=" .. tostring(report.issueCount) .. " | path=" .. tostring(path))
		pcall(Rayfield.Notify, Rayfield, {
			Title = "Showcase Diagnostics",
			Content = "Detected " .. tostring(report.issueCount) .. " issue(s). Report: " .. tostring(path or "memory"),
			Duration = 7
		})
	else
		logLine("DIAG", "Auto diagnostics clean | path=" .. tostring(path))
	end

	if type(_G) == "table" then
		_G.__RAYFIELD_SHOWCASE_DIAGNOSTICS = report
	end
	return report, payload, okWrite == true
end

tabSystem:CreateButton({
	Name = "Run Auto Diagnostics",
	Callback = function()
		local report = runAutoDiagnostics("manual")
		local summary = "Diagnostics issues=" .. tostring(report and report.issueCount or 0)
		sampleLog((report and report.issueCount or 0) > 0 and "warn" or "info", summary)
	end
})

tabSystem:CreateButton({
	Name = "Show Log Paths",
	Callback = function()
		local info = type(ShowcaseLogger.getInfo) == "function" and ShowcaseLogger.getInfo() or {}
		sampleLog("info", "Log file => " .. tostring(info.path))
		sampleLog("info", "Diagnostic latest => " .. tostring(info.latestDiagnosticPath))
	end
})

-- [[ CHECKS ]] --
local function runShowcaseChecks()
	logLine("BOOT", "runShowcaseChecks begin")
	runCheck("Basic tab has baseline controls", function()
		local list = tabCore:GetElements()
		return type(list) == "table" and #list >= 6
	end)

	runCheck("UI API methods available", function()
		return type(Rayfield.SetUIPreset) == "function"
			and type(Rayfield.SetTransitionProfile) == "function"
			and type(Rayfield.ExportSettings) == "function"
			and type(Rayfield.OpenCommandPalette) == "function"
			and type(Rayfield.OpenActionCenter) == "function"
			and type(Rayfield.SetCommandPaletteExecutionMode) == "function"
			and type(Rayfield.GetCommandPaletteExecutionMode) == "function"
			and type(Rayfield.RunCommandPaletteItem) == "function"
			and type(Rayfield.GetUnreadNotificationCount) == "function"
			and type(Rayfield.GetNotificationHistoryEx) == "function"
			and type(Rayfield.SaveWorkspace) == "function"
			and type(Rayfield.LoadWorkspace) == "function"
			and type(Rayfield.ListWorkspaces) == "function"
			and type(Rayfield.SaveProfile) == "function"
			and type(Rayfield.LoadProfile) == "function"
			and type(Rayfield.ListProfiles) == "function"
			and type(Rayfield.CopyWorkspaceToProfile) == "function"
			and type(Rayfield.CopyProfileToWorkspace) == "function"
			and type(Rayfield.OpenPerformanceHUD) == "function"
			and type(Rayfield.ClosePerformanceHUD) == "function"
			and type(Rayfield.TogglePerformanceHUD) == "function"
			and type(Rayfield.ResetPerformanceHUDPosition) == "function"
			and type(Rayfield.GetPerformanceHUDState) == "function"
			and type(Rayfield.GetUsageAnalytics) == "function"
			and type(Rayfield.StartMacroRecording) == "function"
			and type(Rayfield.StopMacroRecording) == "function"
			and type(Rayfield.IsMacroExecuting) == "function"
			and type(Rayfield.ListMacros) == "function"
			and type(Rayfield.ExecuteMacro) == "function"
			and type(Rayfield.ToggleElementInspector) == "function"
			and type(Rayfield.RegisterHubMetadata) == "function"
			and type(Rayfield.OpenLiveThemeEditor) == "function"
			and type(Rayfield.ExportLiveThemeDraftLua) == "function"
			and type(Rayfield.Notify) == "function"
	end)

	runCheck("DataGrid API available (if supported)", function()
		if settingsDataGrid == nil then
			return type(tabAdvanced.CreateDataGrid) ~= "function"
		end
		return type(settingsDataGrid.SetRows) == "function"
			and type(settingsDataGrid.GetRows) == "function"
			and type(settingsDataGrid.SortBy) == "function"
			and type(settingsDataGrid.SetFilter) == "function"
			and type(settingsDataGrid.GetFilter) == "function"
			and type(settingsDataGrid.GetSelectedRow) == "function"
			and type(settingsDataGrid.ExportCSV) == "function"
			and type(settingsDataGrid.ExportJSON) == "function"
	end)

	runCheck("Core element Set/Get works", function()
        pcall(function()
            elToggle:Set(true)
            elSlider:Set(75)
            elInput:Set("Stable-Showcase")
            elDropdown:Set("Beta")
        end)
		return true
	end)

	local summary = string.format("Checks: %d pass / %d fail", checkState.pass, checkState.fail)
	logLine("CHECK", summary)
    pcall(Rayfield.Notify, Rayfield, {
		Title = "Showcase Completed",
		Content = summary,
		Duration = 5
	})
end

task.spawn(function()
	local ok, err = pcall(runShowcaseChecks)
	if not ok then
		logLine("ERROR", "Checks Failed: " .. tostring(err))
		writeCrashSnapshot("checks", err)
		runAutoDiagnostics("checks-crash")
		return
	end
	runAutoDiagnostics("post-checks")
end)

logLine("BOOT", "Final payload return")
return {
	UI = UI, Rayfield = Rayfield, Window = window,
	Tabs = { Core = tabCore, Advanced = tabAdvanced, Settings = tabSettings, System = tabSystem },
	Elements = {
		Advanced = {
			DataGrid = settingsDataGrid
		}
	},
	CheckState = checkState,
	RuntimeState = runtimeState,
	Diagnostics = diagnosticState
}
