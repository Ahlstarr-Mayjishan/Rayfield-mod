local DevExperienceService = {}

local function defaultClone(value, seen)
	local valueType = type(value)
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
		out[defaultClone(key, seen)] = defaultClone(nested, seen)
	end
	return out
end

local function nowIso()
	if type(os.date) == "function" then
		return os.date("!%Y-%m-%dT%H:%M:%SZ")
	end
	return tostring(os.clock())
end

local function toColor3(value, packedToColor3)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "table" then
		if type(packedToColor3) == "function" then
			local converted = packedToColor3(value)
			if typeof(converted) == "Color3" then
				return converted
			end
		end
		local r = tonumber(value.R)
		local g = tonumber(value.G)
		local b = tonumber(value.B)
		if r and g and b then
			return Color3.fromRGB(
				math.clamp(math.floor(r + 0.5), 0, 255),
				math.clamp(math.floor(g + 0.5), 0, 255),
				math.clamp(math.floor(b + 0.5), 0, 255)
			)
		end
	end
	return nil
end

local function colorToLua(value)
	if typeof(value) ~= "Color3" then
		return nil
	end
	local r = math.floor(value.R * 255 + 0.5)
	local g = math.floor(value.G * 255 + 0.5)
	local b = math.floor(value.B * 255 + 0.5)
	return string.format("Color3.fromRGB(%d, %d, %d)", r, g, b)
end

local function clampText(value, maxLen)
	local text = tostring(value or "")
	if maxLen and maxLen > 0 and #text > maxLen then
		text = text:sub(1, maxLen)
	end
	return text
end

