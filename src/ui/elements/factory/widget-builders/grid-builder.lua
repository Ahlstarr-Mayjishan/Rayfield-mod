local GridBuilder = {}

local function resolveFactory(selfRef)
	if (type(selfRef.DataGridFactoryModule) ~= "table" or type(selfRef.DataGridFactoryModule.create) ~= "function")
		and type(selfRef.ResolveDataGridFactory) == "function" then
		local okResolve, resolvedModule = pcall(selfRef.ResolveDataGridFactory)
		if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
			selfRef.DataGridFactoryModule = resolvedModule
		else
			warn("Rayfield | DataGrid module lazy-load failed: " .. tostring(okResolve and resolvedModule or "resolve error"))
		end
	end
	if type(selfRef.DataGridFactoryModule) ~= "table" or type(selfRef.DataGridFactoryModule.create) ~= "function" then
		return nil, "DataGrid factory module unavailable"
	end
	return selfRef.DataGridFactoryModule
end

function GridBuilder.create(context)
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

return GridBuilder
