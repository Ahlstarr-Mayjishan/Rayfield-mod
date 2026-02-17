local Forward = {}

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local client = (loadstring or load)(game:HttpGet(root .. "src/api/client.lua"))()
local loader = client.fetchAndExecute(root .. "src/api/loader.lua")

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
