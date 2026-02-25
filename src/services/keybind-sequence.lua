local KeybindSequence = {}

local DEFAULT_MAX_STEPS = 4
local DEFAULT_STEP_TIMEOUT_MS = 800

local MODIFIER_ORDER = {
	"LeftControl",
	"RightControl",
	"LeftShift",
	"RightShift",
	"LeftAlt",
	"RightAlt"
}

local MODIFIER_SET = {
	LeftControl = true,
	RightControl = true,
	LeftShift = true,
	RightShift = true,
	LeftAlt = true,
	RightAlt = true
}

local TOKEN_ALIASES = {
	ctrl = "LeftControl",
	control = "LeftControl",
	leftctrl = "LeftControl",
	leftcontrol = "LeftControl",
	rightctrl = "RightControl",
	rightcontrol = "RightControl",
	shift = "LeftShift",
	leftshift = "LeftShift",
	rightshift = "RightShift",
	alt = "LeftAlt",
	leftalt = "LeftAlt",
	rightalt = "RightAlt"
}

local DISPLAY_TOKEN_MAP = {
	LeftControl = "Ctrl",
	RightControl = "Ctrl",
	LeftShift = "Shift",
	RightShift = "Shift",
	LeftAlt = "Alt",
	RightAlt = "Alt"
}

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

local function split(value, separator)
	local list = {}
	if type(value) ~= "string" or value == "" then
		return list
	end

	local pattern = string.format("([^%s]+)", separator)
	for token in string.gmatch(value, pattern) do
		table.insert(list, token)
	end
	return list
end

local function toNumber(value, fallback)
	local numberValue = tonumber(value)
	if numberValue == nil then
		return fallback
	end
	return numberValue
end

local function resolveToken(rawToken)
	if typeof(rawToken) == "EnumItem" and rawToken.EnumType == Enum.KeyCode then
		return rawToken.Name
	end

	local token = trim(tostring(rawToken or ""))
	if token == "" then
		return nil, "empty_token"
	end

	token = token:gsub("^Enum%.KeyCode%.", "")
	token = token:gsub("^KeyCode%.", "")
	local lowerToken = string.lower(token)

	if TOKEN_ALIASES[lowerToken] then
		return TOKEN_ALIASES[lowerToken]
	end

	local ok, keyCode = pcall(function()
		return Enum.KeyCode[token]
	end)
	if ok and keyCode then
		return keyCode.Name
	end

	return nil, "invalid_token:" .. tostring(token)
end

local function isModifierName(name)
	return MODIFIER_SET[name] == true
end

local function orderedModifierNames(modifierMap)
	local ordered = {}
	for _, modifierName in ipairs(MODIFIER_ORDER) do
		if modifierMap[modifierName] then
			table.insert(ordered, modifierName)
		end
	end
	return ordered
end

local function parseStep(stepString)
	local tokens = split(stepString, "+")
	if #tokens == 0 then
		return nil, "step_empty"
	end

	local modifierMap = {}
	local primary = nil

	for _, token in ipairs(tokens) do
		local resolvedToken, resolveErr = resolveToken(token)
		if not resolvedToken then
			return nil, resolveErr
		end

		if isModifierName(resolvedToken) then
			modifierMap[resolvedToken] = true
		else
			if primary ~= nil then
				return nil, "step_has_multiple_primary"
			end
			primary = resolvedToken
		end
	end

	if primary == nil then
		return nil, "step_missing_primary"
	end

	local modifiersOrdered = orderedModifierNames(modifierMap)
	local canonicalParts = {}
	for _, modifierName in ipairs(modifiersOrdered) do
		table.insert(canonicalParts, modifierName)
	end
	table.insert(canonicalParts, primary)

	return {
		primary = primary,
		modifierMap = modifierMap,
		modifiersOrdered = modifiersOrdered,
		canonical = table.concat(canonicalParts, "+")
	}
end

local function buildCanonicalFromSteps(steps)
	local parts = {}
	for _, step in ipairs(steps) do
		table.insert(parts, step.canonical)
	end
	return table.concat(parts, ">")
end

