local AutomationEngineService = {}

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

local function nowTimestamp()
	if type(os.date) == "function" then
		return os.date("!%Y-%m-%dT%H:%M:%SZ")
	end
	return tostring(os.clock())
end

local function normalizeRuleId(raw)
	local id = tostring(raw or "")
	id = id:gsub("^%s+", ""):gsub("%s+$", "")
	id = id:gsub("[%s/\\]+", "_")
	id = id:gsub("[^%w_%-:]", "")
	if id == "" then
		id = "rule-" .. tostring(math.floor(os.clock() * 100000))
	end
	return id
end

local function normalizeNumber(value, fallback, minValue)
	local numeric = tonumber(value)
	if numeric == nil then
		numeric = tonumber(fallback) or 0
	end
	numeric = math.max(tonumber(minValue) or 0, numeric)
	return numeric
end

function AutomationEngineService.create(ctx)
	ctx = ctx or {}
	local cloneValue = type(ctx.cloneValue) == "function" and ctx.cloneValue or defaultClone
	local getSetting = type(ctx.getSetting) == "function" and ctx.getSetting or nil
	local setSettingValue = type(ctx.setSettingValue) == "function" and ctx.setSettingValue or nil
	local executeMacro = type(ctx.executeMacro) == "function" and ctx.executeMacro or nil
	local executeCommand = type(ctx.executeCommand) == "function" and ctx.executeCommand or nil
	local notify = type(ctx.notify) == "function" and ctx.notify or nil
	local onEvent = type(ctx.onEvent) == "function" and ctx.onEvent or function() end
	local onPersist = type(ctx.onPersist) == "function" and ctx.onPersist or function() end

	local maxScheduled = normalizeNumber((type(_G) == "table" and _G.__RAYFIELD_AUTOMATION_MAX_SCHEDULED) or ctx.maxScheduled or 32, 32, 4)
	local maxRuleCount = normalizeNumber((type(_G) == "table" and _G.__RAYFIELD_AUTOMATION_MAX_RULES) or ctx.maxRuleCount or 64, 64, 4)

	local storedRules = type(getSetting) == "function" and getSetting("Automation", "rules") or nil
	local rules = type(storedRules) == "table" and cloneValue(storedRules) or {}
	local scheduledTasks = {}
	local nextTaskSerial = 0

	local function persistRules()
		if type(setSettingValue) == "function" then
			setSettingValue("Automation", "rules", cloneValue(rules), true)
		end
		onPersist()
	end

	local function normalizeRule(input)
		if type(input) ~= "table" then
			return nil, "Rule must be a table."
		end
		local rule = cloneValue(input)
		rule.id = normalizeRuleId(rule.id or rule.name)
		rule.name = tostring(rule.name or rule.id)
		rule.enabled = rule.enabled ~= false

		local whenPart = type(rule.when) == "table" and cloneValue(rule.when) or {}
		whenPart.action = tostring(whenPart.action or "")
		whenPart.controlId = tostring(whenPart.controlId or "")
		whenPart.tabId = tostring(whenPart.tabId or "")
		whenPart.interaction = tostring(whenPart.interaction or "")
		whenPart.valueEquals = whenPart.valueEquals
		whenPart.valueNotEquals = whenPart.valueNotEquals
		rule.when = whenPart

		local thenPart = type(rule["then"]) == "table" and cloneValue(rule["then"]) or {}
		thenPart.type = string.lower(tostring(thenPart.type or ""))
		if thenPart.type == "" then
			if tostring(thenPart.macro or "") ~= "" then
				thenPart.type = "macro"
			elseif tostring(thenPart.action or "") ~= "" then
				thenPart.type = "command"
			end
		end
		thenPart.macro = tostring(thenPart.macro or thenPart.name or "")
		thenPart.action = tostring(thenPart.action or "")
		thenPart.payload = cloneValue(thenPart.payload)
		thenPart.options = type(thenPart.options) == "table" and cloneValue(thenPart.options) or {}
		rule["then"] = thenPart

		if thenPart.type ~= "macro" and thenPart.type ~= "command" then
			return nil, "Rule action type must be 'macro' or 'command'."
		end
		if thenPart.type == "macro" and thenPart.macro == "" then
			return nil, "Rule macro name is required."
		end
		if thenPart.type == "command" and thenPart.action == "" then
			return nil, "Rule command action is required."
		end
		return rule, nil
	end

	local function runAction(actionSpec, reason)
		if type(actionSpec) ~= "table" then
			return false, "Action spec must be a table."
		end
		local actionType = string.lower(tostring(actionSpec.type or ""))
		if actionType == "macro" then
			if type(executeMacro) ~= "function" then
				return false, "Macro executor unavailable."
			end
			local macroName = tostring(actionSpec.macro or actionSpec.name or "")
			if macroName == "" then
				return false, "Macro name is required."
			end
			local okMacro, macroMsg = executeMacro(macroName, actionSpec.options)
			if okMacro then
				onEvent("macro", {
					name = macroName,
					reason = reason or "automation"
				})
			end
			return okMacro, macroMsg
		end

		if actionType == "command" then
			if type(executeCommand) ~= "function" then
				return false, "Command executor unavailable."
			end
			local commandAction = tostring(actionSpec.action or "")
			if commandAction == "" then
				return false, "Command action is required."
			end
			local okCommand, commandMsg = executeCommand(commandAction, actionSpec.payload, actionSpec.options)
			if okCommand then
				onEvent("command", {
					action = commandAction,
					reason = reason or "automation"
				})
			end
			return okCommand, commandMsg
		end

		return false, "Unsupported action type."
	end

	local function listRules()
		local out = {}
		for _, rule in pairs(rules) do
			if type(rule) == "table" then
				table.insert(out, cloneValue(rule))
			end
		end
		table.sort(out, function(a, b)
			return tostring(a.name or a.id or "") < tostring(b.name or b.id or "")
		end)
		return out
	end

	local function addRule(ruleInput)
		if type(ruleInput) ~= "table" then
			return false, "Rule must be a table."
		end
		local normalized, err = normalizeRule(ruleInput)
		if not normalized then
			return false, err
		end
		local currentCount = 0
		for _ in pairs(rules) do
			currentCount += 1
		end
		if rules[normalized.id] == nil and currentCount >= maxRuleCount then
			return false, string.format("Automation rule limit reached (%d).", maxRuleCount)
		end
		rules[normalized.id] = normalized
		persistRules()
		return true, "Automation rule saved: " .. tostring(normalized.name), cloneValue(normalized)
	end

	local function removeRule(ruleId)
		local normalizedId = normalizeRuleId(ruleId)
		if rules[normalizedId] == nil then
			return false, "Automation rule not found: " .. normalizedId
		end
		rules[normalizedId] = nil
		persistRules()
		return true, "Automation rule removed: " .. normalizedId
	end

	local function setRuleEnabled(ruleId, enabled)
		local normalizedId = normalizeRuleId(ruleId)
		local existing = rules[normalizedId]
		if type(existing) ~= "table" then
			return false, "Automation rule not found: " .. normalizedId
		end
		existing.enabled = enabled ~= false
		persistRules()
		return true, existing.enabled and "Automation rule enabled." or "Automation rule disabled."
	end

	local function ruleMatches(rule, payload)
		if type(rule) ~= "table" or type(payload) ~= "table" then
			return false
		end
		local whenPart = type(rule.when) == "table" and rule.when or {}
		if whenPart.action ~= "" and tostring(payload.action or "") ~= whenPart.action then
			return false
		end
		if whenPart.controlId ~= "" and tostring(payload.id or payload.controlId or "") ~= whenPart.controlId then
			return false
		end
		if whenPart.tabId ~= "" and tostring(payload.tabId or "") ~= whenPart.tabId then
			return false
		end
		if whenPart.interaction ~= "" and tostring(payload.interaction or "") ~= whenPart.interaction then
			return false
		end
		if whenPart.valueEquals ~= nil and payload.value ~= whenPart.valueEquals then
			return false
		end
		if whenPart.valueNotEquals ~= nil and payload.value == whenPart.valueNotEquals then
			return false
		end
		return true
	end

	local function evaluateRules(eventPayload)
		if type(eventPayload) ~= "table" then
			return false, "Event payload must be a table.", 0
		end
		local triggered = 0
		for _, rule in pairs(rules) do
			if type(rule) == "table" and rule.enabled ~= false and ruleMatches(rule, eventPayload) then
				triggered += 1
				task.spawn(function()
					local okRun, runMsg = runAction(rule["then"], "rule:" .. tostring(rule.id))
					if not okRun and notify then
						notify({
							Title = "Automation Rule",
							Content = tostring(runMsg or "Rule execution failed."),
							Duration = 4
						})
					end
				end)
			end
		end
		return true, "Automation rules evaluated.", triggered
	end

	local function listScheduled()
		local out = {}
		for _, taskInfo in pairs(scheduledTasks) do
			if type(taskInfo) == "table" then
				table.insert(out, cloneValue(taskInfo))
			end
		end
		table.sort(out, function(a, b)
			local runAtA = tonumber(a.runAtClock) or 0
			local runAtB = tonumber(b.runAtClock) or 0
			return runAtA < runAtB
		end)
		return out
	end

	local function scheduleAction(actionSpec, delaySeconds, options)
		local delaySec = normalizeNumber(delaySeconds, 0, 0)
		options = type(options) == "table" and options or {}
		local activeCount = 0
		for _, taskInfo in pairs(scheduledTasks) do
			if type(taskInfo) == "table" and taskInfo.status == "scheduled" then
				activeCount += 1
			end
		end
		if activeCount >= maxScheduled then
			return false, string.format("Scheduled task limit reached (%d).", maxScheduled), nil
		end

		nextTaskSerial += 1
		local taskId = "task-" .. tostring(nextTaskSerial)
		local nowClock = os.clock()
		local record = {
			id = taskId,
			action = cloneValue(actionSpec),
			delaySeconds = delaySec,
			createdAt = nowTimestamp(),
			runAtClock = nowClock + delaySec,
			status = "scheduled",
			reason = tostring(options.reason or "scheduler")
		}
		scheduledTasks[taskId] = record

		task.spawn(function()
			if delaySec > 0 then
				task.wait(delaySec)
			end
			local active = scheduledTasks[taskId]
			if type(active) ~= "table" or active.status ~= "scheduled" then
				return
			end
			active.status = "running"
			local okRun, runMsg = runAction(active.action, "scheduled:" .. taskId)
			active.status = okRun and "completed" or "failed"
			active.completedAt = nowTimestamp()
			active.lastMessage = tostring(runMsg or "")
			onEvent("scheduled", {
				id = taskId,
				success = okRun == true
			})
			if options.keepHistory ~= true then
				task.delay(0.5, function()
					if scheduledTasks[taskId] == active then
						scheduledTasks[taskId] = nil
					end
				end)
			end
		end)

		return true, "Scheduled task created: " .. taskId, cloneValue(record)
	end

	local function scheduleMacro(name, delaySeconds, options)
		local macroName = tostring(name or "")
		if macroName == "" then
			return false, "Macro name is required.", nil
		end
		return scheduleAction({
			type = "macro",
			macro = macroName,
			options = type(options) == "table" and cloneValue(options) or {}
		}, delaySeconds, {
			reason = "schedule_macro"
		})
	end

	local function cancelScheduled(taskId)
		local id = tostring(taskId or "")
		local taskInfo = scheduledTasks[id]
		if type(taskInfo) ~= "table" then
			return false, "Scheduled task not found: " .. id
		end
		if taskInfo.status ~= "scheduled" and taskInfo.status ~= "running" then
			return false, "Scheduled task is not cancellable."
		end
		taskInfo.status = "canceled"
		taskInfo.completedAt = nowTimestamp()
		return true, "Scheduled task canceled: " .. id
	end

	local function clearScheduled()
		for _, taskInfo in pairs(scheduledTasks) do
			if type(taskInfo) == "table" and (taskInfo.status == "scheduled" or taskInfo.status == "running") then
				taskInfo.status = "canceled"
				taskInfo.completedAt = nowTimestamp()
			end
		end
		table.clear(scheduledTasks)
		return true, "Scheduled tasks cleared."
	end

	local service = {
		runAction = runAction,
		scheduleAction = scheduleAction,
		scheduleMacro = scheduleMacro,
		cancelScheduled = cancelScheduled,
		listScheduled = listScheduled,
		clearScheduled = clearScheduled,
		addRule = addRule,
		removeRule = removeRule,
		listRules = listRules,
		setRuleEnabled = setRuleEnabled,
		evaluateRules = evaluateRules
	}

	if type(_G) == "table" then
		_G.__RAYFIELD_AUTOMATION_ENGINE = service
	end

	return service
end

return AutomationEngineService
