local DEFAULT_ROOT = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local function normalizeRootUrl(rootUrl)
	if type(rootUrl) ~= "string" or rootUrl == "" then
		return DEFAULT_ROOT
	end
	if rootUrl:sub(-1) ~= "/" then
		return rootUrl .. "/"
	end
	return rootUrl
end

local function compileChunk(source, label)
	local compileString = loadstring or load
	if not compileString then
		error("No Lua compiler function available (loadstring/load)")
	end
	if type(source) == "string" then
		source = source:gsub("^\239\187\191", "")
		source = source:gsub("^\0+", "")
	end
	local chunk, err = compileString(source)
	if not chunk then
		error("Failed to compile " .. tostring(label or "chunk") .. ": " .. tostring(err))
	end
	return chunk
end

local function fetchAndCompile(url, label)
	local source = game:HttpGet(url)
	return compileChunk(source, label or url)()
end

local bootstrapRoot = normalizeRootUrl((_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or DEFAULT_ROOT)
local Resolver = fetchAndCompile(bootstrapRoot .. "src/api/resolver.lua", "src/api/resolver.lua")
local resolveRoot = (Resolver and Resolver.normalizeRuntimeRoot) or normalizeRootUrl
local root = resolveRoot((Resolver and Resolver.getRuntimeRoot and Resolver.getRuntimeRoot()) or bootstrapRoot)

if type(_G) == "table" and type(_G.__RAYFIELD_BUNDLE_SOURCES) == "table" then
	_G.__RAYFIELD_BUNDLE_MODE = _G.__RAYFIELD_BUNDLE_MODE or "bundle_first"
end

local Client = (_G and _G.__RayfieldApiClient)
if not Client then
	Client = fetchAndCompile(root .. "src/api/client.lua", "src/api/client.lua")
	if _G then
		_G.__RayfieldApiClient = Client
	end
end

local function loadApiModule(relativePath)
	return Client.fetchAndExecute(root .. relativePath)
end

local Cache = loadApiModule("src/api/cache.lua")
local Registry = loadApiModule("src/api/registry.lua")
local Errors = loadApiModule("src/api/errors.lua")

local Loader = {}

local function cacheKey(path)
	return tostring(path)
end

local function loadByPath(path)
	local key = cacheKey(path)
	local cached = Cache.get(key)
	if cached ~= nil then
		return cached
	end
	local value = Client.fetchAndExecute(root .. path)
	Cache.set(key, value)
	return value
end

function Loader.load(moduleName, opts)
	opts = opts or {}
	local mapping = Registry[moduleName]
	if not mapping then
		error("Unknown module in registry: " .. tostring(moduleName))
	end

	local attempts = {}

	if opts.tryStudioRequire and Resolver.isStudio() and opts.scriptRef and mapping.studio then
		local required = Resolver.tryRequire(opts.scriptRef, mapping.studio)
		if required ~= nil then
			return required
		end
		table.insert(attempts, "studio require(" .. tostring(mapping.studio) .. ") failed")
	end

	local canonicalPath = mapping.canonical
	local ok, result = pcall(loadByPath, canonicalPath)
	if ok then
		return result
	end
	table.insert(attempts, tostring(canonicalPath) .. ": " .. tostring(result))

	local legacyPath = mapping.legacy
	if opts.allowLegacyFallback ~= false and type(legacyPath) == "string" and legacyPath ~= "" and legacyPath ~= canonicalPath then
		local legacyOk, legacyResult = pcall(loadByPath, legacyPath)
		if legacyOk then
			return legacyResult
		end
		table.insert(attempts, tostring(legacyPath) .. ": " .. tostring(legacyResult))
	end

	error(Errors.moduleLoadError(moduleName, attempts))
end

function Loader.tryLoad(moduleName, opts)
	local ok, result = pcall(Loader.load, moduleName, opts)
	if ok then
		return true, result
	end
	return false, tostring(result)
end

function Loader.loadPath(path)
	return loadByPath(path)
end

function Loader.clearCache()
	Cache.clear()
end

return Loader