function KeybindSequence.parseCanonical(rawValue, options)
	local opts = options or {}
	local maxSteps = math.max(1, math.floor(toNumber(opts.maxSteps, DEFAULT_MAX_STEPS)))

	if rawValue == nil then
		return nil, nil, "binding_is_nil"
	end

	if typeof(rawValue) == "EnumItem" and rawValue.EnumType == Enum.KeyCode then
		rawValue = rawValue.Name
	end

	if type(rawValue) ~= "string" then
		return nil, nil, "binding_not_string"
	end

	local binding = trim(rawValue)
	if binding == "" then
		return nil, nil, "binding_empty"
	end

	local rawSteps = split(binding, ">")
	if #rawSteps == 0 then
		return nil, nil, "binding_has_no_steps"
	end
	if #rawSteps > maxSteps then
		return nil, nil, "binding_exceeds_max_steps"
	end

	local steps = {}
	for index, rawStep in ipairs(rawSteps) do
		local step, stepErr = parseStep(rawStep)
		if not step then
			return nil, nil, string.format("step_%d_%s", index, tostring(stepErr))
		end
		table.insert(steps, step)
	end

	local canonical = buildCanonicalFromSteps(steps)
	return canonical, steps, nil
end

function KeybindSequence.normalize(rawValue, options)
	local canonical, steps, parseErr = KeybindSequence.parseCanonical(rawValue, options)
	if canonical then
		return canonical, steps, nil
	end

	if type(rawValue) == "table" then
		if type(rawValue.Canonical) == "string" then
			return KeybindSequence.parseCanonical(rawValue.Canonical, options)
		end
		if type(rawValue.CurrentKeybind) == "string" then
			return KeybindSequence.parseCanonical(rawValue.CurrentKeybind, options)
		end
	end

	return nil, nil, parseErr
end

function KeybindSequence.parseUserInput(text, customParser, options)
	local opts = options or {}
	local fallbackToDefault = opts.fallbackToDefault ~= false

	if type(customParser) == "function" then
		local ok, customValueOrErr, maybeErr = pcall(customParser, text)
		if ok and customValueOrErr ~= nil then
			local canonical, steps, normalizeErr = KeybindSequence.normalize(customValueOrErr, options)
			if canonical then
				return canonical, steps, nil
			end
			if not fallbackToDefault then
				return nil, nil, normalizeErr
			end
		elseif not ok and not fallbackToDefault then
			return nil, nil, tostring(customValueOrErr)
		elseif ok and customValueOrErr == nil and not fallbackToDefault then
			return nil, nil, tostring(maybeErr or "custom_parser_returned_nil")
		end
	end

	return KeybindSequence.normalize(text, options)
end

function KeybindSequence.formatDisplay(rawValue, customFormatter, options)
	local canonical = nil
	local steps = nil
	if type(rawValue) == "table" and type(rawValue.canonical) == "string" and type(rawValue.steps) == "table" then
		canonical = rawValue.canonical
		steps = rawValue.steps
	elseif type(rawValue) == "table" and rawValue[1] and rawValue[1].canonical then
		steps = rawValue
		canonical = buildCanonicalFromSteps(steps)
	else
		canonical, steps = KeybindSequence.normalize(rawValue, options)
	end

	if not canonical or not steps then
		return ""
	end

	if type(customFormatter) == "function" then
		local ok, customText = pcall(customFormatter, canonical, steps)
		if ok and type(customText) == "string" and customText ~= "" then
			return customText
		end
	end

	local stepLabels = {}
	for _, step in ipairs(steps) do
		local tokens = {}
		for _, modifierName in ipairs(step.modifiersOrdered) do
			table.insert(tokens, DISPLAY_TOKEN_MAP[modifierName] or modifierName)
		end
		table.insert(tokens, DISPLAY_TOKEN_MAP[step.primary] or step.primary)
		table.insert(stepLabels, table.concat(tokens, " + "))
	end

	return table.concat(stepLabels, " > ")
end

function KeybindSequence.matchStep(input, stepSpec, userInputService)
	if not input or not stepSpec then
		return false
	end

	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return false
	end
	if not input.KeyCode or input.KeyCode == Enum.KeyCode.Unknown then
		return false
	end
	if input.KeyCode.Name ~= stepSpec.primary then
		return false
	end

	if not userInputService or type(userInputService.IsKeyDown) ~= "function" then
		return false
	end

	for modifierName in pairs(stepSpec.modifierMap) do
		local modifierCode = Enum.KeyCode[modifierName]
		if modifierCode and not userInputService:IsKeyDown(modifierCode) then
			return false
		end
	end

	return true