function DevExperienceService.create(ctx)
	ctx = ctx or {}
	local cloneValue = type(ctx.cloneValue) == "function" and ctx.cloneValue or defaultClone
	local getElementsSystem = type(ctx.getElementsSystem) == "function" and ctx.getElementsSystem or function()
		return nil
	end
	local applyThemeStudioTheme = type(ctx.applyThemeStudioTheme) == "function" and ctx.applyThemeStudioTheme or nil
	local getThemeStudioState = type(ctx.getThemeStudioState) == "function" and ctx.getThemeStudioState or nil
	local getThemeStudioColor = type(ctx.getThemeStudioColor) == "function" and ctx.getThemeStudioColor or nil
	local getThemeStudioKeys = type(ctx.getThemeStudioKeys) == "function" and ctx.getThemeStudioKeys or nil
	local packedToColor3 = type(ctx.packedToColor3) == "function" and ctx.packedToColor3 or nil
	local knownThemeKeys = {}
	if type(getThemeStudioKeys) == "function" then
		for _, key in ipairs(getThemeStudioKeys()) do
			knownThemeKeys[tostring(key)] = true
		end
	end

	local state = {
		inspectorEnabled = false,
		inspectorLastSnapshot = nil,
		hubMetadata = nil,
		liveTheme = {
			open = false,
			draft = {}
		}
	}

	local function registerHubMetadata(metadata)
		if type(metadata) ~= "table" then
			return false, "Hub metadata must be a table."
		end
		local normalized = {
			Author = clampText(metadata.Author or metadata.author, 80),
			Version = clampText(metadata.Version or metadata.version, 40),
			UpdateLog = clampText(metadata.UpdateLog or metadata.updateLog, 2000),
			Discord = clampText(metadata.Discord or metadata.discord, 180),
			Name = clampText(metadata.Name or metadata.name, 80)
		}
		if normalized.Author == "" and normalized.Name == "" then
			return false, "Hub metadata requires at least Name or Author."
		end
		normalized.RegisteredAt = nowIso()
		state.hubMetadata = normalized
		if type(_G) == "table" then
			_G.__RAYFIELD_HUB_METADATA = cloneValue(normalized)
		end
		return true, "Hub metadata registered."
	end

	local function getHubMetadata()
		return cloneValue(state.hubMetadata)
	end

	local function listControlRecords()
		local elementsSystem = getElementsSystem()
		if not elementsSystem then
			return {}
		end
		if type(elementsSystem.listControlRecords) == "function" then
			local okRecords, records = pcall(elementsSystem.listControlRecords, true)
			if okRecords and type(records) == "table" then
				return records
			end
		end

		local controls = type(elementsSystem.listControlsForFavorites) == "function" and elementsSystem.listControlsForFavorites(true) or {}
		local records = {}
		for _, control in ipairs(type(controls) == "table" and controls or {}) do
			if type(elementsSystem.getControlRecordById) == "function" then
				local record = elementsSystem.getControlRecordById(control.id)
				if type(record) == "table" then
					table.insert(records, record)
				end
			end
		end
		return records
	end

	local function readElementValue(record)
		if type(record) ~= "table" then
			return nil
		end
		local elementObject = record.ElementObject
		if type(elementObject) ~= "table" then
			return nil
		end
		if type(elementObject.Get) == "function" then
			local okGet, current = pcall(elementObject.Get, elementObject)
			if okGet then
				return current
			end
		end
		return elementObject.CurrentValue
	end

	local function inspectAtPointer(anchor)
		local pointerX = type(anchor) == "table" and tonumber(anchor.x or anchor.X) or nil
		local pointerY = type(anchor) == "table" and tonumber(anchor.y or anchor.Y) or nil
		if not pointerX or not pointerY then
			return false, "Pointer coordinates unavailable."
		end

		local bestRecord = nil
		local bestZ = -math.huge
		for _, record in ipairs(listControlRecords()) do
			local guiObject = record.GuiObject
			if guiObject and guiObject.Parent and guiObject.AbsolutePosition and guiObject.AbsoluteSize then
				local absPos = guiObject.AbsolutePosition
				local absSize = guiObject.AbsoluteSize
				local inside = pointerX >= absPos.X
					and pointerX <= (absPos.X + absSize.X)
					and pointerY >= absPos.Y
					and pointerY <= (absPos.Y + absSize.Y)
				if inside then
					local zIndex = tonumber(guiObject.ZIndex) or 0
					if zIndex >= bestZ then
						bestRecord = record
						bestZ = zIndex
					end
				end
			end
		end

		if not bestRecord then
			state.inspectorLastSnapshot = nil
			return false, "No element under pointer."
		end

		local value = readElementValue(bestRecord)
		local snapshot = {
			id = tostring(bestRecord.Id or ""),
			name = tostring(bestRecord.Name or ""),
			type = tostring(bestRecord.Type or ""),
			flag = bestRecord.Flag and tostring(bestRecord.Flag) or nil,
			tabId = tostring(bestRecord.TabPersistenceId or ""),
			value = cloneValue(value),
			valueType = type(value),
			at = nowIso()
		}
		state.inspectorLastSnapshot = snapshot
		return true, cloneValue(snapshot)
	end

	local function setInspectorEnabled(enabled)
		state.inspectorEnabled = enabled == true
		return true, state.inspectorEnabled and "Element inspector enabled." or "Element inspector disabled."
	end

	local function isInspectorEnabled()
		return state.inspectorEnabled == true
	end

	local function openLiveThemeEditor(seedDraft)
		local draft = {}
		if type(seedDraft) == "table" then
			for key, value in pairs(seedDraft) do
				local color = toColor3(value, packedToColor3)
				if color then
					draft[tostring(key)] = color
				end
			end
		elseif type(getThemeStudioKeys) == "function" and type(getThemeStudioColor) == "function" then
			for _, key in ipairs(getThemeStudioKeys()) do
				local currentColor = getThemeStudioColor(key)
				local color = toColor3(currentColor, packedToColor3)
				if color then
					draft[tostring(key)] = color
				end
			end
		elseif type(getThemeStudioState) == "function" then
			local stateTheme = getThemeStudioState()
			if type(stateTheme) == "table" and type(stateTheme.customThemePacked) == "table" then
				for key, packedColor in pairs(stateTheme.customThemePacked) do
					local color = toColor3(packedColor, packedToColor3)
					if color then
						draft[tostring(key)] = color
					end
				end
			end
		end
		state.liveTheme.open = true
		state.liveTheme.draft = draft
		return true, "Live Theme Editor opened.", cloneValue(draft)
	end

	local function closeLiveThemeEditor()
		state.liveTheme.open = false
		return true, "Live Theme Editor closed."
	end

	local function setLiveThemeValue(themeKey, color)
		local key = tostring(themeKey or "")
		if key == "" then
			return false, "Theme key is required."
		end
		if next(knownThemeKeys) ~= nil and knownThemeKeys[key] ~= true then
			return false, "Unknown Theme Studio key: " .. key
		end
		local parsed = toColor3(color, packedToColor3)
		if typeof(parsed) ~= "Color3" then
			return false, "Theme value must be Color3-compatible."
		end
		state.liveTheme.draft[key] = parsed
		return true, "Theme draft updated."
	end

	local function getLiveThemeDraft()
		return cloneValue(state.liveTheme.draft)
	end

	local function applyLiveThemeDraft()
		if type(applyThemeStudioTheme) ~= "function" then
			return false, "Theme apply handler unavailable."
		end
		local draft = getLiveThemeDraft()
		if next(draft) == nil then
			return false, "Theme draft is empty."
		end
		return applyThemeStudioTheme(draft)
	end

	local function exportLiveThemeDraftLua()
		local draft = state.liveTheme.draft
		local lines = {
			"{"
		}
		local keys = {}
		for key in pairs(draft) do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			local luaColor = colorToLua(draft[key])
			if luaColor then
				table.insert(lines, string.format("    %s = %s,", tostring(key), luaColor))
			end
		end
		table.insert(lines, "}")
		return true, table.concat(lines, "\n")
	end

	local service = {
		registerHubMetadata = registerHubMetadata,
		getHubMetadata = getHubMetadata,
		setInspectorEnabled = setInspectorEnabled,
		isInspectorEnabled = isInspectorEnabled,
		inspectAtPointer = inspectAtPointer,
		openLiveThemeEditor = openLiveThemeEditor,
		closeLiveThemeEditor = closeLiveThemeEditor,
		setLiveThemeValue = setLiveThemeValue,
		getLiveThemeDraft = getLiveThemeDraft,
		applyLiveThemeDraft = applyLiveThemeDraft,
		exportLiveThemeDraftLua = exportLiveThemeDraftLua,
		getState = function()
			return cloneValue(state)
		end
	}

	if type(_G) == "table" then
		_G.__RAYFIELD_DEV_EXPERIENCE = service
	end

	return service
end

return DevExperienceService
