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

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local function tryLoadBundle(path)
	local okFetch, source = pcall(game.HttpGet, game, root .. path)
	if not okFetch or type(source) ~= "string" or source == "" then
		return false
	end
	local okCompile, bundleOrErr = pcall(function()
		return compileChunk(source, path)()
	end)
	if not okCompile then
		warn("Rayfield Mod: bundle preload failed (" .. tostring(path) .. "): " .. tostring(bundleOrErr))
		return false
	end
	return type(bundleOrErr) == "table"
end

local function preloadBundlesIfEnabled()
	if type(_G) ~= "table" then
		return
	end
	if _G.__RAYFIELD_AUTO_PRELOAD_BUNDLES ~= true then
		return
	end
	if _G.__RAYFIELD_BUNDLE_PRELOAD_ATTEMPTED then
		return
	end
	_G.__RAYFIELD_BUNDLE_PRELOAD_ATTEMPTED = true
	local coreOk = tryLoadBundle("dist/rayfield-runtime-core.bundle.lua")
	local uiOk = tryLoadBundle("dist/rayfield-runtime-ui.bundle.lua")
	_G.__RAYFIELD_BUNDLE_PRELOADED = coreOk or uiOk
end

local function fetchSource(path, label)
	if type(_G) == "table" and type(_G.__RAYFIELD_BUNDLE_SOURCES) == "table" then
		local bundled = _G.__RAYFIELD_BUNDLE_SOURCES[path]
		if type(bundled) == "string" and bundled ~= "" then
			return bundled
		end
	end

	local okFetch, source = pcall(game.HttpGet, game, root .. path)
	if not okFetch then
		error("Failed to fetch " .. tostring(label or path) .. ": " .. tostring(source))
	end
	if type(source) ~= "string" or source == "" then
		error("Empty source for " .. tostring(label or path))
	end
	return source
end

preloadBundlesIfEnabled()

local forwardSource = fetchSource("src/legacy/forward.lua", "src/legacy/forward.lua")
local Forward = compileChunk(forwardSource, "src/legacy/forward.lua")()
return Forward.module("allInOne")