end

function KeybindSequence.captureStepFromInput(input, userInputService)
	if not input or input.UserInputType ~= Enum.UserInputType.Keyboard or not input.KeyCode or input.KeyCode == Enum.KeyCode.Unknown then
		return nil, nil, "input_not_keyboard"
	end

	local primaryName = input.KeyCode.Name
	if isModifierName(primaryName) then
		return nil, nil, "input_modifier_only"
	end

	local modifierTokens = {}
	if userInputService and type(userInputService.IsKeyDown) == "function" then
		for _, modifierName in ipairs(MODIFIER_ORDER) do
			local modifierCode = Enum.KeyCode[modifierName]
			if modifierCode and userInputService:IsKeyDown(modifierCode) then
				table.insert(modifierTokens, modifierName)
			end
		end
	end

	table.insert(modifierTokens, primaryName)
	local canonicalStep = table.concat(modifierTokens, "+")
	local stepSpec, stepErr = parseStep(canonicalStep)
	if not stepSpec then
		return nil, nil, stepErr
	end
	return stepSpec.canonical, stepSpec, nil
end

function KeybindSequence.newMatcher(options)
	local opts = options or {}
	local maxSteps = math.max(1, math.floor(toNumber(opts.maxSteps, DEFAULT_MAX_STEPS)))
	local timeoutMs = math.max(1, math.floor(toNumber(opts.stepTimeoutMs, DEFAULT_STEP_TIMEOUT_MS)))
	local timeoutSeconds = timeoutMs / 1000

	local stateIndex = 1
	local stateLastStepTime = nil
	local cachedCanonical = nil
	local cachedSteps = nil

	local function reset()
		stateIndex = 1
		stateLastStepTime = nil
	end

	local function ensureParsed(binding)
		if type(binding) == "table" and binding.canonical and binding.steps then
			return binding.canonical, binding.steps, nil
		end

		local canonical, steps, parseErr = KeybindSequence.normalize(binding, {
			maxSteps = maxSteps
		})
		if not canonical then
			return nil, nil, parseErr
		end

		return canonical, steps, nil
	end

	local function setBinding(binding)
		local canonical, steps, parseErr = ensureParsed(binding)
		if not canonical then
			return nil, nil, parseErr
		end
		cachedCanonical = canonical
		cachedSteps = steps
		reset()
		return canonical, steps, nil
	end

	local function consume(input, binding, userInputService, processed)
		if processed then
			return false, nil, nil
		end

		local canonical = cachedCanonical
		local steps = cachedSteps

		if binding ~= nil then
			local nextCanonical, nextSteps, parseErr = ensureParsed(binding)
			if not nextCanonical then
				reset()
				return false, nil, parseErr
			end
			if nextCanonical ~= cachedCanonical then
				cachedCanonical = nextCanonical
				cachedSteps = nextSteps
				reset()
			end
			canonical = cachedCanonical
			steps = cachedSteps
		end

		if not canonical or not steps or #steps == 0 then
			return false, nil, "binding_not_initialized"
		end

		local now = os.clock()
		if stateLastStepTime and (now - stateLastStepTime) > timeoutSeconds then
			reset()
		end

		local expectedStep = steps[stateIndex]
		if expectedStep and KeybindSequence.matchStep(input, expectedStep, userInputService) then
			if stateIndex >= #steps then
				reset()
				return true, expectedStep, nil
			end
			stateIndex += 1
			stateLastStepTime = now
			return false, expectedStep, nil
		end

		local firstStep = steps[1]
		if stateIndex ~= 1 and firstStep and KeybindSequence.matchStep(input, firstStep, userInputService) then
			if #steps == 1 then
				reset()
				return true, firstStep, nil
			end
			stateIndex = 2
			stateLastStepTime = now
			return false, firstStep, nil
		end

		reset()
		return false, nil, nil
	end

	return {
		reset = reset,
		setBinding = setBinding,
		consume = consume
	}
end

KeybindSequence.DEFAULT_MAX_STEPS = DEFAULT_MAX_STEPS
KeybindSequence.DEFAULT_STEP_TIMEOUT_MS = DEFAULT_STEP_TIMEOUT_MS

return KeybindSequence
