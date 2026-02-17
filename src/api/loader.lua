local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local Client = (_G and _G.__RayfieldApiClient)
if not Client then
	local compileString = loadstring or load
	if not compileString then
		error("No Lua compiler function available (loadstring/load)")
	end
	Client = compileString(game:HttpGet(root .. "src/api/client.lua"))()
	if _G then
		_G.__RayfieldApiClient = Client
	end
end

local function loadApiModule(relativePath)
	return Client.fetchAndExecute(root .. relativePath)
end

local Cache = loadApiModule("src/api/cache.lua")
local Resolver = loadApiModule("src/api/resolver.lua")
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

	error(Errors.moduleLoadError(moduleName, attempts))
end

function Loader.loadPath(path)
	return loadByPath(path)
end

function Loader.clearCache()
	Cache.clear()
end

return Loader
