--[[
	Rayfield share code regression
	Validates RFSC1 export/import/copy workflow for config + internal settings.

	Usage:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-share-code-workflow.lua"))()
]]

local BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local function assertTrue(condition, message)
	if not condition then
		error(message or "assertTrue failed")
	end
end

local function assertEquals(actual, expected, message)
	if actual ~= expected then
		error(message or ("Expected " .. tostring(expected) .. ", got " .. tostring(actual)))
	end
end

local function compileChunk(source)
	local compileString = loadstring or load
	if not compileString then
		error("No Lua compiler function available (loadstring/load)")
	end
	local fn, err = compileString(source)
	if not fn then
		error("compile failed: " .. tostring(err))
	end
	return fn
end

local function loadRemote(url)
	local source = game:HttpGet(url)
	if type(source) ~= "string" or #source == 0 then
		error("Empty source: " .. tostring(url))
	end
	source = source:gsub("^\239\187\191", "")
	source = source:gsub("^\0+", "")
	return compileChunk(source)()
end

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

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
				value += 2 ^ (6 - index)
			end
		end
		return BASE64_ALPHABET:sub(value + 1, value + 1)
	end)

	return encoded .. ({ "", "==", "=" })[#source % 3 + 1]
end

local function encodeSharePayload(payload)
	local httpService = game:GetService("HttpService")
	local json = httpService:JSONEncode(payload)
	if type(httpService.Base64Encode) == "function" then
		return "RFSC1:" .. httpService:Base64Encode(json)
	end
	return "RFSC1:" .. fallbackBase64Encode(json)
end

if type(_G.__RayfieldApiModuleCache) == "table" then
	table.clear(_G.__RayfieldApiModuleCache)
end
if type(_G.RayfieldCache) == "table" then
	table.clear(_G.RayfieldCache)
end
_G.Rayfield = nil
_G.RayfieldUI = nil
_G.RayfieldAllInOneLoaded = nil

local Rayfield = loadRemote(BASE_URL .. "Main%20loader/rayfield-modified.lua")
assertTrue(type(Rayfield) == "table", "Rayfield load failed")

assertTrue(type(Rayfield.ImportCode) == "function", "ImportCode missing")
assertTrue(type(Rayfield.ImportSettings) == "function", "ImportSettings missing")
assertTrue(type(Rayfield.ExportSettings) == "function", "ExportSettings missing")
assertTrue(type(Rayfield.CopyShareCode) == "function", "CopyShareCode missing")

local Window = Rayfield:CreateWindow({
	Name = "Share Code Regression",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false }
})
assertTrue(type(Window) == "table", "CreateWindow failed")

local Tab = Window:CreateTab("Share", 4483362458)
assertTrue(type(Tab) == "table", "CreateTab failed")

local toggle = Tab:CreateToggle({
	Name = "Share Toggle",
	CurrentValue = true,
	Flag = "share_toggle_flag",
	Callback = function() end
})
local input = Tab:CreateInput({
	Name = "Share Input",
	CurrentValue = "alpha",
	PlaceholderText = "Share text",
	Flag = "share_input_flag",
	RemoveTextAfterFocusLost = false,
	Callback = function() end
})
assertTrue(type(toggle) == "table", "Toggle create failed")
assertTrue(type(input) == "table", "Input create failed")

-- Keep flags registered even when ConfigurationSaving.Enabled is false.
Rayfield.Flags = Rayfield.Flags or {}
Rayfield.Flags.share_toggle_flag = toggle
Rayfield.Flags.share_input_flag = input

local exportedCode, exportStatus = Rayfield:ExportSettings()
assertTrue(type(exportedCode) == "string" and exportedCode:sub(1, 6) == "RFSC1:", "ExportSettings should return RFSC1 code")
assertEquals(exportStatus, "ok", "ExportSettings status mismatch")

local copyOk, copyMessage = Rayfield:CopyShareCode()
assertTrue(type(copyOk) == "boolean", "CopyShareCode should return boolean status")
assertTrue(type(copyMessage) == "string", "CopyShareCode should return message")

toggle:Set(false)
input:Set("mutated")
assertEquals(toggle:Get(), false, "Toggle mutation failed")
assertEquals(input.CurrentValue, "mutated", "Input mutation failed")

local importCodeOk, importCodeMessage = Rayfield:ImportCode(exportedCode)
assertTrue(importCodeOk == true, "ImportCode should accept exported payload: " .. tostring(importCodeMessage))

local importSettingsOk, importSettingsMessage = Rayfield:ImportSettings()
assertTrue(importSettingsOk == true, "ImportSettings should apply active payload: " .. tostring(importSettingsMessage))

assertEquals(toggle:Get(), true, "Toggle should restore from share payload")
assertEquals(input.CurrentValue, "alpha", "Input should restore from share payload")

local partialPayloadCode = encodeSharePayload({
	type = "rayfield_share",
	version = 1,
	configuration = {},
	meta = { generatedAt = "test" }
})
local partialOk = Rayfield:ImportCode(partialPayloadCode)
assertTrue(partialOk == false, "ImportCode should reject payload missing internalSettings")

local wrongVersionPayloadCode = encodeSharePayload({
	type = "rayfield_share",
	version = 999,
	configuration = {},
	internalSettings = {},
	meta = { generatedAt = "test" }
})
local wrongVersionOk = Rayfield:ImportCode(wrongVersionPayloadCode)
assertTrue(wrongVersionOk == false, "ImportCode should reject unsupported payload version")

print("Share code regression: PASS")

return {
	status = "PASS",
	exportedLength = #exportedCode,
	importSettingsMessage = importSettingsMessage
}
