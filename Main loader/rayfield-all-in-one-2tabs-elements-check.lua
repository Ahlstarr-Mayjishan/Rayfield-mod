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

local function fetchAndRun(url, label)
	local source = game:HttpGet(url)
	return compileChunk(source, label or url)()
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL)
	or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

if type(warn) == "function" then
	warn("[Rayfield] 'rayfield-all-in-one-2tabs-elements-check.lua' was renamed to 'rayfield-all-in-one-elements-showcase.lua'.")
end

return fetchAndRun(
	root .. "Main%20loader/rayfield-all-in-one-elements-showcase.lua",
	"Main loader/rayfield-all-in-one-elements-showcase.lua"
)
