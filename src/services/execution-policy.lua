local ExecutionPolicyService = {}

function ExecutionPolicyService.ensure(globalEnv, explicitConfig)
	local policyVersion = 2
	local envTable = type(globalEnv) == "table" and globalEnv or nil
	if envTable
		and tonumber(envTable.__RAYFIELD_EXEC_POLICY_VERSION) == policyVersion
		and type(envTable.__RAYFIELD_EXEC_POLICY) == "table"
		and type(envTable.__RAYFIELD_EXEC_POLICY.decideExecutionMode) == "function"
		and type(envTable.__RAYFIELD_EXEC_POLICY.markTimeout) == "function"
		and type(envTable.__RAYFIELD_EXEC_POLICY.markSuccess) == "function" then
		return envTable.__RAYFIELD_EXEC_POLICY
	end

	local state = envTable and envTable.__RAYFIELD_EXEC_POLICY_STATE or nil
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
		if type(explicitConfig) == "table" then
			local mode = string.lower(tostring(explicitConfig.mode or "auto"))
			if mode ~= "auto" and mode ~= "soft" and mode ~= "hard" then
				mode = "auto"
			end
			local escalateAfter = tonumber(explicitConfig.escalateAfter) or 2
			local windowSec = tonumber(explicitConfig.windowSec) or 90
			return {
				mode = mode,
				escalateAfter = math.max(1, math.floor(escalateAfter)),
				windowSec = math.max(1, windowSec)
			}
		end

		local configTable = envTable and envTable.__RAYFIELD_EXEC_POLICY_CONFIG or nil
		if type(configTable) ~= "table" then
			configTable = {}
		end

		local mode = envTable and envTable.__RAYFIELD_EXEC_POLICY_MODE or configTable.mode or "auto"
		mode = string.lower(tostring(mode))
		if mode ~= "auto" and mode ~= "soft" and mode ~= "hard" then
			mode = "auto"
		end

		local escalateAfter = envTable and tonumber(envTable.__RAYFIELD_EXEC_POLICY_ESCALATE_AFTER)
			or tonumber(configTable.escalateAfter)
			or tonumber(configTable.escalate_after)
			or 2
		escalateAfter = math.max(1, math.floor(escalateAfter))

		local windowSec = envTable and tonumber(envTable.__RAYFIELD_EXEC_POLICY_WINDOW_SEC)
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

	if envTable then
		envTable.__RAYFIELD_EXEC_POLICY_STATE = state
		envTable.__RAYFIELD_EXEC_POLICY = policy
		envTable.__RAYFIELD_EXEC_POLICY_VERSION = policyVersion
	end
	return policy
end

return ExecutionPolicyService
