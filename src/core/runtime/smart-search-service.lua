local SmartSearchService = {}

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

local COLOR_MAP = {
	red = Color3.fromRGB(255, 80, 80),
	green = Color3.fromRGB(90, 220, 130),
	blue = Color3.fromRGB(80, 140, 255),
	yellow = Color3.fromRGB(255, 220, 90),
	orange = Color3.fromRGB(255, 150, 80),
	purple = Color3.fromRGB(190, 110, 255),
	white = Color3.fromRGB(255, 255, 255),
	black = Color3.fromRGB(32, 32, 32),
	cyan = Color3.fromRGB(80, 220, 255),
	pink = Color3.fromRGB(255, 120, 190)
}

local function parseHexColor(text)
	local raw = tostring(text or ""):gsub("^#", "")
	if #raw ~= 6 then
		return nil
	end
	local r = tonumber(raw:sub(1, 2), 16)
	local g = tonumber(raw:sub(3, 4), 16)
	local b = tonumber(raw:sub(5, 6), 16)
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(r, g, b)
end

local function normalizeSearchText(value)
	return string.lower(tostring(value or ""))
end

local function splitWords(text)
	local words = {}
	for token in tostring(text or ""):gmatch("[^%s]+") do
		table.insert(words, token)
	end
	return words
end

local function inferRequestFunction()
	return (syn and syn.request)
		or (fluxus and fluxus.request)
		or (http and http.request)
		or http_request
		or request
end

