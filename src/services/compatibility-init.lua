local CompatibilityInitService = {}

local function buildCompatibilityFallback(compileString, warnFn, reason)
	warnFn("Rayfield Mod: [W_BOOTSTRAP_COMPAT] Failed to load compatibility service; using fallback compatibility.")
	if reason then
		warnFn("Rayfield Mod: [W_BOOTSTRAP_COMPAT_REASON] " .. tostring(reason))
	end
	return {
		getService = function(name)
			return game:GetService(name)
		end,
		getCompileString = function()
			return compileString
		end,
		protectAndParent = function(gui, _preferredContainer, opts)
			if opts and opts.useStudio then
				return nil
			end
			local function tryAssign(container)
				if not container then
					return false
				end
				local okAssign = pcall(function()
					gui.Parent = container
				end)
				if not okAssign then
					return false
				end
				return gui.Parent == container
			end

			local okCore, core = pcall(function()
				return game:GetService("CoreGui")
			end)
			if okCore and core and tryAssign(core) then
				return core
			end

			local okPlayers, players = pcall(function()
				return game:GetService("Players")
			end)
			if okPlayers and players and players.LocalPlayer then
				local okPlayerGui, playerGui = pcall(function()
					return players.LocalPlayer:FindFirstChild("PlayerGui") or players.LocalPlayer:WaitForChild("PlayerGui", 5)
				end)
				if okPlayerGui and playerGui and tryAssign(playerGui) then
					return playerGui
				end
			end

			return nil
		end,
		dedupeGuiByName = function()
			return
		end
	}
end

local function buildWidgetBootstrapFallback(apiClient, moduleRootUrl, warnFn, reason)
	warnFn("Rayfield Mod: [W_BOOTSTRAP_WIDGETS] Failed to load widget bootstrap; using fallback widget loader.")
	if reason then
		warnFn("Rayfield Mod: [W_BOOTSTRAP_WIDGETS_REASON] " .. tostring(reason))
	end

	return {
		bootstrapWidget = function(widgetName, targetPath, exportAdapter, opts)
			if type(apiClient) ~= "table" or type(apiClient.fetchAndExecute) ~= "function" then
				error("Rayfield Mod: [E_WIDGET_BOOTSTRAP] ApiClient.fetchAndExecute unavailable for " .. tostring(widgetName))
			end
			local moduleValue = apiClient.fetchAndExecute(moduleRootUrl .. tostring(targetPath))
			if opts and opts.expectedType and type(moduleValue) ~= opts.expectedType then
				error("Rayfield Mod: [E_WIDGET_BOOTSTRAP] " .. tostring(widgetName) .. " expected " .. tostring(opts.expectedType) .. ", got " .. type(moduleValue))
			end
			if type(exportAdapter) == "function" then
				return exportAdapter(moduleValue)
			end
			return moduleValue
		end
	}
end

function CompatibilityInitService.create(options)
	options = type(options) == "table" and options or {}
	local loaderHelpers = options.loaderHelpers
	local apiClient = options.apiClient
	local moduleRootUrl = tostring(options.moduleRootUrl or "")
	local compileString = type(options.compileString) == "function" and options.compileString or (loadstring or load)
	local warnFn = type(options.warn) == "function" and options.warn or warn
	local globalEnv = type(options.globalEnv) == "table" and options.globalEnv or nil

	if type(loaderHelpers) ~= "table" or type(loaderHelpers.fetchExecuteSafely) ~= "function" then
		return nil, "Loader helpers unavailable"
	end

	local fetchExecuteSafely = loaderHelpers.fetchExecuteSafely

	local okCompatibility, compatibilityResult = fetchExecuteSafely("src/services/compatibility.lua")
	local compatibility
	if okCompatibility and type(compatibilityResult) == "table" then
		compatibility = compatibilityResult
	else
		compatibility = buildCompatibilityFallback(compileString, warnFn, compatibilityResult)
	end

	local okWidgetBootstrap, widgetBootstrapResult = fetchExecuteSafely("src/ui/elements/widgets/bootstrap.lua")
	local widgetBootstrap
	if okWidgetBootstrap
		and type(widgetBootstrapResult) == "table"
		and type(widgetBootstrapResult.bootstrapWidget) == "function" then
		widgetBootstrap = widgetBootstrapResult
	else
		widgetBootstrap = buildWidgetBootstrapFallback(apiClient, moduleRootUrl, warnFn, widgetBootstrapResult)
	end

	local okApiLoader, apiLoaderResult = fetchExecuteSafely("src/api/loader.lua")
	if not okApiLoader then
		return nil, "Failed to load API loader: " .. tostring(apiLoaderResult)
	end
	if type(apiLoaderResult) ~= "table" or type(apiLoaderResult.load) ~= "function" then
		return nil, "Invalid API loader contract"
	end

	if type(loaderHelpers.setApiLoader) == "function" then
		loaderHelpers.setApiLoader(apiLoaderResult)
	end

	if globalEnv then
		globalEnv.__RayfieldCompatibility = compatibility
		globalEnv.__RayfieldWidgetBootstrap = widgetBootstrap
	end

	local serviceOverride = nil
	if type(compatibility.getService) == "function" then
		serviceOverride = compatibility.getService
	end

	local compileOverride = nil
	if type(compatibility.getCompileString) == "function" then
		local okCompile, compileOrErr = pcall(compatibility.getCompileString)
		if okCompile and type(compileOrErr) == "function" then
			compileOverride = compileOrErr
		end
	end

	return {
		Compatibility = compatibility,
		WidgetBootstrap = widgetBootstrap,
		ApiLoader = apiLoaderResult,
		getService = serviceOverride,
		compileString = compileOverride
	}
end

return CompatibilityInitService
