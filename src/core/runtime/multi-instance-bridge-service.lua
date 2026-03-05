local MultiInstanceBridgeService = {}

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

local function nowClock()
	return os.clock()
end

local function nowStamp()
	if type(os.date) == "function" then
		return os.date("!%Y-%m-%dT%H:%M:%SZ")
	end
	return tostring(nowClock())
end

local function normalizeMode(mode)
	local normalized = string.lower(tostring(mode or "auto"))
	if normalized ~= "auto" and normalized ~= "file" and normalized ~= "http" and normalized ~= "none" then
		return "auto"
	end
	return normalized
end

local function readJson(HttpService, text)
	if type(HttpService) ~= "table" or type(HttpService.JSONDecode) ~= "function" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, tostring(text or ""))
	if not ok then
		return nil
	end
	return decoded
end

local function writeJson(HttpService, value)
	if type(HttpService) ~= "table" or type(HttpService.JSONEncode) ~= "function" then
		return nil
	end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, value)
	if not ok then
		return nil
	end
	return encoded
end

local function ensureFolderPath(path, makefolderFn, isfolderFn)
	if type(path) ~= "string" or path == "" then
		return true
	end
	if type(makefolderFn) ~= "function" then
		return false
	end
	local normalized = path:gsub("\\", "/")
	local current = ""
	for part in normalized:gmatch("[^/]+") do
		current = current == "" and part or (current .. "/" .. part)
		local exists = false
		if type(isfolderFn) == "function" then
			local okExists, result = pcall(isfolderFn, current)
			exists = okExists and result == true
		end
		if not exists then
			local okMake = pcall(makefolderFn, current)
			if not okMake then
				return false
			end
		end
	end
	return true
end

local function inferRequestFunction()
	return (syn and syn.request)
		or (fluxus and fluxus.request)
		or (http and http.request)
		or http_request
		or request
end

