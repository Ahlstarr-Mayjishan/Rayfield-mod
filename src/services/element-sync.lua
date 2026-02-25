-- Rayfield unified element state/visual synchronization service
-- Pipeline: normalize -> applyVisual -> emitCallback -> persist

local ElementSyncModule = {}

local TRACE_FLAG = "__RAYFIELD_ELEMENT_SYNC_TRACE"
local TRACE_PREFIX = "[RAYFIELD][ELEMENT_SYNC]"

local function getSharedUtils()
	if type(_G) == "table" and type(_G.__RayfieldSharedUtils) == "table" then
		return _G.__RayfieldSharedUtils
	end
	return nil
end

local function trim(value)
	local shared = getSharedUtils()
	if shared and type(shared.trim) == "function" then
		return shared.trim(value)
	end
	if type(value) ~= "string" then
		return ""
	end
	local out = value:gsub("^%s+", "")
	out = out:gsub("%s+$", "")
	return out
end

local function cloneArray(source)
	local result = {}
	if type(source) ~= "table" then
		return result
	end
	for index, value in ipairs(source) do
		result[index] = value
	end
	return result
end

local function cloneTable(source)
	local shared = getSharedUtils()
	if shared and type(shared.cloneTable) == "function" then
		return shared.cloneTable(source)
	end
	if type(source) ~= "table" then
		return source
	end
	local result = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			result[key] = cloneTable(value)
		else
			result[key] = value
		end
	end
	return result
end

local function deepEqual(left, right, seen)
	local shared = getSharedUtils()
	if shared and type(shared.deepEqual) == "function" then
		return shared.deepEqual(left, right, seen)
	end
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end

	seen = seen or {}
	if seen[left] and seen[left] == right then
		return true
	end
	seen[left] = right

	for key, value in pairs(left) do
		if not deepEqual(value, right[key], seen) then
			return false
		end
	end

	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end

	return true
end

local function defaultWarn(message)
	warn(TRACE_PREFIX .. " " .. tostring(message))
end

local function shouldTrace()
	return type(_G) == "table" and _G[TRACE_FLAG] == true
end

local function trace(branchId, payload)
	if not shouldTrace() then
		return
	end
	local data = payload or {}
	print(string.format(
		"%s branch_id=%s stage=%s token=%s reason=%s",
		TRACE_PREFIX,
		tostring(branchId or "unknown"),
		tostring(data.stage or "n/a"),
		tostring(data.token or "n/a"),
		tostring(data.reason or "n/a")
	))
end

local function fail(code, message)
	error(string.format("[%s] %s", tostring(code), tostring(message)), 2)
end

local function normalizeBoolean(rawValue)
	return rawValue == true
end

local function normalizeNumberRange(rawValue, options)
	local opts = options or {}
	local minValue = tonumber(opts.min) or 0
	local maxValue = tonumber(opts.max) or 1
	if maxValue <= minValue then
		maxValue = minValue + 1
	end

	local increment = tonumber(opts.increment) or 1
	if increment <= 0 then
		increment = 1
	end

	local value = tonumber(rawValue)
	if value == nil then
		value = tonumber(opts.default) or minValue
	end
	value = math.clamp(value, minValue, maxValue)
	value = math.floor((value / increment) + 0.5) * increment
	value = math.floor((value * 10000000) + 0.5) / 10000000
	value = math.clamp(value, minValue, maxValue)
	return value
end

local function normalizeText(rawValue, options)
	local opts = options or {}
	local value = rawValue
	if value == nil then
		value = opts.default
	end
	if value == nil then
		value = ""
	end
	value = tostring(value)
	if opts.trim ~= false then
		value = trim(value)
	end
	return value
end

