local Client = {}

local DEFAULT_TIMEOUT = 8

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

function Client.request(url, opts)
	url = normalizeUrl(url)
	opts = opts or {}
	local timeout = tonumber(opts.timeout) or DEFAULT_TIMEOUT
	local completed = false
	local okResult = false
	local payload = nil

	local worker = task.spawn(function()
		local ok, result = pcall(game.HttpGet, game, url)
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
		pcall(task.cancel, worker)
	end)

	while not completed do
		task.wait()
	end

	pcall(task.cancel, timeoutThread)
	return okResult, payload
end

function Client.fetch(url, opts)
	local ok, payload = Client.request(url, opts)
	if not ok then
		error(tostring(payload))
	end
	if type(payload) ~= "string" then
		error("Client.fetch expected string payload, got " .. type(payload))
	end
	return payload
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
	return compileString(code)
end

function Client.execute(code)
	return Client.compile(code)()
end

function Client.fetchAndExecute(url, opts)
	local code = Client.fetch(url, opts)
	return Client.execute(code)
end

if _G then
	_G.__RayfieldApiClient = Client
end

return Client
