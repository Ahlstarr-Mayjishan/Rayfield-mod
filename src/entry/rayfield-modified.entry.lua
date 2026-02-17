-- Canonical entry orchestrator for Rayfield modified runtime

local client = _G and _G.__RayfieldApiClient
if not client then
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
	local clientSource = game:HttpGet(root .. "src/api/client.lua")
	client = compileChunk(clientSource, "src/api/client.lua")()
	if _G then
		_G.__RayfieldApiClient = client
	end
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

-- Force fresh module graph per bootstrap run to avoid stale API module cache
-- when users rerun scripts in the same executor session.
pcall(function()
	local cache = client.fetchAndExecute(root .. "src/api/cache.lua")
	if cache and type(cache.clear) == "function" then
		cache.clear()
	end
end)

local RuntimeEnv = client.fetchAndExecute(root .. "src/core/runtime-env.lua")
local WindowController = client.fetchAndExecute(root .. "src/core/window-controller.lua")

-- Initialize UI orchestration modules so they are part of the canonical graph.
-- The runtime implementation still lives in rayfield-modified.runtime.lua for full compatibility.
local WindowUi = client.fetchAndExecute(root .. "src/ui/window/init.lua")
local TopbarUi = client.fetchAndExecute(root .. "src/ui/topbar/init.lua")
local TabsUi = client.fetchAndExecute(root .. "src/ui/tabs/init.lua")
local NotificationsUi = client.fetchAndExecute(root .. "src/ui/notifications/init.lua")

local runtime = RuntimeEnv.create()
WindowUi.init(runtime)
TopbarUi.init(runtime)
TabsUi.init(runtime)
NotificationsUi.init(runtime)

return WindowController.run(runtime)