local function normalizeSelection(rawSelection, options)
	local opts = options or {}
	local allowedMap = {}
	local normalizedAllowed = {}

	if type(opts.allowedValues) == "table" then
		for _, entry in ipairs(opts.allowedValues) do
			local key = tostring(entry)
			if not allowedMap[key] then
				allowedMap[key] = true
				table.insert(normalizedAllowed, key)
			end
		end
	end

	local function toArray(value)
		local out = {}
		if value == nil then
			return out
		end
		if type(value) == "string" then
			out[1] = value
			return out
		end
		if type(value) ~= "table" then
			out[1] = tostring(value)
			return out
		end

		if #value > 0 then
			for _, entry in ipairs(value) do
				if entry ~= nil then
					table.insert(out, tostring(entry))
				end
			end
		else
			for _, entry in pairs(value) do
				if entry ~= nil then
					table.insert(out, tostring(entry))
				end
			end
		end
		return out
	end

	local multiple = opts.multiple == true
	local dedupe = {}
	local normalized = {}
	for _, entry in ipairs(toArray(rawSelection)) do
		if (next(allowedMap) == nil or allowedMap[entry]) and not dedupe[entry] then
			dedupe[entry] = true
			table.insert(normalized, entry)
		end
	end

	if not multiple and #normalized > 1 then
		normalized = { normalized[1] }
	end

	local fallbackApplied = false
	local fallbackPolicy = tostring(opts.clearBehavior or "default"):lower()
	if fallbackPolicy ~= "none" and #normalized == 0 then
		local fallback = {}
		for _, entry in ipairs(toArray(opts.defaultSelection)) do
			if (next(allowedMap) == nil or allowedMap[entry]) and not dedupe[entry] then
				dedupe[entry] = true
				table.insert(fallback, entry)
			end
		end
		if not multiple and #fallback > 1 then
			fallback = { fallback[1] }
		end
		if #fallback > 0 then
			normalized = fallback
			fallbackApplied = true
		end
	end

	local previous = opts.previousSelection
	local changed = not deepEqual(previous, normalized)
	return normalized, {
		fallbackApplied = fallbackApplied,
		changed = changed,
		allowedValues = normalizedAllowed
	}
end

