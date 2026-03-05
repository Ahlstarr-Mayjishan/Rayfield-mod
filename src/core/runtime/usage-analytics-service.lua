local UsageAnalyticsService = {}

local function defaultClone(value, seen)
	local valueType = type(value)
	if valueType ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	for key, nested in pairs(value) do
		out[defaultClone(key, seen)] = defaultClone(nested, seen)
	end
	return out
end

local function toSafeString(value, fallback)
	local text = tostring(value or "")
	if text == "" then
		return tostring(fallback or "")
	end
	return text
end

function UsageAnalyticsService.create(ctx)
	ctx = ctx or {}

	local cloneValue = type(ctx.cloneValue) == "function" and ctx.cloneValue or defaultClone
	local getSetting = type(ctx.getSetting) == "function" and ctx.getSetting or nil
	local onStateChanged = type(ctx.onStateChanged) == "function" and ctx.onStateChanged or function() end
	local maxEvents = tonumber(ctx.maxEvents)
	if not maxEvents or maxEvents < 30 then
		maxEvents = tonumber(type(_G) == "table" and _G.__RAYFIELD_USAGE_ANALYTICS_MAX_EVENTS or 300) or 300
	end
	maxEvents = math.max(30, math.floor(maxEvents))

	local globalState = type(_G) == "table" and _G.__RAYFIELD_USAGE_ANALYTICS_STATE or nil
	local state = type(globalState) == "table" and globalState or {}
	state.events = type(state.events) == "table" and state.events or {}
	state.controlUsage = type(state.controlUsage) == "table" and state.controlUsage or {}
	state.tabUsage = type(state.tabUsage) == "table" and state.tabUsage or {}
	state.commandUsage = type(state.commandUsage) == "table" and state.commandUsage or {}
	state.macroUsage = type(state.macroUsage) == "table" and state.macroUsage or {}
	state.controlMeta = type(state.controlMeta) == "table" and state.controlMeta or {}
	state.tabMeta = type(state.tabMeta) == "table" and state.tabMeta or {}
	state.commandMeta = type(state.commandMeta) == "table" and state.commandMeta or {}
	state.lastUpdatedAt = tonumber(state.lastUpdatedAt) or 0

	local function isEnabled()
		if not getSetting then
			return true
		end
		return getSetting("System", "usageAnalytics") ~= false
	end

	local function pushEvent(kind, payload)
		if not isEnabled() then
			return
		end
		local entry = {
			kind = toSafeString(kind, "unknown"),
			payload = cloneValue(payload or {}),
			at = os.clock(),
			timestamp = type(os.date) == "function" and os.date("%Y-%m-%d %H:%M:%S") or tostring(os.clock())
		}
		table.insert(state.events, entry)
		while #state.events > maxEvents do
			table.remove(state.events, 1)
		end
		state.lastEvent = entry
		state.lastUpdatedAt = entry.at
		onStateChanged("event", cloneValue(entry))
	end

	local function incrementCounter(bucket, key, amount)
		local safeKey = toSafeString(key, "unknown")
		local safeAmount = tonumber(amount) or 1
		bucket[safeKey] = (tonumber(bucket[safeKey]) or 0) + safeAmount
		state.lastUpdatedAt = os.clock()
		return bucket[safeKey]
	end

	local function normalizeTopEntries(bucket, metaBucket, limit, kind)
		local top = {}
		for key, count in pairs(bucket) do
			table.insert(top, {
				kind = kind,
				key = key,
				count = tonumber(count) or 0,
				meta = cloneValue(metaBucket[key] or {})
			})
		end
		table.sort(top, function(a, b)
			if a.count ~= b.count then
				return a.count > b.count
			end
			return tostring(a.key) < tostring(b.key)
		end)
		local requestedLimit = tonumber(limit)
		if requestedLimit and requestedLimit > 0 and #top > requestedLimit then
			while #top > requestedLimit do
				table.remove(top)
			end
		end
		return top
	end

	local function trackControlUsage(payload)
		if not isEnabled() then
			return 0
		end
		if type(payload) ~= "table" then
			payload = { id = tostring(payload or "") }
		end
		local controlId = toSafeString(payload.id or payload.controlId, "unknown-control")
		state.controlMeta[controlId] = {
			name = toSafeString(payload.name, controlId),
			tabId = toSafeString(payload.tabId, ""),
			type = toSafeString(payload.type, "control")
		}
		local nextCount = incrementCounter(state.controlUsage, controlId, 1)
		pushEvent("control", {
			id = controlId,
			name = state.controlMeta[controlId].name,
			tabId = state.controlMeta[controlId].tabId,
			type = state.controlMeta[controlId].type,
			action = toSafeString(payload.action, "interact"),
			count = nextCount
		})
		return nextCount
	end

	local function trackTabOpen(payload)
		if not isEnabled() then
			return 0
		end
		if type(payload) ~= "table" then
			payload = { tabId = tostring(payload or "") }
		end
		local tabId = toSafeString(payload.tabId, "unknown-tab")
		state.tabMeta[tabId] = {
			name = toSafeString(payload.name, tabId)
		}
		local nextCount = incrementCounter(state.tabUsage, tabId, 1)
		pushEvent("tab", {
			tabId = tabId,
			name = state.tabMeta[tabId].name,
			source = toSafeString(payload.source, "unknown"),
			count = nextCount
		})
		return nextCount
	end

	local function trackCommandUsage(payload)
		if not isEnabled() then
			return 0
		end
		if type(payload) ~= "table" then
			payload = { action = tostring(payload or "") }
		end
		local actionId = toSafeString(payload.action or payload.id, "unknown-command")
		state.commandMeta[actionId] = {
			name = toSafeString(payload.name, actionId),
			type = toSafeString(payload.type, "command")
		}
		local nextCount = incrementCounter(state.commandUsage, actionId, 1)
		pushEvent("command", {
			action = actionId,
			name = state.commandMeta[actionId].name,
			count = nextCount
		})
		return nextCount
	end

	local function trackMacroUsage(payload)
		if not isEnabled() then
			return 0
		end
		if type(payload) ~= "table" then
			payload = { name = tostring(payload or "") }
		end
		local macroName = toSafeString(payload.name, "unnamed-macro")
		local nextCount = incrementCounter(state.macroUsage, macroName, 1)
		pushEvent("macro", {
			name = macroName,
			count = nextCount
		})
		return nextCount
	end

	local function getUsageCount(kind, key)
		local bucket = nil
		if kind == "control" then
			bucket = state.controlUsage
		elseif kind == "tab" then
			bucket = state.tabUsage
		elseif kind == "macro" then
			bucket = state.macroUsage
		else
			bucket = state.commandUsage
		end
		return tonumber(bucket[toSafeString(key, "")]) or 0
	end

	local function getSnapshot(limit)
		local eventLimit = tonumber(limit)
		local events = {}
		if eventLimit and eventLimit > 0 then
			local startIndex = math.max(1, #state.events - eventLimit + 1)
			for index = startIndex, #state.events do
				table.insert(events, cloneValue(state.events[index]))
			end
		else
			for _, entry in ipairs(state.events) do
				table.insert(events, cloneValue(entry))
			end
		end
		return {
			enabled = isEnabled(),
			lastUpdatedAt = state.lastUpdatedAt,
			events = events,
			topControls = normalizeTopEntries(state.controlUsage, state.controlMeta, 10, "control"),
			topTabs = normalizeTopEntries(state.tabUsage, state.tabMeta, 10, "tab"),
			topCommands = normalizeTopEntries(state.commandUsage, state.commandMeta, 10, "command"),
			topMacros = normalizeTopEntries(state.macroUsage, {}, 10, "macro")
		}
	end

	local function clear()
		table.clear(state.events)
		table.clear(state.controlUsage)
		table.clear(state.tabUsage)
		table.clear(state.commandUsage)
		table.clear(state.macroUsage)
		table.clear(state.controlMeta)
		table.clear(state.tabMeta)
		table.clear(state.commandMeta)
		state.lastUpdatedAt = os.clock()
		onStateChanged("clear", {})
		return true, "Usage analytics cleared."
	end

	local service = {
		trackControlUsage = trackControlUsage,
		trackTabOpen = trackTabOpen,
		trackCommandUsage = trackCommandUsage,
		trackMacroUsage = trackMacroUsage,
		getUsageCount = getUsageCount,
		getTopControls = function(limit)
			return normalizeTopEntries(state.controlUsage, state.controlMeta, limit, "control")
		end,
		getTopTabs = function(limit)
			return normalizeTopEntries(state.tabUsage, state.tabMeta, limit, "tab")
		end,
		getTopCommands = function(limit)
			return normalizeTopEntries(state.commandUsage, state.commandMeta, limit, "command")
		end,
		getTopMacros = function(limit)
			return normalizeTopEntries(state.macroUsage, {}, limit, "macro")
		end,
		getSnapshot = getSnapshot,
		clear = clear,
		isEnabled = isEnabled,
		getState = function()
			return state
		end
	}

	if type(_G) == "table" then
		_G.__RAYFIELD_USAGE_ANALYTICS_STATE = state
		_G.__RAYFIELD_USAGE_ANALYTICS = service
	end

	return service
end

return UsageAnalyticsService
