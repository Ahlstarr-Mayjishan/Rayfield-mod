local Bootstrap = {}

function Bootstrap.createRuntimeContext(overrides)
	overrides = overrides or {}
	return {
		useStudio = overrides.useStudio,
		compileString = overrides.compileString,
		runtimeRootUrl = overrides.runtimeRootUrl,
		services = overrides.services or {}
	}
end

return Bootstrap