function MultiInstanceBridgeService.create(ctx)
	ctx = ctx or {}
	local cloneValue = type(ctx.cloneValue) == "function" and ctx.cloneValue or defaultClone
	local HttpService = ctx.HttpService
	local notify = type(ctx.notify) == "function" and ctx.notify or nil
	local onMessage = type(ctx.onMessage) == "function" and ctx.onMessage or nil
	local globalEnv = type(_G) == "table" and _G or nil

	local mode = normalizeMode((globalEnv and globalEnv.__RAYFIELD_MULTI_BRIDGE_MODE) or ctx.mode or "auto")
	local channel = tostring((globalEnv and globalEnv.__RAYFIELD_MULTI_BRIDGE_CHANNEL) or ctx.channel or "default")
	if channel == "" then
		channel = "default"
	end
	local endpoint = tostring((globalEnv and globalEnv.__RAYFIELD_MULTI_BRIDGE_ENDPOINT) or ctx.endpoint or "")
	local filePath = tostring((globalEnv and globalEnv.__RAYFIELD_MULTI_BRIDGE_FILE_PATH) or ctx.filePath or ("Rayfield/Bridge/" .. channel .. ".jsonl"))
	local pollIntervalSec = tonumber((globalEnv and globalEnv.__RAYFIELD_MULTI_BRIDGE_POLL_SEC) or ctx.pollIntervalSec or 1) or 1
	pollIntervalSec = math.max(0.2, pollIntervalSec)
	local historyLimit = tonumber((globalEnv and globalEnv.__RAYFIELD_MULTI_BRIDGE_HISTORY_LIMIT) or ctx.historyLimit or 120) or 120
	historyLimit = math.max(20, math.floor(historyLimit))
	local requestFn = type(ctx.requestFn) == "function" and ctx.requestFn or inferRequestFunction()

	local instanceId = tostring((globalEnv and globalEnv.__RAYFIELD_INSTANCE_ID) or (ctx.instanceId or ""))
	if instanceId == "" then
		local generated = nil
		if type(HttpService) == "table" and type(HttpService.GenerateGUID) == "function" then
			local okGuid, guid = pcall(HttpService.GenerateGUID, HttpService, false)
			if okGuid and type(guid) == "string" and guid ~= "" then
				generated = guid
			end
		end
		instanceId = generated or ("instance-" .. tostring(math.floor(nowClock() * 100000)))
	end

	local appendfileFn = type(appendfile) == "function" and appendfile or nil
	local readfileFn = type(readfile) == "function" and readfile or nil
	local writefileFn = type(writefile) == "function" and writefile or nil
	local isfileFn = type(isfile) == "function" and isfile or nil
	local makefolderFn = type(makefolder) == "function" and makefolder or nil
	local isfolderFn = type(isfolder) == "function" and isfolder or nil

	local messageHistory = {}
	local seen = {}
	local polling = false
	local pollToken = 0

	local function pushHistory(message)
		table.insert(messageHistory, message)
		while #messageHistory > historyLimit do
			table.remove(messageHistory, 1)
		end
	end

	local function hasFileBridge()
		return type(readfileFn) == "function" and (type(appendfileFn) == "function" or type(writefileFn) == "function")
	end

	local function buildMessageId()
		local suffix = tostring(math.floor(nowClock() * 1000000))
		return string.format("%s:%s", instanceId, suffix)
	end

	local function ensureFileFolder()
		if type(filePath) ~= "string" or filePath == "" then
			return false
		end
		local folder = string.match(filePath, "^(.*)[/\\][^/\\]+$")
		if not folder then
			return true
		end
		return ensureFolderPath(folder, makefolderFn, isfolderFn)
	end

	local function appendFileLine(line)
		if type(line) ~= "string" or line == "" then
			return false, "Bridge payload is empty."
		end
		if not ensureFileFolder() then
			return false, "Bridge folder unavailable."
		end
		if appendfileFn then
			local okAppend = pcall(appendfileFn, filePath, line .. "\n")
			if okAppend then
				return true, "ok"
			end
		end
		if writefileFn and readfileFn then
			local existing = ""
			if not isfileFn or pcall(isfileFn, filePath) then
				local okRead, readResult = pcall(readfileFn, filePath)
				if okRead and type(readResult) == "string" then
					existing = readResult
				end
			end
			local okWrite = pcall(writefileFn, filePath, existing .. line .. "\n")
			if okWrite then
				return true, "ok"
			end
		end
		return false, "Bridge file write failed."
	end

	local function sendViaHttp(envelope)
		if endpoint == "" then
			return false, "Bridge endpoint unavailable."
		end
		local encoded = writeJson(HttpService, envelope)
		if not encoded then
			return false, "Bridge JSON encoder unavailable."
		end

		if type(requestFn) == "function" then
			local okRequest, response = pcall(requestFn, {
				Url = endpoint,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json"
				},
				Body = encoded
			})
			if not okRequest then
				return false, tostring(response)
			end
			if type(response) == "table" then
				local statusCode = tonumber(response.StatusCode) or 0
				if statusCode >= 200 and statusCode < 300 then
					return true, "ok"
				end
				return false, "HTTP status " .. tostring(statusCode)
			end
			return true, "ok"
		end

		if type(HttpService) == "table" and type(HttpService.PostAsync) == "function" then
			local okPost, postErr = pcall(HttpService.PostAsync, HttpService, endpoint, encoded, Enum.HttpContentType.ApplicationJson, false)
			if okPost then
				return true, "ok"
			end
			return false, tostring(postErr)
		end

		return false, "HTTP request bridge unavailable."
	end

	local function normalizeEnvelope(rawMessage)
		if type(rawMessage) ~= "table" then
			return nil
		end
		local envelope = cloneValue(rawMessage)
		envelope.id = tostring(envelope.id or "")
		if envelope.id == "" then
			return nil
		end
		envelope.kind = tostring(envelope.kind or "signal")
		envelope.channel = tostring(envelope.channel or "")
		envelope.from = tostring(envelope.from or "")
		envelope.to = tostring(envelope.to or "all")
		envelope.at = tostring(envelope.at or nowStamp())
		envelope.payload = type(envelope.payload) == "table" and envelope.payload or {}
		return envelope
	end

	local function acceptIncoming(envelope)
		if type(envelope) ~= "table" then
			return false
		end
		if envelope.channel ~= channel then
			return false
		end
		if envelope.from == instanceId then
			return false
		end
		if envelope.to ~= "all" and envelope.to ~= instanceId then
			return false
		end
		local seenId = tostring(envelope.id or "")
		if seenId == "" or seen[seenId] == true then
			return false
		end
		seen[seenId] = true
		pushHistory(envelope)
		if type(onMessage) == "function" then
			pcall(onMessage, cloneValue(envelope))
		end
		return true
	end

	local function readFileMessages()
		if not hasFileBridge() then
			return {}
		end
		local okRead, content = pcall(readfileFn, filePath)
		if not okRead or type(content) ~= "string" or content == "" then
			return {}
		end
		local out = {}
		for line in content:gmatch("[^\r\n]+") do
			local decoded = readJson(HttpService, line)
			local envelope = normalizeEnvelope(decoded)
			if envelope then
				table.insert(out, envelope)
			end
		end
		return out
	end

	local function fetchHttpMessages(limit)
		if endpoint == "" then
			return {}
		end
		local queryUrl = string.format("%s?channel=%s&limit=%d", endpoint, channel, tonumber(limit) or 50)
		local responseBody = nil

		if type(requestFn) == "function" then
			local okRequest, response = pcall(requestFn, {
				Url = queryUrl,
				Method = "GET"
			})
			if okRequest and type(response) == "table" then
				responseBody = response.Body or response.body or response.ResponseBody
			end
		elseif type(HttpService) == "table" and type(HttpService.GetAsync) == "function" then
			local okGet, result = pcall(HttpService.GetAsync, HttpService, queryUrl, false)
			if okGet then
				responseBody = result
			end
		end

		if type(responseBody) ~= "string" or responseBody == "" then
			return {}
		end

		local decoded = readJson(HttpService, responseBody)
		if type(decoded) ~= "table" then
			return {}
		end

		local payloadList = decoded
		if type(decoded.messages) == "table" then
			payloadList = decoded.messages
		end
		if type(payloadList) ~= "table" then
			return {}
		end

		local out = {}
		for _, raw in ipairs(payloadList) do
			local envelope = normalizeEnvelope(raw)
			if envelope then
				table.insert(out, envelope)
			end
		end
		return out
	end

	local function modeForOperation(overrideMode)
		local target = normalizeMode(overrideMode or mode)
		if target ~= "auto" then
			return target
		end
		if hasFileBridge() or endpoint ~= "" then
			return "auto"
		end
		return "none"
	end

	local function publish(kind, payload, options)
		options = type(options) == "table" and options or {}
		local resolvedMode = modeForOperation(options.mode)
		if resolvedMode == "none" then
			return false, "Bridge mode is disabled.", nil
		end

		local envelope = {
			id = buildMessageId(),
			kind = tostring(kind or "signal"),
			channel = channel,
			from = instanceId,
			to = tostring(options.target or "all"),
			at = nowStamp(),
			payload = type(payload) == "table" and cloneValue(payload) or {
				value = payload
			}
		}

		local okSend, sendMsg = false, "Unknown bridge mode."
		if resolvedMode == "file" then
			local encoded = writeJson(HttpService, envelope)
			if not encoded then
				return false, "Bridge JSON encoder unavailable.", nil
			end
			okSend, sendMsg = appendFileLine(encoded)
		elseif resolvedMode == "http" then
			okSend, sendMsg = sendViaHttp(envelope)
		elseif resolvedMode == "auto" then
			local encoded = writeJson(HttpService, envelope)
			if encoded and hasFileBridge() then
				okSend, sendMsg = appendFileLine(encoded)
				if okSend then
					seen[envelope.id] = true
					pushHistory(cloneValue(envelope))
					return true, "Bridge message sent (file).", envelope
				end
			end
			okSend, sendMsg = sendViaHttp(envelope)
		end

		if okSend then
			seen[envelope.id] = true
			pushHistory(cloneValue(envelope))
			return true, "Bridge message sent (" .. resolvedMode .. ").", envelope
		end
		return false, tostring(sendMsg or "Bridge send failed."), envelope
	end

	local function poll(limit, options)
		options = type(options) == "table" and options or {}
		local resolvedMode = modeForOperation(options.mode)
		if resolvedMode == "none" then
			return false, "Bridge mode is disabled.", {}
		end
		local newMessages = {}

		local function ingest(messages)
			for _, message in ipairs(type(messages) == "table" and messages or {}) do
				if acceptIncoming(message) then
					table.insert(newMessages, cloneValue(message))
				end
			end
		end

		if resolvedMode == "file" then
			ingest(readFileMessages())
		elseif resolvedMode == "http" then
			ingest(fetchHttpMessages(limit))
		else
			ingest(readFileMessages())
			ingest(fetchHttpMessages(limit))
		end

		return true, "Bridge poll completed.", newMessages
	end

	local function startPolling()
		if polling then
			return true, "Bridge polling already active."
		end
		polling = true
		pollToken += 1
		local token = pollToken
		task.spawn(function()
			while polling and token == pollToken do
				local okPoll, pollMsg = poll(120, {})
				if not okPoll and notify then
					notify({
						Title = "Bridge Poll",
						Content = tostring(pollMsg),
						Duration = 3
					})
				end
				task.wait(pollIntervalSec)
			end
		end)
		return true, "Bridge polling started."
	end

	local function stopPolling()
		if not polling then
			return true, "Bridge polling already stopped."
		end
		polling = false
		pollToken += 1
		return true, "Bridge polling stopped."
	end

	local function listMessages(limit, kind)
		local targetKind = tostring(kind or "")
		local maxCount = tonumber(limit) or #messageHistory
		maxCount = math.max(1, math.floor(maxCount))
		local out = {}
		for index = #messageHistory, 1, -1 do
			local item = messageHistory[index]
			if targetKind == "" or tostring(item.kind) == targetKind then
				table.insert(out, cloneValue(item))
				if #out >= maxCount then
					break
				end
			end
		end
		return out
	end

	local function setMessageHandler(handler)
		if type(handler) ~= "function" then
			onMessage = nil
			return true, "Bridge message handler cleared."
		end
		onMessage = handler
		return true, "Bridge message handler updated."
	end

	local service = {
		sendSignal = function(command, payload, options)
			local safeCommand = tostring(command or "")
			if safeCommand == "" then
				return false, "Signal command is required."
			end
			return publish("signal", {
				command = safeCommand,
				data = cloneValue(payload),
				source = "rayfield"
			}, options)
		end,
		sendChat = function(text, options)
			local messageText = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if messageText == "" then
				return false, "Chat message is empty."
			end
			return publish("chat", {
				text = messageText,
				source = "rayfield"
			}, options)
		end,
		poll = poll,
		startPolling = startPolling,
		stopPolling = stopPolling,
		isPolling = function()
			return polling == true
		end,
		listMessages = listMessages,
		clearHistory = function()
			table.clear(messageHistory)
			return true, "Bridge history cleared."
		end,
		setMessageHandler = setMessageHandler,
		getStatus = function()
			return {
				mode = mode,
				channel = channel,
				instanceId = instanceId,
				filePath = filePath,
				endpoint = endpoint,
				polling = polling == true,
				pollIntervalSec = pollIntervalSec
			}
		end
	}

	if globalEnv then
		globalEnv.__RAYFIELD_MULTI_BRIDGE = service
	end

	return service
end

return MultiInstanceBridgeService
