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
local forwardSource = game:HttpGet(root .. "src/legacy/forward.lua")
if type(forwardSource) == "string" then
	forwardSource = forwardSource:gsub("^\239\187\191", "")
	forwardSource = forwardSource:gsub("^\0+", "")
end
local Forward = compileChunk(forwardSource, "src/legacy/forward.lua")()
return Forward.module("allInOne")
