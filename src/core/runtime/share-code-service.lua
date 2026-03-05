local ShareCodeService = {}

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function trimString(value)
	value = tostring(value or "")
	value = value:gsub("^%s+", "")
	value = value:gsub("%s+$", "")
	return value
end

local function fallbackBase64Encode(input)
	local source = tostring(input or "")
	local bits = source:gsub(".", function(character)
		local byteValue = string.byte(character)
		local chunk = ""
		for index = 8, 1, -1 do
			if byteValue % (2 ^ index) - byteValue % (2 ^ (index - 1)) > 0 then
				chunk = chunk .. "1"
			else
				chunk = chunk .. "0"
			end
		end
		return chunk
	end)

	local paddedBits = bits .. "0000"
	local encoded = paddedBits:gsub("%d%d%d?%d?%d?%d?", function(chunk)
		if #chunk < 6 then
			return ""
		end
		local value = 0
		for index = 1, 6 do
			if chunk:sub(index, index) == "1" then
				value = value + 2 ^ (6 - index)
			end
		end
		return BASE64_ALPHABET:sub(value + 1, value + 1)
	end)

	return encoded .. ({ "", "==", "=" })[#source % 3 + 1]
end

local function fallbackBase64Decode(input)
	local source = tostring(input or "")
	source = source:gsub("%s+", "")
	source = source:gsub("[^" .. BASE64_ALPHABET .. "=]", "")

	local bits = source:gsub(".", function(character)
		if character == "=" then
			return ""
		end
		local index = BASE64_ALPHABET:find(character, 1, true)
		if not index then
			return ""
		end
		local value = index - 1
		local chunk = ""
		for bit = 6, 1, -1 do
			if value % (2 ^ bit) - value % (2 ^ (bit - 1)) > 0 then
				chunk = chunk .. "1"
			else
				chunk = chunk .. "0"
			end
		end
		return chunk
	end)

	return bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(chunk)
		if #chunk ~= 8 then
			return ""
		end
		local value = 0
		for index = 1, 8 do
			if chunk:sub(index, index) == "1" then
				value = value + 2 ^ (8 - index)
			end
		end
		return string.char(value)
	end)
end

local function defaultGeneratedAt()
	local okDate, value = pcall(function()
		return os.date("!%Y-%m-%dT%H:%M:%SZ")
	end)
	if okDate and type(value) == "string" then
		return value
	end
	local okTick, tickValue = pcall(function()
		return tostring(math.floor((tick and tick() or 0) * 1000))
	end)
	if okTick and type(tickValue) == "string" then
		return tickValue
	end
	return "unknown"
end

