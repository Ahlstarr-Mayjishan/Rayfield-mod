local Forward = {}

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local function compileChunk(source, label)
	if type(source) ~= "string" then
		error("Invalid Lua source for " .. tostring(label) .. ": " .. type(source))
	end
	source = source:gsub("^\239\187\191", "")
	source = source:gsub("^\0+", "")
	local chunk, err = compileString(source)
	if not chunk then
		error("Failed to compile " .. tostring(label) .. ": " .. tostring(err))
	end
	return chunk
end

local function tryLoadBundle(path)
	local okFetch, source = pcall(game.HttpGet, game, root .. path)
	if not okFetch or type(source) ~= "string" or source == "" then
		return false
	end
	local okCompile, bundleOrErr = pcall(function()
		return compileChunk(source, path)()
	end)
	if not okCompile then
		warn("Rayfield Mod: failed to preload bundle " .. tostring(path) .. ": " .. tostring(bundleOrErr))
		return false
	end
	return type(bundleOrErr) == "table"
end

if type(_G) == "table" and _G.__RAYFIELD_AUTO_PRELOAD_BUNDLES == true and not _G.__RAYFIELD_BUNDLE_PRELOAD_ATTEMPTED then
	_G.__RAYFIELD_BUNDLE_PRELOAD_ATTEMPTED = true
	local coreOk = tryLoadBundle("dist/rayfield-runtime-core.bundle.lua")
	local uiOk = tryLoadBundle("dist/rayfield-runtime-ui.bundle.lua")
	_G.__RAYFIELD_BUNDLE_PRELOADED = coreOk or uiOk
end

local function fetchSource(path)
	if type(_G) == "table" and type(_G.__RAYFIELD_BUNDLE_SOURCES) == "table" then
		local bundled = _G.__RAYFIELD_BUNDLE_SOURCES[path]
		if type(bundled) == "string" and bundled ~= "" then
			return bundled
		end
	end
	return game:HttpGet(root .. path)
end

local clientSource = fetchSource("src/api/client.lua")
local client = compileChunk(clientSource, "src/api/client.lua")()
if type(client) ~= "table" or type(client.fetchAndExecute) ~= "function" then
	error("Invalid API client bootstrap: missing fetchAndExecute")
end
if type(_G) == "table" then
	_G.__RayfieldApiClient = client
end

if _G and _G.__RayfieldWidgetBootstrap == nil then
	local okBootstrap, bootstrapModule = pcall(client.fetchAndExecute, root .. "src/ui/elements/widgets/bootstrap.lua")
	if not okBootstrap then
		error("Failed to preload widget bootstrap: " .. tostring(bootstrapModule))
	end
	if type(bootstrapModule) ~= "table" or type(bootstrapModule.bootstrapWidget) ~= "function" then
		error("Invalid widget bootstrap module: missing bootstrapWidget")
	end
	_G.__RayfieldWidgetBootstrap = bootstrapModule
end

local loader = client.fetchAndExecute(root .. "src/api/loader.lua")
if type(loader) ~= "table" or type(loader.load) ~= "function" then
	error("Invalid API loader bootstrap: missing loader.load")
end

local function getScriptRef()
	local scriptRef = nil
	pcall(function()
		scriptRef = script
	end)
	return scriptRef
end

function Forward.module(moduleName)
	return loader.load(moduleName, {
		tryStudioRequire = false,
		scriptRef = getScriptRef()
	})
end

function Forward.path(path)
	return loader.loadPath(path)
end

return Forward
