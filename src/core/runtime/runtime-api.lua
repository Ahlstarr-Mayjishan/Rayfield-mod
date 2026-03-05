local RuntimeApi = {}

function RuntimeApi.bind(context)
	if type(context) ~= "table" then
		error("RuntimeApi.bind expected context table")
	end

	local RayfieldLibrary = context.RayfieldLibrary
	if type(RayfieldLibrary) ~= "table" then
		error("RuntimeApi.bind missing RayfieldLibrary")
	end

	local setVisibility = context.setVisibility
	local getHidden = context.getHidden
	local destroyRuntime = context.destroyRuntime
	local isDestroyed = context.isDestroyed
	local configureRuntime = context.configureRuntime
	local getRuntimeConfig = context.getRuntimeConfig

	if type(setVisibility) ~= "function" then
		error("RuntimeApi.bind missing setVisibility")
	end
	if type(getHidden) ~= "function" then
		error("RuntimeApi.bind missing getHidden")
	end
	if type(destroyRuntime) ~= "function" then
		error("RuntimeApi.bind missing destroyRuntime")
	end
	if type(isDestroyed) ~= "function" then
		error("RuntimeApi.bind missing isDestroyed")
	end

	function RayfieldLibrary:SetVisibility(visibility)
		setVisibility(visibility, false)
	end

	function RayfieldLibrary:IsVisible()
		return not getHidden()
	end

	function RayfieldLibrary:Destroy()
		return destroyRuntime()
	end

	function RayfieldLibrary:IsDestroyed()
		return isDestroyed()
	end

	function RayfieldLibrary:ConfigureRuntime(optionsTable)
		if type(configureRuntime) ~= "function" then
			return false, "Runtime configuration is unavailable."
		end
		return configureRuntime(optionsTable)
	end

	function RayfieldLibrary:GetRuntimeConfig()
		if type(getRuntimeConfig) ~= "function" then
			return nil, "Runtime configuration is unavailable."
		end
		return getRuntimeConfig()
	end
end

return RuntimeApi
