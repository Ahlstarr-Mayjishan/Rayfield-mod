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
	self.WidgetAPIInjectorModule = ctx.WidgetAPIInjectorModule
	self.ResolveWidgetAPIInjectorModule = type(ctx.ResolveWidgetAPIInjectorModule) == "function" and ctx.ResolveWidgetAPIInjectorModule or nil
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

	local allControlsById = {}
	local controlOrder = {}
	local controlsByFlag = {}
	local pinnedControlIds = {}
	local controlRegistrySubscribers = {}
	local controlIdSalt = 0
	local pinBadgesVisible = true
	local logHub = {
		connection = nil,
		subscribers = {}
	}
	local tooltipEngine = nil
	local widgetApiInjector = nil

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

	local function ownershipCreateScope(scopeId, metadata)
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
		if not (self.ResourceOwnership and type(self.ResourceOwnership.claimInstance) == "function") then
			return false
		end
		local okClaim, claimed = pcall(self.ResourceOwnership.claimInstance, instance, scopeId, metadata)
		return okClaim and claimed == true
	end

	local function ownershipTrackConnection(connection, scopeId)
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
		local digits = math.max(0, math.floor(tonumber(precision) or 0))
		local scale = 10 ^ digits
		return math.floor((tonumber(value) or 0) * scale + 0.5) / scale
	end

	local function resolveTooltipEngine()
		if tooltipEngine then
			return tooltipEngine
		end
		local moduleValue = self.TooltipEngineModule
		if type(moduleValue) ~= "table" and type(self.ResolveTooltipEngineModule) == "function" then
			moduleValue = self.ResolveTooltipEngineModule()
		end
		if type(moduleValue) ~= "table" or type(moduleValue.create) ~= "function" then
			return nil
		end
		local okCreate, engineOrErr = pcall(moduleValue.create, {
			Rayfield = self.Rayfield,
			Main = self.Main,
			UserInputService = self.UserInputService,
			getSelectedTheme = self.getSelectedTheme
		})
		if okCreate and type(engineOrErr) == "table" then
			tooltipEngine = engineOrErr
		end
		return tooltipEngine
	end

	local function hideTooltip(key)
		local engine = resolveTooltipEngine()
		if engine and type(engine.hide) == "function" then
			engine.hide(key)
		end
	end

	local function showTooltip(key, guiObject, text)
		local engine = resolveTooltipEngine()
		if engine and type(engine.show) == "function" then
			engine.show(key, guiObject, text)
		end
	end

	local function ensureLogHubConnected()
		if not LogService or logHub.connection then
			return
		end
		logHub.connection = LogService.MessageOut:Connect(function(message, messageType)
			local level = "info"
			if messageType == Enum.MessageType.MessageWarning then
				level = "warn"
			elseif messageType == Enum.MessageType.MessageError then
				level = "error"
			end
			for callback in pairs(logHub.subscribers) do
				local ok = pcall(callback, level, tostring(message or ""))
				if not ok then
					logHub.subscribers[callback] = nil
				end
			end
		end)
	end

	local function subscribeGlobalLogs(callback)
		if type(callback) ~= "function" then
			return function() end
		end
		logHub.subscribers[callback] = true
		ensureLogHubConnected()
		local disposed = false
		return function()
			if disposed then
				return
			end
			disposed = true
			logHub.subscribers[callback] = nil
			if not next(logHub.subscribers) and logHub.connection then
				logHub.connection:Disconnect()
				logHub.connection = nil
			end
		end
	end

	local function emitControlRegistryChange(reason)
		for callback in pairs(controlRegistrySubscribers) do
			local ok = pcall(callback, tostring(reason or "changed"))
			if not ok then
				controlRegistrySubscribers[callback] = nil
			end
		end
	end

	local function isControlRecordAlive(record)
		if type(record) ~= "table" then
			return false
		end
		local guiObject = record.GuiObject
		return guiObject and guiObject.Parent ~= nil
	end

	local function applyPinnedVisual(record)
		if type(record) ~= "table" then
			return
		end
		local pinButton = record.PinButton
		if not pinButton then
			return
		end
		local pinned = pinnedControlIds[record.Id] == true
		pinButton.Text = pinned and "*" or "o"
		pinButton.TextColor3 = pinned and Color3.fromRGB(255, 215, 120) or Color3.fromRGB(225, 225, 225)
	end

	local function getRecordByIdOrFlag(idOrFlag)
		if type(idOrFlag) ~= "string" then
			return nil
		end
		local key = tostring(idOrFlag)
		local record = allControlsById[key]
		if record then
			return record
		end
		if controlsByFlag[key] then
			return controlsByFlag[key]
		end
		local byFlagName = controlsByFlag["flag:" .. key]
		if byFlagName then
			return byFlagName
		end
		return nil
	end

	local function buildLocalizationKeysForRecord(record)
		local keys = {}
		if type(record) ~= "table" then
			return keys
		end
		local flagValue = tostring(record.Flag or "")
		local idValue = tostring(record.Id or "")
		local typeValue = tostring(record.Type or "Element")
		local internalValue = tostring(record.InternalName or record.Name or "")
		if flagValue ~= "" then
			table.insert(keys, "flag:" .. flagValue)
		end
		if idValue ~= "" then
			table.insert(keys, "id:" .. idValue)
		end
		if internalValue ~= "" then
			table.insert(keys, string.format("eng:%s:%s", typeValue, internalValue))
		end
		return keys
	end

	local function resolveLocalizationKey(record)
		local keys = buildLocalizationKeysForRecord(record)
		return keys[1] or ""
	end

	local function setGuiTitleText(guiObject, text)
		if not (guiObject and guiObject.Parent) then
			return false
		end
		local applied = false
		local function trySet(target)
			if not target then
				return
			end
			local okSet = pcall(function()
				target.Text = tostring(text or "")
			end)
			if okSet then
				applied = true
			end
		end
		if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
			trySet(guiObject)
		end
		if not applied then
			local titleNode = guiObject:FindFirstChild("Title", true)
			if titleNode then
				trySet(titleNode)
			end
		end
		return applied
	end

	local function applyControlDisplayLabel(record, label)
		if type(record) ~= "table" then
			return false, "Control record is invalid."
		end
		local internalName = tostring(record.InternalName or record.Name or "Unnamed")
		local value = tostring(label or "")
		value = value:gsub("^%s+", ""):gsub("%s+$", "")
		if value == "" then
			value = internalName
		end
		record.DisplayName = value
		record.Name = value
		record.LocalizationKey = resolveLocalizationKey(record)
		if type(record.ElementObject) == "table" then
			record.ElementObject.DisplayName = value
			record.ElementObject.LocalizationKey = record.LocalizationKey
		end
		if record.GuiObject then
			if record.GuiObject.SetAttribute then
				record.GuiObject:SetAttribute("RayfieldLocalizationKey", record.LocalizationKey)
			end
			setGuiTitleText(record.GuiObject, value)
		end
		return true, value
	end

	local function setControlPinnedState(record, shouldPin)
		if type(record) ~= "table" or type(record.Id) ~= "string" then
			return false, "Control record is invalid."
		end

		if shouldPin then
			pinnedControlIds[record.Id] = true
		else
			pinnedControlIds[record.Id] = nil
		end
		applyPinnedVisual(record)
		emitControlRegistryChange(shouldPin and "pin" or "unpin")
		return true, shouldPin and "Pinned." or "Unpinned."
	end

	local function pinControl(idOrFlag)
		local record = getRecordByIdOrFlag(tostring(idOrFlag or ""))
		if not record then
			return false, "Control not found."
		end
		return setControlPinnedState(record, true)
	end

	local function unpinControl(idOrFlag)
		local record = getRecordByIdOrFlag(tostring(idOrFlag or ""))
		if not record then
			return false, "Control not found."
		end
		return setControlPinnedState(record, false)
	end

	local function getPinnedIds(pruneMissing)
		local orderedPinned = {}
		for _, id in ipairs(controlOrder) do
			if pinnedControlIds[id] then
				local record = allControlsById[id]
				if record and isControlRecordAlive(record) then
					table.insert(orderedPinned, id)
				elseif pruneMissing == true then
					pinnedControlIds[id] = nil
				end
			end
		end
		return orderedPinned
	end

	local function setPinnedIds(ids)
		pinnedControlIds = {}
		if type(ids) == "table" then
			for _, value in ipairs(ids) do
				if type(value) == "string" and value ~= "" then
					pinnedControlIds[value] = true
				end
			end
		end
		for _, record in pairs(allControlsById) do
			applyPinnedVisual(record)
		end
		emitControlRegistryChange("set_pinned_ids")
	end

	local function setPinBadgesVisible(visible)
		local show = visible ~= false
		pinBadgesVisible = show
		for _, record in pairs(allControlsById) do
			local pinButton = record.PinButton
			if pinButton then
				pinButton.Visible = show
			end
		end
		emitControlRegistryChange("set_pin_badges_visible")
	end

	local function listControlsForFavorites(pruneMissing)
		local out = {}
		for _, id in ipairs(controlOrder) do
			local record = allControlsById[id]
			if record and isControlRecordAlive(record) then
				table.insert(out, {
					id = record.Id,
					tabId = record.TabPersistenceId,
					name = record.DisplayName or record.Name,
					displayName = record.DisplayName or record.Name,
					internalName = record.InternalName or record.Name,
					type = record.Type,
					flag = record.Flag,
					localizationKey = resolveLocalizationKey(record),
					pinned = pinnedControlIds[record.Id] == true
				})
			elseif pruneMissing == true and pinnedControlIds[id] then
				pinnedControlIds[id] = nil
			end
		end
		return out
	end

	local function getControlRecordById(id)
		local record = allControlsById[tostring(id or "")]
		if not record then
			return nil
		end
		if not isControlRecordAlive(record) then
			return nil
		end
		return record
	end

	local function listControlRecords(pruneMissing)
		local out = {}
		for _, id in ipairs(controlOrder) do
			local record = allControlsById[id]
			if record and isControlRecordAlive(record) then
				table.insert(out, record)
			elseif pruneMissing == true and pinnedControlIds[id] then
				pinnedControlIds[id] = nil
			end
		end
		return out
	end

	local function setControlDisplayLabelByIdOrFlag(idOrFlag, label, options)
		local record = getRecordByIdOrFlag(tostring(idOrFlag or ""))
		if not record then
			return false, "Control not found."
		end
		options = type(options) == "table" and options or {}
		local textValue = tostring(label or "")
		textValue = textValue:gsub("^%s+", ""):gsub("%s+$", "")
		if textValue == "" then
			textValue = nil
		end
		local okApply, displayName = applyControlDisplayLabel(record, textValue)
		if not okApply then
			return false, "Failed to update control label."
		end
		if options.persist ~= false and type(self.persistControlDisplayLabel) == "function" then
			local okPersist, persistResult = pcall(self.persistControlDisplayLabel, record, textValue)
			if not okPersist then
				return false, tostring(persistResult)
			end
		end
		emitControlRegistryChange("control_renamed")
		return true, tostring(displayName)
	end

	local function getControlDisplayLabelByIdOrFlag(idOrFlag)
		local record = getRecordByIdOrFlag(tostring(idOrFlag or ""))
		if not record then
			return nil, nil
		end
		return tostring(record.DisplayName or record.Name or ""), resolveLocalizationKey(record)
	end

	local function resetControlDisplayLabelByIdOrFlag(idOrFlag, options)
		local record = getRecordByIdOrFlag(tostring(idOrFlag or ""))
		if not record then
			return false, "Control not found."
		end
		options = type(options) == "table" and options or {}
		local okApply = applyControlDisplayLabel(record, nil)
		if not okApply then
			return false, "Failed to reset control label."
		end
		if options.persist ~= false then
			if type(self.resetControlDisplayLabel) == "function" then
				local okReset, resetResult = pcall(self.resetControlDisplayLabel, record)
				if not okReset then
					return false, tostring(resetResult)
				end
			elseif type(self.persistControlDisplayLabel) == "function" then
				pcall(self.persistControlDisplayLabel, record, nil)
			end
		end
		emitControlRegistryChange("control_renamed")
		return true, tostring(record.DisplayName or record.Name or "")
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
				while allControlsById[favoriteId] and allControlsById[favoriteId].GuiObject ~= guiObject do
					controlIdSalt += 1
					favoriteId = baseFavoriteId .. "#" .. tostring(controlIdSalt)
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
				if type(self.resolveControlDisplayLabel) == "function" then
					local okLabel, label = pcall(self.resolveControlDisplayLabel, {
						id = controlRecord.Id,
						flag = controlRecord.Flag,
						type = controlRecord.Type,
						internalName = controlRecord.InternalName,
						localizationKey = controlRecord.LocalizationKey
					})
					if okLabel and type(label) == "string" and label ~= "" then
						applyControlDisplayLabel(controlRecord, label)
					else
						applyControlDisplayLabel(controlRecord, nil)
					end
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

				allControlsById[favoriteId] = controlRecord
				table.insert(controlOrder, favoriteId)
				if controlRecord.Flag then
					controlsByFlag[controlRecord.Flag] = controlRecord
					controlsByFlag["flag:" .. controlRecord.Flag] = controlRecord
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
								local binding = hoverBindings[tooltipHoverBindingKey]
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
						tooltipTouchToken += 1
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
					pinButton.Visible = pinBadgesVisible
					pinButton.Parent = guiObject

					local pinCorner = Instance.new("UICorner")
					pinCorner.CornerRadius = UDim.new(0, 5)
					pinCorner.Parent = pinButton

					controlRecord.PinButton = pinButton
					applyPinnedVisual(controlRecord)

					pinConnection = pinButton.MouseButton1Click:Connect(function()
						local currentlyPinned = pinnedControlIds[favoriteId] == true
						setControlPinnedState(controlRecord, not currentlyPinned)
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
									setControlPinnedState(controlRecord, not currentlyPinned)
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
					if controlRecord.Flag then
						controlsByFlag[controlRecord.Flag] = nil
						controlsByFlag["flag:" .. controlRecord.Flag] = nil
					end
					allControlsById[favoriteId] = nil
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
	
			-- ColorPicker
			function Tab:CreateColorPicker(ColorPickerSettings) -- by Throit
				ColorPickerSettings.Type = "ColorPicker"
				local ColorPicker = self.Elements.Template.ColorPicker:Clone()
				local Background = ColorPicker.CPBackground
				local Display = Background.Display
				local Main = Background.MainCP
				local Slider = ColorPicker.ColorSlider
				ColorPicker.ClipsDescendants = true
				ColorPicker.Name = ColorPickerSettings.Name
				ColorPicker.Title.Text = ColorPickerSettings.Name
				ColorPicker.Visible = true
				ColorPicker.Parent = TabPage
				ColorPicker.Size = UDim2.new(1, -10, 0, 45)
				Background.Size = UDim2.new(0, 39, 0, 22)
				Display.BackgroundTransparency = 0
				self.Main.MainPoint.ImageTransparency = 1
				ColorPicker.Interact.Size = UDim2.new(1, 0, 1, 0)
				ColorPicker.Interact.Position = UDim2.new(0.5, 0, 0.5, 0)
				ColorPicker.RGB.Position = UDim2.new(0, 17, 0, 70)
				ColorPicker.HexInput.Position = UDim2.new(0, 17, 0, 90)
				self.Main.ImageTransparency = 1
				Background.BackgroundTransparency = 1
	
				for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren()) do
					if rgbinput:IsA("Frame") then
						rgbinput.BackgroundColor3 = self.getSelectedTheme().InputBackground
						rgbinput.UIStroke.Color = self.getSelectedTheme().InputStroke
					end
				end
	
				ColorPicker.HexInput.BackgroundColor3 = self.getSelectedTheme().InputBackground
				ColorPicker.HexInput.UIStroke.Color = self.getSelectedTheme().InputStroke
	
				local opened = false 
				local mouse = Players.LocalPlayer:GetMouse()
				self.Main.Image = "http://www.roblox.com/asset/?id=11415645739"
				local mainDragging = false 
				local sliderDragging = false 
				ColorPicker.Interact.MouseButton1Down:Connect(function()
					task.spawn(function()
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
						self.Animation:Create(ColorPicker.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						task.wait(0.2)
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
						self.Animation:Create(ColorPicker.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
					end)
	
					if not opened then
						opened = true 
						self.Animation:Create(Background, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 18, 0, 15)}):Play()
						task.wait(0.1)
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 120)}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 173, 0, 86)}):Play()
						self.Animation:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.289, 0, 0.5, 0)}):Play()
						self.Animation:Create(ColorPicker.RGB, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 40)}):Play()
						self.Animation:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 73)}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0.574, 0, 1, 0)}):Play()
						self.Animation:Create(self.Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
						self.Animation:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default and 0.25 or 0.1}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
					else
						opened = false
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, -10, 0, 45)}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 39, 0, 22)}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 1, 0)}):Play()
						self.Animation:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
						self.Animation:Create(ColorPicker.RGB, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 70)}):Play()
						self.Animation:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 17, 0, 90)}):Play()
						self.Animation:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
						self.Animation:Create(self.Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
						self.Animation:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
						self.Animation:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
					end
	
				end)
	
				self.UserInputService.InputEnded:Connect(function(input, gameProcessed) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						local wasDragging = mainDragging or sliderDragging
						mainDragging = false
						sliderDragging = false
						if wasDragging and not ColorPickerSettings.Ext then
							self.SaveConfiguration()
						end
					end end)
				self.Main.MouseButton1Down:Connect(function()
					if opened then
						mainDragging = true 
					end
				end)
				self.Main.MainPoint.MouseButton1Down:Connect(function()
					if opened then
						mainDragging = true 
					end
				end)
				Slider.MouseButton1Down:Connect(function()
					sliderDragging = true 
				end)
				Slider.SliderPoint.MouseButton1Down:Connect(function()
					sliderDragging = true 
				end)
				local h,s,v = ColorPickerSettings.Color:ToHSV()
				local color = Color3.fromHSV(h,s,v) 
				local hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
				ColorPicker.HexInput.InputBox.Text = hex
				local function setDisplay()
					--Main
					self.Main.MainPoint.Position = UDim2.new(s,-self.Main.MainPoint.AbsoluteSize.X/2,1-v,-self.Main.MainPoint.AbsoluteSize.Y/2)
					self.Main.MainPoint.ImageColor3 = Color3.fromHSV(h,s,v)
					Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
					Display.BackgroundColor3 = Color3.fromHSV(h,s,v)
					--Slider 
					local x = h * Slider.AbsoluteSize.X
					Slider.SliderPoint.Position = UDim2.new(0,x-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
					Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h,1,1)
					local color = Color3.fromHSV(h,s,v) 
					local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
					ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
					ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
					hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
					ColorPicker.HexInput.InputBox.Text = hex
				end
				setDisplay()
				ColorPicker.HexInput.InputBox.FocusLost:Connect(function()
					if not pcall(function()
							local r, g, b = string.match(ColorPicker.HexInput.InputBox.Text, "^#?(%w%w)(%w%w)(%w%w)$")
							local rgbColor = Color3.fromRGB(tonumber(r, 16),tonumber(g, 16), tonumber(b, 16))
							h,s,v = rgbColor:ToHSV()
							hex = ColorPicker.HexInput.InputBox.Text
							setDisplay()
							ColorPickerSettings.Color = rgbColor
						end) 
					then 
						ColorPicker.HexInput.InputBox.Text = hex 
					end
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
					local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					if not ColorPickerSettings.Ext then
						self.SaveConfiguration()
					end
				end)
				--RGB
				local function rgbBoxes(box,toChange)
					local value = tonumber(box.Text) 
					local color = Color3.fromHSV(h,s,v) 
					local oldR,oldG,oldB = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					local save 
					if toChange == "R" then save = oldR;oldR = value elseif toChange == "G" then save = oldG;oldG = value else save = oldB;oldB = value end
					if value then 
						value = math.clamp(value,0,255)
						h,s,v = Color3.fromRGB(oldR,oldG,oldB):ToHSV()
	
						setDisplay()
					else 
						box.Text = tostring(save)
					end
					local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					if not ColorPickerSettings.Ext then
						self.SaveConfiguration(ColorPickerSettings.Flag..'\n'..tostring(ColorPickerSettings.Color))
					end
				end
				ColorPicker.RGB.RInput.InputBox.FocusLost:connect(function()
					rgbBoxes(ColorPicker.RGB.RInput.InputBox,"R")
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				end)
				ColorPicker.RGB.GInput.InputBox.FocusLost:connect(function()
					rgbBoxes(ColorPicker.RGB.GInput.InputBox,"G")
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				end)
				ColorPicker.RGB.BInput.InputBox.FocusLost:connect(function()
					rgbBoxes(ColorPicker.RGB.BInput.InputBox,"B")
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				end)
	
				local prevH, prevS, prevV = h, s, v
				self.RunService.RenderStepped:connect(function()
					if mainDragging then
						local localX = math.clamp(mouse.X-self.Main.AbsolutePosition.X,0,self.Main.AbsoluteSize.X)
						local localY = math.clamp(mouse.Y-self.Main.AbsolutePosition.Y,0,self.Main.AbsoluteSize.Y)
						self.Main.MainPoint.Position = UDim2.new(0,localX-self.Main.MainPoint.AbsoluteSize.X/2,0,localY-self.Main.MainPoint.AbsoluteSize.Y/2)
						s = localX / self.Main.AbsoluteSize.X
						v = 1 - (localY / self.Main.AbsoluteSize.Y)
						local color = Color3.fromHSV(h,s,v)
						Display.BackgroundColor3 = color
						self.Main.MainPoint.ImageColor3 = color
						Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
						local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
						ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
						ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
						ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
						ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
						ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
						if h ~= prevH or s ~= prevS or v ~= prevV then
							prevH, prevS, prevV = h, s, v
							pcall(ColorPickerSettings.Callback, color)
						end
					end
					if sliderDragging then
						local localX = math.clamp(mouse.X-Slider.AbsolutePosition.X,0,Slider.AbsoluteSize.X)
						h = localX / Slider.AbsoluteSize.X
						local color = Color3.fromHSV(h,s,v)
						local hueColor = Color3.fromHSV(h,1,1)
						Display.BackgroundColor3 = color
						Slider.SliderPoint.Position = UDim2.new(0,localX-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
						Slider.SliderPoint.ImageColor3 = hueColor
						Background.BackgroundColor3 = hueColor
						self.Main.MainPoint.ImageColor3 = color
						local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
						ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
						ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
						ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
						ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
						ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
						if h ~= prevH or s ~= prevS or v ~= prevV then
							prevH, prevS, prevV = h, s, v
							pcall(ColorPickerSettings.Callback, color)
						end
					end
				end)
	
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and ColorPickerSettings.Flag then
						self.RayfieldLibrary.Flags[ColorPickerSettings.Flag] = ColorPickerSettings
					end
				end
	
				function ColorPickerSettings:Set(RGBColor)
					ColorPickerSettings.Color = RGBColor
					h,s,v = ColorPickerSettings.Color:ToHSV()
					color = Color3.fromHSV(h,s,v)
					setDisplay()
				end
	
				local colorPickerHoverBindingKey = registerHoverBinding(ColorPicker,
					function()
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
					end,
					function()
						self.Animation:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					end
				)
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					for _, rgbinput in ipairs(ColorPicker.RGB:GetChildren()) do
						if rgbinput:IsA("Frame") then
							rgbinput.BackgroundColor3 = self.getSelectedTheme().InputBackground
							rgbinput.UIStroke.Color = self.getSelectedTheme().InputStroke
						end
					end
	
					ColorPicker.HexInput.BackgroundColor3 = self.getSelectedTheme().InputBackground
					ColorPicker.HexInput.UIStroke.Color = self.getSelectedTheme().InputStroke
				end)
	
				function ColorPickerSettings:Destroy()
					ColorPicker:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(ColorPickerSettings, ColorPickerSettings.Name, "ColorPicker", ColorPicker, colorPickerHoverBindingKey)
	
				return ColorPickerSettings
			end
	
			-- Section
			function Tab:CreateSection(SectionName)
				currentImplicitSection = nil

				local SectionValue = {}
	
				if SDone then
					local SectionSpace = self.Elements.Template.SectionSpacing:Clone()
					SectionSpace.Visible = true
					SectionSpace.Parent = TabPage
				end
	
				local Section = self.Elements.Template.SectionTitle:Clone()
				Section.Title.Text = SectionName
				Section.Visible = true
				Section.Parent = TabPage
	
				Section.Title.TextTransparency = 1
				self.Animation:Create(Section.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0.4}):Play()
	
				function SectionValue:Set(NewSection)
					Section.Title.Text = NewSection
				end
	
				function SectionValue:Destroy()
					Section:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(SectionValue, SectionName, "Section", Section)
	
				SDone = true

				return SectionValue
			end

			function Tab:CreateCollapsibleSection(sectionSettings)
				local settingsValue = sectionSettings
				if type(settingsValue) == "string" then
					settingsValue = { Name = settingsValue }
				end
				settingsValue = settingsValue or {}
				local sectionName = tostring(settingsValue.Name or settingsValue.Title or "Section")
				local sectionId = tostring(settingsValue.Id or sectionName)
				local sectionKey = tostring(tabPersistenceId) .. "::" .. sectionId
				local persistState = settingsValue.PersistState ~= false
				local implicitScope = settingsValue.ImplicitScope ~= false

				local collapsedMap = getCollapsedSectionsMap()
				local initialCollapsed = settingsValue.Collapsed == true
				if persistState and type(collapsedMap[sectionKey]) == "boolean" then
					initialCollapsed = collapsedMap[sectionKey]
				end

				local root = Instance.new("Frame")
				root.Name = "CollapsibleSection"
				root.Size = UDim2.new(1, -10, 0, 28)
				root.AutomaticSize = Enum.AutomaticSize.Y
				root.BackgroundTransparency = 1
				root.BorderSizePixel = 0
				root.Visible = true
				root.Parent = TabPage

				local rootList = Instance.new("UIListLayout")
				rootList.SortOrder = Enum.SortOrder.LayoutOrder
				rootList.Padding = UDim.new(0, 6)
				rootList.Parent = root

				local header = Instance.new("Frame")
				header.Name = "Header"
				header.Size = UDim2.new(1, 0, 0, 26)
				header.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
				header.BorderSizePixel = 0
				header.Parent = root

				local headerCorner = Instance.new("UICorner")
				headerCorner.CornerRadius = UDim.new(0, 6)
				headerCorner.Parent = header

				local headerStroke = Instance.new("UIStroke")
				headerStroke.Color = self.getSelectedTheme().SecondaryElementStroke
				headerStroke.Parent = header

				local titleLabel = Instance.new("TextLabel")
				titleLabel.BackgroundTransparency = 1
				titleLabel.Position = UDim2.new(0, 10, 0, 0)
				titleLabel.Size = UDim2.new(1, -38, 1, 0)
				titleLabel.Font = Enum.Font.GothamSemibold
				titleLabel.TextSize = 13
				titleLabel.TextXAlignment = Enum.TextXAlignment.Left
				titleLabel.TextColor3 = self.getSelectedTheme().TextColor
				titleLabel.Text = sectionName
				titleLabel.Parent = header

				local chevron = Instance.new("TextLabel")
				chevron.BackgroundTransparency = 1
				chevron.AnchorPoint = Vector2.new(1, 0.5)
				chevron.Position = UDim2.new(1, -10, 0.5, 0)
				chevron.Size = UDim2.new(0, 16, 0, 16)
				chevron.Font = Enum.Font.GothamBold
				chevron.TextSize = 15
				chevron.TextColor3 = self.getSelectedTheme().SectionChevron or self.getSelectedTheme().TextColor
				chevron.Text = "v"
				chevron.Parent = header

				local interact = Instance.new("TextButton")
				interact.BackgroundTransparency = 1
				interact.Size = UDim2.new(1, 0, 1, 0)
				interact.Text = ""
				interact.Parent = header

				local content = Instance.new("Frame")
				content.Name = "Content"
				content.BackgroundTransparency = 1
				content.BorderSizePixel = 0
				content.Size = UDim2.new(1, 0, 0, 0)
				content.AutomaticSize = Enum.AutomaticSize.Y
				content.Parent = root

				local contentLayout = Instance.new("UIListLayout")
				contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
				contentLayout.Padding = UDim.new(0, 6)
				contentLayout.Parent = content

				local sectionRecord = {
					Key = sectionKey,
					Root = root,
					Header = header,
					ContentFrame = content,
					Collapsed = false,
					ImplicitScope = implicitScope
				}

				local sectionValue = {
					__SectionContentFrame = content,
					__SectionRecord = sectionRecord
				}

				local function applyCollapsedState(nextCollapsed, persist)
					sectionRecord.Collapsed = nextCollapsed == true
					content.Visible = not sectionRecord.Collapsed
					chevron.Text = sectionRecord.Collapsed and ">" or "v"
					if persist ~= false and persistState then
						persistCollapsedState(sectionKey, sectionRecord.Collapsed)
					end
				end

				function sectionValue:Set(newName)
					sectionName = tostring(newName or sectionName)
					titleLabel.Text = sectionName
				end

				function sectionValue:Collapse()
					applyCollapsedState(true, true)
				end

				function sectionValue:Expand()
					applyCollapsedState(false, true)
				end

				function sectionValue:Toggle()
					applyCollapsedState(not sectionRecord.Collapsed, true)
				end

				function sectionValue:IsCollapsed()
					return sectionRecord.Collapsed == true
				end

				function sectionValue:Destroy()
					if currentImplicitSection == sectionRecord then
						currentImplicitSection = nil
					end
					local snapshot = {}
					for _, tracked in ipairs(TabElements) do
						snapshot[#snapshot + 1] = tracked
					end
					for _, tracked in ipairs(snapshot) do
						if tracked.GuiObject and tracked.GuiObject:IsDescendantOf(content) and tracked.Object and type(tracked.Object.Destroy) == "function" then
							tracked.Object:Destroy()
						end
					end
					root:Destroy()
				end

				interact.MouseButton1Click:Connect(function()
					sectionValue:Toggle()
				end)

				self.Rayfield.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
					if not root.Parent then
						return
					end
					header.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
					headerStroke.Color = self.getSelectedTheme().SecondaryElementStroke
					titleLabel.TextColor3 = self.getSelectedTheme().TextColor
					chevron.TextColor3 = self.getSelectedTheme().SectionChevron or self.getSelectedTheme().TextColor
				end)

				applyCollapsedState(initialCollapsed, false)
				currentImplicitSection = implicitScope and sectionRecord or nil
				table.insert(TabSections, sectionRecord)
				addExtendedAPI(sectionValue, sectionName, "CollapsibleSection", root)
				return sectionValue
			end

			local function resolveElementParentFromSettings(elementObject, sourceSettings)
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

			local function connectThemeRefresh(handler)
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
				local settingsValue = stepperSettings or {}
				local stepper = {}
				stepper.Name = tostring(settingsValue.Name or "Number Stepper")
				stepper.Flag = settingsValue.Flag
				stepper.CurrentValue = clampNumber(settingsValue.CurrentValue, settingsValue.Min, settingsValue.Max, 0)

				local minValue = tonumber(settingsValue.Min)
				local maxValue = tonumber(settingsValue.Max)
				local stepValue = math.max(0.0001, tonumber(settingsValue.Step) or 1)
				local precision = math.max(0, math.floor(tonumber(settingsValue.Precision) or 2))
				local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end

				local root = Instance.new("Frame")
				root.Name = stepper.Name
				root.Size = UDim2.new(1, -10, 0, 45)
				root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
				root.BorderSizePixel = 0
				root.Visible = true
				root.Parent = TabPage

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 6)
				corner.Parent = root

				local stroke = Instance.new("UIStroke")
				stroke.Color = self.getSelectedTheme().ElementStroke
				stroke.Parent = root

				local title = Instance.new("TextLabel")
				title.BackgroundTransparency = 1
				title.Position = UDim2.new(0, 10, 0, 0)
				title.Size = UDim2.new(0.45, -8, 1, 0)
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.Font = Enum.Font.GothamMedium
				title.TextSize = 13
				title.Text = stepper.Name
				title.TextColor3 = self.getSelectedTheme().TextColor
				title.Parent = root

				local minus = Instance.new("TextButton")
				minus.Name = "Minus"
				minus.AnchorPoint = Vector2.new(1, 0.5)
				minus.Position = UDim2.new(1, -78, 0.5, 0)
				minus.Size = UDim2.new(0, 22, 0, 22)
				minus.Text = "-"
				minus.Font = Enum.Font.GothamBold
				minus.TextSize = 16
				minus.TextColor3 = self.getSelectedTheme().TextColor
				minus.BackgroundColor3 = self.getSelectedTheme().InputBackground
				minus.BorderSizePixel = 0
				minus.Parent = root

				local valueBox = Instance.new("TextBox")
				valueBox.Name = "Value"
				valueBox.AnchorPoint = Vector2.new(1, 0.5)
				valueBox.Position = UDim2.new(1, -50, 0.5, 0)
				valueBox.Size = UDim2.new(0, 56, 0, 22)
				valueBox.ClearTextOnFocus = false
				valueBox.Font = Enum.Font.Gotham
				valueBox.TextSize = 13
				valueBox.TextColor3 = self.getSelectedTheme().TextColor
				valueBox.PlaceholderText = "0"
				valueBox.BackgroundColor3 = self.getSelectedTheme().InputBackground
				valueBox.BorderSizePixel = 0
				valueBox.Parent = root

				local plus = Instance.new("TextButton")
				plus.Name = "Plus"
				plus.AnchorPoint = Vector2.new(1, 0.5)
				plus.Position = UDim2.new(1, -22, 0.5, 0)
				plus.Size = UDim2.new(0, 22, 0, 22)
				plus.Text = "+"
				plus.Font = Enum.Font.GothamBold
				plus.TextSize = 16
				plus.TextColor3 = self.getSelectedTheme().TextColor
				plus.BackgroundColor3 = self.getSelectedTheme().InputBackground
				plus.BorderSizePixel = 0
				plus.Parent = root

				local function formatValue(numberValue)
					local template = "%." .. tostring(precision) .. "f"
					return string.format(template, numberValue)
				end

				local function commitValue(nextValue, options)
					options = options or {}
					local normalized = roundToPrecision(clampNumber(nextValue, minValue, maxValue, stepper.CurrentValue), precision)
					if normalized == stepper.CurrentValue and options.force ~= true then
						valueBox.Text = formatValue(stepper.CurrentValue)
						return
					end
					stepper.CurrentValue = normalized
					valueBox.Text = formatValue(normalized)
					local okCallback, callbackErr = pcall(callback, normalized)
					if not okCallback then
						warn("Rayfield | NumberStepper callback failed: " .. tostring(callbackErr))
					end
					if settingsValue.Ext ~= true and options.persist ~= false then
						self.SaveConfiguration()
					end
				end

				minus.MouseButton1Click:Connect(function()
					commitValue(stepper.CurrentValue - stepValue, {persist = true})
				end)
				plus.MouseButton1Click:Connect(function()
					commitValue(stepper.CurrentValue + stepValue, {persist = true})
				end)
				valueBox.FocusLost:Connect(function()
					commitValue(valueBox.Text, {persist = true, force = true})
				end)

				function stepper:Set(nextValue)
					commitValue(nextValue, {persist = true, force = true})
				end

				function stepper:Get()
					return stepper.CurrentValue
				end

				function stepper:Increment()
					commitValue(stepper.CurrentValue + stepValue, {persist = true})
				end

				function stepper:Decrement()
					commitValue(stepper.CurrentValue - stepValue, {persist = true})
				end

				function stepper:Destroy()
					root:Destroy()
				end

				connectThemeRefresh(function()
					root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					stroke.Color = self.getSelectedTheme().ElementStroke
					title.TextColor3 = self.getSelectedTheme().TextColor
					minus.TextColor3 = self.getSelectedTheme().TextColor
					minus.BackgroundColor3 = self.getSelectedTheme().InputBackground
					plus.TextColor3 = self.getSelectedTheme().TextColor
					plus.BackgroundColor3 = self.getSelectedTheme().InputBackground
					valueBox.TextColor3 = self.getSelectedTheme().TextColor
					valueBox.BackgroundColor3 = self.getSelectedTheme().InputBackground
				end)

				resolveElementParentFromSettings(stepper, settingsValue)
				commitValue(stepper.CurrentValue, {persist = false, force = true})
				addExtendedAPI(stepper, stepper.Name, "NumberStepper", root)

				if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and stepper.Flag then
					self.RayfieldLibrary.Flags[stepper.Flag] = stepper
				end

				return stepper
			end

			function Tab:CreateConfirmButton(confirmSettings)
				local settingsValue = confirmSettings or {}
				local element = {}
				element.Name = tostring(settingsValue.Name or "Confirm Button")
				element.Flag = settingsValue.Flag
				element.Ext = settingsValue.Ext

				local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
				local mode = tostring(settingsValue.ConfirmMode or "hold"):lower()
				local holdDuration = clampNumber(settingsValue.HoldDuration, 0.05, 6, 1.2)
				local doubleWindow = clampNumber(settingsValue.DoubleWindow, 0.05, 4, 0.4)
				local timeout = clampNumber(settingsValue.Timeout, 0.2, 12, 2)
				local armed = false
				local armedToken = 0
				local lastClickTime = 0
				local holdActive = false
				local holdToken = 0

				local root = Instance.new("Frame")
				root.Name = element.Name
				root.Size = UDim2.new(1, -10, 0, 45)
				root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
				root.BorderSizePixel = 0
				root.Visible = true
				root.Parent = TabPage

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 6)
				corner.Parent = root

				local stroke = Instance.new("UIStroke")
				stroke.Color = self.getSelectedTheme().ElementStroke
				stroke.Parent = root

				local button = Instance.new("TextButton")
				button.Name = "Interact"
				button.Size = UDim2.new(1, 0, 1, 0)
				button.BackgroundTransparency = 1
				button.Text = element.Name
				button.Font = Enum.Font.GothamSemibold
				button.TextSize = 13
				button.TextColor3 = self.getSelectedTheme().TextColor
				button.Parent = root

				local function setArmedVisual(value)
					armed = value == true
					if armed then
						root.BackgroundColor3 = self.getSelectedTheme().ConfirmArmed or self.getSelectedTheme().ElementBackgroundHover
					else
						root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					end
				end

				local function fireConfirmed()
					setArmedVisual(false)
					emitUICue("click")
					local okCallback, callbackErr = pcall(callback)
					if not okCallback then
						emitUICue("error")
						warn("Rayfield | ConfirmButton callback failed: " .. tostring(callbackErr))
					else
						emitUICue("success")
					end
					if settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				local function armWithTimeout()
					armedToken += 1
					local localToken = armedToken
					setArmedVisual(true)
					task.delay(timeout, function()
						if armed and armedToken == localToken then
							setArmedVisual(false)
						end
					end)
				end

				local function isModeEnabled(modeName)
					return mode == modeName or mode == "either"
				end

				button.MouseButton1Click:Connect(function()
					local now = os.clock()
					if isModeEnabled("double") then
						if armed and (now - lastClickTime) <= doubleWindow then
							fireConfirmed()
							lastClickTime = 0
							return
						end
						lastClickTime = now
						armWithTimeout()
						return
					end
					if not isModeEnabled("hold") then
						fireConfirmed()
					end
				end)

				button.InputBegan:Connect(function(input)
					if not isModeEnabled("hold") then
						return
					end
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
						return
					end
					holdActive = true
					holdToken += 1
					local localToken = holdToken
					setArmedVisual(true)
					task.delay(holdDuration, function()
						if holdActive and holdToken == localToken then
							fireConfirmed()
						end
					end)
				end)

				button.InputEnded:Connect(function(input)
					if not isModeEnabled("hold") then
						return
					end
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
						return
					end
					holdActive = false
					if armed then
						setArmedVisual(false)
					end
				end)

				function element:Arm()
					armWithTimeout()
					return true, "armed"
				end

				function element:Cancel()
					holdActive = false
					setArmedVisual(false)
					return true, "cancelled"
				end

				function element:SetMode(nextMode)
					local normalized = tostring(nextMode or "hold"):lower()
					if normalized ~= "hold" and normalized ~= "double" and normalized ~= "either" then
						return false, "Invalid mode."
					end
					mode = normalized
					return true, "ok"
				end

				function element:SetHoldDuration(nextDuration)
					holdDuration = clampNumber(nextDuration, 0.05, 6, holdDuration)
					return true, "ok"
				end

				function element:SetDoubleWindow(nextWindow)
					doubleWindow = clampNumber(nextWindow, 0.05, 4, doubleWindow)
					return true, "ok"
				end

				function element:Destroy()
					root:Destroy()
				end

				connectThemeRefresh(function()
					button.TextColor3 = self.getSelectedTheme().TextColor
					stroke.Color = self.getSelectedTheme().ElementStroke
					setArmedVisual(armed)
				end)

				resolveElementParentFromSettings(element, settingsValue)
				addExtendedAPI(element, element.Name, "ConfirmButton", root)
				return element
			end

			local function resolveImageSourceUri(source)
				local valueType = typeof(source)
				if valueType == "nil" then
					return "rbxassetid://0", nil
				end
				if valueType == "number" then
					return "rbxassetid://" .. tostring(math.floor(source)), nil
				end
				if valueType ~= "string" then
					return "rbxassetid://0", "Image source must be a number or string."
				end
				local normalized = tostring(source)
				if normalized == "" then
					return "rbxassetid://0", "Image source is empty."
				end
				if normalized:match("^rbxassetid://") then
					return normalized, nil
				end
				if normalized:match("^https?://") then
					local hasBridge = type(getcustomasset) == "function" or type(getsynasset) == "function"
					if not hasBridge then
						return "rbxassetid://0", "URL image source unsupported in this executor (no asset bridge)."
					end
					return normalized, nil
				end
				if tonumber(normalized) then
					return "rbxassetid://" .. tostring(math.floor(tonumber(normalized))), nil
				end
				return normalized, nil
			end

			function Tab:CreateImage(imageSettings)
				local settingsValue = imageSettings or {}
				local imageElement = {}
				imageElement.Name = tostring(settingsValue.Name or "Image")
				imageElement.Flag = settingsValue.Flag
				local initialSource, initialWarning = resolveImageSourceUri(settingsValue.Source)
				imageElement.CurrentValue = {
					source = initialSource,
					fitMode = tostring(settingsValue.FitMode or "fill"):lower(),
					caption = tostring(settingsValue.Caption or "")
				}
				if initialWarning then
					warn("Rayfield | Image source warning: " .. tostring(initialWarning))
				end

				local root = Instance.new("Frame")
				root.Name = imageElement.Name
				root.Size = UDim2.new(1, -10, 0, clampNumber(settingsValue.Height, 60, 360, 130))
				root.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
				root.BorderSizePixel = 0
				root.Visible = true
				root.Parent = TabPage

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, clampNumber(settingsValue.CornerRadius, 0, 24, 8))
				corner.Parent = root

				local stroke = Instance.new("UIStroke")
				stroke.Color = self.getSelectedTheme().SecondaryElementStroke
				stroke.Parent = root

				local image = Instance.new("ImageLabel")
				image.Name = "Image"
				image.BackgroundTransparency = 1
				image.Position = UDim2.new(0, 0, 0, 0)
				image.Size = UDim2.new(1, 0, 1, -24)
				image.Image = imageElement.CurrentValue.source
				image.ScaleType = imageElement.CurrentValue.fitMode == "fit" and Enum.ScaleType.Fit or Enum.ScaleType.Crop
				image.Parent = root

				local caption = Instance.new("TextLabel")
				caption.Name = "Caption"
				caption.BackgroundTransparency = 1
				caption.AnchorPoint = Vector2.new(0.5, 1)
				caption.Position = UDim2.new(0.5, 0, 1, -4)
				caption.Size = UDim2.new(1, -12, 0, 18)
				caption.Font = Enum.Font.Gotham
				caption.TextSize = 12
				caption.TextXAlignment = Enum.TextXAlignment.Left
				caption.TextColor3 = self.getSelectedTheme().TextColor
				caption.Text = imageElement.CurrentValue.caption
				caption.Visible = imageElement.CurrentValue.caption ~= ""
				caption.Parent = root

				local function persistImageState()
					if settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				function imageElement:SetSource(nextSource)
					local resolved, warningMessage = resolveImageSourceUri(nextSource)
					imageElement.CurrentValue.source = resolved
					image.Image = imageElement.CurrentValue.source
					persistImageState()
					if warningMessage then
						warn("Rayfield | Image source warning: " .. tostring(warningMessage))
						return false, warningMessage
					end
					return true, "ok"
				end

				function imageElement:GetSource()
					return imageElement.CurrentValue.source
				end

				function imageElement:SetFitMode(nextMode)
					local normalized = tostring(nextMode or "fill"):lower()
					if normalized ~= "fill" and normalized ~= "fit" then
						normalized = "fill"
					end
					imageElement.CurrentValue.fitMode = normalized
					image.ScaleType = normalized == "fit" and Enum.ScaleType.Fit or Enum.ScaleType.Crop
					persistImageState()
				end

				function imageElement:SetCaption(nextCaption)
					imageElement.CurrentValue.caption = tostring(nextCaption or "")
					caption.Text = imageElement.CurrentValue.caption
					caption.Visible = imageElement.CurrentValue.caption ~= ""
					persistImageState()
				end

				function imageElement:GetPersistValue()
					return cloneSerializable(imageElement.CurrentValue)
				end

				function imageElement:Set(value)
					if type(value) == "table" then
						if value.source ~= nil then
							imageElement:SetSource(value.source)
						end
						if value.fitMode ~= nil then
							imageElement:SetFitMode(value.fitMode)
						end
						if value.caption ~= nil then
							imageElement:SetCaption(value.caption)
						end
					else
						imageElement:SetSource(value)
					end
				end

				function imageElement:Destroy()
					root:Destroy()
				end

				connectThemeRefresh(function()
					root.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
					stroke.Color = self.getSelectedTheme().SecondaryElementStroke
					caption.TextColor3 = self.getSelectedTheme().TextColor
				end)

				resolveElementParentFromSettings(imageElement, settingsValue)
				addExtendedAPI(imageElement, imageElement.Name, "Image", root)
				if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and imageElement.Flag then
					self.RayfieldLibrary.Flags[imageElement.Flag] = imageElement
				end
				return imageElement
			end

			function Tab:CreateGallery(gallerySettings)
				local settingsValue = gallerySettings or {}
				local gallery = {}
				gallery.Name = tostring(settingsValue.Name or "Gallery")
				gallery.Flag = settingsValue.Flag
				local selectionMode = tostring(settingsValue.SelectionMode or "single"):lower()
				if selectionMode ~= "single" and selectionMode ~= "multi" then
					selectionMode = "single"
				end
				local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
				local columns = settingsValue.Columns or "auto"
				local items = {}
				local selected = {}

				local root = Instance.new("Frame")
				root.Name = gallery.Name
				root.Size = UDim2.new(1, -10, 0, clampNumber(settingsValue.Height, 140, 520, 220))
				root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
				root.BorderSizePixel = 0
				root.Visible = true
				root.Parent = TabPage

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 6)
				corner.Parent = root

				local stroke = Instance.new("UIStroke")
				stroke.Color = self.getSelectedTheme().ElementStroke
				stroke.Parent = root

				local title = Instance.new("TextLabel")
				title.BackgroundTransparency = 1
				title.Position = UDim2.new(0, 10, 0, 0)
				title.Size = UDim2.new(1, -12, 0, 22)
				title.Font = Enum.Font.GothamSemibold
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextSize = 13
				title.TextColor3 = self.getSelectedTheme().TextColor
				title.Text = gallery.Name
				title.Parent = root

				local list = Instance.new("ScrollingFrame")
				list.Name = "List"
				list.BackgroundTransparency = 1
				list.BorderSizePixel = 0
				list.Position = UDim2.new(0, 6, 0, 24)
				list.Size = UDim2.new(1, -12, 1, -30)
				list.CanvasSize = UDim2.new(0, 0, 0, 0)
				list.ScrollBarImageTransparency = 0.5
				list.Parent = root

				local grid = Instance.new("UIGridLayout")
				grid.CellPadding = UDim2.new(0, 8, 0, 8)
				grid.SortOrder = Enum.SortOrder.LayoutOrder
				grid.Parent = list

				local function applyGridSizing()
					local targetColumns = 2
					if type(columns) == "number" then
						targetColumns = math.max(1, math.floor(columns))
					else
						targetColumns = math.max(1, math.floor((list.AbsoluteSize.X + 8) / 116))
					end
					local width = math.max(70, math.floor((list.AbsoluteSize.X - ((targetColumns - 1) * 8)) / targetColumns))
					grid.CellSize = UDim2.new(0, width, 0, 92)
				end

				local function snapshotSelection()
					if selectionMode == "single" then
						for id in pairs(selected) do
							return id
						end
						return nil
					end
					local out = {}
					for id in pairs(selected) do
						table.insert(out, id)
					end
					table.sort(out)
					return out
				end

				local function emitSelection()
					local okCallback, callbackErr = pcall(callback, snapshotSelection())
					if not okCallback then
						warn("Rayfield | Gallery callback failed: " .. tostring(callbackErr))
					end
					if settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				local cardById = {}

				local function applyCardSelectionVisual(itemId)
					local card = cardById[itemId]
					if not card then
						return
					end
					local active = selected[itemId] == true
					card.BackgroundColor3 = active and (self.getSelectedTheme().DropdownSelected or self.getSelectedTheme().ElementBackgroundHover) or self.getSelectedTheme().SecondaryElementBackground
				end

				local function renderItems()
					for _, child in ipairs(list:GetChildren()) do
						if child:IsA("Frame") then
							child:Destroy()
						end
					end
					cardById = {}

					for index, item in ipairs(items) do
						local itemId = tostring(item.id or item.Id or index)
						local card = Instance.new("Frame")
						card.Name = "Item_" .. itemId
						card.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
						card.BorderSizePixel = 0
						card.LayoutOrder = index
						card.Parent = list

						local cardCorner = Instance.new("UICorner")
						cardCorner.CornerRadius = UDim.new(0, 6)
						cardCorner.Parent = card

						local image = Instance.new("ImageLabel")
						image.BackgroundTransparency = 1
						image.Position = UDim2.new(0, 6, 0, 6)
						image.Size = UDim2.new(1, -12, 1, -30)
						image.ScaleType = Enum.ScaleType.Crop
						image.Image = resolveImageSourceUri(item.image or item.Image or item.source or item.Source)
						image.Parent = card

						local label = Instance.new("TextLabel")
						label.BackgroundTransparency = 1
						label.Position = UDim2.new(0, 6, 1, -22)
						label.Size = UDim2.new(1, -12, 0, 16)
						label.Font = Enum.Font.Gotham
						label.TextSize = 11
						label.TextXAlignment = Enum.TextXAlignment.Left
						label.TextColor3 = self.getSelectedTheme().TextColor
						label.Text = tostring(item.name or item.Name or itemId)
						label.Parent = card

						local interact = Instance.new("TextButton")
						interact.BackgroundTransparency = 1
						interact.Size = UDim2.new(1, 0, 1, 0)
						interact.Text = ""
						interact.Parent = card
						interact.MouseButton1Click:Connect(function()
							if selectionMode == "single" then
								selected = {}
								selected[itemId] = true
							else
								if selected[itemId] then
									selected[itemId] = nil
								else
									selected[itemId] = true
								end
							end
							for id in pairs(cardById) do
								applyCardSelectionVisual(id)
							end
							emitSelection()
						end)

						cardById[itemId] = card
						applyCardSelectionVisual(itemId)
					end

					task.defer(function()
						applyGridSizing()
						list.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 8)
					end)
				end

				list:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					applyGridSizing()
					list.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 8)
				end)
				grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					list.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 8)
				end)

				function gallery:SetItems(nextItems)
					items = {}
					if type(nextItems) == "table" then
						for _, item in ipairs(nextItems) do
							table.insert(items, cloneSerializable(item))
						end
					end
					renderItems()
				end

				function gallery:AddItem(item)
					if type(item) ~= "table" then
						return
					end
					table.insert(items, cloneSerializable(item))
					renderItems()
				end

				function gallery:RemoveItem(itemId)
					local key = tostring(itemId or "")
					for index, item in ipairs(items) do
						local id = tostring(item.id or item.Id or index)
						if id == key then
							table.remove(items, index)
							selected[key] = nil
							break
						end
					end
					renderItems()
					emitSelection()
				end

				function gallery:Select(itemId)
					local key = tostring(itemId or "")
					if selectionMode == "single" then
						selected = {}
					end
					selected[key] = true
					applyCardSelectionVisual(key)
					emitSelection()
				end

				function gallery:Deselect(itemId)
					local key = tostring(itemId or "")
					selected[key] = nil
					applyCardSelectionVisual(key)
					emitSelection()
				end

				function gallery:ClearSelection()
					selected = {}
					for id in pairs(cardById) do
						applyCardSelectionVisual(id)
					end
					emitSelection()
				end

				function gallery:SetSelection(nextSelection)
					selected = {}
					if selectionMode == "single" then
						local value = type(nextSelection) == "table" and nextSelection[1] or nextSelection
						if value ~= nil then
							selected[tostring(value)] = true
						end
					else
						if type(nextSelection) == "table" then
							for _, value in ipairs(nextSelection) do
								selected[tostring(value)] = true
							end
						elseif nextSelection ~= nil then
							selected[tostring(nextSelection)] = true
						end
					end
					for id in pairs(cardById) do
						applyCardSelectionVisual(id)
					end
					emitSelection()
				end

				function gallery:GetSelection()
					return snapshotSelection()
				end

				function gallery:GetPersistValue()
					return cloneSerializable(snapshotSelection())
				end

				function gallery:Set(value)
					gallery:SetSelection(value)
				end

				function gallery:Destroy()
					root:Destroy()
				end

				connectThemeRefresh(function()
					root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					stroke.Color = self.getSelectedTheme().ElementStroke
					title.TextColor3 = self.getSelectedTheme().TextColor
					for id in pairs(cardById) do
						local card = cardById[id]
						if card then
							local label = card:FindFirstChildOfClass("TextLabel")
							if label then
								label.TextColor3 = self.getSelectedTheme().TextColor
							end
						end
						applyCardSelectionVisual(id)
					end
				end)

				resolveElementParentFromSettings(gallery, settingsValue)
				gallery:SetItems(settingsValue.Items or {})
				addExtendedAPI(gallery, gallery.Name, "Gallery", root)
				if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and gallery.Flag then
					self.RayfieldLibrary.Flags[gallery.Flag] = gallery
				end
				return gallery
			end

			function Tab:CreateDataGrid(dataGridSettings)
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

				return self.DataGridFactoryModule.create({
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

				return self.ChartFactoryModule.create({
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

			function Tab:CreateLogConsole(logSettings)
				local settingsValue = logSettings or {}
				local console = {}
				console.Name = tostring(settingsValue.Name or "Log Console")
				console.Flag = settingsValue.Flag
				local captureMode = tostring(settingsValue.CaptureMode or "manual"):lower()
				if captureMode ~= "manual" and captureMode ~= "global" and captureMode ~= "both" then
					captureMode = "manual"
				end
				local maxEntries = math.max(10, math.floor(tonumber(settingsValue.MaxEntries) or 500))
				local autoScroll = settingsValue.AutoScroll ~= false
				local showTimestamp = settingsValue.ShowTimestamp ~= false
				local entries = {}
				local globalUnsubscribe = nil

				local root = Instance.new("Frame")
				root.Name = console.Name
				root.Size = UDim2.new(1, -10, 0, clampNumber(settingsValue.Height, 150, 420, 230))
				root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
				root.BorderSizePixel = 0
				root.Visible = true
				root.Parent = TabPage

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 6)
				corner.Parent = root

				local stroke = Instance.new("UIStroke")
				stroke.Color = self.getSelectedTheme().ElementStroke
				stroke.Parent = root

				local title = Instance.new("TextLabel")
				title.BackgroundTransparency = 1
				title.Position = UDim2.new(0, 10, 0, 0)
				title.Size = UDim2.new(1, -110, 0, 22)
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.Font = Enum.Font.GothamSemibold
				title.TextSize = 13
				title.TextColor3 = self.getSelectedTheme().TextColor
				title.Text = console.Name
				title.Parent = root

				local modeLabel = Instance.new("TextLabel")
				modeLabel.BackgroundTransparency = 1
				modeLabel.AnchorPoint = Vector2.new(1, 0)
				modeLabel.Position = UDim2.new(1, -40, 0, 2)
				modeLabel.Size = UDim2.new(0, 64, 0, 18)
				modeLabel.Font = Enum.Font.Gotham
				modeLabel.TextSize = 11
				modeLabel.TextXAlignment = Enum.TextXAlignment.Right
				modeLabel.TextColor3 = self.getSelectedTheme().TextColor
				modeLabel.Text = string.upper(captureMode)
				modeLabel.Parent = root

				local clearButton = Instance.new("TextButton")
				clearButton.AnchorPoint = Vector2.new(1, 0)
				clearButton.Position = UDim2.new(1, -6, 0, 2)
				clearButton.Size = UDim2.new(0, 28, 0, 18)
				clearButton.Text = "CLR"
				clearButton.Font = Enum.Font.GothamBold
				clearButton.TextSize = 9
				clearButton.TextColor3 = self.getSelectedTheme().TextColor
				clearButton.BackgroundColor3 = self.getSelectedTheme().InputBackground
				clearButton.BorderSizePixel = 0
				clearButton.Parent = root

				local list = Instance.new("ScrollingFrame")
				list.Name = "Entries"
				list.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
				list.BorderSizePixel = 0
				list.Position = UDim2.new(0, 8, 0, 24)
				list.Size = UDim2.new(1, -16, 1, -32)
				list.CanvasSize = UDim2.new(0, 0, 0, 0)
				list.ScrollBarImageTransparency = 0.5
				list.Parent = root

				local listLayout = Instance.new("UIListLayout")
				listLayout.Padding = UDim.new(0, 3)
				listLayout.SortOrder = Enum.SortOrder.LayoutOrder
				listLayout.Parent = list

				local function levelColor(level)
					local normalized = tostring(level or "info"):lower()
					if normalized == "warn" then
						return self.getSelectedTheme().LogWarn or self.getSelectedTheme().SliderStroke
					elseif normalized == "error" then
						return self.getSelectedTheme().LogError or self.getSelectedTheme().ToggleEnabled
					end
					return self.getSelectedTheme().LogInfo or self.getSelectedTheme().TextColor
				end

				local function formatEntry(entry)
					local ts = ""
					if showTimestamp then
						ts = "[" .. os.date("%H:%M:%S", math.floor(entry.time or os.time())) .. "] "
					end
					return ts .. "[" .. string.upper(tostring(entry.level or "info")) .. "] " .. tostring(entry.text or "")
				end

				local function trimEntries()
					while #entries > maxEntries do
						table.remove(entries, 1)
					end
				end

				local function renderEntries()
					for _, child in ipairs(list:GetChildren()) do
						if child:IsA("TextLabel") then
							child:Destroy()
						end
					end
					for index, entry in ipairs(entries) do
						local label = Instance.new("TextLabel")
						label.BackgroundTransparency = 1
						label.Size = UDim2.new(1, -8, 0, 16)
						label.Position = UDim2.new(0, 4, 0, 0)
						label.TextXAlignment = Enum.TextXAlignment.Left
						label.Font = Enum.Font.Code
						label.TextSize = 12
						label.TextColor3 = levelColor(entry.level)
						label.Text = formatEntry(entry)
						label.LayoutOrder = index
						label.Parent = list
					end
					task.defer(function()
						list.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 6)
						if autoScroll then
							list.CanvasPosition = Vector2.new(0, math.max(0, list.CanvasSize.Y.Offset - list.AbsoluteSize.Y))
						end
					end)
				end

				local function appendEntry(level, textValue, persist)
					table.insert(entries, {
						level = tostring(level or "info"):lower(),
						text = tostring(textValue or ""),
						time = os.time()
					})
					trimEntries()
					renderEntries()
					if persist ~= false and settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				local function setCaptureMode(nextMode, persist)
					local normalized = tostring(nextMode or "manual"):lower()
					if normalized ~= "manual" and normalized ~= "global" and normalized ~= "both" then
						return false, "Invalid capture mode."
					end
					captureMode = normalized
					modeLabel.Text = string.upper(captureMode)
					if globalUnsubscribe then
						globalUnsubscribe()
						globalUnsubscribe = nil
					end
					if captureMode == "global" or captureMode == "both" then
						globalUnsubscribe = subscribeGlobalLogs(function(level, textValue)
							appendEntry(level, textValue, true)
						end)
					end
					if persist ~= false and settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
					return true, "ok"
				end

				function console:Log(level, textValue)
					appendEntry(level or "info", textValue, true)
				end

				function console:Info(textValue)
					appendEntry("info", textValue, true)
				end

				function console:Warn(textValue)
					appendEntry("warn", textValue, true)
				end

				function console:Error(textValue)
					appendEntry("error", textValue, true)
				end

				function console:Clear()
					entries = {}
					renderEntries()
					if settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				function console:SetCaptureMode(nextMode)
					return setCaptureMode(nextMode, true)
				end

				function console:GetEntries()
					return cloneSerializable(entries)
				end

				function console:GetPersistValue()
					return {
						captureMode = captureMode,
						entries = cloneSerializable(entries)
					}
				end

				function console:Set(value)
					if type(value) == "table" then
						if type(value.entries) == "table" then
							entries = cloneSerializable(value.entries) or {}
							trimEntries()
							renderEntries()
						end
						if value.captureMode ~= nil then
							setCaptureMode(value.captureMode, false)
						end
					end
				end

				function console:Destroy()
					if globalUnsubscribe then
						globalUnsubscribe()
						globalUnsubscribe = nil
					end
					root:Destroy()
				end

				clearButton.MouseButton1Click:Connect(function()
					console:Clear()
				end)
				setCaptureMode(captureMode, false)

				connectThemeRefresh(function()
					root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					stroke.Color = self.getSelectedTheme().ElementStroke
					title.TextColor3 = self.getSelectedTheme().TextColor
					modeLabel.TextColor3 = self.getSelectedTheme().TextColor
					clearButton.BackgroundColor3 = self.getSelectedTheme().InputBackground
					clearButton.TextColor3 = self.getSelectedTheme().TextColor
					list.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
					renderEntries()
				end)

				resolveElementParentFromSettings(console, settingsValue)
				if type(settingsValue.Entries) == "table" then
					console:Set({
						captureMode = captureMode,
						entries = settingsValue.Entries
					})
				else
					renderEntries()
				end
				addExtendedAPI(console, console.Name, "LogConsole", root)
				if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and console.Flag then
					self.RayfieldLibrary.Flags[console.Flag] = console
				end
				return console
			end

			function Tab:CreateLoadingSpinner(spinnerSettings)
				local settingsValue = spinnerSettings or {}
				local spinner = {}
				spinner.Name = tostring(settingsValue.Name or "Loading Spinner")
				spinner.Flag = settingsValue.Flag

				local spinnerSize = math.floor(clampNumber(settingsValue.Size, 14, 64, 26))
				local spinnerThickness = clampNumber(settingsValue.Thickness, 1, 8, 3)
				local spinnerSpeed = clampNumber(settingsValue.Speed, 0.1, 8, 1.2)
				local running = settingsValue.AutoStart ~= false
				local customColor = typeof(settingsValue.Color) == "Color3" and settingsValue.Color or nil
				local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
				local rotation = 0
				local loopState = {}

				local root = Instance.new("Frame")
				root.Name = spinner.Name
				root.Size = UDim2.new(1, -10, 0, 44)
				root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
				root.BorderSizePixel = 0
				root.Visible = true
				root.Parent = TabPage

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 6)
				corner.Parent = root

				local stroke = Instance.new("UIStroke")
				stroke.Color = self.getSelectedTheme().ElementStroke
				stroke.Parent = root

				local title = Instance.new("TextLabel")
				title.BackgroundTransparency = 1
				title.Position = UDim2.new(0, 10, 0, 0)
				title.Size = UDim2.new(1, -70, 1, 0)
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.Font = Enum.Font.GothamMedium
				title.TextSize = 13
				title.TextColor3 = self.getSelectedTheme().TextColor
				title.Text = spinner.Name
				title.Parent = root

				local spinnerHost = Instance.new("Frame")
				spinnerHost.Name = "SpinnerHost"
				spinnerHost.AnchorPoint = Vector2.new(1, 0.5)
				spinnerHost.Position = UDim2.new(1, -12, 0.5, 0)
				spinnerHost.Size = UDim2.new(0, spinnerSize, 0, spinnerSize)
				spinnerHost.BackgroundTransparency = 1
				spinnerHost.Parent = root

				local ring = Instance.new("Frame")
				ring.Name = "Ring"
				ring.Size = UDim2.new(1, 0, 1, 0)
				ring.BackgroundTransparency = 1
				ring.BorderSizePixel = 0
				ring.Parent = spinnerHost

				local ringCorner = Instance.new("UICorner")
				ringCorner.CornerRadius = UDim.new(1, 0)
				ringCorner.Parent = ring

				local ringStroke = Instance.new("UIStroke")
				ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				ringStroke.Thickness = spinnerThickness
				ringStroke.Transparency = 0.55
				ringStroke.Parent = ring

				local dot = Instance.new("Frame")
				dot.Name = "Dot"
				dot.Size = UDim2.new(0, math.max(4, math.floor(spinnerThickness * 1.9)), 0, math.max(4, math.floor(spinnerThickness * 1.9)))
				dot.BackgroundColor3 = self.getSelectedTheme().LoadingSpinner or self.getSelectedTheme().SliderProgress
				dot.BorderSizePixel = 0
				dot.Parent = spinnerHost

				local dotCorner = Instance.new("UICorner")
				dotCorner.CornerRadius = UDim.new(1, 0)
				dotCorner.Parent = dot

				local function resolveSpinnerColor()
					return customColor or self.getSelectedTheme().LoadingSpinner or self.getSelectedTheme().SliderProgress
				end

				local function updateSpinnerPosition()
					local hostWidth = math.max(1, spinnerHost.AbsoluteSize.X)
					local hostHeight = math.max(1, spinnerHost.AbsoluteSize.Y)
					local dotSize = math.max(4, math.floor(spinnerThickness * 1.9))
					dot.Size = UDim2.new(0, dotSize, 0, dotSize)
					local radius = math.max(3, math.min(hostWidth, hostHeight) * 0.5 - math.max(dotSize * 0.55, spinnerThickness))
					local centerX = hostWidth * 0.5
					local centerY = hostHeight * 0.5
					local x = centerX + math.cos(rotation) * radius - (dotSize * 0.5)
					local y = centerY + math.sin(rotation) * radius - (dotSize * 0.5)
					dot.Position = UDim2.new(0, x, 0, y)
				end

				local function applySpinnerVisual()
					root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					stroke.Color = self.getSelectedTheme().ElementStroke
					title.TextColor3 = self.getSelectedTheme().TextColor
					ringStroke.Color = self.getSelectedTheme().LoadingTrack or self.getSelectedTheme().SliderBackground
					ringStroke.Thickness = spinnerThickness
					dot.BackgroundColor3 = resolveSpinnerColor()
					spinnerHost.Size = UDim2.new(0, spinnerSize, 0, spinnerSize)
					updateSpinnerPosition()
				end

				local function getStateSnapshot()
					return {
						running = running == true,
						speed = spinnerSpeed,
						size = spinnerSize,
						thickness = spinnerThickness
					}
				end

				local function emitStateChanged(persist)
					local okCallback, callbackErr = pcall(callback, cloneSerializable(getStateSnapshot()))
					if not okCallback then
						warn("Rayfield | LoadingSpinner callback failed: " .. tostring(callbackErr))
					end
					if persist ~= false and settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				local function stepSpinner(deltaTime)
					if running ~= true then
						return
					end
					rotation += (deltaTime * spinnerSpeed * math.pi * 2)
					if rotation > (math.pi * 2) then
						rotation -= (math.pi * 2)
					end
					updateSpinnerPosition()
				end

				function spinner:Start(persist)
					if running == true then
						startRenderLoop(loopState, stepSpinner)
						return true, "already_running"
					end
					running = true
					startRenderLoop(loopState, stepSpinner)
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function spinner:Stop(persist)
					if running ~= true then
						stopRenderLoop(loopState)
						return true, "already_stopped"
					end
					running = false
					stopRenderLoop(loopState)
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function spinner:IsRunning()
					return running == true and loopState.Connection ~= nil
				end

				function spinner:SetSpeed(nextSpeed, persist)
					spinnerSpeed = clampNumber(nextSpeed, 0.1, 8, spinnerSpeed)
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function spinner:GetSpeed()
					return spinnerSpeed
				end

				function spinner:SetColor(nextColor, persist)
					if typeof(nextColor) ~= "Color3" then
						return false, "SetColor expects Color3."
					end
					customColor = nextColor
					applySpinnerVisual()
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function spinner:SetSize(nextSize, persist)
					spinnerSize = math.floor(clampNumber(nextSize, 14, 64, spinnerSize))
					applySpinnerVisual()
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function spinner:GetPersistValue()
					local snapshot = getStateSnapshot()
					local packed = packColor3(customColor)
					if packed then
						snapshot.colorPacked = packed
					end
					return snapshot
				end

				function spinner:Set(value)
					if type(value) ~= "table" then
						return
					end
					if value.size ~= nil then
						spinnerSize = math.floor(clampNumber(value.size, 14, 64, spinnerSize))
					end
					if value.thickness ~= nil then
						spinnerThickness = clampNumber(value.thickness, 1, 8, spinnerThickness)
					end
					if value.speed ~= nil then
						spinnerSpeed = clampNumber(value.speed, 0.1, 8, spinnerSpeed)
					end
					if value.colorPacked ~= nil then
						customColor = unpackColor3(value.colorPacked) or customColor
					elseif typeof(value.color) == "Color3" then
						customColor = value.color
					end
					applySpinnerVisual()
					if value.running == true then
						spinner:Start(false)
					elseif value.running == false then
						spinner:Stop(false)
					else
						emitStateChanged(false)
					end
				end

				function spinner:Destroy()
					stopRenderLoop(loopState)
					root:Destroy()
				end

				connectThemeRefresh(function()
					applySpinnerVisual()
				end)

				resolveElementParentFromSettings(spinner, settingsValue)
				applySpinnerVisual()
				if running == true then
					startRenderLoop(loopState, stepSpinner)
				end
				addExtendedAPI(spinner, spinner.Name, "LoadingSpinner", root)
				if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and spinner.Flag then
					self.RayfieldLibrary.Flags[spinner.Flag] = spinner
				end
				return spinner
			end

			function Tab:CreateLoadingBar(barSettings)
				local settingsValue = barSettings or {}
				local loadingBar = {}
				loadingBar.Name = tostring(settingsValue.Name or "Loading Bar")
				loadingBar.Flag = settingsValue.Flag

				local mode = tostring(settingsValue.Mode or "indeterminate"):lower()
				if mode ~= "indeterminate" and mode ~= "determinate" then
					mode = "indeterminate"
				end
				local speed = clampNumber(settingsValue.Speed, 0.1, 6, 1.1)
				local chunkScale = clampNumber(settingsValue.ChunkScale, 0.1, 0.8, 0.35)
				local progress = clampNumber(settingsValue.Progress, 0, 1, 0)
				local showLabel = settingsValue.ShowLabel == true
				local customLabel = nil
				local labelFormatter = type(settingsValue.LabelFormatter) == "function" and settingsValue.LabelFormatter or nil
				local callback = type(settingsValue.Callback) == "function" and settingsValue.Callback or function() end
				local running = mode == "indeterminate" and settingsValue.AutoStart ~= false
				local loopState = {}
				local animationPhase = 0
				local barHeight = math.floor(clampNumber(settingsValue.Height, 12, 40, 18))

				local root = Instance.new("Frame")
				root.Name = loadingBar.Name
				root.Size = UDim2.new(1, -10, 0, math.max(44, barHeight + 26))
				root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
				root.BorderSizePixel = 0
				root.Visible = true
				root.Parent = TabPage

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 6)
				corner.Parent = root

				local stroke = Instance.new("UIStroke")
				stroke.Color = self.getSelectedTheme().ElementStroke
				stroke.Parent = root

				local title = Instance.new("TextLabel")
				title.BackgroundTransparency = 1
				title.Position = UDim2.new(0, 10, 0, 0)
				title.Size = UDim2.new(0.65, 0, 0, 20)
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.Font = Enum.Font.GothamMedium
				title.TextSize = 13
				title.TextColor3 = self.getSelectedTheme().TextColor
				title.Text = loadingBar.Name
				title.Parent = root

				local statusLabel = Instance.new("TextLabel")
				statusLabel.BackgroundTransparency = 1
				statusLabel.AnchorPoint = Vector2.new(1, 0)
				statusLabel.Position = UDim2.new(1, -10, 0, 2)
				statusLabel.Size = UDim2.new(0.35, -4, 0, 18)
				statusLabel.TextXAlignment = Enum.TextXAlignment.Right
				statusLabel.Font = Enum.Font.Gotham
				statusLabel.TextSize = 11
				statusLabel.TextColor3 = self.getSelectedTheme().LoadingText or self.getSelectedTheme().TextColor
				statusLabel.Visible = showLabel
				statusLabel.Parent = root

				local track = Instance.new("Frame")
				track.Name = "Track"
				track.Position = UDim2.new(0, 10, 0, 22)
				track.Size = UDim2.new(1, -20, 0, barHeight)
				track.BackgroundColor3 = self.getSelectedTheme().LoadingTrack or self.getSelectedTheme().SliderBackground
				track.BorderSizePixel = 0
				track.ClipsDescendants = true
				track.Parent = root

				local trackCorner = Instance.new("UICorner")
				trackCorner.CornerRadius = UDim.new(0, math.max(4, math.floor(barHeight * 0.5)))
				trackCorner.Parent = track

				local fill = Instance.new("Frame")
				fill.Name = "Fill"
				fill.Size = UDim2.new(progress, 0, 1, 0)
				fill.BackgroundColor3 = self.getSelectedTheme().LoadingBar or self.getSelectedTheme().SliderProgress
				fill.BorderSizePixel = 0
				fill.Parent = track

				local fillCorner = Instance.new("UICorner")
				fillCorner.CornerRadius = UDim.new(0, math.max(4, math.floor(barHeight * 0.5)))
				fillCorner.Parent = fill

				local chunk = Instance.new("Frame")
				chunk.Name = "Chunk"
				chunk.Size = UDim2.new(chunkScale, 0, 1, 0)
				chunk.Position = UDim2.new(0, 0, 0, 0)
				chunk.BackgroundColor3 = self.getSelectedTheme().LoadingBar or self.getSelectedTheme().SliderProgress
				chunk.BorderSizePixel = 0
				chunk.Parent = track

				local chunkCorner = Instance.new("UICorner")
				chunkCorner.CornerRadius = UDim.new(0, math.max(4, math.floor(barHeight * 0.5)))
				chunkCorner.Parent = chunk

				local function getStateSnapshot()
					return {
						mode = mode,
						running = running == true and mode == "indeterminate",
						progress = progress,
						speed = speed,
						chunkScale = chunkScale,
						label = customLabel
					}
				end

				local function emitStateChanged(persist)
					local okCallback, callbackErr = pcall(callback, cloneSerializable(getStateSnapshot()))
					if not okCallback then
						warn("Rayfield | LoadingBar callback failed: " .. tostring(callbackErr))
					end
					if persist ~= false and settingsValue.Ext ~= true then
						self.SaveConfiguration()
					end
				end

				local function formatLabelText()
					if customLabel and customLabel ~= "" then
						return customLabel
					end
					local percent = math.floor((progress * 100) + 0.5)
					if labelFormatter then
						local okFormat, formatted = pcall(labelFormatter, progress, percent, mode)
						if okFormat and formatted ~= nil then
							return tostring(formatted)
						end
					end
					if mode == "determinate" then
						return tostring(percent) .. "%"
					end
					return "Loading..."
				end

				local function updateBarVisual()
					root.BackgroundColor3 = self.getSelectedTheme().ElementBackground
					stroke.Color = self.getSelectedTheme().ElementStroke
					title.TextColor3 = self.getSelectedTheme().TextColor
					statusLabel.TextColor3 = self.getSelectedTheme().LoadingText or self.getSelectedTheme().TextColor
					statusLabel.Visible = showLabel
					if showLabel then
						statusLabel.Text = formatLabelText()
					end
					track.BackgroundColor3 = self.getSelectedTheme().LoadingTrack or self.getSelectedTheme().SliderBackground
					fill.BackgroundColor3 = self.getSelectedTheme().LoadingBar or self.getSelectedTheme().SliderProgress
					chunk.BackgroundColor3 = self.getSelectedTheme().LoadingBar or self.getSelectedTheme().SliderProgress
					fill.Visible = mode == "determinate"
					chunk.Visible = mode == "indeterminate" and running == true
					if mode == "determinate" then
						fill.Size = UDim2.new(progress, 0, 1, 0)
					end
				end

				local function stepBar(deltaTime)
					if mode ~= "indeterminate" or running ~= true then
						return
					end
					local trackWidth = math.max(1, track.AbsoluteSize.X)
					local chunkWidth = math.max(8, math.floor(trackWidth * chunkScale))
					chunk.Size = UDim2.new(0, chunkWidth, 1, 0)
					animationPhase = (animationPhase + (deltaTime * speed)) % 2
					local t = animationPhase
					if t > 1 then
						t = 2 - t
					end
					local usableWidth = math.max(0, trackWidth - chunkWidth)
					local x = math.floor(usableWidth * t + 0.5)
					chunk.Position = UDim2.new(0, x, 0, 0)
				end

				function loadingBar:Start(persist)
					if mode ~= "indeterminate" then
						return false, "Start is available only in indeterminate mode."
					end
					if running == true then
						startRenderLoop(loopState, stepBar)
						return true, "already_running"
					end
					running = true
					startRenderLoop(loopState, stepBar)
					updateBarVisual()
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function loadingBar:Stop(persist)
					if running ~= true then
						stopRenderLoop(loopState)
						return true, "already_stopped"
					end
					running = false
					stopRenderLoop(loopState)
					updateBarVisual()
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function loadingBar:IsRunning()
					return mode == "indeterminate" and running == true and loopState.Connection ~= nil
				end

				function loadingBar:SetMode(nextMode, persist)
					local normalized = tostring(nextMode or ""):lower()
					if normalized ~= "indeterminate" and normalized ~= "determinate" then
						return false, "Invalid mode."
					end
					mode = normalized
					if mode ~= "indeterminate" then
						running = false
						stopRenderLoop(loopState)
					end
					updateBarVisual()
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function loadingBar:GetMode()
					return mode
				end

				function loadingBar:SetProgress(nextProgress, persist)
					progress = clampNumber(nextProgress, 0, 1, progress)
					if mode ~= "determinate" then
						mode = "determinate"
						running = false
						stopRenderLoop(loopState)
					end
					updateBarVisual()
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function loadingBar:GetProgress()
					return progress
				end

				function loadingBar:SetSpeed(nextSpeed, persist)
					speed = clampNumber(nextSpeed, 0.1, 6, speed)
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function loadingBar:SetLabel(text, persist)
					if not showLabel then
						return false, "ShowLabel is disabled."
					end
					customLabel = tostring(text or "")
					updateBarVisual()
					emitStateChanged(persist ~= false)
					return true, "ok"
				end

				function loadingBar:GetPersistValue()
					return getStateSnapshot()
				end

				function loadingBar:Set(value)
					if type(value) ~= "table" then
						return
					end
					if value.mode ~= nil then
						local normalized = tostring(value.mode):lower()
						if normalized == "indeterminate" or normalized == "determinate" then
							mode = normalized
						end
					end
					if value.speed ~= nil then
						speed = clampNumber(value.speed, 0.1, 6, speed)
					end
					if value.chunkScale ~= nil then
						chunkScale = clampNumber(value.chunkScale, 0.1, 0.8, chunkScale)
					end
					if value.progress ~= nil then
						progress = clampNumber(value.progress, 0, 1, progress)
					end
					if value.label ~= nil then
						customLabel = tostring(value.label or "")
					end
					if value.running == true and mode == "indeterminate" then
						running = true
					elseif value.running == false or mode ~= "indeterminate" then
						running = false
					end
					updateBarVisual()
					if mode == "indeterminate" and running == true then
						startRenderLoop(loopState, stepBar)
					else
						stopRenderLoop(loopState)
					end
					emitStateChanged(false)
				end

				function loadingBar:Destroy()
					stopRenderLoop(loopState)
					root:Destroy()
				end

				connectThemeRefresh(function()
					updateBarVisual()
				end)

				resolveElementParentFromSettings(loadingBar, settingsValue)
				updateBarVisual()
				if mode == "indeterminate" and running == true then
					startRenderLoop(loopState, stepBar)
				end
				addExtendedAPI(loadingBar, loadingBar.Name, "LoadingBar", root)
				if Settings.ConfigurationSaving and Settings.ConfigurationSaving.Enabled and loadingBar.Flag then
					self.RayfieldLibrary.Flags[loadingBar.Flag] = loadingBar
				end
				return loadingBar
			end

			-- Divider
			function Tab:CreateDivider()
				local DividerValue = {}
	
				local Divider = self.Elements.Template.Divider:Clone()
				Divider.Visible = true
				Divider.Parent = TabPage
	
				Divider.Divider.BackgroundTransparency = 1
				self.Animation:Create(Divider.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.85}):Play()
	
				function DividerValue:Set(Value)
					Divider.Visible = Value
				end
	
				function DividerValue:Destroy()
					Divider:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(DividerValue, "Divider", "Divider", Divider)
	
				return DividerValue
			end
	
			-- Label
			function Tab:CreateLabel(LabelText, Icon, Color, IgnoreTheme)
				local LabelValue = {}
	
				local Label = self.Elements.Template.Label:Clone()
				Label.Title.Text = LabelText
				Label.Visible = true
				Label.Parent = TabPage
	
				Label.BackgroundColor3 = Color or self.getSelectedTheme().SecondaryElementBackground
				Label.UIStroke.Color = Color or self.getSelectedTheme().SecondaryElementStroke
	
				if Icon then
					if typeof(Icon) == 'string' and self.Icons then
						local asset = self.getIcon(Icon)
	
						Label.Icon.Image = 'rbxassetid://'..asset.id
						Label.Icon.ImageRectOffset = asset.imageRectOffset
						Label.Icon.ImageRectSize = asset.imageRectSize
					else
						Label.Icon.Image = self.getAssetUri(Icon)
					end
				else
					Label.Icon.Image = "rbxassetid://" .. 0
				end
	
				if Icon and Label:FindFirstChild('Icon') then
					Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
					Label.Title.Size = UDim2.new(1, -100, 0, 14)
	
					if Icon then
						if typeof(Icon) == 'string' and self.Icons then
							local asset = self.getIcon(Icon)
	
							Label.Icon.Image = 'rbxassetid://'..asset.id
							Label.Icon.ImageRectOffset = asset.imageRectOffset
							Label.Icon.ImageRectSize = asset.imageRectSize
						else
							Label.Icon.Image = self.getAssetUri(Icon)
						end
					else
						Label.Icon.Image = "rbxassetid://" .. 0
					end
	
					Label.Icon.Visible = true
				end
	
				Label.Icon.ImageTransparency = 1
				Label.BackgroundTransparency = 1
				Label.UIStroke.Transparency = 1
				Label.Title.TextTransparency = 1
	
				self.Animation:Create(Label, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = Color and 0.8 or 0}):Play()
				self.Animation:Create(Label.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = Color and 0.7 or 0}):Play()
				self.Animation:Create(Label.Icon, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0.2}):Play()
				self.Animation:Create(Label.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = Color and 0.2 or 0}):Play()	
	
				function LabelValue:Set(NewLabel, Icon, Color)
					Label.Title.Text = NewLabel
	
					if Color then
						Label.BackgroundColor3 = Color or self.getSelectedTheme().SecondaryElementBackground
						Label.UIStroke.Color = Color or self.getSelectedTheme().SecondaryElementStroke
					end
	
					if Icon and Label:FindFirstChild('Icon') then
						Label.Title.Position = UDim2.new(0, 45, 0.5, 0)
						Label.Title.Size = UDim2.new(1, -100, 0, 14)
	
						if Icon then
							if typeof(Icon) == 'string' and self.Icons then
								local asset = self.getIcon(Icon)
	
								Label.Icon.Image = 'rbxassetid://'..asset.id
								Label.Icon.ImageRectOffset = asset.imageRectOffset
								Label.Icon.ImageRectSize = asset.imageRectSize
							else
								Label.Icon.Image = self.getAssetUri(Icon)
							end
						else
							Label.Icon.Image = "rbxassetid://" .. 0
						end
	
						Label.Icon.Visible = true
					end
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Label.BackgroundColor3 = IgnoreTheme and (Color or Label.BackgroundColor3) or self.getSelectedTheme().SecondaryElementBackground
					Label.UIStroke.Color = IgnoreTheme and (Color or Label.BackgroundColor3) or self.getSelectedTheme().SecondaryElementStroke
				end)
	
				function LabelValue:Destroy()
					Label:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(LabelValue, LabelText, "Label", Label)
	
				return LabelValue
			end
	
			-- Paragraph
			function Tab:CreateParagraph(ParagraphSettings)
				local ParagraphValue = {}
	
				local Paragraph = self.Elements.Template.Paragraph:Clone()
				Paragraph.Title.Text = ParagraphSettings.Title
				Paragraph.Content.Text = ParagraphSettings.Content
				Paragraph.Visible = true
				Paragraph.Parent = TabPage
	
				Paragraph.BackgroundTransparency = 1
				Paragraph.UIStroke.Transparency = 1
				Paragraph.Title.TextTransparency = 1
				Paragraph.Content.TextTransparency = 1
	
				Paragraph.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
				Paragraph.UIStroke.Color = self.getSelectedTheme().SecondaryElementStroke
	
				self.Animation:Create(Paragraph, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Paragraph.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Paragraph.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
				self.Animation:Create(Paragraph.Content, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	
				function ParagraphValue:Set(NewParagraphSettings)
					Paragraph.Title.Text = NewParagraphSettings.Title
					Paragraph.Content.Text = NewParagraphSettings.Content
				end
	
				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					Paragraph.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
					Paragraph.UIStroke.Color = self.getSelectedTheme().SecondaryElementStroke
				end)
	
				function ParagraphValue:Destroy()
					Paragraph:Destroy()
				end
	
				-- Add extended API
				addExtendedAPI(ParagraphValue, ParagraphSettings.Title, "Paragraph", Paragraph)
	
				return ParagraphValue
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

			local function normalizeBarSettings(rawSettings, defaults)
				local settings = rawSettings or {}
				settings.Name = settings.Name or defaults.name
				settings.Range = settings.Range or {0, 100}

				local rangeMin = tonumber(settings.Range[1]) or 0
				local rangeMax = tonumber(settings.Range[2]) or 100
				if rangeMax <= rangeMin then
					rangeMax = rangeMin + 1
				end
				settings.Range = {rangeMin, rangeMax}

				settings.Increment = tonumber(settings.Increment) or 1
				if settings.Increment <= 0 then
					settings.Increment = 1
				end

				local currentValue = tonumber(settings.CurrentValue)
				if currentValue == nil then
					currentValue = rangeMin
				end
				settings.CurrentValue = math.clamp(currentValue, rangeMin, rangeMax)

				if type(settings.Callback) ~= "function" then
					settings.Callback = function() end
				end

				if settings.Draggable == nil then
					settings.Draggable = defaults.draggable
				end

				settings.Type = defaults.typeName
				return settings
			end

			local function createCustomBar(rawSettings, customOptions)
				local ctx = self
				customOptions = customOptions or {}
				local barSettings = normalizeBarSettings(rawSettings, {
					name = customOptions.defaultName or "Bar",
					draggable = customOptions.defaultDraggable ~= false,
					typeName = customOptions.typeName or "Bar"
				})
				local showText = customOptions.showText == true
				local statusMode = customOptions.statusMode == true
				local barMin = barSettings.Range[1]
				local barMax = barSettings.Range[2]
				local barDragging = false

				local Bar = self.Elements.Template.Slider:Clone()
				Bar.Name = barSettings.Name
				Bar.Title.Text = barSettings.Name
				Bar.Visible = true
				Bar.Parent = TabPage

				Bar.BackgroundTransparency = 1
				Bar.UIStroke.Transparency = 1
				Bar.Title.TextTransparency = 1

				local BarMain = Bar.Main
				local BarProgress = BarMain.Progress
				local BarValueLabel = BarMain.Information

				if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
					BarMain.Shadow.Visible = false
				end

				self.bindTheme(BarMain, "BackgroundColor3", "SliderBackground")
				self.bindTheme(BarMain.UIStroke, "Color", "SliderStroke")
				self.bindTheme(BarProgress.UIStroke, "Color", "SliderStroke")
				self.bindTheme(BarProgress, "BackgroundColor3", "SliderProgress")

				self.Animation:Create(Bar, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				self.Animation:Create(Bar.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				self.Animation:Create(Bar.Title, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()

				if showText then
					BarValueLabel.Visible = true
					if statusMode then
						BarValueLabel.AnchorPoint = Vector2.new(0.5, 0.5)
						BarValueLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
						BarValueLabel.Size = UDim2.new(1, -8, 1, 0)
						BarValueLabel.TextXAlignment = Enum.TextXAlignment.Center
						BarValueLabel.TextYAlignment = Enum.TextYAlignment.Center
						BarValueLabel.ZIndex = BarProgress.ZIndex + 2
						BarValueLabel.TextStrokeTransparency = 0.7
						if barSettings.TextSize then
							BarValueLabel.TextSize = barSettings.TextSize
						end
					end
				else
					BarValueLabel.Visible = false
					BarValueLabel.TextTransparency = 1
				end

				local function ensureCorner(target, radiusPx)
					local corner = target:FindFirstChildWhichIsA("UICorner")
					if not corner then
						corner = Instance.new("UICorner")
						corner.Parent = target
					end
					corner.CornerRadius = UDim.new(0, radiusPx)
				end

				local function applyBarGeometry()
					local desiredHeight = tonumber(barSettings.Height) or tonumber(barSettings.BarHeight)
					if statusMode and not desiredHeight and barSettings.AutoHeight ~= false then
						local textSize = tonumber(barSettings.TextSize) or (BarValueLabel and BarValueLabel.TextSize or 14)
						desiredHeight = math.clamp(math.floor(textSize + 12), 26, 44)
					end

					if desiredHeight then
						desiredHeight = math.max(12, math.floor(desiredHeight))
						local baseYOffset = BarMain.Position.Y.Offset
						if baseYOffset <= 0 then
							baseYOffset = 24
						end
						BarMain.Size = UDim2.new(BarMain.Size.X.Scale, BarMain.Size.X.Offset, 0, desiredHeight)
						Bar.Size = UDim2.new(1, -10, 0, baseYOffset + desiredHeight + 10)
					end

					if statusMode or barSettings.Roundness then
						local roundness = tonumber(barSettings.Roundness)
						if not roundness then
							local sourceHeight = BarMain.Size.Y.Offset
							roundness = math.max(6, math.floor(sourceHeight / 2))
						end
						ensureCorner(BarMain, roundness)
						ensureCorner(BarProgress, roundness)
					end
				end

				applyBarGeometry()

				local function formatBarText(value)
					if not showText then
						return ""
					end

					local percent = ((value - barMin) / (barMax - barMin)) * 100
					if type(barSettings.TextFormatter) == "function" then
						local ok, custom = pcall(barSettings.TextFormatter, value, barMax, percent)
						if ok and custom ~= nil then
							return tostring(custom)
						end
					end

					local defaultText = tostring(value) .. "/" .. tostring(barMax)
					if barSettings.Suffix and tostring(barSettings.Suffix) ~= "" then
						defaultText = defaultText .. " " .. tostring(barSettings.Suffix)
					end
					return defaultText
				end

				local function valueToWidth(value)
					local width = BarMain.AbsoluteSize.X
					if width <= 0 then
						return 0
					end
					local ratio = math.clamp((value - barMin) / (barMax - barMin), 0, 1)
					local result = width * ratio
					if ratio > 0 and result < 5 then
						result = 5
					end
					return result
				end

				local function applyVisualValue(value, animate)
					local targetWidth = valueToWidth(value)
					if animate then
						self.Animation:Create(BarProgress, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(0, targetWidth, 1, 0)}):Play()
					else
						BarProgress.Size = UDim2.new(0, targetWidth, 1, 0)
					end

					if showText and BarValueLabel then
						BarValueLabel.Text = formatBarText(value)
					end
				end

				local function handleBarCallbackError(response)
					self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					self.Animation:Create(Bar.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
					Bar.Title.Text = "Callback Error"
					print("Rayfield | " .. barSettings.Name .. " Callback Error " .. tostring(response))
					warn('Check docs.sirius.menu for help with Rayfield specific development.')
					task.wait(0.5)
					Bar.Title.Text = barSettings.Name
					self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					self.Animation:Create(Bar.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
				end

				local function triggerCallback(nextValue)
					local Success, Response = pcall(function()
						barSettings.Callback(nextValue)
					end)
					if not Success then
						handleBarCallbackError(Response)
					end
					return Success
				end

				local function normalizeValue(rawValue)
					local value = math.clamp(tonumber(rawValue) or barMin, barMin, barMax)
					value = math.floor((value / barSettings.Increment) + 0.5) * barSettings.Increment
					value = math.floor((value * 10000000) + 0.5) / 10000000
					return math.clamp(value, barMin, barMax)
				end

				local barSyncToken = nil
				local function applyBarValue(rawValue, opts)
					opts = opts or {}
					if barSyncToken then
						return commitElementSync(barSyncToken, rawValue, {
							reason = opts.reason or "bar_update",
							source = opts.source or "unknown",
							emitCallback = opts.emitCallback,
							persist = opts.persist,
							forceCallback = opts.forceCallback,
							animate = opts.animate
						})
					end

					local nextValue = normalizeValue(rawValue)
					applyVisualValue(nextValue, opts.animate ~= false)
					local callbackSuccess = triggerCallback(nextValue)
					barSettings.CurrentValue = nextValue
					if callbackSuccess and opts.persist and not barSettings.Ext then
						self.SaveConfiguration()
					end
					return callbackSuccess
				end

				barSyncToken = registerElementSync({
					name = barSettings.Name,
					getState = function()
						return barSettings.CurrentValue
					end,
					normalize = function(rawValue)
						local nextValue = normalizeValue(rawValue)
						return nextValue, {
							changed = barSettings.CurrentValue ~= nextValue
						}
					end,
					applyVisual = function(value, syncMeta)
						local animate = true
						if syncMeta and syncMeta.options and syncMeta.options.animate == false then
							animate = false
						end
						applyVisualValue(value, animate)
						barSettings.CurrentValue = value
					end,
					emitCallback = function(value)
						barSettings.Callback(value)
					end,
					persist = function()
						self.SaveConfiguration()
					end,
					isExt = function()
						return barSettings.Ext == true
					end,
					isAlive = function()
						return Bar ~= nil and Bar.Parent ~= nil
					end,
					isVisibleContext = function()
						return Bar.Visible and Bar:IsDescendantOf(TabPage) and self.Elements.UIPageLayout.CurrentPage == TabPage
					end,
					onCallbackError = handleBarCallbackError
				})

				applyVisualValue(barSettings.CurrentValue, false)
				task.defer(function()
					if Bar and Bar.Parent then
						applyVisualValue(barSettings.CurrentValue, false)
					end
				end)

				local barHoverBindingKey = registerHoverBinding(Bar,
					function()
						self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover}):Play()
					end,
					function()
						self.Animation:Create(Bar, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = self.getSelectedTheme().ElementBackground}):Play()
					end
				)

				BarMain.Interact.InputBegan:Connect(function(Input)
					if not barSettings.Draggable then
						return
					end
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						self.Animation:Create(BarMain.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						self.Animation:Create(BarProgress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
						barDragging = true
					end
				end)

				BarMain.Interact.InputEnded:Connect(function(Input)
					if not barSettings.Draggable then
						return
					end
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						self.Animation:Create(BarMain.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.4}):Play()
						self.Animation:Create(BarProgress.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {Transparency = 0.3}):Play()
						barDragging = false
					end
				end)

				BarMain.Interact.MouseButton1Down:Connect(function(mouseX)
					if not barSettings.Draggable then
						return
					end

					local currentX = BarProgress.AbsolutePosition.X + BarProgress.AbsoluteSize.X
					local startX = currentX
					local locationX = mouseX
					local progressTween = nil
					local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

					local loopConn
					loopConn = self.RunService.Stepped:Connect(function()
						if barDragging then
							locationX = self.UserInputService:GetMouseLocation().X
							currentX = currentX + 0.025 * (locationX - startX)

							local minX = BarMain.AbsolutePosition.X
							local maxX = BarMain.AbsolutePosition.X + BarMain.AbsoluteSize.X

							if locationX < minX then
								locationX = minX
							elseif locationX > maxX then
								locationX = maxX
							end

							if currentX < minX + 5 then
								currentX = minX + 5
							elseif currentX > maxX then
								currentX = maxX
							end

							if (currentX <= locationX and (locationX - startX) < 0) or (currentX >= locationX and (locationX - startX) > 0) then
								startX = locationX
							end

							if progressTween then
								progressTween:Cancel()
							end
							progressTween = self.Animation:Create(BarProgress, tweenInfo, {Size = UDim2.new(0, currentX - minX, 1, 0)})
							progressTween:Play()

							local nextValue = barMin + ((locationX - minX) / math.max(1, BarMain.AbsoluteSize.X)) * (barMax - barMin)
							if barSettings.CurrentValue ~= normalizeValue(nextValue) then
								applyBarValue(nextValue, {animate = false, persist = true})
							end
						else
							self.Animation:Create(BarProgress, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
								Size = UDim2.new(0, locationX - BarMain.AbsolutePosition.X > 5 and locationX - BarMain.AbsolutePosition.X or 5, 1, 0)
							}):Play()

							if loopConn then
								loopConn:Disconnect()
							end
						end
					end)
				end)

				function barSettings:Set(NewVal)
					applyBarValue(NewVal, {animate = true, persist = true, forceCallback = true})
				end

				function barSettings:Get()
					return barSettings.CurrentValue
				end

				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and barSettings.Flag then
						self.RayfieldLibrary.Flags[barSettings.Flag] = barSettings
					end
				end

				self.Rayfield.Main:GetPropertyChangedSignal('BackgroundColor3'):Connect(function()
					if self.getSelectedTheme() ~= self.RayfieldLibrary.Theme.Default then
						BarMain.Shadow.Visible = false
					end

					BarMain.BackgroundColor3 = self.getSelectedTheme().SliderBackground
					BarMain.UIStroke.Color = self.getSelectedTheme().SliderStroke
					BarProgress.UIStroke.Color = self.getSelectedTheme().SliderStroke
					BarProgress.BackgroundColor3 = self.getSelectedTheme().SliderProgress
					if showText and BarValueLabel then
						BarValueLabel.TextColor3 = self.getSelectedTheme().TextColor
					end
				end)

				function barSettings:Destroy()
					Bar:Destroy()
				end

				addExtendedAPI(barSettings, barSettings.Name, customOptions.typeName or "Bar", Bar, barHoverBindingKey, barSyncToken)
				return barSettings
			end

			function Tab:CreateTrackBar(TrackBarSettings)
				return createCustomBar(TrackBarSettings, {
					defaultName = "Track Bar",
					defaultDraggable = true,
					showText = false,
					statusMode = false,
					typeName = "TrackBar"
				})
			end

			function Tab:CreateStatusBar(StatusBarSettings)
				return createCustomBar(StatusBarSettings, {
					defaultName = "Status Bar",
					defaultDraggable = false,
					showText = true,
					statusMode = true,
					typeName = "StatusBar"
				})
			end

			function Tab:CreateDragBar(settings)
				return self:CreateTrackBar(settings)
			end

			function Tab:CreateSliderLite(settings)
				return self:CreateTrackBar(settings)
			end

			function Tab:CreateInfoBar(settings)
				return self:CreateStatusBar(settings)
			end

			function Tab:CreateSliderDisplay(settings)
				return self:CreateStatusBar(settings)
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
		return pinBadgesVisible == true
	end
	self.subscribeControlRegistry = function(callback)
		if type(callback) ~= "function" then
			return function() end
		end
		controlRegistrySubscribers[callback] = true
		local unsubscribed = false
		return function()
			if unsubscribed then
				return
			end
			unsubscribed = true
			controlRegistrySubscribers[callback] = nil
		end
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



