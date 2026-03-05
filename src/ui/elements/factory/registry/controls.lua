local ControlRegistry = {}

local function defaultSetGuiTitleText(guiObject, text)
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

function ControlRegistry.create(options)
	options = type(options) == "table" and options or {}

	local resolveControlDisplayLabel = type(options.resolveControlDisplayLabel) == "function" and options.resolveControlDisplayLabel or nil
	local persistControlDisplayLabel = type(options.persistControlDisplayLabel) == "function" and options.persistControlDisplayLabel or nil
	local resetControlDisplayLabel = type(options.resetControlDisplayLabel) == "function" and options.resetControlDisplayLabel or nil
	local setGuiTitleText = type(options.setGuiTitleText) == "function" and options.setGuiTitleText or defaultSetGuiTitleText

	local state = {
		allControlsById = {},
		controlOrder = {},
		controlsByFlag = {},
		pinnedControlIds = {},
		controlRegistrySubscribers = {},
		controlIdSalt = 0,
		pinBadgesVisible = true
	}

	local registry = {
		state = state
	}

	local function emitControlRegistryChange(reason)
		for callback in pairs(state.controlRegistrySubscribers) do
			local ok = pcall(callback, tostring(reason or "changed"))
			if not ok then
				state.controlRegistrySubscribers[callback] = nil
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
		local pinned = state.pinnedControlIds[record.Id] == true
		pinButton.Text = pinned and "*" or "o"
		pinButton.TextColor3 = pinned and Color3.fromRGB(255, 215, 120) or Color3.fromRGB(225, 225, 225)
	end

	local function getRecordByIdOrFlag(idOrFlag)
		if type(idOrFlag) ~= "string" then
			return nil
		end
		local key = tostring(idOrFlag)
		local record = state.allControlsById[key]
		if record then
			return record
		end
		if state.controlsByFlag[key] then
			return state.controlsByFlag[key]
		end
		local byFlagName = state.controlsByFlag["flag:" .. key]
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
			state.pinnedControlIds[record.Id] = true
		else
			state.pinnedControlIds[record.Id] = nil
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
		for _, id in ipairs(state.controlOrder) do
			if state.pinnedControlIds[id] then
				local record = state.allControlsById[id]
				if record and isControlRecordAlive(record) then
					table.insert(orderedPinned, id)
				elseif pruneMissing == true then
					state.pinnedControlIds[id] = nil
				end
			end
		end
		return orderedPinned
	end

	local function setPinnedIds(ids)
		for key in pairs(state.pinnedControlIds) do
			state.pinnedControlIds[key] = nil
		end
		if type(ids) == "table" then
			for _, value in ipairs(ids) do
				if type(value) == "string" and value ~= "" then
					state.pinnedControlIds[value] = true
				end
			end
		end
		for _, record in pairs(state.allControlsById) do
			applyPinnedVisual(record)
		end
		emitControlRegistryChange("set_pinned_ids")
	end

	local function setPinBadgesVisible(visible)
		local show = visible ~= false
		state.pinBadgesVisible = show
		for _, record in pairs(state.allControlsById) do
			local pinButton = record.PinButton
			if pinButton then
				pinButton.Visible = show
			end
		end
		emitControlRegistryChange("set_pin_badges_visible")
	end

	local function listControlsForFavorites(pruneMissing)
		local out = {}
		for _, id in ipairs(state.controlOrder) do
			local record = state.allControlsById[id]
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
					pinned = state.pinnedControlIds[record.Id] == true
				})
			elseif pruneMissing == true and state.pinnedControlIds[id] then
				state.pinnedControlIds[id] = nil
			end
		end
		return out
	end

	local function getControlRecordById(id)
		local record = state.allControlsById[tostring(id or "")]
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
		for _, id in ipairs(state.controlOrder) do
			local record = state.allControlsById[id]
			if record and isControlRecordAlive(record) then
				table.insert(out, record)
			elseif pruneMissing == true and state.pinnedControlIds[id] then
				state.pinnedControlIds[id] = nil
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
		if options.persist ~= false and type(persistControlDisplayLabel) == "function" then
			local okPersist, persistResult = pcall(persistControlDisplayLabel, record, textValue)
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
			if type(resetControlDisplayLabel) == "function" then
				local okReset, resetResult = pcall(resetControlDisplayLabel, record)
				if not okReset then
					return false, tostring(resetResult)
				end
			elseif type(persistControlDisplayLabel) == "function" then
				pcall(persistControlDisplayLabel, record, nil)
			end
		end
		emitControlRegistryChange("control_renamed")
		return true, tostring(record.DisplayName or record.Name or "")
	end

	local function resolveInitialDisplayLabel(record)
		if type(resolveControlDisplayLabel) == "function" then
			local okLabel, label = pcall(resolveControlDisplayLabel, {
				id = record.Id,
				flag = record.Flag,
				type = record.Type,
				internalName = record.InternalName,
				localizationKey = record.LocalizationKey
			})
			if okLabel and type(label) == "string" and label ~= "" then
				return applyControlDisplayLabel(record, label)
			end
		end
		return applyControlDisplayLabel(record, nil)
	end

	local function allocateUniqueControlId(baseFavoriteId, guiObject)
		local baseId = tostring(baseFavoriteId or "")
		if baseId == "" then
			baseId = "control"
		end
		local favoriteId = baseId
		while state.allControlsById[favoriteId] and state.allControlsById[favoriteId].GuiObject ~= guiObject do
			state.controlIdSalt = state.controlIdSalt + 1
			favoriteId = baseId .. "#" .. tostring(state.controlIdSalt)
		end
		return favoriteId
	end

	local function registerControlRecord(record)
		if type(record) ~= "table" or type(record.Id) ~= "string" or record.Id == "" then
			return false
		end
		state.allControlsById[record.Id] = record
		table.insert(state.controlOrder, record.Id)
		if record.Flag then
			state.controlsByFlag[record.Flag] = record
			state.controlsByFlag["flag:" .. record.Flag] = record
		end
		return true
	end

	local function unregisterControlRecord(recordOrId)
		local record = nil
		if type(recordOrId) == "table" then
			record = recordOrId
		else
			record = state.allControlsById[tostring(recordOrId or "")]
		end
		if type(record) ~= "table" or type(record.Id) ~= "string" then
			return false
		end
		state.allControlsById[record.Id] = nil
		state.pinnedControlIds[record.Id] = nil
		if record.Flag then
			state.controlsByFlag[record.Flag] = nil
			state.controlsByFlag["flag:" .. record.Flag] = nil
		end
		return true
	end

	local function subscribe(callback)
		if type(callback) ~= "function" then
			return function() end
		end
		state.controlRegistrySubscribers[callback] = true
		local unsubscribed = false
		return function()
			if unsubscribed then
				return
			end
			unsubscribed = true
			state.controlRegistrySubscribers[callback] = nil
		end
	end

	registry.emitControlRegistryChange = emitControlRegistryChange
	registry.isControlRecordAlive = isControlRecordAlive
	registry.applyPinnedVisual = applyPinnedVisual
	registry.getRecordByIdOrFlag = getRecordByIdOrFlag
	registry.buildLocalizationKeysForRecord = buildLocalizationKeysForRecord
	registry.resolveLocalizationKey = resolveLocalizationKey
	registry.applyControlDisplayLabel = applyControlDisplayLabel
	registry.pinControl = pinControl
	registry.unpinControl = unpinControl
	registry.getPinnedIds = getPinnedIds
	registry.setPinnedIds = setPinnedIds
	registry.setPinBadgesVisible = setPinBadgesVisible
	registry.getPinBadgesVisible = function()
		return state.pinBadgesVisible == true
	end
	registry.listControlsForFavorites = listControlsForFavorites
	registry.getControlRecordById = getControlRecordById
	registry.listControlRecords = listControlRecords
	registry.setControlDisplayLabelByIdOrFlag = setControlDisplayLabelByIdOrFlag
	registry.getControlDisplayLabelByIdOrFlag = getControlDisplayLabelByIdOrFlag
	registry.resetControlDisplayLabelByIdOrFlag = resetControlDisplayLabelByIdOrFlag
	registry.resolveInitialDisplayLabel = resolveInitialDisplayLabel
	registry.allocateUniqueControlId = allocateUniqueControlId
	registry.registerControlRecord = registerControlRecord
	registry.unregisterControlRecord = unregisterControlRecord
	registry.subscribe = subscribe

	return registry
end

return ControlRegistry
