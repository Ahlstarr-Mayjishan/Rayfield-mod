local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local function compileChunk(source, label)
	if type(source) ~= "string" then
		error("Invalid Lua source for " .. tostring(label) .. ": " .. type(source))
	end
	source = source:gsub("^\239\187\191", "")
	source = source:gsub("^\0+", "")
	local fn, err = compileString(source)
	if not fn then
		error("Failed to compile " .. tostring(label) .. ": " .. tostring(err))
	end
	return fn
end

local function tryLoadBundle(path)
	local okFetch, source = pcall(game.HttpGet, game, root .. path)
	if not okFetch or type(source) ~= "string" or source == "" then
		return false
	end
	local okCompile = pcall(function()
		compileChunk(source, path)()
	end)
	return okCompile
end

if type(_G) == "table" and _G.__RAYFIELD_AUTO_PRELOAD_BUNDLES == true and not _G.__RAYFIELD_BUNDLE_PRELOAD_ATTEMPTED then
	_G.__RAYFIELD_BUNDLE_PRELOAD_ATTEMPTED = true
	local coreOk = tryLoadBundle("dist/rayfield-runtime-core.bundle.lua")
	local uiOk = tryLoadBundle("dist/rayfield-runtime-ui.bundle.lua")
	_G.__RAYFIELD_BUNDLE_PRELOADED = coreOk or uiOk
end

local forwardSource = nil
if type(_G) == "table" and type(_G.__RAYFIELD_BUNDLE_SOURCES) == "table" then
	forwardSource = _G.__RAYFIELD_BUNDLE_SOURCES["src/legacy/forward.lua"]
end
if type(forwardSource) ~= "string" or forwardSource == "" then
	forwardSource = game:HttpGet(root .. "src/legacy/forward.lua")
end

local Forward = compileChunk(forwardSource, "src/legacy/forward.lua")()
return Forward.module("allInOne")
