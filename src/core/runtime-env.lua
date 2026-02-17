local RuntimeEnv = {}

local function getService(name)
	local ok, service = pcall(function()
		return game:GetService(name)
	end)
	if ok and service then
		if cloneref then
			local okRef, ref = pcall(cloneref, service)
			if okRef and ref then
				return ref
			end
		end
		return service
	end
	return nil
end

function RuntimeEnv.create(overrides)
	overrides = overrides or {}
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
		services = {
			RunService = runService,
			UserInputService = overrides.userInputService or getService("UserInputService"),
			TweenService = overrides.tweenService or getService("TweenService"),
			HttpService = overrides.httpService or getService("HttpService")
		}
	}
end

return RuntimeEnv