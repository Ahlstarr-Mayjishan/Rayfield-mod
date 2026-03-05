local TooltipProvider = {}

function TooltipProvider.create(options)
	options = type(options) == "table" and options or {}

	local tooltipEngineModule = options.tooltipEngineModule
	local resolveTooltipEngineModule = type(options.resolveTooltipEngineModule) == "function" and options.resolveTooltipEngineModule or nil
	local engineCreateOptions = type(options.engineCreateOptions) == "table" and options.engineCreateOptions or {}

	local provider = {
		engine = nil
	}

	function provider.resolveEngine()
		if provider.engine then
			return provider.engine
		end
		local moduleValue = tooltipEngineModule
		if type(moduleValue) ~= "table" and resolveTooltipEngineModule then
			moduleValue = resolveTooltipEngineModule()
		end
		if type(moduleValue) ~= "table" or type(moduleValue.create) ~= "function" then
			return nil
		end
		local okCreate, engineOrErr = pcall(moduleValue.create, engineCreateOptions)
		if okCreate and type(engineOrErr) == "table" then
			provider.engine = engineOrErr
		end
		return provider.engine
	end

	function provider.show(key, guiObject, text)
		local engine = provider.resolveEngine()
		if engine and type(engine.show) == "function" then
			engine.show(key, guiObject, text)
		end
	end

	function provider.hide(key)
		local engine = provider.resolveEngine()
		if engine and type(engine.hide) == "function" then
			engine.hide(key)
		end
	end

	return provider
end

return TooltipProvider
