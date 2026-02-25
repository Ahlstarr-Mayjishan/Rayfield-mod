local Client = {}

local DEFAULT_TIMEOUT = 8

local function getBundleTable()
	if type(_G) ~= "table" or type(_G.__RAYFIELD_BUNDLE_SOURCES) ~= "table" then
		return nil
	end
	return _G.__RAYFIELD_BUNDLE_SOURCES
end

local function getBrokenBundleMap()
	if type(_G) ~= "table" then
		return nil
	end
	if type(_G.__RAYFIELD_BUNDLE_BROKEN_PATHS) ~= "table" then
		_G.__RAYFIELD_BUNDLE_BROKEN_PATHS = {}
	end
	return _G.__RAYFIELD_BUNDLE_BROKEN_PATHS
end

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

local function resolveBundlePath(url)
	local function urlDecode(value)
		return (value:gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end))
	end

	local runtimeRoot = nil
	if type(_G) == "table" and type(_G.__RAYFIELD_RUNTIME_ROOT_URL) == "string" and _G.__RAYFIELD_RUNTIME_ROOT_URL ~= "" then
		runtimeRoot = _G.__RAYFIELD_RUNTIME_ROOT_URL
	end
	if runtimeRoot and url:sub(1, #runtimeRoot) == runtimeRoot then
		return urlDecode(url:sub(#runtimeRoot + 1))
	end

	local githubPath = url:match("^https?://raw%.githubusercontent%.com/[^/]+/[^/]+/[^/]+/(.+)$")
	if githubPath then
		return urlDecode(githubPath)
	end

	return nil
end

local function tryGetBundledSource(url, opts)
	opts = opts or {}
	if opts.noBundle then
		return nil, nil
	end

	local bundle = getBundleTable()
	if not bundle then
		return nil, nil
	end

	local path = resolveBundlePath(url)
	local broken = getBrokenBundleMap()
	if path and broken and broken[path] then
		return nil, path
	end
	if broken and broken[url] then
		return nil, path
	end

	if path then
		local byPath = bundle[path]
		if type(byPath) == "string" and #byPath > 0 then
			return byPath, path
		end
	end

	local byUrl = bundle[url]
	if type(byUrl) == "string" and #byUrl > 0 then
		return byUrl, path
	end

	return nil, path
end

local function resolveSource(url, opts)
	opts = opts or {}
	local bundledSource, bundledPath = tryGetBundledSource(url, opts)
	if bundledSource then
		return bundledSource, true, bundledPath
	end

	local ok, payload = Client.request(url, opts)
	if not ok then
		error(tostring(payload))
	end
	if type(payload) ~= "string" then
		error("Client.fetch expected string payload, got " .. type(payload))
	end
	return payload, false, bundledPath
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
	local source = resolveSource(url, opts)
	return source
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
	local chunk, compileError = compileString(code)
	if not chunk then
		error("Client.compile failed: " .. tostring(compileError))
	end
	return chunk
end

function Client.execute(code)
	return Client.compile(code)()
end

function Client.fetchAndExecute(url, opts)
	opts = opts or {}
	local code, fromBundle, bundlePath = resolveSource(url, opts)
	local okExecute, result = pcall(Client.execute, code)
	if okExecute then
		return result
	end

	if fromBundle then
		local broken = getBrokenBundleMap()
		if broken then
			if bundlePath then
				broken[bundlePath] = true
			end
			broken[url] = true
		end
		local retryOpts = {}
		for key, value in pairs(opts) do
			retryOpts[key] = value
		end
		retryOpts.noBundle = true
		local retryCode = Client.fetch(url, retryOpts)
		return Client.execute(retryCode)
	end

	error(result)
end

if _G then
	_G.__RayfieldApiClient = Client
end

return Client
