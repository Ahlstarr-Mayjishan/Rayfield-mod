local ChartBuilder = {}

local function resolveFactory(selfRef)
	if (type(selfRef.ChartFactoryModule) ~= "table" or type(selfRef.ChartFactoryModule.create) ~= "function")
		and type(selfRef.ResolveChartFactory) == "function" then
		local okResolve, resolvedModule = pcall(selfRef.ResolveChartFactory)
		if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
			selfRef.ChartFactoryModule = resolvedModule
		else
			warn("Rayfield | Chart module lazy-load failed: " .. tostring(okResolve and resolvedModule or "resolve error"))
		end
	end
	if type(selfRef.ChartFactoryModule) ~= "table" or type(selfRef.ChartFactoryModule.create) ~= "function" then
		return nil, "Chart factory module unavailable"
	end
	return selfRef.ChartFactoryModule
end

function ChartBuilder.create(context)
	context = type(context) == "table" and context or {}
	local selfRef = context.self
	if type(selfRef) ~= "table" then
		return nil
	end
	local moduleValue, errMessage = resolveFactory(selfRef)
	if not moduleValue then
		warn("Rayfield | " .. tostring(errMessage))
		return nil
	end
	return moduleValue.create(context)
end

return ChartBuilder
