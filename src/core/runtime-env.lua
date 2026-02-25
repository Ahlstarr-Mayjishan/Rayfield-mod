local RuntimeEnv = {}

local function resolveCompatibility()
	if type(_G) == "table" and type(_G.__RayfieldCompatibility) == "table" then
		return _G.__RayfieldCompatibility
	end

	local client = type(_G) == "table" and _G.__RayfieldApiClient or nil
	if type(client) ~= "table" or type(client.fetchAndExecute) ~= "function" then
		return nil
	end

	local root = (type(_G) == "table" and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
	local ok, compat = pcall(client.fetchAndExecute, root .. "src/services/compatibility.lua")
	if ok and type(compat) == "table" then
		if type(_G) == "table" then
			_G.__RayfieldCompatibility = compat
		end
		return compat
	end

	return nil
end

local function fallbackGetService(name)
	local ok, service = pcall(function()
		return game:GetService(name)
	end)
	if ok and service then
		return service
	end
	return nil
end

function RuntimeEnv.create(overrides)
	overrides = overrides or {}
	local compatibility = overrides.compatibility or resolveCompatibility()
	local getService = fallbackGetService
	if compatibility and type(compatibility.getService) == "function" then
		getService = compatibility.getService
	end

	local runService = overrides.runService or getService("RunService")
	local useStudio = overrides.useStudio
	if useStudio == nil and runService then
		local okStudio, studio = pcall(function()
			return runService:IsStudio()
		end)
		useStudio = okStudio and studio or false
	end
	if useStudio == nil then
		useStudio = false
	end

	return {
		useStudio = useStudio,
		runtimeRootUrl = overrides.runtimeRootUrl or ((_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"),
		compatibility = compatibility,
		services = {
			RunService = runService,
			UserInputService = overrides.userInputService or getService("UserInputService"),
			TweenService = overrides.tweenService or getService("TweenService"),
			HttpService = overrides.httpService or getService("HttpService")
		}
	}
end

return RuntimeEnv
