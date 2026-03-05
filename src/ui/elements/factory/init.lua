-- Rayfield Element Factories Module
-- Handles tab creation and all element factories

local ElementsModule = {}

function ElementsModule.init(ctx)
	local self = {}

	-- Inject dependencies
	self.TweenService = ctx.TweenService
	self.Animation = ctx.Animation or ctx.TweenService
	self.RunService = ctx.RunService
	self.UserInputService = ctx.UserInputService
	self.HttpService = ctx.HttpService
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.TabList = ctx.TabList
	self.Elements = ctx.Elements
	self.Rayfield = ctx.Rayfield
	self.RayfieldLibrary = ctx.RayfieldLibrary
	self.Icons = ctx.Icons
	self.getIcon = ctx.getIcon
	self.getAssetUri = ctx.getAssetUri
	self.getSelectedTheme = ctx.getSelectedTheme
	self.rayfieldDestroyed = ctx.rayfieldDestroyed
	self.getMinimised = ctx.getMinimised or function() return false end
	self.getSetting = ctx.getSetting
	self.getInternalSetting = ctx.getInternalSetting or self.getSetting
	self.setInternalSetting = ctx.setInternalSetting
	self.bindTheme = ctx.bindTheme
	self.SaveConfiguration = ctx.SaveConfiguration
	self.makeElementDetachable = ctx.makeElementDetachable
	self.ElementSync = ctx.ElementSync
	self.ViewportVirtualization = ctx.ViewportVirtualization
	self.KeybindSequence = ctx.KeybindSequence
	self.ResourceOwnership = ctx.ResourceOwnership
	self.playUICue = ctx.playUICue
	self.showContextMenu = ctx.showContextMenu
	self.hideContextMenu = ctx.hideContextMenu
	self.trackElementInteraction = ctx.trackElementInteraction
	self.trackTabActivation = ctx.trackTabActivation
	self.resolveControlDisplayLabel = type(ctx.resolveControlDisplayLabel) == "function" and ctx.resolveControlDisplayLabel or nil
	self.persistControlDisplayLabel = type(ctx.persistControlDisplayLabel) == "function" and ctx.persistControlDisplayLabel or nil
	self.resetControlDisplayLabel = type(ctx.resetControlDisplayLabel) == "function" and ctx.resetControlDisplayLabel or nil
	self.localizeSystemString = type(ctx.localizeSystemString) == "function" and ctx.localizeSystemString or function(_, fallback)
		return tostring(fallback or "")
	end
	self.DataGridFactoryModule = ctx.DataGridFactoryModule
	self.ResolveDataGridFactory = type(ctx.ResolveDataGridFactory) == "function" and ctx.ResolveDataGridFactory or nil
	self.ChartFactoryModule = ctx.ChartFactoryModule
	self.ResolveChartFactory = type(ctx.ResolveChartFactory) == "function" and ctx.ResolveChartFactory or nil
	self.InputFactoryModule = ctx.InputFactoryModule
	self.ResolveInputFactory = type(ctx.ResolveInputFactory) == "function" and ctx.ResolveInputFactory or nil
	self.DropdownFactoryModule = ctx.DropdownFactoryModule
	self.ResolveDropdownFactory = type(ctx.ResolveDropdownFactory) == "function" and ctx.ResolveDropdownFactory or nil
	self.KeybindFactoryModule = ctx.KeybindFactoryModule
	self.ResolveKeybindFactory = type(ctx.ResolveKeybindFactory) == "function" and ctx.ResolveKeybindFactory or nil
	self.ToggleFactoryModule = ctx.ToggleFactoryModule
	self.ResolveToggleFactory = type(ctx.ResolveToggleFactory) == "function" and ctx.ResolveToggleFactory or nil
	self.SliderFactoryModule = ctx.SliderFactoryModule
	self.ResolveSliderFactory = type(ctx.ResolveSliderFactory) == "function" and ctx.ResolveSliderFactory or nil
	self.ButtonFactoryModule = ctx.ButtonFactoryModule
	self.ResolveButtonFactory = type(ctx.ResolveButtonFactory) == "function" and ctx.ResolveButtonFactory or nil
	self.TabManagerModule = ctx.TabManagerModule
	self.ResolveTabManagerModule = type(ctx.ResolveTabManagerModule) == "function" and ctx.ResolveTabManagerModule or nil
	self.HoverProviderModule = ctx.HoverProviderModule
	self.ResolveHoverProviderModule = type(ctx.ResolveHoverProviderModule) == "function" and ctx.ResolveHoverProviderModule or nil
	self.TooltipEngineModule = ctx.TooltipEngineModule
	self.ResolveTooltipEngineModule = type(ctx.ResolveTooltipEngineModule) == "function" and ctx.ResolveTooltipEngineModule or nil
	self.TooltipProviderModule = ctx.TooltipProviderModule
	self.ResolveTooltipProviderModule = type(ctx.ResolveTooltipProviderModule) == "function" and ctx.ResolveTooltipProviderModule or nil
	self.LoggingProviderModule = ctx.LoggingProviderModule
	self.ResolveLoggingProviderModule = type(ctx.ResolveLoggingProviderModule) == "function" and ctx.ResolveLoggingProviderModule or nil
	self.WidgetAPIInjectorModule = ctx.WidgetAPIInjectorModule
	self.ResolveWidgetAPIInjectorModule = type(ctx.ResolveWidgetAPIInjectorModule) == "function" and ctx.ResolveWidgetAPIInjectorModule or nil
	self.MathUtilsModule = ctx.MathUtilsModule
	self.ResolveMathUtilsModule = type(ctx.ResolveMathUtilsModule) == "function" and ctx.ResolveMathUtilsModule or nil
	self.ResourceGuardModule = ctx.ResourceGuardModule
	self.ResolveResourceGuardModule = type(ctx.ResolveResourceGuardModule) == "function" and ctx.ResolveResourceGuardModule or nil
	self.SectionFactoryModule = ctx.SectionFactoryModule
	self.ResolveSectionFactoryModule = type(ctx.ResolveSectionFactoryModule) == "function" and ctx.ResolveSectionFactoryModule or nil
	self.ControlRegistryModule = ctx.ControlRegistryModule
	self.ResolveControlRegistryModule = type(ctx.ResolveControlRegistryModule) == "function" and ctx.ResolveControlRegistryModule or nil
	self.GridBuilderModule = ctx.GridBuilderModule
	self.ResolveGridBuilderModule = type(ctx.ResolveGridBuilderModule) == "function" and ctx.ResolveGridBuilderModule or nil
	self.ChartBuilderModule = ctx.ChartBuilderModule
	self.ResolveChartBuilderModule = type(ctx.ResolveChartBuilderModule) == "function" and ctx.ResolveChartBuilderModule or nil
	self.RangeBarsFactoryModule = ctx.RangeBarsFactoryModule
	self.ResolveRangeBarsFactoryModule = type(ctx.ResolveRangeBarsFactoryModule) == "function" and ctx.ResolveRangeBarsFactoryModule or nil
	self.FeedbackWidgetsFactoryModule = ctx.FeedbackWidgetsFactoryModule
	self.ResolveFeedbackWidgetsFactoryModule = type(ctx.ResolveFeedbackWidgetsFactoryModule) == "function" and ctx.ResolveFeedbackWidgetsFactoryModule or nil
	self.ComponentWidgetsFactoryModule = ctx.ComponentWidgetsFactoryModule
	self.ResolveComponentWidgetsFactoryModule = type(ctx.ResolveComponentWidgetsFactoryModule) == "function" and ctx.ResolveComponentWidgetsFactoryModule or nil
	-- Improvement 4: Add safe fallbacks for critical dependencies
	self.keybindConnections = ctx.keybindConnections or {} -- Fallback to empty table
	self.getDebounce = ctx.getDebounce or function() return false end
	self.setDebounce = ctx.setDebounce or function(val) end

	self.useMobileSizing = ctx.useMobileSizing
	local LogService = nil
	do
		local okLogService, serviceOrErr = pcall(function()
			return game:GetService("LogService")
		end)
		if okLogService then
			LogService = serviceOrErr
		end
	end

	-- Window Settings (passed from CreateWindow)
	local Settings = ctx.Settings or {}
	local function isHeadlessPerformanceMode()
		if Settings.PerformanceMode == true then
			return true
		end
		local profile = type(Settings.PerformanceProfile) == "table" and Settings.PerformanceProfile or nil
		if not profile or profile.Enabled ~= true then
			return false
		end
		local mode = string.lower(tostring(profile.Mode or ""))
		if profile.DisableAnimations == true then
			return true
		end
		if profile.Aggressive == true then
			return true
		end
		return mode == "potato" or mode == "mobile"
	end

	-- Module state
	local tabRegistry = nil
	do
		local tabManagerModule = self.TabManagerModule
		if type(tabManagerModule) ~= "table" and type(self.ResolveTabManagerModule) == "function" then
			tabManagerModule = self.ResolveTabManagerModule()
		end
		if type(tabManagerModule) == "table" and type(tabManagerModule.create) == "function" then
			local okCreate, managerOrErr = pcall(tabManagerModule.create)
			if okCreate and type(managerOrErr) == "table" then
				tabRegistry = managerOrErr
			end
		end
	end
	if type(tabRegistry) ~= "table" then
		local fallbackState = {
			firstTab = false,
			nameCounts = {},
			recordsByPersistenceId = {}
		}
		tabRegistry = {
			allocatePersistenceId = function(baseName)
				local basePersistenceId = tostring(baseName or "")
				local nextIndex = (fallbackState.nameCounts[basePersistenceId] or 0) + 1
				fallbackState.nameCounts[basePersistenceId] = nextIndex
				if nextIndex > 1 then
					return basePersistenceId .. "#" .. tostring(nextIndex)
				end
				return basePersistenceId
			end,
			registerRecord = function(persistenceId, record)
				fallbackState.recordsByPersistenceId[tostring(persistenceId or "")] = record
			end,
			unregisterRecord = function(persistenceId)
				fallbackState.recordsByPersistenceId[tostring(persistenceId or "")] = nil
			end,
			getFirstTab = function()
				return fallbackState.firstTab
			end,
			setFirstTab = function(value)
				fallbackState.firstTab = value
				return fallbackState.firstTab
			end,
			getTabRecordByPersistenceId = function(tabId)
				if tabId == nil then
					return nil
				end
				return fallbackState.recordsByPersistenceId[tostring(tabId)]
			end,
			getTabLayoutOrderByPersistenceId = function(tabId)
				local record = tabRegistry.getTabRecordByPersistenceId(tabId)
				if not record or not record.TabPage then
					return math.huge
				end
				return tonumber(record.TabPage.LayoutOrder) or math.huge
			end,
			getCurrentTabPersistenceId = function(currentPage)
				if not currentPage then
					return nil
				end
				for persistenceId, record in pairs(fallbackState.recordsByPersistenceId) do
					if record and record.TabPage == currentPage then
						return persistenceId
					end
				end
				return nil
			end,
			activateTabByPersistenceId = function(tabId, ignoreMinimisedCheck, source)
				local record = tabRegistry.getTabRecordByPersistenceId(tabId)
				if not record or type(record.Activate) ~= "function" then
					return false
				end
				return record.Activate(ignoreMinimisedCheck == true, source)
			end
		}
	end

	local controlRegistry = nil
	local allControlsById = {}
	local controlOrder = {}
	local controlsByFlag = {}
	local pinnedControlIds = {}
	local controlRegistrySubscribers = {}
	local loggingProvider = nil
	local tooltipProvider = nil
	local widgetApiInjector = nil
	local resourceGuard = nil
	local mathUtils = nil
	local gridBuilder = nil
	local chartBuilder = nil
	local rangeBarsFactory = nil
	local feedbackWidgetsFactory = nil
	local sectionFactory = nil
	local componentWidgetsFactory = nil

	local function cloneArray(values)
		local out = {}
		if type(values) ~= "table" then
			return out
		end
		for index, value in ipairs(values) do
			out[index] = value
		end
		return out
	end

	local function emitUICue(cueName)
		if type(self.playUICue) ~= "function" then
			return false
		end
		local okCall = pcall(self.playUICue, cueName)
		return okCall
	end

	local function resolveMathUtils()
		if type(mathUtils) == "table" then
			return mathUtils
		end
		local moduleValue = self.MathUtilsModule
		if type(moduleValue) ~= "table" and type(self.ResolveMathUtilsModule) == "function" then
			moduleValue = self.ResolveMathUtilsModule()
		end
		if type(moduleValue) ~= "table" then
			moduleValue = {}
		end
		mathUtils = moduleValue
		return mathUtils
	end

	local function resolveControlRegistry()
		if type(controlRegistry) == "table" then
			return controlRegistry
		end
		local moduleValue = self.ControlRegistryModule
		if type(moduleValue) ~= "table" and type(self.ResolveControlRegistryModule) == "function" then
			moduleValue = self.ResolveControlRegistryModule()
		end
		if type(moduleValue) == "table" and type(moduleValue.create) == "function" then
			local okCreate, registryOrErr = pcall(moduleValue.create, {
				resolveControlDisplayLabel = self.resolveControlDisplayLabel,
				persistControlDisplayLabel = self.persistControlDisplayLabel,
				resetControlDisplayLabel = self.resetControlDisplayLabel
			})
			if okCreate and type(registryOrErr) == "table" and type(registryOrErr.state) == "table" then
				controlRegistry = registryOrErr
			end
		end
		if type(controlRegistry) ~= "table" or type(controlRegistry.state) ~= "table" then
			controlRegistry = {
				state = {
					allControlsById = {},
					controlOrder = {},
					controlsByFlag = {},
					pinnedControlIds = {},
					controlRegistrySubscribers = {},
					pinBadgesVisible = true
				}
			}
		end

		allControlsById = controlRegistry.state.allControlsById or {}
		controlOrder = controlRegistry.state.controlOrder or {}
		controlsByFlag = controlRegistry.state.controlsByFlag or {}
		pinnedControlIds = controlRegistry.state.pinnedControlIds or {}
		controlRegistrySubscribers = controlRegistry.state.controlRegistrySubscribers or {}
		return controlRegistry
	end

	local function resolveResourceGuard()
		if resourceGuard then
			return resourceGuard
		end
		local moduleValue = self.ResourceGuardModule
		if type(moduleValue) ~= "table" and type(self.ResolveResourceGuardModule) == "function" then
			moduleValue = self.ResolveResourceGuardModule()
		end
		if type(moduleValue) == "table" and type(moduleValue.create) == "function" then
			local okCreate, guardOrErr = pcall(moduleValue.create, {
				resourceOwnership = self.ResourceOwnership
			})
			if okCreate and type(guardOrErr) == "table" then
				resourceGuard = guardOrErr
			end
		end
		return resourceGuard
	end

	local function ownershipCreateScope(scopeId, metadata)
		local guard = resolveResourceGuard()
		if guard and type(guard.createScope) == "function" then
			return guard.createScope(scopeId, metadata)
		end
		if not (self.ResourceOwnership and type(self.ResourceOwnership.createScope) == "function") then
			return nil
		end
		local okScope, scopeOrErr = pcall(self.ResourceOwnership.createScope, scopeId, metadata)
		if okScope and type(scopeOrErr) == "string" and scopeOrErr ~= "" then
			return scopeOrErr
		end
		if okScope then
			return scopeId
		end
		return nil
	end

	local function ownershipClaimInstance(instance, scopeId, metadata)
		local guard = resolveResourceGuard()
		if guard and type(guard.claimInstance) == "function" then
			return guard.claimInstance(instance, scopeId, metadata)
		end
		if not (self.ResourceOwnership and type(self.ResourceOwnership.claimInstance) == "function") then
			return false
		end
		local okClaim, claimed = pcall(self.ResourceOwnership.claimInstance, instance, scopeId, metadata)
		return okClaim and claimed == true
	end

	local function ownershipTrackConnection(connection, scopeId)
		local guard = resolveResourceGuard()
		if guard and type(guard.trackConnection) == "function" then
			return guard.trackConnection(connection, scopeId)
		end
		if not connection or type(scopeId) ~= "string" or scopeId == "" then
			return false
		end
		if not (self.ResourceOwnership and type(self.ResourceOwnership.trackConnection) == "function") then
			return false
		end
		local okTrack, tracked = pcall(self.ResourceOwnership.trackConnection, connection, scopeId)
		return okTrack and tracked == true
	end

	local function ownershipTrackCleanup(cleanupFn, scopeId)
		local guard = resolveResourceGuard()
		if guard and type(guard.trackCleanup) == "function" then
			return guard.trackCleanup(cleanupFn, scopeId)
		end
		if type(cleanupFn) ~= "function" or type(scopeId) ~= "string" or scopeId == "" then
			return false
		end
		if not (self.ResourceOwnership and type(self.ResourceOwnership.trackCleanup) == "function") then
			return false
		end
		local okTrack, tracked = pcall(self.ResourceOwnership.trackCleanup, cleanupFn, scopeId)
		return okTrack and tracked == true
	end

	local function ownershipCleanupScope(scopeId, options)
		local guard = resolveResourceGuard()
		if guard and type(guard.cleanupScope) == "function" then
			return guard.cleanupScope(scopeId, options)
		end
		if type(scopeId) ~= "string" or scopeId == "" then
			return false
		end
		if not (self.ResourceOwnership and type(self.ResourceOwnership.cleanupScope) == "function") then
			return false
		end
		local okCleanup, cleaned = pcall(self.ResourceOwnership.cleanupScope, scopeId, options or {
			destroyInstances = false,
			clearAttributes = true
		})
		return okCleanup and cleaned == true
	end

	local function cloneSerializable(value, seen)
		local valueType = type(value)
		if valueType == "function" or valueType == "userdata" or valueType == "thread" then
			return nil
		end
		if valueType ~= "table" then
			return value
		end
		seen = seen or {}
		if seen[value] then
			return seen[value]
		end
		local out = {}
		seen[value] = out
		for key, nested in pairs(value) do
			if key ~= "Element" then
				local clonedKey = cloneSerializable(key, seen)
				local clonedNested = cloneSerializable(nested, seen)
				if clonedKey ~= nil and clonedNested ~= nil then
					out[clonedKey] = clonedNested
				end
			end
		end
		return out
	end

	local function clampNumber(value, minimum, maximum, fallback)
		local utilsModule = resolveMathUtils()
		if type(utilsModule.clampNumber) == "function" then
			return utilsModule.clampNumber(value, minimum, maximum, fallback)
		end
		local numberValue = tonumber(value)
		if not numberValue then
			numberValue = tonumber(fallback) or 0
		end
		if minimum ~= nil then
			numberValue = math.max(minimum, numberValue)
		end
		if maximum ~= nil then
			numberValue = math.min(maximum, numberValue)
		end
		return numberValue
	end

	local function packColor3(colorValue)
		local utilsModule = resolveMathUtils()
		if type(utilsModule.packColor3) == "function" then
			return utilsModule.packColor3(colorValue)
		end
		if typeof(colorValue) ~= "Color3" then
			return nil
		end
		return {
			R = math.floor((colorValue.R * 255) + 0.5),
			G = math.floor((colorValue.G * 255) + 0.5),
			B = math.floor((colorValue.B * 255) + 0.5)
		}
	end

	local function unpackColor3(colorValue)
		local utilsModule = resolveMathUtils()
		if type(utilsModule.unpackColor3) == "function" then
			return utilsModule.unpackColor3(colorValue)
		end
		if type(colorValue) ~= "table" then
			return nil
		end
		local r = tonumber(colorValue.R)
		local g = tonumber(colorValue.G)
		local b = tonumber(colorValue.B)
		if not (r and g and b) then
			return nil
		end
		return Color3.fromRGB(
			math.clamp(math.floor(r + 0.5), 0, 255),
			math.clamp(math.floor(g + 0.5), 0, 255),
			math.clamp(math.floor(b + 0.5), 0, 255)
		)
	end

	local function roundToPrecision(value, precision)
		local utilsModule = resolveMathUtils()
		if type(utilsModule.roundToPrecision) == "function" then
			return utilsModule.roundToPrecision(value, precision)
		end
		local digits = math.max(0, math.floor(tonumber(precision) or 0))
		local scale = 10 ^ digits
		return math.floor((tonumber(value) or 0) * scale + 0.5) / scale
	end

	local function resolveTooltipProvider()
		if type(tooltipProvider) == "table" then
			return tooltipProvider
		end
		local moduleValue = self.TooltipProviderModule
		if type(moduleValue) ~= "table" and type(self.ResolveTooltipProviderModule) == "function" then
			moduleValue = self.ResolveTooltipProviderModule()
		end
		if type(moduleValue) == "table" and type(moduleValue.create) == "function" then
			local okCreate, providerOrErr = pcall(moduleValue.create, {
				tooltipEngineModule = self.TooltipEngineModule,
				resolveTooltipEngineModule = self.ResolveTooltipEngineModule,
				engineCreateOptions = {
					Rayfield = self.Rayfield,
					Main = self.Main,
					UserInputService = self.UserInputService,
					getSelectedTheme = self.getSelectedTheme
				}
			})
			if okCreate and type(providerOrErr) == "table" then
				tooltipProvider = providerOrErr
			end
		end
		if type(tooltipProvider) ~= "table" then
			tooltipProvider = {
				show = function() end,
				hide = function() end
			}
		end
		return tooltipProvider
	end

	local function hideTooltip(key)
		local provider = resolveTooltipProvider()
		if type(provider.hide) == "function" then
			provider.hide(key)
		end
	end

	local function showTooltip(key, guiObject, text)
		local provider = resolveTooltipProvider()
		if type(provider.show) == "function" then
			provider.show(key, guiObject, text)
		end
	end

	local function resolveLoggingProvider()
		if type(loggingProvider) == "table" then
			return loggingProvider
		end
		local moduleValue = self.LoggingProviderModule
		if type(moduleValue) ~= "table" and type(self.ResolveLoggingProviderModule) == "function" then
			moduleValue = self.ResolveLoggingProviderModule()
		end
		if type(moduleValue) == "table" and type(moduleValue.create) == "function" then
			local okCreate, providerOrErr = pcall(moduleValue.create, {
				logService = LogService
			})
			if okCreate and type(providerOrErr) == "table" then
				loggingProvider = providerOrErr
			end
		end
		if type(loggingProvider) ~= "table" then
			loggingProvider = {
				subscribe = function()
					return function() end
				end
			}
		end
		return loggingProvider
	end

	local function subscribeGlobalLogs(callback)
		local provider = resolveLoggingProvider()
		if type(provider.subscribe) == "function" then
			return provider.subscribe(callback)
		end
		return function() end
	end

	local function emitControlRegistryChange(reason)
		local registry = resolveControlRegistry()
		if type(registry.emitControlRegistryChange) == "function" then
			registry.emitControlRegistryChange(reason)
		end
	end

	local function isControlRecordAlive(record)
		local registry = resolveControlRegistry()
		if type(registry.isControlRecordAlive) == "function" then
			return registry.isControlRecordAlive(record)
		end
		return false
	end

	local function applyPinnedVisual(record)
		local registry = resolveControlRegistry()
		if type(registry.applyPinnedVisual) == "function" then
			registry.applyPinnedVisual(record)
		end
	end

	local function getRecordByIdOrFlag(idOrFlag)
		local registry = resolveControlRegistry()
		if type(registry.getRecordByIdOrFlag) == "function" then
			return registry.getRecordByIdOrFlag(idOrFlag)
		end
		return nil
	end

	local function buildLocalizationKeysForRecord(record)
		local registry = resolveControlRegistry()
		if type(registry.buildLocalizationKeysForRecord) == "function" then
			return registry.buildLocalizationKeysForRecord(record)
		end
		return {}
	end

	local function resolveLocalizationKey(record)
		local registry = resolveControlRegistry()
		if type(registry.resolveLocalizationKey) == "function" then
			return registry.resolveLocalizationKey(record)
		end
		return ""
	end

	local function applyControlDisplayLabel(record, label)
		local registry = resolveControlRegistry()
		if type(registry.applyControlDisplayLabel) == "function" then
			return registry.applyControlDisplayLabel(record, label)
		end
		return false, "Localization unavailable."
	end

	local function pinControl(idOrFlag)
		local registry = resolveControlRegistry()
		if type(registry.pinControl) == "function" then
			return registry.pinControl(idOrFlag)
		end
		return false, "Pin unavailable."
	end

	local function unpinControl(idOrFlag)
		local registry = resolveControlRegistry()
		if type(registry.unpinControl) == "function" then
			return registry.unpinControl(idOrFlag)
		end
		return false, "Unpin unavailable."
	end

	local function getPinnedIds(pruneMissing)
		local registry = resolveControlRegistry()
		if type(registry.getPinnedIds) == "function" then
			return registry.getPinnedIds(pruneMissing)
		end
		return {}
	end

	local function setPinnedIds(ids)
		local registry = resolveControlRegistry()
		if type(registry.setPinnedIds) == "function" then
			registry.setPinnedIds(ids)
		end
	end

	local function setPinBadgesVisible(visible)
		local registry = resolveControlRegistry()
		if type(registry.setPinBadgesVisible) == "function" then
			registry.setPinBadgesVisible(visible ~= false)
		end
	end

	local function listControlsForFavorites(pruneMissing)
		local registry = resolveControlRegistry()
		if type(registry.listControlsForFavorites) == "function" then
			return registry.listControlsForFavorites(pruneMissing)
		end
		return {}
	end

	local function getControlRecordById(id)
		local registry = resolveControlRegistry()
		if type(registry.getControlRecordById) == "function" then
			return registry.getControlRecordById(id)
		end
		return nil
	end

	local function listControlRecords(pruneMissing)
		local registry = resolveControlRegistry()
		if type(registry.listControlRecords) == "function" then
			return registry.listControlRecords(pruneMissing)
		end
		return {}
	end

	local function setControlDisplayLabelByIdOrFlag(idOrFlag, label, options)
		local registry = resolveControlRegistry()
		if type(registry.setControlDisplayLabelByIdOrFlag) == "function" then
			return registry.setControlDisplayLabelByIdOrFlag(idOrFlag, label, options)
		end
		return false, "Localization unavailable."
	end

	local function getControlDisplayLabelByIdOrFlag(idOrFlag)
		local registry = resolveControlRegistry()
		if type(registry.getControlDisplayLabelByIdOrFlag) == "function" then
			return registry.getControlDisplayLabelByIdOrFlag(idOrFlag)
		end
		return nil, nil
	end

	local function resetControlDisplayLabelByIdOrFlag(idOrFlag, options)
		local registry = resolveControlRegistry()
		if type(registry.resetControlDisplayLabelByIdOrFlag) == "function" then
			return registry.resetControlDisplayLabelByIdOrFlag(idOrFlag, options)
		end
		return false, "Localization unavailable."
	end

	local function L(key, fallback)
		local okValue, value = pcall(self.localizeSystemString, key, fallback)
		if okValue and type(value) == "string" and value ~= "" then
			return value
		end
		return tostring(fallback or key or "")
	end

	local function resolveWidgetApiInjector()
		if widgetApiInjector then
			return widgetApiInjector
		end
		local moduleValue = self.WidgetAPIInjectorModule
		if type(moduleValue) ~= "table" and type(self.ResolveWidgetAPIInjectorModule) == "function" then
			moduleValue = self.ResolveWidgetAPIInjectorModule()
		end
		if type(moduleValue) == "table" and type(moduleValue.inject) == "function" then
			widgetApiInjector = moduleValue
		end
		return widgetApiInjector
	end

	local function resolveGridBuilder()
		if gridBuilder then
			return gridBuilder
		end
		local moduleValue = self.GridBuilderModule
		if type(moduleValue) ~= "table" and type(self.ResolveGridBuilderModule) == "function" then
			moduleValue = self.ResolveGridBuilderModule()
		end
		if type(moduleValue) == "table" and type(moduleValue.create) == "function" then
			gridBuilder = moduleValue
		end
		return gridBuilder
	end

	local function resolveChartBuilder()
		if chartBuilder then
			return chartBuilder
		end
		local moduleValue = self.ChartBuilderModule
		if type(moduleValue) ~= "table" and type(self.ResolveChartBuilderModule) == "function" then
			moduleValue = self.ResolveChartBuilderModule()
		end
		if type(moduleValue) == "table" and type(moduleValue.create) == "function" then
			chartBuilder = moduleValue
		end
		return chartBuilder
	end

	local function resolveRangeBarsFactory()
		if rangeBarsFactory then
			return rangeBarsFactory
		end
		local moduleValue = self.RangeBarsFactoryModule
		if type(moduleValue) ~= "table" and type(self.ResolveRangeBarsFactoryModule) == "function" then
			moduleValue = self.ResolveRangeBarsFactoryModule()
		end
		if type(moduleValue) == "table"
			and type(moduleValue.createTrackBar) == "function"
			and type(moduleValue.createStatusBar) == "function" then
			rangeBarsFactory = moduleValue
		end
		return rangeBarsFactory
	end

	local function resolveFeedbackWidgetsFactory()
		if feedbackWidgetsFactory then
			return feedbackWidgetsFactory
		end
		local moduleValue = self.FeedbackWidgetsFactoryModule
		if type(moduleValue) ~= "table" and type(self.ResolveFeedbackWidgetsFactoryModule) == "function" then
			moduleValue = self.ResolveFeedbackWidgetsFactoryModule()
		end
		if type(moduleValue) == "table"
			and type(moduleValue.createLogConsole) == "function"
			and type(moduleValue.createLoadingSpinner) == "function"
			and type(moduleValue.createLoadingBar) == "function" then
			feedbackWidgetsFactory = moduleValue
		end
		return feedbackWidgetsFactory
	end

	local function resolveSectionFactory()
		if sectionFactory then
			return sectionFactory
		end
		local moduleValue = self.SectionFactoryModule
		if type(moduleValue) ~= "table" and type(self.ResolveSectionFactoryModule) == "function" then
			moduleValue = self.ResolveSectionFactoryModule()
		end
		if type(moduleValue) == "table"
			and type(moduleValue.createSection) == "function"
			and type(moduleValue.createCollapsibleSection) == "function" then
			sectionFactory = moduleValue
		end
		return sectionFactory
	end

	local function resolveComponentWidgetsFactory()
		if componentWidgetsFactory then
			return componentWidgetsFactory
		end
		local moduleValue = self.ComponentWidgetsFactoryModule
		if type(moduleValue) ~= "table" and type(self.ResolveComponentWidgetsFactoryModule) == "function" then
			moduleValue = self.ResolveComponentWidgetsFactoryModule()
		end
		if type(moduleValue) == "table"
			and type(moduleValue.createColorPicker) == "function"
			and type(moduleValue.createNumberStepper) == "function"
			and type(moduleValue.createConfirmButton) == "function"
			and type(moduleValue.createImage) == "function"
			and type(moduleValue.createGallery) == "function"
			and type(moduleValue.createDivider) == "function"
			and type(moduleValue.createLabel) == "function"
			and type(moduleValue.createParagraph) == "function" then
			componentWidgetsFactory = moduleValue
		end
		return componentWidgetsFactory
	end

	-- Extract code starts here

		local function CreateTab(Name, Image, Ext)
			local basePersistenceId = tostring(Name)
			local tabPersistenceId = tabRegistry.allocatePersistenceId(basePersistenceId)
			local SDone = false
			local TabButton = self.TabList.Template:Clone()
			TabButton.Name = Name
			TabButton.Title.Text = Name
			TabButton.Parent = self.TabList
			TabButton.Title.TextWrapped = false
			TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 30, 0, 30)
	
			if Image and Image ~= 0 then
				if typeof(Image) == 'string' and self.Icons then
					local asset = self.getIcon(Image)
	
					TabButton.Image.Image = 'rbxassetid://'..asset.id
					TabButton.Image.ImageRectOffset = asset.imageRectOffset
					TabButton.Image.ImageRectSize = asset.imageRectSize
				else
					TabButton.Image.Image = self.getAssetUri(Image)
				end
	
				TabButton.Title.AnchorPoint = Vector2.new(0, 0.5)
				TabButton.Title.Position = UDim2.new(0, 37, 0.5, 0)
				TabButton.Image.Visible = true
				TabButton.Title.TextXAlignment = Enum.TextXAlignment.Left
				TabButton.Size = UDim2.new(0, TabButton.Title.TextBounds.X + 52, 0, 30)
			end
	
	
	
			TabButton.BackgroundTransparency = 1
			TabButton.Title.TextTransparency = 1
			TabButton.Image.ImageTransparency = 1
			TabButton.UIStroke.Transparency = 1

			local TabHoverGlow = Instance.new("UIStroke")
			TabHoverGlow.Name = "HoverGlow"
			TabHoverGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			TabHoverGlow.Thickness = 2.8
			TabHoverGlow.Transparency = 1
			TabHoverGlow.Color = Color3.fromRGB(110, 175, 240)
			TabHoverGlow.Parent = TabButton
	
			TabButton.Visible = not Ext or false
	
			-- Create self.Elements Page
			local TabPage = self.Elements.Template:Clone()
			TabPage.Name = Name
			TabPage.Visible = true
	
			TabPage.LayoutOrder = #self.Elements:GetChildren() or Ext and 10000
	
			for _, TemplateElement in ipairs(TabPage:GetChildren()) do
				if TemplateElement.ClassName == "Frame" and TemplateElement.Name ~= "Placeholder" then
					TemplateElement:Destroy()
				end
			end

			TabPage.Parent = self.Elements

			local tabRecord = {
				Name = Name,
				PersistenceId = tabPersistenceId,
				Ext = Ext and true or false,
				TabButton = TabButton,
				TabPage = TabPage,
				DefaultVisible = TabButton.Visible,
				IsSplit = false,
				SplitPanelId = nil,
				SuppressNextClick = false,
				IsSettings = (Name == "Rayfield Settings" and Ext == true)
			}
			tabRegistry.registerRecord(tabPersistenceId, tabRecord)
			local tabHover = false
			
			-- Reactive coloring for TabPage elements
			TabPage.ChildAdded:Connect(function(Element)
				if Element.ClassName == "Frame" and Element.Name ~= "Placeholder" and Element.Name ~= "SectionSpacing" and Element.Name ~= "Divider" and Element.Name ~= "SectionTitle" and Element.Name ~= "SearchTitle-fsefsefesfsefesfesfThanks" then
					self.bindTheme(Element, "BackgroundColor3", "ElementBackground")
					-- Guard: not all frames have a UIStroke child
					if Element:FindFirstChildWhichIsA("UIStroke") then
						self.bindTheme(Element.UIStroke, "Color", "ElementStroke")
					end
				end
			end)
			
			if not tabRegistry.getFirstTab() and not Ext then
				self.Elements.UIPageLayout.Animated = false
				self.Elements.UIPageLayout:JumpTo(TabPage)
				self.Elements.UIPageLayout.Animated = true
			end
	
			self.bindTheme(TabButton.UIStroke, "Color", "TabStroke")
	
			local function UpdateTabColors()
				TabButton.UIStroke.Color = self.getSelectedTheme().TabStroke
				TabHoverGlow.Color = self.getSelectedTheme().SliderProgress or self.getSelectedTheme().TabStroke
				if self.Elements.UIPageLayout.CurrentPage == TabPage then
					tabHover = false
					TabButton.UIStroke.Thickness = 1
					TabHoverGlow.Transparency = 1
					TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackgroundSelected
					TabButton.Image.ImageColor3 = self.getSelectedTheme().SelectedTabTextColor
					TabButton.Title.TextColor3 = self.getSelectedTheme().SelectedTabTextColor
				else
					if not tabHover then
						TabButton.UIStroke.Thickness = 1
						TabHoverGlow.Transparency = 1
					end
					TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackground
					TabButton.Image.ImageColor3 = self.getSelectedTheme().TabTextColor
					TabButton.Title.TextColor3 = self.getSelectedTheme().TabTextColor
				end
			end

			local function applyTabHoverVisual(duration)
				if tabRecord.IsSplit then
					return
				end
				if self.Elements.UIPageLayout.CurrentPage == TabPage then
					return
				end

				local tweenDuration = duration or 0.16
				local theme = self.getSelectedTheme() or {}
				local targetBackgroundTransparency = tabHover and 0.58 or 0.7
				local targetStrokeTransparency = tabHover and 0.32 or 0.5
				local targetStrokeThickness = tabHover and 1.2 or 1
				local targetStrokeColor = tabHover and (theme.SliderProgress or theme.TabStroke) or theme.TabStroke
				local targetGlowTransparency = tabHover and 0.84 or 1
				local targetGlowThickness = tabHover and 3.3 or 2.8
				local targetGlowColor = theme.SliderProgress or theme.TabStroke
				local targetTextTransparency = tabHover and 0.05 or 0.2
				local targetImageTransparency = tabHover and 0.05 or 0.2

				self.Animation:Create(TabButton, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = targetBackgroundTransparency}):Play()
				self.Animation:Create(TabButton.UIStroke, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = targetStrokeTransparency,
					Thickness = targetStrokeThickness,
					Color = targetStrokeColor
				}):Play()
				self.Animation:Create(TabHoverGlow, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = targetGlowTransparency,
					Thickness = targetGlowThickness,
					Color = targetGlowColor
				}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = targetTextTransparency}):Play()
				self.Animation:Create(TabButton.Image, TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = targetImageTransparency}):Play()
			end

			-- Listen for theme changes to update tab colors
			local themeValueFolder = self.Main:FindFirstChild("ThemeValues")
			if themeValueFolder then
				themeValueFolder:FindFirstChild("Background").Changed:Connect(UpdateTabColors)
			end
			
			self.Elements.UIPageLayout:GetPropertyChangedSignal("CurrentPage"):Connect(UpdateTabColors)
	
	
			-- Animate
			task.wait(0.1)
			if tabRegistry.getFirstTab() or Ext then
				TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackground
				TabButton.Image.ImageColor3 = self.getSelectedTheme().TabTextColor
				TabButton.Title.TextColor3 = self.getSelectedTheme().TabTextColor
				self.Animation:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
				self.Animation:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
				self.Animation:Create(TabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
				TabHoverGlow.Transparency = 1
			elseif not Ext then
				tabRegistry.setFirstTab(Name)
				TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackgroundSelected
				TabButton.Image.ImageColor3 = self.getSelectedTheme().SelectedTabTextColor
				TabButton.Title.TextColor3 = self.getSelectedTheme().SelectedTabTextColor
				self.Animation:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
				self.Animation:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
				TabHoverGlow.Transparency = 1
			end
	
			local function activateTab(ignoreMinimisedCheck, source)
				if tabRecord.IsSplit then return false end
				if not ignoreMinimisedCheck and self.getMinimised() then return false end

				tabHover = false
				self.Animation:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(TabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
				self.Animation:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
				self.Animation:Create(TabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().TabBackgroundSelected}):Play()
				self.Animation:Create(TabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextColor3 = self.getSelectedTheme().SelectedTabTextColor}):Play()
				self.Animation:Create(TabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageColor3 = self.getSelectedTheme().SelectedTabTextColor}):Play()
				TabButton.UIStroke.Thickness = 1
				TabButton.UIStroke.Color = self.getSelectedTheme().TabStroke
				TabHoverGlow.Transparency = 1

				for _, OtherTabButton in ipairs(self.TabList:GetChildren()) do
					if OtherTabButton.Name ~= "Template" and OtherTabButton.ClassName == "Frame" and OtherTabButton ~= TabButton and OtherTabButton.Name ~= "Placeholder" and OtherTabButton.Visible then
						self.Animation:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().TabBackground}):Play()
						self.Animation:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextColor3 = self.getSelectedTheme().TabTextColor}):Play()
						self.Animation:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageColor3 = self.getSelectedTheme().TabTextColor}):Play()
						self.Animation:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.7}):Play()
						self.Animation:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.2}):Play()
						self.Animation:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
						self.Animation:Create(OtherTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
						OtherTabButton.UIStroke.Thickness = 1
						OtherTabButton.UIStroke.Color = self.getSelectedTheme().TabStroke
						local otherGlow = OtherTabButton:FindFirstChild("HoverGlow")
						if otherGlow and otherGlow:IsA("UIStroke") then
							otherGlow.Transparency = 1
						end
					end
				end

				if self.Elements.UIPageLayout.CurrentPage ~= TabPage then
					self.Elements.UIPageLayout:JumpTo(TabPage)
				end

				if type(self.trackTabActivation) == "function" then
					pcall(self.trackTabActivation, {
						tabId = tostring(tabPersistenceId),
						name = tostring(Name),
						source = tostring(source or "activate")
					})
				end

				return true
			end

			tabRecord.Activate = activateTab

			TabButton.Interact.MouseEnter:Connect(function()
				if self.Elements.UIPageLayout.CurrentPage == TabPage then
					return
				end
				tabHover = true
				applyTabHoverVisual(0.14)
			end)

			TabButton.Interact.MouseLeave:Connect(function()
				tabHover = false
				UpdateTabColors()
				applyTabHoverVisual(0.14)
			end)
	
			TabButton.Interact.MouseButton1Click:Connect(function()
				if tabRecord.SuppressNextClick then
					tabRecord.SuppressNextClick = false
					return
				end

				activateTab(false, "tab_button")
			end)
	
			-- Preserve module context for Tab:Create* methods where `self` is Tab.
			local Tab = setmetatable({}, { __index = self })
			Tab.__TabRecord = tabRecord
			function Tab:GetInternalRecord()
				return tabRecord
			end
			tabRecord.Tab = Tab
	
			-- Element tracking system for extended API
			local elementSync = self.ElementSync
			local tabSyncId = tabRecord.PersistenceId or tabRecord.Name or tostring(TabPage)
			local tabVirtualHostId = "tab:" .. tostring(tabPersistenceId)
			local viewportVirtualization = self.ViewportVirtualization
			local tabSyncTokens = {}
			local TabElements = {} -- Stores all elements created in this tab
			local TabSections = {}-- Stores all sections created in this tab
			local currentImplicitSection = nil
			local hoverProvider = nil
			local virtualHostRegistered = false
			local syncHoverBindingsFromPointer
			local markHoverSyncDirty
			local registerHoverBinding
			local cleanupHoverBinding
			local cleanupAllHoverBindings
			local getHoverBinding

			local function markVirtualHostDirty(reason)
				if viewportVirtualization and type(viewportVirtualization.refreshHost) == "function" then
					pcall(viewportVirtualization.refreshHost, tabVirtualHostId, reason or "tab_update")
				end
			end

			local function registerVirtualHost()
				if not (viewportVirtualization and type(viewportVirtualization.registerHost) == "function") then
					return false
				end
				local okRegister, registerResult = pcall(viewportVirtualization.registerHost, tabVirtualHostId, TabPage, {
					mode = "auto"
				})
				virtualHostRegistered = okRegister and registerResult == true
				return virtualHostRegistered
			end

			local function unregisterVirtualHost()
				if not virtualHostRegistered then
					return
				end
				virtualHostRegistered = false
				if viewportVirtualization and type(viewportVirtualization.unregisterHost) == "function" then
					pcall(viewportVirtualization.unregisterHost, tabVirtualHostId)
				end
			end

			local function registerVirtualElement(guiObject, elementName, elementType, syncToken)
				if not virtualHostRegistered then
					return nil
				end
				if not (viewportVirtualization and type(viewportVirtualization.registerElement) == "function") then
					return nil
				end
				local okToken, virtualToken = pcall(viewportVirtualization.registerElement, tabVirtualHostId, guiObject, {
					meta = {
						name = elementName,
						elementType = elementType,
						tabId = tabPersistenceId
					},
					onWake = function()
						if syncToken and elementSync then
							elementSync.resync(syncToken, "viewport_wake")
						end
						markHoverSyncDirty()
						task.defer(function()
							syncHoverBindingsFromPointer(nil, true)
						end)
					end
				})
				if not okToken then
					return nil
				end
				if guiObject and guiObject.SetAttribute and type(virtualToken) == "string" then
					guiObject:SetAttribute("RayfieldVirtualToken", virtualToken)
				end
				return virtualToken
			end

			registerVirtualHost()

			do
				local moduleValue = self.HoverProviderModule
				if type(moduleValue) ~= "table" and type(self.ResolveHoverProviderModule) == "function" then
					moduleValue = self.ResolveHoverProviderModule()
				end
				if type(moduleValue) == "table" and type(moduleValue.create) == "function" then
					local okCreate, providerOrErr = pcall(moduleValue.create, {
						RunService = self.RunService,
						UserInputService = self.UserInputService,
						HttpService = self.HttpService,
						PageLayout = self.Elements.UIPageLayout,
						TabPage = TabPage,
						HoverSyncInterval = 1 / 30,
						onCurrentPageChanged = function()
							markVirtualHostDirty("current_page_changed")
							if elementSync and self.Elements.UIPageLayout.CurrentPage == TabPage then
								elementSync.resyncTab(tabSyncId, "tab_page_changed")
							end
						end
					})
					if okCreate and type(providerOrErr) == "table" then
						hoverProvider = providerOrErr
					end
				end
			end
			if type(hoverProvider) ~= "table" then
				hoverProvider = {
					markDirty = function() end,
					sync = function() end,
					registerBinding = function()
						return nil
					end,
					cleanupBinding = function() end,
					cleanupAll = function() end,
					getBinding = function()
						return nil
					end,
					destroy = function() end
				}
			end

			markHoverSyncDirty = function()
				if type(hoverProvider.markDirty) == "function" then
					hoverProvider.markDirty()
				end
			end

			syncHoverBindingsFromPointer = function(point, force)
				if type(hoverProvider.sync) == "function" then
					hoverProvider.sync(point, force)
				end
			end

			cleanupHoverBinding = function(key)
				if type(hoverProvider.cleanupBinding) == "function" then
					hoverProvider.cleanupBinding(key)
				end
			end

			cleanupAllHoverBindings = function()
				if type(hoverProvider.cleanupAll) == "function" then
					hoverProvider.cleanupAll()
				end
			end

			registerHoverBinding = function(guiObject, onEnter, onLeave, key)
				if type(hoverProvider.registerBinding) ~= "function" then
					return nil
				end
				return hoverProvider.registerBinding(guiObject, onEnter, onLeave, key)
			end

			getHoverBinding = function(key)
				if type(hoverProvider.getBinding) ~= "function" then
					return nil
				end
				return hoverProvider.getBinding(key)
			end

			TabPage.Destroying:Connect(function()
				tabRegistry.unregisterRecord(tabPersistenceId)
				if type(hoverProvider.destroy) == "function" then
					hoverProvider.destroy()
				end
				for _, trackedElement in ipairs(TabElements) do
					local elementObject = trackedElement and trackedElement.Object
					if type(elementObject) == "table" then
						local cleanupScopeId = nil
						if type(elementObject.GetCleanupScope) == "function" then
							local okScope, scopeValue = pcall(elementObject.GetCleanupScope, elementObject)
							if okScope and type(scopeValue) == "string" and scopeValue ~= "" then
								cleanupScopeId = scopeValue
							end
						end
						if not cleanupScopeId and type(elementObject.__CleanupScope) == "string" and elementObject.__CleanupScope ~= "" then
							cleanupScopeId = elementObject.__CleanupScope
						end
						if cleanupScopeId then
							ownershipCleanupScope(cleanupScopeId, {
								destroyInstances = false,
								clearAttributes = true
							})
						end
					end
				end
				cleanupAllHoverBindings()
				unregisterVirtualHost()
				if elementSync and tabSyncTokens then
					for token in pairs(tabSyncTokens) do
						elementSync.unregister(token)
						tabSyncTokens[token] = nil
					end
				end
			end)
			TabPage.AncestryChanged:Connect(function()
				markVirtualHostDirty("tab_reparent")
			end)

			local function registerElementSync(spec)
				if not elementSync then
					return nil
				end
				spec = spec or {}
				spec.tabId = tabSyncId
				local token = elementSync.register(spec)
				if token then
					tabSyncTokens[token] = true
				end
				return token
			end

			local function unregisterElementSync(token)
				if not token or not elementSync then
					return
				end
				elementSync.unregister(token)
				tabSyncTokens[token] = nil
			end

			local function commitElementSync(token, nextState, options)
				if not token or not elementSync then
					return false, nil
				end
				return elementSync.commit(token, nextState, options)
			end

			local function getCollapsedSectionsMap()
				if type(self.getInternalSetting) ~= "function" then
					return {}
				end
				local map = self.getInternalSetting("Layout", "collapsedSections")
				if type(map) ~= "table" then
					return {}
				end
				return cloneSerializable(map)
			end

			local function setCollapsedSectionsMap(nextMap)
				if type(self.setInternalSetting) == "function" then
					self.setInternalSetting("Layout", "collapsedSections", cloneSerializable(nextMap or {}), true)
					return
				end
				if type(self.getSetting) == "function" and type(self.SaveConfiguration) == "function" then
					self.SaveConfiguration()
				end
			end

			local function persistCollapsedState(sectionKey, collapsed)
				if type(sectionKey) ~= "string" or sectionKey == "" then
					return
				end
				local map = getCollapsedSectionsMap()
				map[sectionKey] = collapsed == true
				setCollapsedSectionsMap(map)
			end

			local function resolveElementParent(elementType, elementObject)
				if not (elementObject and type(elementObject) == "table") then
					return TabPage
				end
				if elementType == "Section" or elementType == "CollapsibleSection" then
					return TabPage
				end

				local explicitSection = rawget(elementObject, "__ParentSection")
				if type(explicitSection) == "table" then
					local content = rawget(explicitSection, "__SectionContentFrame")
					if content and content.Parent then
						return content
					end
				end

				if currentImplicitSection then
					local implicitContent = currentImplicitSection.ContentFrame
					if implicitContent and implicitContent.Parent then
						return implicitContent
					end
				end

				return TabPage
			end

			local hoverCueElementTypes = {
				Button = true,
				Toggle = true,
				Dropdown = true,
				Input = true,
				Keybind = true,
				ConfirmButton = true
			}
	
			-- Helper function to add extended API to all elements
			local function addExtendedAPI(elementObject, elementName, elementType, guiObject, hoverBindingKey, syncToken)
				local flagName = type(elementObject) == "table" and tostring(elementObject.Flag or "") or ""
				local baseFavoriteId = nil
				if flagName ~= "" then
					baseFavoriteId = "flag:" .. flagName
				else
					local layoutOrder = (guiObject and tonumber(guiObject.LayoutOrder)) or 0
					baseFavoriteId = string.format(
						"path:%s:%s:%s:%d",
						tostring(tabPersistenceId),
						tostring(elementType or "Element"),
						tostring(elementName or "Unnamed"),
						layoutOrder
					)
				end

				local favoriteId = baseFavoriteId
				local registryForId = resolveControlRegistry()
				if type(registryForId.allocateUniqueControlId) == "function" then
					favoriteId = registryForId.allocateUniqueControlId(baseFavoriteId, guiObject)
				end

				local internalName = tostring(elementName or "Unnamed")
				local controlRecord = {
					Id = favoriteId,
					Name = internalName,
					InternalName = internalName,
					DisplayName = internalName,
					Type = tostring(elementType or "Element"),
					Flag = flagName ~= "" and flagName or nil,
					TabPersistenceId = tabPersistenceId,
					GuiObject = guiObject,
					ElementObject = elementObject,
					TabPage = TabPage,
					PinButton = nil,
					CleanupScope = nil,
					LocalizationKey = ""
				}
				controlRecord.LocalizationKey = resolveLocalizationKey(controlRecord)
				local registryForLabel = resolveControlRegistry()
				if type(registryForLabel.resolveInitialDisplayLabel) == "function" then
					registryForLabel.resolveInitialDisplayLabel(controlRecord)
				else
					applyControlDisplayLabel(controlRecord, nil)
				end

				local function readCurrentValue()
					if type(elementObject) ~= "table" then
						return nil
					end
					if type(elementObject.Get) == "function" then
						local okGet, valueOrErr = pcall(elementObject.Get, elementObject)
						if okGet then
							return cloneSerializable(valueOrErr)
						end
					end
					return cloneSerializable(rawget(elementObject, "CurrentValue"))
				end

				local function emitControlInteraction(action, extra)
					if type(self.trackElementInteraction) ~= "function" then
						return
					end
					local payload = {
						action = tostring(action or "interact"),
						id = tostring(favoriteId),
						name = tostring(controlRecord.Name),
						type = tostring(controlRecord.Type),
						flag = controlRecord.Flag and tostring(controlRecord.Flag) or nil,
						tabId = tostring(tabPersistenceId),
						value = readCurrentValue()
					}
					if type(extra) == "table" then
						for key, value in pairs(extra) do
							payload[key] = value
						end
					end
					pcall(self.trackElementInteraction, payload)
				end

				function elementObject:GetInspectorSnapshot()
					return {
						id = tostring(favoriteId),
						name = tostring(controlRecord.DisplayName or controlRecord.Name),
						internalName = tostring(controlRecord.InternalName or controlRecord.Name),
						displayName = tostring(controlRecord.DisplayName or controlRecord.Name),
						localizationKey = tostring(controlRecord.LocalizationKey or resolveLocalizationKey(controlRecord)),
						type = tostring(controlRecord.Type),
						flag = controlRecord.Flag and tostring(controlRecord.Flag) or nil,
						tabId = tostring(tabPersistenceId),
						value = readCurrentValue()
					}
				end
				local resolvedParent = resolveElementParent(elementType, elementObject)
				if guiObject and resolvedParent and guiObject.Parent ~= resolvedParent then
					guiObject.Parent = resolvedParent
				end

				local cleanupScopeId = ownershipCreateScope("element:" .. tostring(favoriteId), {
					kind = "element",
					tabId = tabPersistenceId,
					favoriteId = favoriteId,
					elementType = tostring(elementType or "Element"),
					elementName = tostring(elementName or "Unnamed")
				})
				if cleanupScopeId and guiObject then
					ownershipClaimInstance(guiObject, cleanupScopeId, {
						favoriteId = favoriteId,
						tabId = tabPersistenceId,
						elementType = tostring(elementType or "Element")
					})
					controlRecord.CleanupScope = cleanupScopeId
				end

				local registryForRegister = resolveControlRegistry()
				if type(registryForRegister.registerControlRecord) == "function" then
					registryForRegister.registerControlRecord(controlRecord)
				else
					allControlsById[favoriteId] = controlRecord
					table.insert(controlOrder, favoriteId)
					if controlRecord.Flag then
						controlsByFlag[controlRecord.Flag] = controlRecord
						controlsByFlag["flag:" .. controlRecord.Flag] = controlRecord
					end
				end

				local virtualToken = registerVirtualElement(guiObject, elementName, elementType, syncToken)
				local detachable = self.makeElementDetachable and self.makeElementDetachable(guiObject, elementName, elementType) or nil
				if detachable and type(detachable.SetPersistenceMetadata) == "function" then
					local metadata = {
						flag = type(elementObject) == "table" and elementObject.Flag or nil,
						tabId = tabPersistenceId,
						virtualHostId = tabVirtualHostId,
						elementName = elementName,
						elementType = elementType
					}
					pcall(detachable.SetPersistenceMetadata, metadata)
				end
				local ancestrySyncConnection = nil
				local pinConnection = nil
				local contextMenuConnection = nil
				local tooltipHoverBindingKey = nil
				local hoverCueBindingKey = nil
				local tooltipTouchBeganConnection = nil
				local tooltipTouchEndedConnection = nil
				local tooltipTouchActive = false
				local tooltipTouchToken = 0
				if guiObject and guiObject.SetAttribute then
					guiObject:SetAttribute("RayfieldElementSyncToken", syncToken)
					guiObject:SetAttribute("RayfieldFavoriteId", favoriteId)
					guiObject:SetAttribute("RayfieldLocalizationKey", controlRecord.LocalizationKey)
				end
				if syncToken and elementSync and guiObject and guiObject.AncestryChanged then
					ancestrySyncConnection = guiObject.AncestryChanged:Connect(function()
						task.defer(function()
							if guiObject and guiObject.Parent then
								elementSync.resync(syncToken, "element_reparent")
							end
						end)
					end)
				end

				local function applyTooltipBehavior(options)
					if tooltipHoverBindingKey then
						cleanupHoverBinding(tooltipHoverBindingKey)
						tooltipHoverBindingKey = nil
					end
					if tooltipTouchBeganConnection then
						tooltipTouchBeganConnection:Disconnect()
						tooltipTouchBeganConnection = nil
					end
					if tooltipTouchEndedConnection then
						tooltipTouchEndedConnection:Disconnect()
						tooltipTouchEndedConnection = nil
					end
					hideTooltip(favoriteId)

					if not (guiObject and guiObject:IsA("GuiObject")) then
						return
					end
					local tooltipText = tostring((options and options.Text) or "")
					if tooltipText == "" then
						return
					end
					local desktopDelay = clampNumber(options and options.DesktopDelay, 0.01, 5, 0.15)
					local mobileDelay = clampNumber(options and options.MobileDelay, 0.01, 5, 0.35)

					tooltipHoverBindingKey = registerHoverBinding(guiObject,
						function()
							task.delay(desktopDelay, function()
								local binding = getHoverBinding(tooltipHoverBindingKey)
								if binding and binding.Hovered and guiObject and guiObject.Parent then
									showTooltip(favoriteId, guiObject, tooltipText)
								end
							end)
						end,
						function()
							hideTooltip(favoriteId)
						end,
						"tooltip:" .. favoriteId
					)

					tooltipTouchBeganConnection = guiObject.InputBegan:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.Touch then
							return
						end
						tooltipTouchActive = true
						tooltipTouchToken = tooltipTouchToken + 1
						local token = tooltipTouchToken
						task.delay(mobileDelay, function()
							if tooltipTouchActive and tooltipTouchToken == token and guiObject and guiObject.Parent then
								showTooltip(favoriteId, guiObject, tooltipText)
							end
						end)
					end)
					tooltipTouchEndedConnection = guiObject.InputEnded:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.Touch then
							return
						end
						tooltipTouchActive = false
						hideTooltip(favoriteId)
					end)
				end

				local canAttachPinButton = (guiObject and guiObject:IsA("GuiObject")) and (
					controlRecord.Type == "Button"
					or controlRecord.Type == "Toggle"
					or controlRecord.Type == "Slider"
					or controlRecord.Type == "Input"
					or controlRecord.Type == "Dropdown"
					or controlRecord.Type == "Keybind"
					or controlRecord.Type == "ColorPicker"
					or controlRecord.Type == "TrackBar"
					or controlRecord.Type == "StatusBar"
					or controlRecord.Type == "Bar"
					or controlRecord.Type == "NumberStepper"
					or controlRecord.Type == "ConfirmButton"
					or controlRecord.Type == "Gallery"
					or controlRecord.Type == "DataGrid"
					or controlRecord.Type == "Image"
					or controlRecord.Type == "Chart"
					or controlRecord.Type == "LogConsole"
					or controlRecord.Type == "LoadingSpinner"
					or controlRecord.Type == "LoadingBar"
				)
				if canAttachPinButton then
					local pinButton = Instance.new("TextButton")
					pinButton.Name = "FavoritePin"
					pinButton.AnchorPoint = Vector2.new(1, 0)
					pinButton.Position = UDim2.new(1, -6, 0, 4)
					pinButton.Size = UDim2.new(0, 16, 0, 16)
					pinButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
					pinButton.BackgroundTransparency = 0.25
					pinButton.BorderSizePixel = 0
					pinButton.Text = "o"
					pinButton.TextScaled = true
					pinButton.TextWrapped = true
					pinButton.TextColor3 = Color3.fromRGB(225, 225, 225)
					pinButton.Font = Enum.Font.GothamBold
					pinButton.ZIndex = (guiObject.ZIndex or 1) + 7
					pinButton.AutoButtonColor = true
					local showPinBadges = true
					local registryForPinBadge = resolveControlRegistry()
					if type(registryForPinBadge.getPinBadgesVisible) == "function" then
						showPinBadges = registryForPinBadge.getPinBadgesVisible()
					end
					pinButton.Visible = showPinBadges
					pinButton.Parent = guiObject

					local pinCorner = Instance.new("UICorner")
					pinCorner.CornerRadius = UDim.new(0, 5)
					pinCorner.Parent = pinButton

					controlRecord.PinButton = pinButton
					applyPinnedVisual(controlRecord)

					pinConnection = pinButton.MouseButton1Click:Connect(function()
						local currentlyPinned = pinnedControlIds[favoriteId] == true
						if currentlyPinned then
							unpinControl(favoriteId)
						else
							pinControl(favoriteId)
						end
					end)
				end

				local tooltipOptions = rawget(elementObject, "__TooltipOptions")
				if tooltipOptions == nil and type(elementObject) == "table" then
					local tooltipText = rawget(elementObject, "Tooltip")
					if tooltipText ~= nil then
						tooltipOptions = { Text = tostring(tooltipText) }
					end
				end
				if type(tooltipOptions) == "table" then
					applyTooltipBehavior(tooltipOptions)
				end

				if guiObject and hoverCueElementTypes[controlRecord.Type] then
					hoverCueBindingKey = registerHoverBinding(guiObject,
						function()
							emitUICue("hover")
						end,
						nil,
						"cue:hover:" .. favoriteId
					)
				end

				local function copyText(textValue)
					local clipboard = nil
					if type(setclipboard) == "function" then
						clipboard = setclipboard
					elseif type(toclipboard) == "function" then
						clipboard = toclipboard
					end
					if type(clipboard) ~= "function" then
						return false, "Clipboard unavailable."
					end
					local okCopy, copyErr = pcall(clipboard, tostring(textValue or ""))
					if not okCopy then
						return false, tostring(copyErr)
					end
					return true, "Copied."
				end

				if guiObject and guiObject.InputBegan then
					contextMenuConnection = guiObject.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							emitControlInteraction("click", { inputType = "mouse1" })
						elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
							emitControlInteraction("right_click", { inputType = "mouse2" })
						elseif input.UserInputType == Enum.UserInputType.Touch then
							emitControlInteraction("touch", { inputType = "touch" })
						end
						if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
							return
						end
						if type(self.showContextMenu) ~= "function" then
							return
						end
						local pointerX = input.Position and input.Position.X or guiObject.AbsolutePosition.X
						local pointerY = input.Position and input.Position.Y or guiObject.AbsolutePosition.Y
						self.showContextMenu({
							{
								id = "pin_toggle",
								label = (pinnedControlIds[favoriteId] == true) and L("context.unpin_control", "Unpin Control") or L("context.pin_control", "Pin Control"),
								callback = function()
									local currentlyPinned = pinnedControlIds[favoriteId] == true
									if currentlyPinned then
										unpinControl(favoriteId)
									else
										pinControl(favoriteId)
									end
								end
							},
							{
								id = "copy_name",
								label = L("context.copy_name", "Copy Name"),
								callback = function()
									copyText(controlRecord.DisplayName or controlRecord.Name)
								end
							},
							{
								id = "copy_id",
								label = L("context.copy_id", "Copy ID"),
								callback = function()
									copyText(controlRecord.Id)
								end
							},
							{
								id = "copy_localization_key",
								label = L("context.copy_localization_key", "Copy Localization Key"),
								callback = function()
									copyText(controlRecord.LocalizationKey or resolveLocalizationKey(controlRecord))
								end
							},
							{
								id = "reset_display_label",
								label = L("context.reset_display_label", "Reset Display Label"),
								callback = function()
									resetControlDisplayLabelByIdOrFlag(controlRecord.Id, { persist = true })
								end
							}
						}, {
							x = pointerX,
							y = pointerY
						})
					end)
				end

				if type(elementObject.Set) == "function" and rawget(elementObject, "__TelemetrySetWrapped") ~= true then
					local originalSet = elementObject.Set
					elementObject.Set = function(target, ...)
						local results = { originalSet(target, ...) }
						local firstArg = select(1, ...)
						emitControlInteraction("set", {
							inputValue = cloneSerializable(firstArg)
						})
						return table.unpack(results)
					end
					rawset(elementObject, "__TelemetrySetWrapped", true)
				end

				emitControlRegistryChange("control_added")
	
				-- Destroy with tracking removal
				local originalDestroy = elementObject.Destroy
				elementObject.Destroy = function(self)
					if cleanupScopeId then
						ownershipCleanupScope(cleanupScopeId, {
							destroyInstances = false,
							clearAttributes = true
						})
						cleanupScopeId = nil
						self.__CleanupScope = nil
					end
					if hoverBindingKey then
						cleanupHoverBinding(hoverBindingKey)
					end
					if guiObject and guiObject.SetAttribute then
						guiObject:SetAttribute("RayfieldElementSyncToken", nil)
						guiObject:SetAttribute("RayfieldVirtualToken", nil)
						guiObject:SetAttribute("RayfieldFavoriteId", nil)
						guiObject:SetAttribute("RayfieldLocalizationKey", nil)
					end
					if viewportVirtualization and type(viewportVirtualization.unregisterElement) == "function" then
						if virtualToken then
							pcall(viewportVirtualization.unregisterElement, virtualToken)
						elseif guiObject then
							pcall(viewportVirtualization.unregisterElement, guiObject)
						end
					end
					virtualToken = nil
					unregisterElementSync(syncToken)
					if ancestrySyncConnection then
						ancestrySyncConnection:Disconnect()
						ancestrySyncConnection = nil
					end
					if pinConnection then
						pinConnection:Disconnect()
						pinConnection = nil
					end
					if contextMenuConnection then
						contextMenuConnection:Disconnect()
						contextMenuConnection = nil
					end
					if tooltipTouchBeganConnection then
						tooltipTouchBeganConnection:Disconnect()
						tooltipTouchBeganConnection = nil
					end
					if tooltipTouchEndedConnection then
						tooltipTouchEndedConnection:Disconnect()
						tooltipTouchEndedConnection = nil
					end
					if tooltipHoverBindingKey then
						cleanupHoverBinding(tooltipHoverBindingKey)
						tooltipHoverBindingKey = nil
					end
					if hoverCueBindingKey then
						cleanupHoverBinding(hoverCueBindingKey)
						hoverCueBindingKey = nil
					end
					hideTooltip(favoriteId)
					if controlRecord.PinButton and controlRecord.PinButton.Parent then
						controlRecord.PinButton:Destroy()
					end
					local registryForUnregister = resolveControlRegistry()
					if type(registryForUnregister.unregisterControlRecord) == "function" then
						registryForUnregister.unregisterControlRecord(controlRecord)
					else
						if controlRecord.Flag then
							controlsByFlag[controlRecord.Flag] = nil
							controlsByFlag["flag:" .. controlRecord.Flag] = nil
						end
						allControlsById[favoriteId] = nil
					end
					if detachable and detachable.Destroy then
						detachable.Destroy()
					end
					if originalDestroy then
						originalDestroy(self)
					end
					-- Remove from tracking
					for i, element in ipairs(TabElements) do
						if element.Object == elementObject then
							table.remove(TabElements, i)
							break
						end
					end
					emitControlRegistryChange("control_removed")
					markVirtualHostDirty("element_destroy")
				end
	
				-- Visibility methods
				function elementObject:Show()
					guiObject.Visible = true
					if syncToken and elementSync then
						elementSync.resync(syncToken, "element_show")
					end
					markVirtualHostDirty("element_show")
				end
	
				function elementObject:Hide()
					guiObject.Visible = false
					if syncToken and elementSync then
						elementSync.resync(syncToken, "element_hide")
					end
					markVirtualHostDirty("element_hide")
				end
	
				function elementObject:SetVisible(visible)
					guiObject.Visible = visible
					if syncToken and elementSync then
						elementSync.resync(syncToken, "element_set_visible")
					end
					markVirtualHostDirty("element_set_visible")
				end
	
				function elementObject:GetParent()
					return Tab
				end
	
				if detachable then
					function elementObject:Detach(position)
						local result = detachable.Detach(position)
						if syncToken and elementSync then
							elementSync.resync(syncToken, "element_detach")
						end
						markVirtualHostDirty("element_detach")
						return result
					end
	
					function elementObject:Dock()
						local result = detachable.Dock()
						if syncToken and elementSync then
							elementSync.resync(syncToken, "element_dock")
						end
						markVirtualHostDirty("element_dock")
						return result
					end
	
					function elementObject:GetRememberedState()
						return detachable.GetRememberedState()
					end
	
					function elementObject:IsDetached()
						return detachable.IsDetached()
					end
				end
	
				-- Add metadata
				elementObject.Name = internalName
				elementObject.DisplayName = controlRecord.DisplayName
				elementObject.Type = elementType
				elementObject.Flag = type(elementObject) == "table" and elementObject.Flag or nil
				elementObject.__ElementSyncToken = syncToken
				elementObject.__TabPersistenceId = tabPersistenceId
				elementObject.__TabLayoutOrder = tonumber(TabPage.LayoutOrder) or 0
				elementObject.__ElementLayoutOrder = (guiObject and tonumber(guiObject.LayoutOrder)) or 0
				elementObject.__GuiObject = guiObject
				elementObject.__TabPage = TabPage
				elementObject.__FavoriteId = favoriteId
				elementObject.__CleanupScope = cleanupScopeId
				elementObject.__LocalizationKey = controlRecord.LocalizationKey

				function elementObject:GetFavoriteId()
					return favoriteId
				end

				function elementObject:GetCleanupScope()
					return cleanupScopeId
				end

				function elementObject:Pin()
					return pinControl(favoriteId)
				end

				function elementObject:Unpin()
					return unpinControl(favoriteId)
				end

				function elementObject:IsPinned()
					return pinnedControlIds[favoriteId] == true
				end

				function elementObject:SetDisplayLabel(label)
					return setControlDisplayLabelByIdOrFlag(favoriteId, label, { persist = true })
				end

				function elementObject:GetDisplayLabel()
					return tostring(controlRecord.DisplayName or controlRecord.Name or "")
				end

				function elementObject:ResetDisplayLabel()
					return resetControlDisplayLabelByIdOrFlag(favoriteId, { persist = true })
				end

				function elementObject:GetLocalizationKey()
					return tostring(controlRecord.LocalizationKey or resolveLocalizationKey(controlRecord))
				end

				function elementObject:SetTooltip(textOrOptions)
					local options
					if type(textOrOptions) == "table" then
						options = {
							Text = tostring(textOrOptions.Text or textOrOptions.text or ""),
							DesktopDelay = clampNumber(textOrOptions.DesktopDelay or textOrOptions.desktopDelay, 0.01, 5, 0.15),
							MobileDelay = clampNumber(textOrOptions.MobileDelay or textOrOptions.mobileDelay, 0.01, 5, 0.35)
						}
					else
						options = {
							Text = tostring(textOrOptions or ""),
							DesktopDelay = 0.15,
							MobileDelay = 0.35
						}
					end
					elementObject.__TooltipOptions = options
					applyTooltipBehavior(options)
					return true, "ok"
				end

				function elementObject:ClearTooltip()
					elementObject.__TooltipOptions = nil
					applyTooltipBehavior({Text = ""})
					hideTooltip(favoriteId)
					return true, "ok"
				end

				-- Add to tracking
				table.insert(TabElements, {
					Name = elementName,
					Type = elementType,
					Object = elementObject,
					GuiObject = guiObject,
					HoverBindingKey = hoverBindingKey,
					SyncToken = syncToken
				})
	
				return elementObject
			end
	
			-- Tab utility functions
			function Tab:GetElements()
				return TabElements
			end
	
			function Tab:FindElement(name)
				for _, element in ipairs(TabElements) do
					if element.Name == name then
						return element.Object
					end
				end
				return nil
			end
	
			function Tab:Clear()
				if elementSync then
					for token in pairs(tabSyncTokens) do
						elementSync.unregister(token)
						tabSyncTokens[token] = nil
					end
				end
				-- Snapshot elements and clear tracking first to avoid
				-- concurrent modification (custom Destroy also removes from TabElements)
				local snapshot = {}
				for i, element in ipairs(TabElements) do
					snapshot[i] = element
				end
				-- Clear tracking table before destroying to prevent index corruption
				for i = #TabElements, 1, -1 do
					TabElements[i] = nil
				end
				-- Now safely destroy each element
				for _, element in ipairs(snapshot) do
					if element.Object and element.Object.Destroy then
						element.Object:Destroy()
					end
				end
				cleanupAllHoverBindings()
				markVirtualHostDirty("tab_clear")
			end
	
			-- Button
			function Tab:CreateButton(ButtonSettings)
				if (type(self.ButtonFactoryModule) ~= "table" or type(self.ButtonFactoryModule.create) ~= "function")
					and type(self.ResolveButtonFactory) == "function" then
					local okResolve, resolvedModule = pcall(self.ResolveButtonFactory)
					if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
						self.ButtonFactoryModule = resolvedModule
					end
				end

				if type(self.ButtonFactoryModule) == "table" and type(self.ButtonFactoryModule.create) == "function" then
					return self.ButtonFactoryModule.create({
						Tab = Tab,
						TabPage = TabPage,
						Settings = Settings,
						addExtendedAPI = addExtendedAPI,
						registerHoverBinding = registerHoverBinding,
						emitUICue = emitUICue,
						settings = ButtonSettings
					})
				end

				local ButtonValue = {}
	
				local Button = self.Elements.Template.Button:Clone()
				Button.Name = ButtonSettings.Name
				Button.Title.Text = ButtonSettings.Name
				Button.Visible = true
				Button.Parent = TabPage
	
				Button.BackgroundTransparency = 1
				Button.UIStroke.Transparency = 1
				Button.Title.TextTransparency = 1
	
				self.Animation:Create(Button, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Button.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Button.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	
	
				Button.Interact.MouseButton1Click:Connect(function()
					emitUICue("click")
					local Success, Response = pcall(ButtonSettings.Callback)
					-- Prevents animation from trying to play if the button's callback called RayfieldLibrary:Destroy()
					if self.rayfieldDestroyed() then
						return
					end
					if not Success then
						emitUICue("error")
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						Button.Title.Text = "Callback Error"
						print("Rayfield | "..ButtonSettings.Name.." Callback Error " ..tostring(Response))
						warn('Check docs.sirius.menu for help with Rayfield specific development.')
						task.wait(0.5)
						Button.Title.Text = ButtonSettings.Name
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
						self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					else
						emitUICue("success")
						if not ButtonSettings.Ext then
							self.SaveConfiguration(ButtonSettings.Name..'\n')
						end
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						task.wait(0.2)
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
						self.Animation:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end
				end)
	
				local buttonHoverBindingKey = registerHoverBinding(Button,
					function()
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.7}):Play()
					end,
					function()
						self.Animation:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {TextTransparency = 0.9}):Play()
					end
				)
	
				function ButtonValue:Set(NewButton)
					Button.Title.Text = NewButton
					Button.Name = NewButton
				end
	
				function ButtonValue:Destroy()
					Button:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(ButtonValue, ButtonSettings.Name, "Button", Button, buttonHoverBindingKey)
	
				return ButtonValue
			end
	
			local resolveElementParentFromSettings
			local connectThemeRefresh

			-- ColorPicker
			local function createComponentWidget(factoryMethod, settingsOrArg1, arg2, arg3, arg4)
				local moduleValue = resolveComponentWidgetsFactory()
				if type(moduleValue) ~= "table" or type(moduleValue[factoryMethod]) ~= "function" then
					warn("Rayfield | Component widgets factory module unavailable for method: " .. tostring(factoryMethod))
					return nil
				end
				return moduleValue[factoryMethod]({
					self = self,
					Tab = Tab,
					TabPage = TabPage,
					Settings = Settings,
					addExtendedAPI = addExtendedAPI,
					registerHoverBinding = registerHoverBinding,
					connectThemeRefresh = connectThemeRefresh,
					resolveElementParentFromSettings = resolveElementParentFromSettings,
					cloneSerializable = cloneSerializable,
					clampNumber = clampNumber,
					roundToPrecision = roundToPrecision,
					emitUICue = emitUICue,
					Players = game:GetService("Players")
				}, settingsOrArg1, arg2, arg3, arg4)
			end
			function Tab:CreateColorPicker(ColorPickerSettings) -- by Throit
				return createComponentWidget("createColorPicker", ColorPickerSettings)
			end

			local function createSectionWidget(factoryMethod, sectionSettings)
				local moduleValue = resolveSectionFactory()
				if type(moduleValue) ~= "table" or type(moduleValue[factoryMethod]) ~= "function" then
					warn("Rayfield | Section factory module unavailable for method: " .. tostring(factoryMethod))
					return nil
				end
				return moduleValue[factoryMethod]({
					self = self,
					Tab = Tab,
					TabPage = TabPage,
					Settings = Settings,
					tabPersistenceId = tabPersistenceId,
					addExtendedAPI = addExtendedAPI,
					getCollapsedSectionsMap = getCollapsedSectionsMap,
					persistCollapsedState = persistCollapsedState,
					getCurrentImplicitSection = function()
						return currentImplicitSection
					end,
					setCurrentImplicitSection = function(value)
						currentImplicitSection = value
					end,
					tabSections = TabSections,
					tabElements = TabElements,
					getSectionSpacingDone = function()
						return SDone == true
					end,
					setSectionSpacingDone = function(value)
						SDone = value == true
					end
				}, sectionSettings)
			end

			-- Section
			function Tab:CreateSection(SectionName)
				return createSectionWidget("createSection", SectionName)
			end

			function Tab:CreateCollapsibleSection(sectionSettings)
				return createSectionWidget("createCollapsibleSection", sectionSettings)
			end

			resolveElementParentFromSettings = function(elementObject, sourceSettings)
				if type(sourceSettings) == "table" and type(sourceSettings.ParentSection) == "table" then
					elementObject.__ParentSection = sourceSettings.ParentSection
				end
				if type(sourceSettings) == "table" and sourceSettings.Tooltip ~= nil then
					elementObject.__TooltipOptions = {
						Text = tostring(sourceSettings.Tooltip),
						DesktopDelay = clampNumber(sourceSettings.TooltipDesktopDelay, 0.01, 5, 0.15),
						MobileDelay = clampNumber(sourceSettings.TooltipMobileDelay, 0.01, 5, 0.35)
					}
				end
			end

			connectThemeRefresh = function(handler)
				if type(handler) ~= "function" then
					return
				end
				self.Rayfield.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
					pcall(handler)
				end)
			end

			local function startRenderLoop(loopState, stepFn)
				if type(loopState) ~= "table" or type(stepFn) ~= "function" then
					return false, "Invalid render loop setup."
				end
				if loopState.Connection then
					return true, "already_running"
				end
				loopState.Connection = self.RunService.RenderStepped:Connect(function(deltaTime)
					pcall(stepFn, deltaTime)
				end)
				return true, "ok"
			end

			local function stopRenderLoop(loopState)
				if type(loopState) ~= "table" then
					return false, "Invalid render loop state."
				end
				if loopState.Connection then
					loopState.Connection:Disconnect()
					loopState.Connection = nil
					return true, "ok"
				end
				return true, "already_stopped"
			end

			function Tab:CreateNumberStepper(stepperSettings)
				return createComponentWidget("createNumberStepper", stepperSettings)
			end

			function Tab:CreateConfirmButton(confirmSettings)
				return createComponentWidget("createConfirmButton", confirmSettings)
			end

			function Tab:CreateImage(imageSettings)
				return createComponentWidget("createImage", imageSettings)
			end

			function Tab:CreateGallery(gallerySettings)
				return createComponentWidget("createGallery", gallerySettings)
			end

			function Tab:CreateDataGrid(dataGridSettings)
				local gridBuilderModule = resolveGridBuilder()
				local createFn = gridBuilderModule and gridBuilderModule.create or nil
				if type(createFn) ~= "function" then
					createFn = function(builderContext)
						if (type(self.DataGridFactoryModule) ~= "table" or type(self.DataGridFactoryModule.create) ~= "function")
							and type(self.ResolveDataGridFactory) == "function" then
							local okResolve, resolvedModule = pcall(self.ResolveDataGridFactory)
							if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
								self.DataGridFactoryModule = resolvedModule
							else
								warn("Rayfield | DataGrid module lazy-load failed: " .. tostring(okResolve and resolvedModule or "resolve error"))
							end
						end
						if type(self.DataGridFactoryModule) ~= "table" or type(self.DataGridFactoryModule.create) ~= "function" then
							warn("Rayfield | DataGrid factory module unavailable")
							return nil
						end
						return self.DataGridFactoryModule.create(builderContext)
					end
				end

				return createFn({
					self = self,
					TabPage = TabPage,
					Settings = Settings,
					settings = dataGridSettings,
					addExtendedAPI = addExtendedAPI,
					resolveElementParentFromSettings = resolveElementParentFromSettings,
					connectThemeRefresh = connectThemeRefresh,
					cloneSerializable = cloneSerializable,
					clampNumber = clampNumber,
					emitUICue = emitUICue
				})
			end

			function Tab:CreateChart(chartSettings)
				local chartBuilderModule = resolveChartBuilder()
				local createFn = chartBuilderModule and chartBuilderModule.create or nil
				if type(createFn) ~= "function" then
					createFn = function(builderContext)
						if (type(self.ChartFactoryModule) ~= "table" or type(self.ChartFactoryModule.create) ~= "function")
							and type(self.ResolveChartFactory) == "function" then
							local okResolve, resolvedModule = pcall(self.ResolveChartFactory)
							if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
								self.ChartFactoryModule = resolvedModule
							else
								warn("Rayfield | Chart module lazy-load failed: " .. tostring(okResolve and resolvedModule or "resolve error"))
							end
						end
						if type(self.ChartFactoryModule) ~= "table" or type(self.ChartFactoryModule.create) ~= "function" then
							warn("Rayfield | Chart factory module unavailable")
							return nil
						end
						return self.ChartFactoryModule.create(builderContext)
					end
				end

				return createFn({
					self = self,
					TabPage = TabPage,
					Settings = Settings,
					settings = chartSettings,
					addExtendedAPI = addExtendedAPI,
					resolveElementParentFromSettings = resolveElementParentFromSettings,
					connectThemeRefresh = connectThemeRefresh,
					cloneSerializable = cloneSerializable,
					clampNumber = clampNumber,
					isHeadlessPerformanceMode = isHeadlessPerformanceMode
				})
			end

			local function createFeedbackWidget(factoryMethod, rawSettings)
				local moduleValue = resolveFeedbackWidgetsFactory()
				if type(moduleValue) ~= "table" or type(moduleValue[factoryMethod]) ~= "function" then
					warn("Rayfield | Feedback widgets factory module unavailable for method: " .. tostring(factoryMethod))
					return nil
				end
				return moduleValue[factoryMethod]({
					self = self,
					Tab = Tab,
					TabPage = TabPage,
					Settings = Settings,
					addExtendedAPI = addExtendedAPI,
					resolveElementParentFromSettings = resolveElementParentFromSettings,
					connectThemeRefresh = connectThemeRefresh,
					subscribeGlobalLogs = subscribeGlobalLogs,
					cloneSerializable = cloneSerializable,
					clampNumber = clampNumber,
					packColor3 = packColor3,
					unpackColor3 = unpackColor3,
					startRenderLoop = startRenderLoop,
					stopRenderLoop = stopRenderLoop
				}, rawSettings)
			end

			function Tab:CreateLogConsole(logSettings)
				return createFeedbackWidget("createLogConsole", logSettings)
			end

			function Tab:CreateLoadingSpinner(spinnerSettings)
				return createFeedbackWidget("createLoadingSpinner", spinnerSettings)
			end

			function Tab:CreateLoadingBar(barSettings)
				return createFeedbackWidget("createLoadingBar", barSettings)
			end

			-- Divider
			function Tab:CreateDivider()
				return createComponentWidget("createDivider")
			end

			-- Label
			function Tab:CreateLabel(LabelText, Icon, Color, IgnoreTheme)
				return createComponentWidget("createLabel", LabelText, Icon, Color, IgnoreTheme)
			end

			-- Paragraph
			function Tab:CreateParagraph(ParagraphSettings)
				return createComponentWidget("createParagraph", ParagraphSettings)
			end

			-- Input
			-- Input
			function Tab:CreateInput(InputSettings)
				if (type(self.InputFactoryModule) ~= "table" or type(self.InputFactoryModule.create) ~= "function")
					and type(self.ResolveInputFactory) == "function" then
					local okResolve, resolvedModule = pcall(self.ResolveInputFactory)
					if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
						self.InputFactoryModule = resolvedModule
					end
				end

				if type(self.InputFactoryModule) ~= "table" or type(self.InputFactoryModule.create) ~= "function" then
					warn("Rayfield | Input factory module unavailable.")
					return nil
				end

				return self.InputFactoryModule.create({
					Tab = Tab,
					TabPage = TabPage,
					Settings = Settings,
					addExtendedAPI = addExtendedAPI,
					registerHoverBinding = registerHoverBinding,
					registerElementSync = registerElementSync,
					commitElementSync = commitElementSync,
					emitUICue = emitUICue,
					settings = InputSettings
				})
			end

			-- Dropdown
			function Tab:CreateDropdown(DropdownSettings)
				if (type(self.DropdownFactoryModule) ~= "table" or type(self.DropdownFactoryModule.create) ~= "function")
					and type(self.ResolveDropdownFactory) == "function" then
					local okResolve, resolvedModule = pcall(self.ResolveDropdownFactory)
					if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
						self.DropdownFactoryModule = resolvedModule
					end
				end

				if type(self.DropdownFactoryModule) ~= "table" or type(self.DropdownFactoryModule.create) ~= "function" then
					warn("Rayfield | Dropdown factory module unavailable.")
					return nil
				end

				return self.DropdownFactoryModule.create({
					Tab = Tab,
					TabPage = TabPage,
					Settings = Settings,
					addExtendedAPI = addExtendedAPI,
					registerHoverBinding = registerHoverBinding,
					registerElementSync = registerElementSync,
					commitElementSync = commitElementSync,
					emitUICue = emitUICue,
					settings = DropdownSettings
				})
			end

			local SequenceLib = self.KeybindSequence

			local function trim(value)
				if type(value) ~= "string" then
					return ""
				end
				local out = value:gsub("^%s+", "")
				out = out:gsub("%s+$", "")
				return out
			end

			local function resolveSequenceRuntimeOptions(sourceSettings)
				local maxSteps = 4
				local stepTimeoutMs = 800

				if SequenceLib and SequenceLib.DEFAULT_MAX_STEPS then
					maxSteps = SequenceLib.DEFAULT_MAX_STEPS
				end
				if SequenceLib and SequenceLib.DEFAULT_STEP_TIMEOUT_MS then
					stepTimeoutMs = SequenceLib.DEFAULT_STEP_TIMEOUT_MS
				end

				if sourceSettings then
					local customMaxSteps = tonumber(sourceSettings.MaxSteps)
					if customMaxSteps and customMaxSteps > 0 then
						maxSteps = math.floor(customMaxSteps)
					end

					local customTimeout = tonumber(sourceSettings.StepTimeoutMs)
					if customTimeout and customTimeout > 0 then
						stepTimeoutMs = math.floor(customTimeout)
					end
				end

				maxSteps = math.clamp(maxSteps, 1, 4)
				stepTimeoutMs = math.max(1, stepTimeoutMs)
				return maxSteps, stepTimeoutMs
			end

			local function normalizeSequenceBinding(rawBinding, sourceSettings)
				if not SequenceLib then
					if rawBinding == nil or tostring(rawBinding) == "" then
						return nil, nil, "sequence_lib_missing"
					end
					local fallback = tostring(rawBinding)
					local split = string.split(fallback, ">")
					local single = split[1]
					if single and single ~= "" then
						fallback = tostring(single)
					end
					return fallback, nil, nil
				end

				local maxSteps, _ = resolveSequenceRuntimeOptions(sourceSettings)
				return SequenceLib.normalize(rawBinding, {
					maxSteps = maxSteps
				})
			end

			local function parseSequenceInput(rawText, sourceSettings)
				if not SequenceLib then
					return normalizeSequenceBinding(rawText, sourceSettings)
				end

				local maxSteps, _ = resolveSequenceRuntimeOptions(sourceSettings)
				return SequenceLib.parseUserInput(rawText, sourceSettings and sourceSettings.ParseInput, {
					maxSteps = maxSteps,
					fallbackToDefault = true
				})
			end

			local function formatSequenceDisplay(canonical, steps, sourceSettings)
				if not canonical or canonical == "" then
					return ""
				end
				if not SequenceLib then
					return tostring(canonical)
				end

				local displaySource = steps
				if type(displaySource) ~= "table" or displaySource[1] == nil then
					displaySource = canonical
				end

				local display = SequenceLib.formatDisplay(displaySource, sourceSettings and sourceSettings.DisplayFormatter, {
					maxSteps = select(1, resolveSequenceRuntimeOptions(sourceSettings))
				})

				if type(display) ~= "string" or display == "" then
					return tostring(canonical)
				end

				return display
			end
	
			-- Keybind
			function Tab:CreateKeybind(KeybindSettings)
				if (type(self.KeybindFactoryModule) ~= "table" or type(self.KeybindFactoryModule.create) ~= "function")
					and type(self.ResolveKeybindFactory) == "function" then
					local okResolve, resolvedModule = pcall(self.ResolveKeybindFactory)
					if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
						self.KeybindFactoryModule = resolvedModule
					end
				end

				if type(self.KeybindFactoryModule) ~= "table" or type(self.KeybindFactoryModule.create) ~= "function" then
					warn("Rayfield | Keybind factory module unavailable.")
					return nil
				end

				return self.KeybindFactoryModule.create({
					Tab = Tab,
					TabPage = TabPage,
					Settings = Settings,
					SequenceLib = SequenceLib,
					trim = trim,
					resolveSequenceRuntimeOptions = resolveSequenceRuntimeOptions,
					normalizeSequenceBinding = normalizeSequenceBinding,
					parseSequenceInput = parseSequenceInput,
					formatSequenceDisplay = formatSequenceDisplay,
					addExtendedAPI = addExtendedAPI,
					registerHoverBinding = registerHoverBinding,
					ownershipTrackConnection = ownershipTrackConnection,
					ownershipTrackCleanup = ownershipTrackCleanup,
					emitUICue = emitUICue,
					settings = KeybindSettings
				})
			end

			-- Toggle
			function Tab:CreateToggle(ToggleSettings)
				if (type(self.ToggleFactoryModule) ~= "table" or type(self.ToggleFactoryModule.create) ~= "function")
					and type(self.ResolveToggleFactory) == "function" then
					local okResolve, resolvedModule = pcall(self.ResolveToggleFactory)
					if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
						self.ToggleFactoryModule = resolvedModule
					end
				end

				if type(self.ToggleFactoryModule) ~= "table" or type(self.ToggleFactoryModule.create) ~= "function" then
					warn("Rayfield | Toggle factory module unavailable.")
					return nil
				end

				return self.ToggleFactoryModule.create({
					Tab = Tab,
					TabPage = TabPage,
					Settings = Settings,
					SequenceLib = SequenceLib,
					trim = trim,
					resolveSequenceRuntimeOptions = resolveSequenceRuntimeOptions,
					normalizeSequenceBinding = normalizeSequenceBinding,
					parseSequenceInput = parseSequenceInput,
					formatSequenceDisplay = formatSequenceDisplay,
					addExtendedAPI = addExtendedAPI,
					registerHoverBinding = registerHoverBinding,
					registerElementSync = registerElementSync,
					commitElementSync = commitElementSync,
					ownershipTrackConnection = ownershipTrackConnection,
					ownershipTrackCleanup = ownershipTrackCleanup,
					elementSync = elementSync,
					emitUICue = emitUICue,
					settings = ToggleSettings
				})
			end

			function Tab:CreateToggleBind(ToggleSettings)
				ToggleSettings = ToggleSettings or {}
				local keybindSettings = ToggleSettings.Keybind
				if type(keybindSettings) ~= "table" then
					keybindSettings = {}
				end
				keybindSettings.Enabled = true
				ToggleSettings.Keybind = keybindSettings
				return self:CreateToggle(ToggleSettings)
			end

			function Tab:CreateHotToggle(ToggleSettings)
				return self:CreateToggleBind(ToggleSettings)
			end

			function Tab:CreateKeybindToggle(ToggleSettings)
				return self:CreateToggleBind(ToggleSettings)
			end
	
			-- Slider
			function Tab:CreateSlider(SliderSettings)
				if (type(self.SliderFactoryModule) ~= "table" or type(self.SliderFactoryModule.create) ~= "function")
					and type(self.ResolveSliderFactory) == "function" then
					local okResolve, resolvedModule = pcall(self.ResolveSliderFactory)
					if okResolve and type(resolvedModule) == "table" and type(resolvedModule.create) == "function" then
						self.SliderFactoryModule = resolvedModule
					end
				end

				if type(self.SliderFactoryModule) ~= "table" or type(self.SliderFactoryModule.create) ~= "function" then
					warn("Rayfield | Slider factory module unavailable.")
					return nil
				end

				return self.SliderFactoryModule.create({
					Tab = Tab,
					TabPage = TabPage,
					Settings = Settings,
					addExtendedAPI = addExtendedAPI,
					registerHoverBinding = registerHoverBinding,
					registerElementSync = registerElementSync,
					commitElementSync = commitElementSync,
					elementSync = elementSync,
					settings = SliderSettings
				})
			end

			local function createRangeBar(factoryMethod, rawSettings)
				local moduleValue = resolveRangeBarsFactory()
				if type(moduleValue) ~= "table" or type(moduleValue[factoryMethod]) ~= "function" then
					warn("Rayfield | Range bars factory module unavailable for method: " .. tostring(factoryMethod))
					return nil
				end
				return moduleValue[factoryMethod]({
					self = self,
					Tab = Tab,
					TabPage = TabPage,
					Settings = Settings,
					addExtendedAPI = addExtendedAPI,
					registerHoverBinding = registerHoverBinding,
					registerElementSync = registerElementSync,
					commitElementSync = commitElementSync
				}, rawSettings)
			end

			function Tab:CreateTrackBar(TrackBarSettings)
				return createRangeBar("createTrackBar", TrackBarSettings)
			end

			function Tab:CreateStatusBar(StatusBarSettings)
				return createRangeBar("createStatusBar", StatusBarSettings)
			end

			function Tab:CreateDragBar(settings)
				return createRangeBar("createDragBar", settings)
			end

			function Tab:CreateSliderLite(settings)
				return createRangeBar("createSliderLite", settings)
			end

			function Tab:CreateInfoBar(settings)
				return createRangeBar("createInfoBar", settings)
			end

			function Tab:CreateSliderDisplay(settings)
				return createRangeBar("createSliderDisplay", settings)
			end
	
			self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
				TabButton.UIStroke.Color = self.getSelectedTheme().TabStroke
	
				if self.Elements.UIPageLayout.CurrentPage == TabPage then
					TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackgroundSelected
					TabButton.Image.ImageColor3 = self.getSelectedTheme().SelectedTabTextColor
					TabButton.Title.TextColor3 = self.getSelectedTheme().SelectedTabTextColor
				else
					TabButton.BackgroundColor3 = self.getSelectedTheme().TabBackground
					TabButton.Image.ImageColor3 = self.getSelectedTheme().TabTextColor
					TabButton.Title.TextColor3 = self.getSelectedTheme().TabTextColor
				end
			end)
	
			return Tab
		end

	
	-- Export function
	self.CreateTab = CreateTab
	self.getFirstTab = function() return tabRegistry.getFirstTab() end
	self.getTabRecordByPersistenceId = function(tabId)
		return tabRegistry.getTabRecordByPersistenceId(tabId)
	end
	self.getTabLayoutOrderByPersistenceId = function(tabId)
		return tabRegistry.getTabLayoutOrderByPersistenceId(tabId)
	end
	self.getCurrentTabPersistenceId = function()
		local currentPage = self.Elements and self.Elements.UIPageLayout and self.Elements.UIPageLayout.CurrentPage
		return tabRegistry.getCurrentTabPersistenceId(currentPage)
	end
	self.activateTabByPersistenceId = function(tabId, ignoreMinimisedCheck, source)
		return tabRegistry.activateTabByPersistenceId(tabId, ignoreMinimisedCheck, source)
	end
	self.listControlsForFavorites = function(pruneMissing)
		return listControlsForFavorites(pruneMissing == true)
	end
	self.pinControl = function(idOrFlag)
		return pinControl(tostring(idOrFlag or ""))
	end
	self.unpinControl = function(idOrFlag)
		return unpinControl(tostring(idOrFlag or ""))
	end
	self.getPinnedIds = function(pruneMissing)
		return cloneArray(getPinnedIds(pruneMissing == true))
	end
	self.setPinnedIds = function(ids)
		setPinnedIds(ids)
		return true
	end
	self.setPinBadgesVisible = function(visible)
		setPinBadgesVisible(visible ~= false)
		return true
	end
	self.getPinBadgesVisible = function()
		local registry = resolveControlRegistry()
		if type(registry.getPinBadgesVisible) == "function" then
			return registry.getPinBadgesVisible()
		end
		return false
	end
	self.subscribeControlRegistry = function(callback)
		local registry = resolveControlRegistry()
		if type(registry.subscribe) == "function" then
			return registry.subscribe(callback)
		end
		return function() end
	end
	self.getControlRecordById = function(id)
		return getControlRecordById(id)
	end
	self.getControlRecordByIdOrFlag = function(idOrFlag)
		return getRecordByIdOrFlag(tostring(idOrFlag or ""))
	end
	self.setControlDisplayLabel = function(idOrFlag, label, options)
		return setControlDisplayLabelByIdOrFlag(idOrFlag, label, options)
	end
	self.getControlDisplayLabel = function(idOrFlag)
		return getControlDisplayLabelByIdOrFlag(idOrFlag)
	end
	self.resetControlDisplayLabel = function(idOrFlag, options)
		return resetControlDisplayLabelByIdOrFlag(idOrFlag, options)
	end
	self.listControlRecords = function(pruneMissing)
		return listControlRecords(pruneMissing == true)
	end

	return self
end

return ElementsModule






