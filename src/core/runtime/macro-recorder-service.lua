local MacroRecorderService = {}

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

local function normalizeMacroName(rawName)
	local name = tostring(rawName or "")
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return nil
	end
	if #name > 64 then
		name = name:sub(1, 64)
	end
	return name
end

local function normalizeKeybind(rawValue)
	local tokens = {}
	for token in tostring(rawValue or ""):gmatch("[^%+]+") do
		local cleaned = token:gsub("^%s+", ""):gsub("%s+$", "")
		if cleaned ~= "" then
			table.insert(tokens, cleaned)
		end
	end
	if #tokens == 0 then
		return ""
	end
	return table.concat(tokens, "+")
end

function MacroRecorderService.create(ctx)
	ctx = ctx or {}
	local cloneValue = type(ctx.cloneValue) == "function" and ctx.cloneValue or defaultClone
	local getSetting = type(ctx.getSetting) == "function" and ctx.getSetting or nil
	local setSettingValue = type(ctx.setSettingValue) == "function" and ctx.setSettingValue or nil
	local onPersist = type(ctx.onPersist) == "function" and ctx.onPersist or function() end
	local onMacroExecuted = type(ctx.onMacroExecuted) == "function" and ctx.onMacroExecuted or function() end
	local maxSteps = tonumber(type(_G) == "table" and _G.__RAYFIELD_MACRO_MAX_STEPS or ctx.maxSteps or 120) or 120
	maxSteps = math.max(10, math.floor(maxSteps))
	local maxExecuteSteps = tonumber(type(_G) == "table" and _G.__RAYFIELD_MACRO_MAX_EXECUTE_STEPS or ctx.maxExecuteSteps or 200) or 200
	maxExecuteSteps = math.max(10, math.floor(maxExecuteSteps))
	local executionTimeoutSec = tonumber(type(_G) == "table" and _G.__RAYFIELD_MACRO_EXEC_TIMEOUT_SEC or ctx.executionTimeoutSec or 8) or 8
	executionTimeoutSec = math.max(1, executionTimeoutSec)
	local dedupeWindowSec = tonumber(type(_G) == "table" and _G.__RAYFIELD_MACRO_DEDUPE_WINDOW_SEC or ctx.dedupeWindowSec or 0.12) or 0.12
	dedupeWindowSec = math.max(0, dedupeWindowSec)

	local storedMacros = type(getSetting) == "function" and getSetting("Macros", "items") or nil
	local macros = type(storedMacros) == "table" and cloneValue(storedMacros) or {}
	local recordingState = nil
	local executing = false
	local allowedActions = {
		control = true,
		open_settings = true,
		open_action_center = true,
		toggle_visibility = true
	}

	local function persistMacros()
		if type(setSettingValue) == "function" then
			setSettingValue("Macros", "items", cloneValue(macros), true)
		end
		onPersist()
	end

	local function listMacros()
		local names = {}
		for name in pairs(macros) do
			table.insert(names, tostring(name))
		end
		table.sort(names)
		return names
	end

	local function startRecording(name)
		if recordingState then
			return false, "A macro recording session is already active."
		end
		local normalizedName = normalizeMacroName(name)
		if not normalizedName then
			return false, "Invalid macro name."
		end
		recordingState = {
			name = normalizedName,
			startedAtClock = os.clock(),
			startedAt = nowTimestamp(),
			steps = {},
			lastFingerprint = nil,
			lastAt = nil
		}
		return true, "Macro recording started: " .. normalizedName
	end

	local function stopRecording(saveResult)
		if not recordingState then
			return false, "No macro recording in progress."
		end
		local shouldSave = saveResult ~= false
		local finished = recordingState
		recordingState = nil
		if shouldSave then
			local existing = macros[finished.name]
			macros[finished.name] = {
				name = finished.name,
				version = 1,
				createdAt = existing and existing.createdAt or finished.startedAt,
				updatedAt = nowTimestamp(),
				keybind = existing and existing.keybind or "",
				steps = cloneValue(finished.steps)
			}
			persistMacros()
			return true, string.format("Macro saved: %s (%d steps).", finished.name, #finished.steps), cloneValue(macros[finished.name])
		end
		return true, string.format("Macro recording canceled: %s.", finished.name), nil
	end

	local function cancelRecording()
		return stopRecording(false)
	end

	local function recordStep(step)
		if not recordingState then
			return false
		end
		if type(step) ~= "table" then
			return false
		end
		if #recordingState.steps >= maxSteps then
			return false
		end
		local actionName = tostring(step.action or "")
		if actionName == "" or allowedActions[actionName] ~= true then
			return false
		end
		local payload = cloneValue(step)
		payload.t = math.max(0, os.clock() - recordingState.startedAtClock)
		local fingerprint = table.concat({
			tostring(payload.action or ""),
			tostring(payload.controlId or ""),
			tostring(payload.tabId or ""),
			tostring(payload.name or ""),
			tostring(payload.interaction or ""),
			tostring(payload.value)
		}, "|")
		local nowClock = os.clock()
		if recordingState.lastFingerprint == fingerprint
			and type(recordingState.lastAt) == "number"
			and (nowClock - recordingState.lastAt) <= dedupeWindowSec then
			return false
		end
		recordingState.lastFingerprint = fingerprint
		recordingState.lastAt = nowClock
		table.insert(recordingState.steps, payload)
		return true
	end

	local function getMacro(name)
		local normalizedName = normalizeMacroName(name)
		if not normalizedName then
			return nil
		end
		local macro = macros[normalizedName]
		if type(macro) ~= "table" then
			return nil
		end
		return cloneValue(macro)
	end

	local function deleteMacro(name)
		local normalizedName = normalizeMacroName(name)
		if not normalizedName then
			return false, "Invalid macro name."
		end
		if macros[normalizedName] == nil then
			return false, "Macro not found: " .. normalizedName
		end
		macros[normalizedName] = nil
		persistMacros()
		return true, "Macro deleted: " .. normalizedName
	end

	local function bindMacro(name, keybind)
		local normalizedName = normalizeMacroName(name)
		if not normalizedName then
			return false, "Invalid macro name."
		end
		local macro = macros[normalizedName]
		if type(macro) ~= "table" then
			return false, "Macro not found: " .. normalizedName
		end
		macro.keybind = normalizeKeybind(keybind)
		macro.updatedAt = nowTimestamp()
		persistMacros()
		return true, "Macro keybind updated."
	end

	local function getBoundMacros()
		local out = {}
		for name, macro in pairs(macros) do
			if type(macro) == "table" and tostring(macro.keybind or "") ~= "" then
				table.insert(out, {
					name = tostring(name),
					keybind = tostring(macro.keybind),
					steps = type(macro.steps) == "table" and #macro.steps or 0
				})
			end
		end
		table.sort(out, function(a, b)
			return tostring(a.name) < tostring(b.name)
		end)
		return out
	end

	local function executeMacro(name, handlers, options)
		if executing then
			return false, "Macro execution already in progress."
		end
		local macro = getMacro(name)
		if type(macro) ~= "table" then
			return false, "Macro not found: " .. tostring(name)
		end
		if type(macro.steps) == "table" and #macro.steps > maxExecuteSteps then
			return false, string.format("Macro exceeds execution step limit (%d).", maxExecuteSteps)
		end
		local executeStep = type(handlers) == "table" and handlers.executeStep or nil
		if type(executeStep) ~= "function" then
			return false, "Macro execution handler unavailable."
		end
		options = type(options) == "table" and options or {}
		local respectDelay = options.respectDelay == true
		local delayScale = tonumber(options.delayScale) or 1
		delayScale = math.max(0, delayScale)
		local completed = 0
		local startedAt = os.clock()
		executing = true

		local okRun, runErr = pcall(function()
			local previousTime = 0
			for _, step in ipairs(macro.steps or {}) do
				if (os.clock() - startedAt) > executionTimeoutSec then
					error("execution timeout")
				end
				local stepTime = tonumber(step.t) or 0
				if respectDelay and stepTime > previousTime then
					task.wait((stepTime - previousTime) * delayScale)
				end
				previousTime = stepTime
				local okStep, stepResult, stepMessage = pcall(executeStep, cloneValue(step), macro)
				if not okStep then
					error("step failed: " .. tostring(stepResult))
				end
				if stepResult == false then
					error("step rejected: " .. tostring(stepMessage or "unknown"))
				end
				completed += 1
			end
		end)
		executing = false
		if not okRun then
			return false, "Macro execution failed: " .. tostring(runErr)
		end
		onMacroExecuted(macro.name, completed)
		return true, string.format("Macro executed: %s (%d steps).", tostring(macro.name), completed)
	end

	local function triggerByKeybind(keybind, handlers, options)
		local normalized = normalizeKeybind(keybind)
		if normalized == "" then
			return false, "Keybind is empty."
		end
		for name, macro in pairs(macros) do
			if type(macro) == "table" and normalizeKeybind(macro.keybind) == normalized then
				return executeMacro(name, handlers, options)
			end
		end
		return false, "No macro bound to keybind: " .. normalized
	end

	local service = {
		startRecording = startRecording,
		stopRecording = stopRecording,
		cancelRecording = cancelRecording,
		recordStep = recordStep,
		isRecording = function()
			return recordingState ~= nil
		end,
		getRecordingState = function()
			return cloneValue(recordingState)
		end,
		listMacros = listMacros,
		getMacro = getMacro,
		deleteMacro = deleteMacro,
		bindMacro = bindMacro,
		getBoundMacros = getBoundMacros,
		executeMacro = executeMacro,
		triggerByKeybind = triggerByKeybind,
		isExecuting = function()
			return executing == true
		end,
		getAll = function()
			return cloneValue(macros)
		end
	}

	if type(_G) == "table" then
		_G.__RAYFIELD_MACRO_RECORDER = service
	end

	return service
end

return MacroRecorderService
