local LocalizationService = {}

local FILE_VERSION = 1

local function clone(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	for key, nested in pairs(value) do
		out[clone(key, seen)] = clone(nested, seen)
	end
	return out
end

local function trim(text)
	local value = tostring(text or "")
	value = value:gsub("^%s+", "")
	value = value:gsub("%s+$", "")
	return value
end

local function sanitizeToken(rawValue)
	local value = trim(rawValue)
	value = value:gsub("[%s/\\]+", "_")
	value = value:gsub("[^%w_%-%.]", "")
	if value == "" then
		return "default"
	end
	return value
end

local function hasEntries(map)
	if type(map) ~= "table" then
		return false
	end
	for key, value in pairs(map) do
		if type(key) == "string" and key ~= "" and type(value) == "string" and value ~= "" then
			return true
		end
	end
	return false
end

local function countEntries(map)
	local count = 0
	if type(map) ~= "table" then
		return 0
	end
	for key, value in pairs(map) do
		if type(key) == "string" and key ~= "" and type(value) == "string" and value ~= "" then
			count += 1
		end
	end
	return count
end

local function nowIso()
	local okDate, value = pcall(function()
		return os.date("!%Y-%m-%dT%H:%M:%SZ")
	end)
	if okDate and type(value) == "string" then
		return value
	end
	return tostring(os.clock())
end

local function dedupeInsert(list, value, seen)
	local key = tostring(value or "")
	if key == "" then
		return
	end
	if seen[key] then
		return
	end
	seen[key] = true
	table.insert(list, key)
end

function LocalizationService.create(ctx)
	ctx = ctx or {}

	local HttpService = ctx.HttpService
	local getSetting = type(ctx.getSetting) == "function" and ctx.getSetting or nil
	local setSettingValue = type(ctx.setSettingValue) == "function" and ctx.setSettingValue or nil
	local getElementsSystem = type(ctx.getElementsSystem) == "function" and ctx.getElementsSystem or function()
		return nil
	end
	local rayfieldFolder = tostring(ctx.rayfieldFolder or "Rayfield")
	local getHubSlug = type(ctx.getHubSlug) == "function" and ctx.getHubSlug or function()
		return nil
	end
	local getStringFallbacks = type(ctx.getStringFallbacks) == "function" and ctx.getStringFallbacks or function()
		return {}
	end

	local readFileFn = type(readfile) == "function" and readfile or nil
	local writeFileFn = type(writefile) == "function" and writefile or nil
	local isFileFn = type(isfile) == "function" and isfile or nil
	local isFolderFn = type(isfolder) == "function" and isfolder or nil
	local makeFolderFn = type(makefolder) == "function" and makefolder or nil

	local state = {
		scopeMode = "hybrid_migrate",
		scopeKey = "",
		scopePath = "",
		controlLabels = {},
		systemLabels = {},
		meta = {
			languageTag = "en",
			source = "user",
			updatedAt = nowIso(),
			scopeKey = ""
		}
	}

	local function getCurrentSetting(category, name, fallback)
		if type(getSetting) ~= "function" then
			return fallback
		end
		local okGet, value = pcall(getSetting, category, name)
		if okGet then
			if value ~= nil then
				return value
			end
		end
		return fallback
	end

	local function saveSettingValue(category, name, value, persist)
		if type(setSettingValue) ~= "function" then
			return
		end
		pcall(setSettingValue, category, name, value, persist ~= false)
	end

	local function computeScopeKey()
		local gameId = 0
		local placeId = 0
		if type(game) == "userdata" or type(game) == "table" then
			gameId = tonumber(game.GameId) or 0
			placeId = tonumber(game.PlaceId) or 0
		end
		local hubToken = sanitizeToken(getHubSlug() or getCurrentSetting("Workspaces", "active", "") or "default")
		return string.format("u%s_p%s_h%s", tostring(gameId), tostring(placeId), hubToken)
	end

	local function ensureFolder(path)
		if type(path) ~= "string" or path == "" then
			return true
		end
		if not makeFolderFn then
			return false
		end
		local normalized = path:gsub("\\", "/")
		local current = ""
		for part in normalized:gmatch("[^/]+") do
			current = current == "" and part or (current .. "/" .. part)
			local exists = false
			if isFolderFn then
				local okExists, result = pcall(isFolderFn, current)
				exists = okExists and result == true
			end
			if not exists then
				pcall(makeFolderFn, current)
			end
		end
		return true
	end

	local function decodeJson(text)
		if type(HttpService) ~= "table" or type(HttpService.JSONDecode) ~= "function" then
			return false, "JSONDecode unavailable"
		end
		local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, text)
		if not okDecode then
			return false, tostring(decoded)
		end
		if type(decoded) ~= "table" then
			return false, "Decoded payload is not a table."
		end
		return true, decoded
	end

	local function encodeJson(value)
		if type(HttpService) ~= "table" or type(HttpService.JSONEncode) ~= "function" then
			return false, "JSONEncode unavailable"
		end
		local okEncode, encoded = pcall(HttpService.JSONEncode, HttpService, value)
		if not okEncode then
			return false, tostring(encoded)
		end
		return true, encoded
	end

	local function readScopeFile(path)
		if type(path) ~= "string" or path == "" then
			return nil
		end
		if not (readFileFn and isFileFn) then
			return nil
		end
		local okExists, exists = pcall(isFileFn, path)
		if not okExists or exists ~= true then
			return nil
		end
		local okRead, text = pcall(readFileFn, path)
		if not okRead or type(text) ~= "string" or text == "" then
			return nil
		end
		local okDecode, payload = decodeJson(text)
		if not okDecode then
			return nil
		end
		return payload
	end

	local function writeScopeFile(path, payload)
		if not writeFileFn then
			return false, "writefile unavailable"
		end
		local okEncode, encodedOrErr = encodeJson(payload)
		if not okEncode then
			return false, encodedOrErr
		end
		local directory = tostring(path or ""):gsub("\\", "/"):match("^(.*)/[^/]*$")
		if directory and directory ~= "" then
			ensureFolder(directory)
		end
		local okWrite, writeErr = pcall(writeFileFn, path, encodedOrErr)
		if not okWrite then
			return false, tostring(writeErr)
		end
		return true, "ok"
	end

	local function toControlKeys(record)
		local keys = {}
		local seen = {}
		if type(record) == "table" then
			local flagValue = record.flag or record.Flag
			if type(flagValue) == "string" and flagValue ~= "" then
				dedupeInsert(keys, "flag:" .. flagValue, seen)
			end
			local idValue = record.id or record.Id
			if type(idValue) == "string" and idValue ~= "" then
				dedupeInsert(keys, "id:" .. idValue, seen)
			end
			local typeValue = tostring(record.type or record.Type or "Control")
			local nameValue = tostring(record.internalName or record.InternalName or record.name or record.Name or "")
			if nameValue ~= "" then
				dedupeInsert(keys, "eng:" .. typeValue .. ":" .. nameValue, seen)
			end
		end
		return keys
	end

	local function resolveRecordFromInput(idOrRecord)
		if type(idOrRecord) == "table" then
			return idOrRecord
		end
		local value = trim(idOrRecord)
		if value == "" then
			return nil
		end
		local elementsSystem = getElementsSystem()
		if elementsSystem and type(elementsSystem.getControlRecordByIdOrFlag) == "function" then
			local okRecord, record = pcall(elementsSystem.getControlRecordByIdOrFlag, value)
			if okRecord and type(record) == "table" then
				return record
			end
		end
		if elementsSystem and type(elementsSystem.getControlRecordById) == "function" then
			local okRecord, record = pcall(elementsSystem.getControlRecordById, value)
			if okRecord and type(record) == "table" then
				return record
			end
		end
		return nil
	end

	local function resolveKeys(idOrRecord)
		local rawValue = trim(idOrRecord)
		if type(idOrRecord) == "string" and rawValue ~= "" then
			if rawValue:find("^flag:", 1, false) or rawValue:find("^id:", 1, false) or rawValue:find("^eng:", 1, false) then
				return { rawValue }
			end
		end
		local record = resolveRecordFromInput(idOrRecord)
		local keys = toControlKeys(record)
		if #keys > 0 then
			return keys, record
		end
		if rawValue ~= "" then
			return { "flag:" .. rawValue, "id:" .. rawValue }
		end
		return {}
	end

	local function makeFilePayload()
		return {
			type = "rayfield_localization_scope",
			version = FILE_VERSION,
			scopeMode = state.scopeMode,
			scopeKey = state.scopeKey,
			controlLabels = clone(state.controlLabels),
			systemLabels = clone(state.systemLabels),
			meta = clone(state.meta)
		}
	end

	local function persistScope()
		state.meta.updatedAt = nowIso()
		state.meta.scopeKey = state.scopeKey
		saveSettingValue("Localization", "activeScope", state.scopeKey, false)
		saveSettingValue("Localization", "scopeMode", state.scopeMode, false)
		saveSettingValue("Localization", "lastLanguageTag", state.meta.languageTag, false)
		if state.scopePath ~= "" then
			writeScopeFile(state.scopePath, makeFilePayload())
		end
	end

	local function applyControlLabelsToUi()
		local elementsSystem = getElementsSystem()
		if not elementsSystem or type(elementsSystem.listControlRecords) ~= "function" then
			return
		end
		local okList, records = pcall(elementsSystem.listControlRecords, true)
		if not okList or type(records) ~= "table" then
			return
		end
		for _, record in ipairs(records) do
			if type(record) == "table" then
				local keys = toControlKeys(record)
				local resolved = nil
				for _, key in ipairs(keys) do
					local candidate = state.controlLabels[key]
					if type(candidate) == "string" and candidate ~= "" then
						resolved = candidate
						break
					end
				end
				if type(elementsSystem.setControlDisplayLabel) == "function" then
					pcall(elementsSystem.setControlDisplayLabel, tostring(record.Id or ""), resolved, {
						persist = false,
						source = "localization_apply"
					})
				end
			end
		end
	end

	local function loadInitialState()
		state.scopeMode = tostring(getCurrentSetting("Localization", "scopeMode", "hybrid_migrate") or "hybrid_migrate")
		if state.scopeMode == "" then
			state.scopeMode = "hybrid_migrate"
		end

		state.scopeKey = computeScopeKey()
		state.scopePath = string.format("%s/Localization/%s.rfloc", rayfieldFolder, state.scopeKey)

		local scopedPayload = readScopeFile(state.scopePath)
		if type(scopedPayload) == "table" then
			state.controlLabels = type(scopedPayload.controlLabels) == "table" and clone(scopedPayload.controlLabels) or {}
			state.systemLabels = type(scopedPayload.systemLabels) == "table" and clone(scopedPayload.systemLabels) or {}
			if type(scopedPayload.meta) == "table" then
				state.meta.languageTag = tostring(scopedPayload.meta.languageTag or state.meta.languageTag or "en")
				state.meta.source = tostring(scopedPayload.meta.source or state.meta.source or "user")
				state.meta.updatedAt = tostring(scopedPayload.meta.updatedAt or state.meta.updatedAt or nowIso())
			end
		else
			local legacyControl = getCurrentSetting("Localization", "legacyControlLabels", {})
			local legacySystem = getCurrentSetting("Localization", "legacySystemLabels", {})
			local legacyMeta = getCurrentSetting("Localization", "legacyMeta", {})
			if type(legacyControl) == "table" then
				state.controlLabels = clone(legacyControl)
			end
			if type(legacySystem) == "table" then
				state.systemLabels = clone(legacySystem)
			end
			if type(legacyMeta) == "table" and type(legacyMeta.languageTag) == "string" and legacyMeta.languageTag ~= "" then
				state.meta.languageTag = legacyMeta.languageTag
			end
			if hasEntries(state.controlLabels) or hasEntries(state.systemLabels) then
				persistScope()
			end
		end

		state.meta.scopeKey = state.scopeKey
		saveSettingValue("Localization", "activeScope", state.scopeKey, false)
		saveSettingValue("Localization", "scopeMode", state.scopeMode, false)
		saveSettingValue("Localization", "lastLanguageTag", state.meta.languageTag, false)
	end

	local function resolveControlLabel(record)
		local keys = toControlKeys(record)
		for _, key in ipairs(keys) do
			local value = state.controlLabels[key]
			if type(value) == "string" and value ~= "" then
				return value, key
			end
		end
		return nil, nil
	end

	local function setControlLabel(idOrKey, label)
		local keys, record = resolveKeys(idOrKey)
		if #keys == 0 then
			return false, "Control key is invalid."
		end
		local primaryKey = tostring(keys[1])
		local text = trim(label)
		if text == "" then
			state.controlLabels[primaryKey] = nil
		else
			state.controlLabels[primaryKey] = text
		end
		persistScope()

		local elementsSystem = getElementsSystem()
		if elementsSystem and type(elementsSystem.setControlDisplayLabel) == "function" then
			local target = nil
			if type(record) == "table" and type(record.Id) == "string" and record.Id ~= "" then
				target = record.Id
			elseif type(idOrKey) == "string" then
				target = idOrKey
			end
			if target then
				pcall(elementsSystem.setControlDisplayLabel, tostring(target), text ~= "" and text or nil, {
					persist = false,
					source = "localization_set"
				})
			end
		end
		return true, "ok", primaryKey
	end

	local function getControlLabel(idOrKey)
		local keys = resolveKeys(idOrKey)
		for _, key in ipairs(keys) do
			local value = state.controlLabels[key]
			if type(value) == "string" and value ~= "" then
				return value, key
			end
		end
		return nil, nil
	end

	local function resetControlLabel(idOrKey)
		local keys = resolveKeys(idOrKey)
		if #keys == 0 then
			return false, "Control key is invalid."
		end
		local removed = false
		for _, key in ipairs(keys) do
			if state.controlLabels[key] ~= nil then
				state.controlLabels[key] = nil
				removed = true
			end
		end
		if removed then
			persistScope()
		end
		local elementsSystem = getElementsSystem()
		if elementsSystem and type(elementsSystem.setControlDisplayLabel) == "function" then
			pcall(elementsSystem.setControlDisplayLabel, tostring(idOrKey or ""), nil, {
				persist = false,
				source = "localization_reset"
			})
		end
		return true, "ok"
	end

	local function setSystemLabel(key, text)
		local stringKey = trim(key)
		if stringKey == "" then
			return false, "System key is required."
		end
		local value = trim(text)
		if value == "" then
			state.systemLabels[stringKey] = nil
		else
			state.systemLabels[stringKey] = value
		end
		persistScope()
		return true, "ok"
	end

	local function getSystemLabel(key)
		local stringKey = tostring(key or "")
		local value = state.systemLabels[stringKey]
		if type(value) == "string" and value ~= "" then
			return value
		end
		return nil
	end

	local function localize(key, fallback)
		local stringKey = tostring(key or "")
		local value = state.systemLabels[stringKey]
		if type(value) == "string" and value ~= "" then
			return value
		end
		local defaults = getStringFallbacks()
		local fallbackFromDefaults = type(defaults) == "table" and defaults[stringKey] or nil
		if type(fallbackFromDefaults) == "string" and fallbackFromDefaults ~= "" then
			return fallbackFromDefaults
		end
		if fallback ~= nil then
			return tostring(fallback)
		end
		return stringKey
	end

	local function setLanguageTag(languageTag)
		local value = trim(languageTag)
		if value == "" then
			value = "en"
		end
		state.meta.languageTag = value
		persistScope()
		return true, value
	end

	local function resetAllToEnglish()
		state.controlLabels = {}
		state.systemLabels = {}
		state.meta.languageTag = "en"
		state.meta.source = "user"
		persistScope()
		applyControlLabelsToUi()
		return true, "Localization reset to English."
	end

	local function exportScopePack(options)
		local payload = makeFilePayload()
		payload.meta = payload.meta or {}
		payload.meta.exportedAt = nowIso()
		payload.meta.controlLabelCount = countEntries(state.controlLabels)
		payload.meta.systemLabelCount = countEntries(state.systemLabels)
		if type(options) == "table" and options.asJson == true then
			local okEncode, encoded = encodeJson(payload)
			if not okEncode then
				return false, encoded
			end
			return true, encoded
		end
		return true, payload
	end

	local function importScopePack(payloadOrJson, options)
		local payload = payloadOrJson
		if type(payloadOrJson) == "string" then
			local okDecode, decodedOrErr = decodeJson(payloadOrJson)
			if not okDecode then
				return false, "Invalid localization JSON: " .. tostring(decodedOrErr)
			end
			payload = decodedOrErr
		end
		if type(payload) ~= "table" then
			return false, "Localization payload must be a table."
		end
		local mergeMode = type(options) == "table" and options.merge == true or false

		local incomingControls = type(payload.controlLabels) == "table" and payload.controlLabels or {}
		local incomingSystem = type(payload.systemLabels) == "table" and payload.systemLabels or {}
		local incomingMeta = type(payload.meta) == "table" and payload.meta or {}

		if not mergeMode then
			state.controlLabels = {}
			state.systemLabels = {}
		end
		for key, value in pairs(incomingControls) do
			if type(key) == "string" and key ~= "" and type(value) == "string" and value ~= "" then
				state.controlLabels[key] = value
			end
		end
		for key, value in pairs(incomingSystem) do
			if type(key) == "string" and key ~= "" and type(value) == "string" and value ~= "" then
				state.systemLabels[key] = value
			end
		end
		if type(incomingMeta.languageTag) == "string" and incomingMeta.languageTag ~= "" then
			state.meta.languageTag = incomingMeta.languageTag
		end
		if type(incomingMeta.source) == "string" and incomingMeta.source ~= "" then
			state.meta.source = incomingMeta.source
		end

		persistScope()
		applyControlLabelsToUi()
		return true, "Localization imported."
	end

	local function detectForeignDisplay(payloadLike)
		local languageTag = ""
		local hasCustom = false

		local payload = payloadLike
		if type(payloadLike) == "string" then
			local okDecode, decoded = decodeJson(payloadLike)
			if okDecode then
				payload = decoded
			end
		end

		if type(payload) == "table" then
			local metaRoot = type(payload.meta) == "table" and payload.meta or {}
			local metaLocalization = type(metaRoot.localization) == "table" and metaRoot.localization or {}
			local payloadLocalization = type(payload.localization) == "table" and payload.localization or {}
			local payloadLocalizationMeta = type(payloadLocalization.meta) == "table" and payloadLocalization.meta or {}
			local payloadLocalizationControls = type(payloadLocalization.controlLabels) == "table" and payloadLocalization.controlLabels or {}
			local payloadLocalizationSystem = type(payloadLocalization.systemLabels) == "table" and payloadLocalization.systemLabels or {}
			local internal = type(payload.internalSettings) == "table" and payload.internalSettings or {}
			local internalLocalization = type(internal.Localization) == "table" and internal.Localization or {}
			local internalLegacyControls = type(internalLocalization.legacyControlLabels) == "table" and internalLocalization.legacyControlLabels or {}
			local internalLegacySystem = type(internalLocalization.legacySystemLabels) == "table" and internalLocalization.legacySystemLabels or {}

			languageTag = tostring(metaLocalization.languageTag
				or payloadLocalizationMeta.languageTag
				or internalLocalization.lastLanguageTag
				or "")
			local metaControlCount = tonumber(metaLocalization.controlLabelCount) or 0
			local metaSystemCount = tonumber(metaLocalization.systemLabelCount) or 0
			local payloadControlCount = tonumber(payloadLocalizationMeta.controlLabelCount) or 0
			local payloadSystemCount = tonumber(payloadLocalizationMeta.systemLabelCount) or 0
			hasCustom = (metaControlCount + metaSystemCount) > 0
				or (payloadControlCount + payloadSystemCount) > 0
				or hasEntries(type(payload.controlLabels) == "table" and payload.controlLabels or nil)
				or hasEntries(type(payload.systemLabels) == "table" and payload.systemLabels or nil)
				or hasEntries(payloadLocalizationControls)
				or hasEntries(payloadLocalizationSystem)
				or hasEntries(internalLegacyControls)
				or hasEntries(internalLegacySystem)
		end

		if languageTag == "" then
			languageTag = "en"
		end
		local normalized = string.lower(languageTag)
		local isForeign = hasCustom and normalized ~= "en" and normalized ~= "en-us" and normalized ~= "en_us"
		return isForeign, {
			languageTag = languageTag,
			hasCustomLabels = hasCustom
		}
	end

	local function getState()
		return {
			scopeMode = state.scopeMode,
			scopeKey = state.scopeKey,
			scopePath = state.scopePath,
			meta = clone(state.meta),
			controlLabelCount = countEntries(state.controlLabels),
			systemLabelCount = countEntries(state.systemLabels)
		}
	end

	local function getMetaForShare()
		return {
			languageTag = tostring(state.meta.languageTag or "en"),
			source = tostring(state.meta.source or "user"),
			controlLabelCount = countEntries(state.controlLabels),
			systemLabelCount = countEntries(state.systemLabels),
			scopeKey = tostring(state.scopeKey or "")
		}
	end

	loadInitialState()

	return {
		resolveControlLabel = resolveControlLabel,
		setControlLabel = setControlLabel,
		getControlLabel = getControlLabel,
		resetControlLabel = resetControlLabel,
		setSystemLabel = setSystemLabel,
		getSystemLabel = getSystemLabel,
		localize = localize,
		setLanguageTag = setLanguageTag,
		resetAllToEnglish = resetAllToEnglish,
		exportScopePack = exportScopePack,
		importScopePack = importScopePack,
		detectForeignDisplay = detectForeignDisplay,
		applyControlLabelsToUi = applyControlLabelsToUi,
		getState = getState,
		getMetaForShare = getMetaForShare
	}
end

return LocalizationService