function ShareCodeService.create(options)
	options = type(options) == "table" and options or {}
	local httpService = options.HttpService
	local configSystem = options.ConfigSystem
	local settingsSystem = options.SettingsSystem
	local uiStateSystem = options.UIStateSystem
	local localizationService = options.LocalizationService
	local interfaceBuild = tostring(options.InterfaceBuild or "")
	local release = tostring(options.Release or "")
	local shareCodePrefix = tostring(options.SHARE_CODE_PREFIX or "RFSC1:")
	local sharePayloadVersion = tonumber(options.SHARE_PAYLOAD_VERSION) or 1
	local sharePayloadType = tostring(options.SHARE_PAYLOAD_TYPE or "rayfield_share")
	local generatedAtProvider = type(options.buildGeneratedAtStamp) == "function" and options.buildGeneratedAtStamp or defaultGeneratedAt

	local activeShareCode = ""
	local activeSharePayload = nil
	local pendingForeignDisplay = nil

	local service = {}

	local function encodeBase64(input)
		if httpService and type(httpService.Base64Encode) == "function" then
			local okEncoded, encoded = pcall(httpService.Base64Encode, httpService, input)
			if okEncoded and type(encoded) == "string" then
				return true, encoded
			end
		end
		local okFallback, encoded = pcall(fallbackBase64Encode, input)
		if not okFallback then
			return false, tostring(encoded)
		end
		return true, encoded
	end

	local function decodeBase64(input)
		if httpService and type(httpService.Base64Decode) == "function" then
			local okDecoded, decoded = pcall(httpService.Base64Decode, httpService, input)
			if okDecoded and type(decoded) == "string" then
				return true, decoded
			end
		end
		local okFallback, decoded = pcall(fallbackBase64Decode, input)
		if not okFallback then
			return false, tostring(decoded)
		end
		return true, decoded
	end

	local function validateSharePayload(payload)
		if type(payload) ~= "table" then
			return false, "Share code payload is invalid."
		end
		if payload.type ~= sharePayloadType then
			return false, "Share code payload type is invalid."
		end
		if tonumber(payload.version) ~= sharePayloadVersion then
			return false, "Share code version is unsupported."
		end
		if type(payload.configuration) ~= "table" then
			return false, "Share code is missing configuration data."
		end
		if type(payload.internalSettings) ~= "table" then
			return false, "Share code is missing internal settings data."
		end
		return true
	end

	local function notifyShareCodeStatus(success, message)
		if not uiStateSystem or type(uiStateSystem.Notify) ~= "function" then
			return
		end
		local content = tostring(message or "")
		if content == "" then
			if success then
				content = "Share code operation completed."
			else
				content = "Share code operation failed."
			end
		end
		pcall(uiStateSystem.Notify, {
			Title = "Rayfield Share Code",
			Content = content,
			Image = success and 4483362458 or 4384402990
		})
	end

	local function setActiveSharePayload(code, payload)
		activeShareCode = tostring(code or "")
		activeSharePayload = payload
		pendingForeignDisplay = nil
		if settingsSystem and type(settingsSystem.setShareCodeInputValue) == "function" then
			pcall(settingsSystem.setShareCodeInputValue, activeShareCode)
		end
	end

	local function encodeSharePayload(payload)
		local okJson, jsonOrErr = pcall(function()
			return httpService:JSONEncode(payload)
		end)
		if not okJson or type(jsonOrErr) ~= "string" then
			return nil, "Failed to encode share payload."
		end

		local okBase64, encodedOrErr = encodeBase64(jsonOrErr)
		if not okBase64 then
			return nil, "Failed to encode share payload as Base64."
		end

		return shareCodePrefix .. encodedOrErr
	end

	local function decodeShareCode(code)
		local normalized = trimString(code)
		if normalized == "" then
			return false, "Share code cannot be empty."
		end
		if normalized:sub(1, #shareCodePrefix) ~= shareCodePrefix then
			return false, "Share code prefix is invalid."
		end

		local encodedBody = normalized:sub(#shareCodePrefix + 1):gsub("%s+", "")
		if encodedBody == "" then
			return false, "Share code payload is empty."
		end

		local okDecode, decodedOrErr = decodeBase64(encodedBody)
		if not okDecode or type(decodedOrErr) ~= "string" then
			return false, "Share code Base64 payload is invalid."
		end

		local okJson, payloadOrErr = pcall(function()
			return httpService:JSONDecode(decodedOrErr)
		end)
		if not okJson or type(payloadOrErr) ~= "table" then
			return false, "Share code JSON payload is invalid."
		end

		return true, shareCodePrefix .. encodedBody, payloadOrErr
	end

	function service.getActiveShareCode()
		return activeShareCode
	end

	function service.getActiveSharePayload()
		return activeSharePayload
	end

	function service.notifyStatus(success, message)
		notifyShareCodeStatus(success == true, message)
	end

	function service.importCode(code)
		local okDecode, canonicalOrMessage, payload = decodeShareCode(code)
		if not okDecode then
			return false, tostring(canonicalOrMessage)
		end

		local validPayload, payloadMessage = validateSharePayload(payload)
		if not validPayload then
			return false, tostring(payloadMessage)
		end

		setActiveSharePayload(canonicalOrMessage, payload)
		if localizationService and type(localizationService.detectForeignDisplay) == "function" then
			local okDetect, isForeign, detectMeta = pcall(localizationService.detectForeignDisplay, payload)
			if okDetect and isForeign == true then
				pendingForeignDisplay = type(detectMeta) == "table" and detectMeta or {
					languageTag = "unknown",
					hasCustomLabels = true
				}
			else
				pendingForeignDisplay = nil
			end
		end
		return true, "Share code imported."
	end

	function service.importSettings(importOptions)
		if type(activeSharePayload) ~= "table" then
			return false, "No active share code. Import code first."
		end

		local validPayload, payloadMessage = validateSharePayload(activeSharePayload)
		if not validPayload then
			return false, tostring(payloadMessage)
		end
		importOptions = type(importOptions) == "table" and importOptions or {}

		local foreignMeta = pendingForeignDisplay
		if localizationService and type(localizationService.detectForeignDisplay) == "function" then
			local okDetect, isForeign, detectMeta = pcall(localizationService.detectForeignDisplay, activeSharePayload)
			if okDetect and isForeign == true then
				foreignMeta = type(detectMeta) == "table" and detectMeta or foreignMeta
			else
				foreignMeta = nil
			end
		end
		if foreignMeta and importOptions.confirmForeignDisplay ~= true then
			pendingForeignDisplay = foreignMeta
			local languageTag = tostring(foreignMeta.languageTag or "unknown")
			return false, "Foreign display language detected. Confirm required.", {
				confirmRequired = true,
				languageTag = languageTag,
				hasCustomLabels = foreignMeta.hasCustomLabels == true
			}
		end

		if not configSystem or type(configSystem.ImportConfigurationData) ~= "function" then
			return false, "Configuration import is unavailable."
		end
		if not settingsSystem or type(settingsSystem.ImportInternalSettingsData) ~= "function" then
			return false, "Internal settings import is unavailable."
		end

		local okConfig, configSuccess, configDetail = pcall(configSystem.ImportConfigurationData, activeSharePayload.configuration)
		if not okConfig then
			return false, "Failed to apply configuration data: " .. tostring(configSuccess)
		end
		if configSuccess ~= true then
			return false, tostring(configDetail or "Failed to apply configuration data.")
		end

		local okInternal, internalSuccess, internalDetail = pcall(settingsSystem.ImportInternalSettingsData, activeSharePayload.internalSettings)
		if not okInternal then
			return false, "Failed to apply internal settings: " .. tostring(internalSuccess)
		end
		if internalSuccess ~= true then
			return false, tostring(internalDetail or "Failed to apply internal settings.")
		end

		if localizationService and type(localizationService.importScopePack) == "function" then
			local incomingLocalization = activeSharePayload.localization
			if type(incomingLocalization) == "table" then
				local okLocImport, locSuccess, locMessage = pcall(localizationService.importScopePack, incomingLocalization, {
					merge = false
				})
				if not okLocImport then
					return false, "Failed to apply localization payload: " .. tostring(locSuccess)
				end
				if locSuccess ~= true then
					return false, tostring(locMessage or "Failed to apply localization payload.")
				end
			end
		end
		pendingForeignDisplay = nil

		local persistenceWarnings = {}
		if configSystem and type(configSystem.SaveConfigurationForced) == "function" then
			local okPersistConfig, persistedConfig = pcall(configSystem.SaveConfigurationForced)
			if not okPersistConfig or persistedConfig == false then
				table.insert(persistenceWarnings, "configuration")
			end
		end
		if settingsSystem and type(settingsSystem.saveSettings) == "function" then
			local okPersistSettings, persistedSettings = pcall(settingsSystem.saveSettings)
			if not okPersistSettings or persistedSettings == false then
				table.insert(persistenceWarnings, "internal settings")
			end
		end

		if #persistenceWarnings > 0 then
			return true, "Share settings applied, but persistence failed for: " .. table.concat(persistenceWarnings, ", ") .. "."
		end

		local changedConfiguration = configDetail == true
		local appliedInternalCount = tonumber(internalDetail) or 0
		if changedConfiguration or appliedInternalCount > 0 then
			return true, "Share settings applied."
		end
		return true, "Share settings were already up to date."
	end

	function service.exportSettings()
		if not configSystem or type(configSystem.ExportConfigurationData) ~= "function" then
			return nil, "Configuration export is unavailable."
		end
		if not settingsSystem or type(settingsSystem.ExportInternalSettingsData) ~= "function" then
			return nil, "Internal settings export is unavailable."
		end

		local okConfig, configurationData = pcall(configSystem.ExportConfigurationData)
		if not okConfig or type(configurationData) ~= "table" then
			return nil, "Failed to collect configuration data."
		end
		local okSettings, internalSettingsData = pcall(settingsSystem.ExportInternalSettingsData)
		if not okSettings or type(internalSettingsData) ~= "table" then
			return nil, "Failed to collect internal settings data."
		end

		local payload = {
			type = sharePayloadType,
			version = sharePayloadVersion,
			configuration = configurationData,
			internalSettings = internalSettingsData,
			meta = {
				generatedAt = tostring(generatedAtProvider() or "unknown"),
				interfaceBuild = interfaceBuild,
				release = release
			}
		}
		if localizationService and type(localizationService.exportScopePack) == "function" then
			local okLocExport, localizationPayload = pcall(localizationService.exportScopePack, {
				asJson = false
			})
			if okLocExport and type(localizationPayload) == "table" then
				payload.localization = localizationPayload
			end
			if type(localizationService.getMetaForShare) == "function" then
				local okMeta, meta = pcall(localizationService.getMetaForShare)
				if okMeta and type(meta) == "table" then
					payload.meta.localization = meta
				end
			end
		end

		local encodedCode, encodedErr = encodeSharePayload(payload)
		if type(encodedCode) ~= "string" then
			return nil, tostring(encodedErr or "Failed to export share code.")
		end

		setActiveSharePayload(encodedCode, payload)
		return encodedCode, "ok"
	end

	function service.copyShareCode(suppressNotify)
		local shouldNotify = suppressNotify ~= true
		if type(activeShareCode) ~= "string" or activeShareCode == "" then
			local message = "No active share code. Export or import a code first."
			if shouldNotify then
				notifyShareCodeStatus(false, message)
			end
			return false, message
		end

		local clipboardWriter = nil
		if type(setclipboard) == "function" then
			clipboardWriter = setclipboard
		elseif type(toclipboard) == "function" then
			clipboardWriter = toclipboard
		end

		if type(clipboardWriter) ~= "function" then
			if settingsSystem and type(settingsSystem.setShareCodeInputValue) == "function" then
				pcall(settingsSystem.setShareCodeInputValue, activeShareCode)
			end
			local message = "Clipboard is unavailable. Share code was placed in the Share Code input."
			if shouldNotify then
				notifyShareCodeStatus(false, message)
			end
			return false, message
		end

		local okCopy, copyErr = pcall(clipboardWriter, activeShareCode)
		if not okCopy then
			if settingsSystem and type(settingsSystem.setShareCodeInputValue) == "function" then
				pcall(settingsSystem.setShareCodeInputValue, activeShareCode)
			end
			local message = "Failed to copy share code: " .. tostring(copyErr)
			if shouldNotify then
				notifyShareCodeStatus(false, message)
			end
			return false, message
		end

		local message = "Share code copied to clipboard."
		if shouldNotify then
			notifyShareCodeStatus(true, message)
		end
		return true, message
	end

	return service
end

return ShareCodeService
