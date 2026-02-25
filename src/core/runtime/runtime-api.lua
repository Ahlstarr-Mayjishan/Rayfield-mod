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
end

return RuntimeApi
