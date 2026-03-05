local module = {}

local function attachModuleList(ctx, modules)
	if type(modules) ~= "table" then
		return
	end
	for _, moduleValue in ipairs(modules) do
		if type(moduleValue) == "table" and type(moduleValue.attach) == "function" then
			moduleValue.attach(ctx)
		end
	end
end

function module.attach(ctx)
	attachModuleList(ctx, ctx.movementEventModules)
end

return module
