local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local function formatBootstrapError(code, message)
	return string.format("Rayfield Mod: [%s] %s", tostring(code or "E_BOOTSTRAP"), tostring(message or "Unknown bootstrap error"))
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

local function fetchSource(url, label)
	local ok, body = pcall(game.HttpGet, game, url)
	if not ok then
		error(formatBootstrapError("E_BOOTSTRAP_FETCH", "Failed to fetch " .. tostring(label) .. ": " .. tostring(body)))
	end
	if type(body) ~= "string" or #body == 0 then
		error(formatBootstrapError("E_BOOTSTRAP_EMPTY", "Empty response for " .. tostring(label)))
	end
	return body
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local forwardOk, forwardResult = pcall(function()
	local forwardSource = fetchSource(root .. "src/legacy/forward.lua", "src/legacy/forward.lua")
	local Forward = compileChunk(forwardSource, "src/legacy/forward.lua")()
	if type(Forward) ~= "table" or type(Forward.module) ~= "function" then
		error(formatBootstrapError("E_BOOTSTRAP_FORWARD", "Invalid legacy forward contract"))
	end
	return Forward.module("modifiedEntry")
end)

if forwardOk then
	return forwardResult
end

warn(formatBootstrapError("W_BOOTSTRAP_FORWARD_FALLBACK", "Legacy forward failed, trying direct entry fallback."))
warn(formatBootstrapError("W_BOOTSTRAP_FORWARD_REASON", tostring(forwardResult)))

local fallbackSource = fetchSource(root .. "src/entry/rayfield-modified.entry.lua", "src/entry/rayfield-modified.entry.lua")
local fallback = compileChunk(fallbackSource, "src/entry/rayfield-modified.entry.lua")()
return fallback
