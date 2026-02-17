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

local clientSource = game:HttpGet(root .. "src/api/client.lua")
local client = compileChunk(clientSource, "src/api/client.lua")()
if type(client) ~= "table" or type(client.fetchAndExecute) ~= "function" then
	error("Invalid API client bootstrap: missing fetchAndExecute")
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
