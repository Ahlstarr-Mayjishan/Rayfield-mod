local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local Client = compileString(game:HttpGet(root .. "src/api/client.lua"))()
if _G then
	_G.__RayfieldApiClient = Client
end
return Client.fetchAndExecute(root .. "src/feature/enhanced/init.lua")