function SmartSearchService.create(ctx)
	ctx = ctx or {}
	local cloneValue = type(ctx.cloneValue) == "function" and ctx.cloneValue or defaultClone
	local HttpService = type(ctx.HttpService) == "table" and ctx.HttpService or nil
	local notify = type(ctx.notify) == "function" and ctx.notify or nil
	local applyThemeColor = type(ctx.applyThemeColor) == "function" and ctx.applyThemeColor or nil
	local toggleVisibility = type(ctx.toggleVisibility) == "function" and ctx.toggleVisibility or nil
	local openSettings = type(ctx.openSettings) == "function" and ctx.openSettings or nil
	local openFavorites = type(ctx.openFavorites) == "function" and ctx.openFavorites or nil
	local openActionCenter = type(ctx.openActionCenter) == "function" and ctx.openActionCenter or nil
	local sendGlobalSignal = type(ctx.sendGlobalSignal) == "function" and ctx.sendGlobalSignal or nil
	local sendInternalChat = type(ctx.sendInternalChat) == "function" and ctx.sendInternalChat or nil
	local scheduleMacro = type(ctx.scheduleMacro) == "function" and ctx.scheduleMacro or nil
	local registerDiscoveryProviderFn = type(ctx.registerDiscoveryProvider) == "function" and ctx.registerDiscoveryProvider or nil
	local askHandler = type(ctx.askAssistant) == "function" and ctx.askAssistant or nil
	local requestFn = type(ctx.requestFn) == "function" and ctx.requestFn or inferRequestFunction()

	local providers = {}
	local providerOrder = {}
	local aiHistory = {}

	local function addAiHistory(prompt, answer, ok)
		table.insert(aiHistory, {
			prompt = tostring(prompt or ""),
			answer = tostring(answer or ""),
			ok = ok == true,
			at = type(os.date) == "function" and os.date("%Y-%m-%d %H:%M:%S") or tostring(os.clock())
		})
		while #aiHistory > 30 do
			table.remove(aiHistory, 1)
		end
	end

	local function registerProvider(id, provider)
		local safeId = tostring(id or "")
		if safeId == "" then
			return false, "Provider id is required."
		end
		if type(provider) ~= "function" then
			return false, "Provider must be a function."
		end
		local isNew = providers[safeId] == nil
		providers[safeId] = provider
		if isNew then
			table.insert(providerOrder, safeId)
		end
		return true, "Provider registered."
	end

	local function unregisterProvider(id)
		local safeId = tostring(id or "")
		if safeId == "" or providers[safeId] == nil then
			return false, "Provider not found."
		end
		providers[safeId] = nil
		for index = #providerOrder, 1, -1 do
			if providerOrder[index] == safeId then
				table.remove(providerOrder, index)
			end
		end
		return true, "Provider unregistered."
	end

	local function queryDiscovery(query)
		local queryText = tostring(query or "")
		local queryLower = normalizeSearchText(queryText)
		if queryLower == "" then
			return {}
		end
		local out = {}
		for _, providerId in ipairs(providerOrder) do
			local provider = providers[providerId]
			if type(provider) == "function" then
				local okProvider, itemsOrErr = pcall(provider, queryText, queryLower)
				if okProvider and type(itemsOrErr) == "table" then
					for _, item in ipairs(itemsOrErr) do
						if type(item) == "table" then
							local entry = cloneValue(item)
							entry.id = tostring(entry.id or (providerId .. ":" .. tostring(entry.name or "item")))
							entry.action = "discovery_item"
							entry.type = tostring(entry.type or "discovery")
							entry.providerId = providerId
							entry.searchText = tostring(entry.searchText or (entry.name or entry.id))
							entry.matchScore = tonumber(entry.matchScore) or 620
							table.insert(out, entry)
						end
					end
				end
			end
		end
		return out
	end

	local function askAssistant(prompt, options)
		local question = tostring(prompt or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if question == "" then
			return false, "Prompt is empty."
		end
		options = type(options) == "table" and options or {}

		local handler = askHandler
		if type(handler) ~= "function" and type(_G) == "table" and type(_G.__RAYFIELD_AI_BRIDGE_ASK) == "function" then
			handler = _G.__RAYFIELD_AI_BRIDGE_ASK
		end
		if type(handler) ~= "function" then
			local globalEnv = type(_G) == "table" and _G or nil
			local endpoint = tostring(options.endpoint or (globalEnv and globalEnv.__RAYFIELD_AI_BRIDGE_ENDPOINT) or "")
			local method = tostring(options.method or (globalEnv and globalEnv.__RAYFIELD_AI_BRIDGE_METHOD) or "POST")
			method = string.upper(method)
			if endpoint == "" then
				return false, "AI bridge handler unavailable."
			end
			if type(requestFn) ~= "function" then
				return false, "AI bridge request function unavailable."
			end
			if not HttpService or type(HttpService.JSONEncode) ~= "function" then
				return false, "AI bridge JSON encoder unavailable."
			end

			local headers = {
				["Content-Type"] = "application/json"
			}
			if type(globalEnv and globalEnv.__RAYFIELD_AI_BRIDGE_HEADERS) == "table" then
				for key, value in pairs(globalEnv.__RAYFIELD_AI_BRIDGE_HEADERS) do
					headers[tostring(key)] = tostring(value)
				end
			end
			if type(options.headers) == "table" then
				for key, value in pairs(options.headers) do
					headers[tostring(key)] = tostring(value)
				end
			end

			local payload = {
				prompt = question,
				question = question,
				model = tostring(options.model or (globalEnv and globalEnv.__RAYFIELD_AI_BRIDGE_MODEL) or ""),
				context = cloneValue(options.context),
				source = "rayfield"
			}
			local okEncode, encodedBody = pcall(HttpService.JSONEncode, HttpService, payload)
			if not okEncode then
				return false, "AI bridge JSON encode failed: " .. tostring(encodedBody)
			end

			local okRequest, responseOrErr = pcall(requestFn, {
				Url = endpoint,
				Method = method,
				Headers = headers,
				Body = encodedBody
			})
			if not okRequest then
				addAiHistory(question, tostring(responseOrErr), false)
				return false, tostring(responseOrErr)
			end
			local response = type(responseOrErr) == "table" and responseOrErr or {}
			local statusCode = tonumber(response.StatusCode or response.statusCode or response.Status or 0) or 0
			local body = ""
			if type(responseOrErr) == "string" then
				body = responseOrErr
			else
				body = tostring(response.Body or response.body or response.ResponseBody or response.response or "")
			end
			if statusCode > 0 and (statusCode < 200 or statusCode >= 300) then
				addAiHistory(question, body ~= "" and body or ("HTTP " .. tostring(statusCode)), false)
				return false, body ~= "" and body or ("HTTP " .. tostring(statusCode))
			end

			local answer = body
			if body ~= "" and type(HttpService.JSONDecode) == "function" then
				local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, body)
				if okDecode and type(decoded) == "table" then
					answer = tostring(decoded.answer or decoded.response or decoded.text or decoded.message or body)
				end
			end
			if answer == "" then
				answer = "No response."
			end
			addAiHistory(question, answer, true)
			return true, answer
		end

		local okAsk, answerOrErr = pcall(handler, question, cloneValue(options))
		if not okAsk then
			addAiHistory(question, tostring(answerOrErr), false)
			return false, tostring(answerOrErr)
		end

		local answer = answerOrErr
		if type(answer) == "table" then
			answer = answer.answer or answer.response or answer.text or ""
		end
		answer = tostring(answer or "")
		if answer == "" then
			answer = "No response."
		end
		addAiHistory(question, answer, true)
		return true, answer
	end

	local function parsePromptCommand(rawText)
		local text = tostring(rawText or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then
			return nil
		end

		local lowered = normalizeSearchText(text)
		local words = splitWords(lowered)
		if #words == 0 then
			return nil
		end

		local lead = words[1]
		local isSlash = string.sub(lead, 1, 1) == "/"
		if isSlash then
			lead = string.sub(lead, 2)
		end

		if lead == "ask" then
			local question = text:gsub("^%s*/?ask%s*", "")
			return {
				id = "prompt:ask",
				action = "prompt_command",
				type = "prompt",
				name = "Ask Assistant",
				searchText = text,
				matchScore = 1100,
				prompt = "ask",
				payload = {
					question = question
				}
			}
		end

		if lead == "set" and words[2] == "color" then
			local colorToken = splitWords(text:gsub("^%s*/?set%s+color%s*", ""))[1]
			if colorToken and colorToken ~= "" then
				return {
					id = "prompt:set_color",
					action = "prompt_command",
					type = "prompt",
					name = "Set Accent Color",
					searchText = text,
					matchScore = 1050,
					prompt = "set_color",
					payload = {
						color = colorToken
					}
				}
			end
		end

		if lead == "toggle" and words[2] == "ui" then
			return {
				id = "prompt:toggle_ui",
				action = "prompt_command",
				type = "prompt",
				name = "Toggle Interface",
				searchText = text,
				matchScore = 1020,
				prompt = "toggle_ui",
				payload = {}
			}
		end

		if lead == "open" then
			local target = words[2]
			if target == "settings" then
				return {
					id = "prompt:open_settings",
					action = "prompt_command",
					type = "prompt",
					name = "Open Settings",
					searchText = text,
					matchScore = 1020,
					prompt = "open_settings",
					payload = {}
				}
			elseif target == "favorites" then
				return {
					id = "prompt:open_favorites",
					action = "prompt_command",
					type = "prompt",
					name = "Open Favorites",
					searchText = text,
					matchScore = 1020,
					prompt = "open_favorites",
					payload = {}
				}
			elseif target == "actioncenter" or target == "action-center" then
				return {
					id = "prompt:open_action_center",
					action = "prompt_command",
					type = "prompt",
					name = "Open Action Center",
					searchText = text,
					matchScore = 1020,
					prompt = "open_action_center",
					payload = {}
				}
			end
		end

		if lead == "signal" and words[2] then
			local command = tostring(words[2] or "")
			local payloadText = text:gsub("^%s*/?signal%s+[^%s]+%s*", "")
			return {
				id = "prompt:signal",
				action = "prompt_command",
				type = "prompt",
				name = "Send Global Signal",
				searchText = text,
				matchScore = 1030,
				prompt = "signal",
				payload = {
					command = command,
					text = payloadText
				}
			}
		end

		if lead == "chat" then
			local chatText = text:gsub("^%s*/?chat%s*", "")
			if chatText ~= "" then
				return {
					id = "prompt:chat",
					action = "prompt_command",
					type = "prompt",
					name = "Send Internal Chat",
					searchText = text,
					matchScore = 1030,
					prompt = "chat",
					payload = {
						text = chatText
					}
				}
			end
		end

		if lead == "schedule" and words[2] == "macro" and words[3] then
			local macroName = tostring(words[3] or "")
			local delaySec = tonumber(words[4]) or 5
			delaySec = math.max(0, delaySec)
			return {
				id = "prompt:schedule_macro",
				action = "prompt_command",
				type = "prompt",
				name = "Schedule Macro",
				searchText = text,
				matchScore = 1035,
				prompt = "schedule_macro",
				payload = {
					macro = macroName,
					delay = delaySec
				}
			}
		end

		return nil
	end

	local function executePromptCommand(rawText, parsedCommand)
		local parsed = parsedCommand or parsePromptCommand(rawText)
		if type(parsed) ~= "table" then
			return false, "Unsupported prompt command."
		end

		if parsed.prompt == "set_color" then
			if type(applyThemeColor) ~= "function" then
				return false, "Theme color handler unavailable."
			end
			local colorToken = tostring(parsed.payload and parsed.payload.color or "")
			local color = COLOR_MAP[normalizeSearchText(colorToken)] or parseHexColor(colorToken)
			if typeof(color) ~= "Color3" then
				return false, "Unknown color. Use a named color or #RRGGBB."
			end
			return applyThemeColor(color)
		elseif parsed.prompt == "toggle_ui" then
			if type(toggleVisibility) ~= "function" then
				return false, "Visibility handler unavailable."
			end
			return toggleVisibility()
		elseif parsed.prompt == "open_settings" then
			if type(openSettings) ~= "function" then
				return false, "Settings handler unavailable."
			end
			return openSettings()
		elseif parsed.prompt == "open_favorites" then
			if type(openFavorites) ~= "function" then
				return false, "Favorites handler unavailable."
			end
			return openFavorites()
		elseif parsed.prompt == "open_action_center" then
			if type(openActionCenter) ~= "function" then
				return false, "Action Center handler unavailable."
			end
			return openActionCenter()
		elseif parsed.prompt == "ask" then
			local question = tostring(parsed.payload and parsed.payload.question or "")
			local okAsk, answer = askAssistant(question, {})
			if notify then
				notify({
					Title = okAsk and "Assistant" or "Assistant Error",
					Content = tostring(answer),
					Duration = okAsk and 8 or 4
				})
			end
			return okAsk, answer
		elseif parsed.prompt == "signal" then
			if type(sendGlobalSignal) ~= "function" then
				return false, "Global signal handler unavailable."
			end
			local command = tostring(parsed.payload and parsed.payload.command or "")
			local payloadText = tostring(parsed.payload and parsed.payload.text or "")
			return sendGlobalSignal(command, {
				text = payloadText,
				source = "prompt"
			})
		elseif parsed.prompt == "chat" then
			if type(sendInternalChat) ~= "function" then
				return false, "Internal chat handler unavailable."
			end
			local text = tostring(parsed.payload and parsed.payload.text or "")
			return sendInternalChat(text, {
				source = "prompt"
			})
		elseif parsed.prompt == "schedule_macro" then
			if type(scheduleMacro) ~= "function" then
				return false, "Automation scheduler unavailable."
			end
			local macroName = tostring(parsed.payload and parsed.payload.macro or "")
			local delay = tonumber(parsed.payload and parsed.payload.delay) or 5
			return scheduleMacro(macroName, delay, {
				respectDelay = false
			})
		end

		return false, "Unsupported prompt command."
	end

	if type(registerDiscoveryProviderFn) == "function" then
		local okDefault, providerMap = pcall(registerDiscoveryProviderFn)
		if okDefault and type(providerMap) == "table" then
			for providerId, provider in pairs(providerMap) do
				if type(provider) == "function" then
					registerProvider(providerId, provider)
				end
			end
		end
	end

	local service = {
		registerProvider = registerProvider,
		unregisterProvider = unregisterProvider,
		queryDiscovery = queryDiscovery,
		parsePromptCommand = parsePromptCommand,
		executePromptCommand = executePromptCommand,
		askAssistant = askAssistant,
		getAiHistory = function()
			return cloneValue(aiHistory)
		end
	}

	if type(_G) == "table" then
		_G.__RAYFIELD_SMART_SEARCH = service
	end

	return service
end

return SmartSearchService
