local client = _G and _G.__RayfieldApiClient
if not client then
	error("Rayfield ApiClient is not initialized")
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local FactoryModule = client.fetchAndExecute(root .. "src/ui/elements/factory/init.lua")

local CreateTab = {}

function CreateTab.execute(factoryState, ...)
	if type(factoryState) == "table" and type(factoryState.CreateTab) == "function" then
		return factoryState.CreateTab(...)
	end
	error("CreateTab.execute expects a factory state returned from ElementsModule.init(ctx)")
end

CreateTab.FactoryModule = FactoryModule

return CreateTab