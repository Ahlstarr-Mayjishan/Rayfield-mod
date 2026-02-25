--[[
	Rayfield Security Adapter
	Handles multi-provider key authentication and session token generation.
]]

local SecurityAdapter = {}
local HttpService = game:GetService("HttpService")

local SESSION_TOKEN = nil
local IS_TAMPERED = false

local function trim(value)
	if type(value) ~= "string" then
		return ""
	end
	local out = value:gsub("^%s+", "")
	out = out:gsub("%s+$", "")
	return out
end

local function normalizeKeyList(rawKeys)
	local out = {}
	local seen = {}

	local function push(entry)
		local key = trim(tostring(entry or ""))
		if key == "" or seen[key] then
			return
		end
		seen[key] = true
		table.insert(out, key)
	end

	if type(rawKeys) == "table" then
		if #rawKeys > 0 then
			for _, entry in ipairs(rawKeys) do
				push(entry)
			end
		else
			for _, entry in pairs(rawKeys) do
				push(entry)
			end
		end
	else
		push(rawKeys)
	end

	return out
end

local function readProvidedKey(keySettings)
	if type(keySettings) ~= "table" then
		return ""
	end
	return trim(tostring(
		keySettings.ProvidedKey
		or keySettings.InputKey
		or keySettings.EnteredKey
		or keySettings.CurrentInput
		or ""
	))
end

local function getClientIdSafe()
	local okService, analyticsService = pcall(function()
		return game:GetService("RbxAnalyticsService")
	end)
	if not okService or not analyticsService then
		return "unknown_client"
	end

	local okClientId, clientId = pcall(function()
		return analyticsService:GetClientId()
	end)
	if not okClientId or type(clientId) ~= "string" or clientId == "" then
		return "unknown_client"
	end
	return clientId
end

local function isBypassTamperDetected()
	if type(_G) ~= "table" then
		return false
	end
	return _G.Rayfield_Bypass == true or _G.IsPremiumUser == true
end

function SecurityAdapter.init(ctx)
	local self = {}
	
	-- Session token is intentionally non-secret and runtime-local only.
	-- Real security should be performed by a remote validator.
	local function generateSessionToken(key, hwid)
		local raw = string.format("%s:%s", tostring(key or ""), tostring(hwid or ""))
		local nonce = HttpService:GenerateGUID(false):gsub("%-", ""):sub(1, 8)
		return "RBX-" .. nonce .. "-" .. tostring(#raw)
	end

	local function runCustomValidator(validator, providedKey, settings, hwid)
		local okValidate, isValid, tokenOrErr = pcall(validator, providedKey, settings, hwid)
		if not okValidate then
			return false, "E_VALIDATOR_ERROR:" .. tostring(isValid)
		end
		if isValid ~= true then
			return false, tostring(tokenOrErr or "E_INVALID_KEY")
		end

		if type(tokenOrErr) == "string" and tokenOrErr ~= "" then
			SESSION_TOKEN = tokenOrErr
			return true, SESSION_TOKEN
		end

		SESSION_TOKEN = generateSessionToken(providedKey, hwid)
		return true, SESSION_TOKEN
	end

	local function runAllowlistValidator(allowedKeys, providedKey, hwid)
		for _, allowedKey in ipairs(allowedKeys) do
			if providedKey == allowedKey then
				SESSION_TOKEN = generateSessionToken(providedKey, hwid)
				return true, SESSION_TOKEN
			end
		end
		return false, "E_INVALID_KEY"
	end

	function self.validateKey(settings)
		if not settings or not settings.KeySettings then 
			return false, "E_NO_SETTINGS"
		end
		
		local keySettings = settings.KeySettings
		local hwid = getClientIdSafe()
		local providedKey = readProvidedKey(keySettings)
		if providedKey == "" then
			return false, "E_NO_PROVIDED_KEY"
		end
		
		-- Honey pot check
		if isBypassTamperDetected() then
			IS_TAMPERED = true
			warn("Rayfield | Honey Pot Triggered: Unauthorized Bypass Attempt Detected.")
			return false, "E_TAMPERED_BYPASS"
		end

		local validator = keySettings.Validator
		if type(validator) == "function" then
			return runCustomValidator(validator, providedKey, settings, hwid)
		end

		-- Local allowlist fallback for offline/manual validation.
		local allowedKeys = normalizeKeyList(
			keySettings.AllowedKeys
			or keySettings.ValidKeys
			or keySettings.Keys
			or keySettings.Key
		)
		if #allowedKeys == 0 then
			return false, "E_UNCONFIGURED_VALIDATION"
		end
		return runAllowlistValidator(allowedKeys, providedKey, hwid)
	end

	function self.getSessionToken()
		return SESSION_TOKEN
	end

	function self.isTampered()
		return IS_TAMPERED
	end

	return self
end

return SecurityAdapter