function ElementSyncModule.init(ctx)
	local self = {}
	local context = ctx or {}
	local warningFn = type(context.warn) == "function" and context.warn or defaultWarn

	local records = {}
	local recordsByTab = {}
	local tokenCounter = 0

	local function unregister(token)
		local record = records[token]
		if not record then
			return false
		end
		records[token] = nil

		local tabId = record.tabId or "__global"
		local tabBucket = recordsByTab[tabId]
		if tabBucket then
			tabBucket[token] = nil
			if next(tabBucket) == nil then
				recordsByTab[tabId] = nil
			end
		end

		trace("UNREGISTER", {
			stage = "unregister",
			token = token,
			reason = "record_removed"
		})
		return true
	end

	local function register(spec)
		if type(spec) ~= "table" then
			fail("E_SPEC_INVALID", "register(spec) expects table")
		end
		if type(spec.getState) ~= "function" then
			fail("E_SPEC_INVALID", "spec.getState must be a function")
		end
		if type(spec.normalize) ~= "function" then
			fail("E_SPEC_INVALID", "spec.normalize must be a function")
		end
		if type(spec.applyVisual) ~= "function" then
			fail("E_SPEC_INVALID", "spec.applyVisual must be a function")
		end
		if type(spec.emitCallback) ~= "function" then
			fail("E_SPEC_INVALID", "spec.emitCallback must be a function")
		end
		if type(spec.persist) ~= "function" then
			fail("E_SPEC_INVALID", "spec.persist must be a function")
		end

		tokenCounter += 1
		local token = "element_sync_" .. tostring(tokenCounter)
		spec.token = token
		records[token] = spec

		local tabId = spec.tabId or "__global"
		recordsByTab[tabId] = recordsByTab[tabId] or {}
		recordsByTab[tabId][token] = true

		trace("REGISTER", {
			stage = "register",
			token = token,
			reason = tostring(spec.name or "unnamed")
		})
		return token
	end

	local function isRecordActive(record)
		if not record then
			return false
		end
		if type(record.isAlive) == "function" then
			local ok, alive = pcall(record.isAlive)
			if not ok or alive == false then
				return false
			end
		end
		return true
	end

	local function commit(token, nextState, options)
		options = options or {}
		local record = records[token]
		if not record then
			return false, { error = "record_missing" }
		end
		if not isRecordActive(record) then
			unregister(token)
			return false, { error = "record_inactive" }
		end

		local previousState = nil
		local okPrev, prevResult = pcall(record.getState)
		if okPrev then
			previousState = cloneTable(prevResult)
		end

		trace("COMMIT_NORMALIZE", {
			stage = "normalize",
			token = token,
			reason = options.reason or "unknown"
		})
		local normalizeOk, normalizedState, normalizeMeta = pcall(record.normalize, nextState, {
			previousState = previousState,
			reason = options.reason,
			source = options.source,
			options = options
		})
		if not normalizeOk then
			warningFn("normalize failed for token=" .. tostring(token) .. " error=" .. tostring(normalizedState))
			return false, { error = "normalize_failed", detail = normalizedState }
		end

		local meta = type(normalizeMeta) == "table" and normalizeMeta or {}
		local changed = meta.changed
		if changed == nil then
			changed = not deepEqual(previousState, normalizedState)
		end
		local fallbackApplied = meta.fallbackApplied == true
		local emitCallback = options.emitCallback
		if emitCallback == nil then
			emitCallback = true
		end
		local shouldPersist = options.persist
		if shouldPersist == nil then
			shouldPersist = true
		end

		trace("COMMIT_VISUAL", {
			stage = "applyVisual",
			token = token,
			reason = options.reason or "unknown"
		})
		local visualOk, visualErr = pcall(record.applyVisual, normalizedState, {
			previousState = previousState,
			changed = changed,
			fallbackApplied = fallbackApplied,
			reason = options.reason,
			source = options.source,
			options = options
		})
		if not visualOk then
			warningFn("applyVisual failed for token=" .. tostring(token) .. " error=" .. tostring(visualErr))
		end

		local callbackOk = true
		local callbackErr = nil
		local shouldEmit = emitCallback and (changed or fallbackApplied or options.forceCallback == true)
		if shouldEmit then
			trace("COMMIT_CALLBACK", {
				stage = "emitCallback",
				token = token,
				reason = options.reason or "unknown"
			})
			callbackOk, callbackErr = pcall(record.emitCallback, normalizedState, {
				previousState = previousState,
				changed = changed,
				fallbackApplied = fallbackApplied,
				reason = options.reason,
				source = options.source,
				options = options
			})
			if not callbackOk and type(record.onCallbackError) == "function" then
				pcall(record.onCallbackError, callbackErr)
			end
		end

		local isExt = false
		if type(record.isExt) == "function" then
			local okExt, value = pcall(record.isExt)
			isExt = okExt and value == true or false
		end

		if shouldPersist and callbackOk and not isExt then
			trace("COMMIT_PERSIST", {
				stage = "persist",
				token = token,
				reason = options.reason or "unknown"
			})
			local okPersist, persistErr = pcall(record.persist, normalizedState, {
				previousState = previousState,
				changed = changed,
				fallbackApplied = fallbackApplied,
				reason = options.reason,
				source = options.source,
				options = options
			})
			if not okPersist then
				warningFn("persist failed for token=" .. tostring(token) .. " error=" .. tostring(persistErr))
			end
		end

		local result = {
			token = token,
			normalized = cloneTable(normalizedState),
			changed = changed,
			fallbackApplied = fallbackApplied,
			callbackOk = callbackOk,
			callbackError = callbackErr,
			reason = options.reason,
			source = options.source
		}

		return callbackOk, result
	end

	local function resync(token, reason)
		local record = records[token]
		if not record then
			return false
		end
		if type(record.isVisibleContext) == "function" then
			local okVisible, visible = pcall(record.isVisibleContext)
			if not okVisible or visible == false then
				return false
			end
		end
		local okState, currentState = pcall(record.getState)
		if not okState then
			return false
		end
		local _, result = commit(token, currentState, {
			reason = reason or "resync",
			source = "resync",
			emitCallback = false,
			persist = false,
			forceCallback = false
		})
		return result ~= nil
	end

	local function resyncTab(tabId, reason)
		local bucket = recordsByTab[tabId or "__global"]
		if not bucket then
			return 0
		end
		local syncedCount = 0
		for token in pairs(bucket) do
			if resync(token, reason or "resync_tab") then
				syncedCount += 1
			end
		end
		return syncedCount
	end

	local function destroy()
		for token in pairs(records) do
			records[token] = nil
		end
		for tabId in pairs(recordsByTab) do
			recordsByTab[tabId] = nil
		end
	end

	self.register = register
	self.unregister = unregister
	self.commit = commit
	self.resync = resync
	self.resyncTab = resyncTab
	self.destroy = destroy
	self.normalize = {
		boolean = normalizeBoolean,
		numberRange = normalizeNumberRange,
		text = normalizeText,
		selection = normalizeSelection
	}

	return self
end

return ElementSyncModule
