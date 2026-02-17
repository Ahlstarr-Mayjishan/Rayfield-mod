local client = _G and _G.__RayfieldApiClient
if not client then
	error("Rayfield ApiClient is not initialized")
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
return client.fetchAndExecute(root .. "src/ui/window/init.lua")