--[[
	Rayfield Widget Bootstrap Regression Tests

	Usage:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-widget-bootstrap.lua"))()
]]

local BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local function compileChunk(source)
	if type(loadstring) == "function" then
		local fn, err = loadstring(source)
		if not fn then
			error("loadstring failed: " .. tostring(err))
		end
		return fn
	end

	if type(load) == "function" then
		local fn, err = load(source)
		if not fn then
			error("load failed: " .. tostring(err))
		end
		return fn
	end

	error("No Lua compiler function available (loadstring/load)")
end

local function loadRemoteModule(url)
	local source = game:HttpGet(url)
	if type(source) ~= "string" or #source == 0 then
		error("Empty source from: " .. tostring(url))
	end
	return compileChunk(source)()
end

local function assertContains(haystack, needle, message)
	if type(haystack) ~= "string" or not string.find(haystack, needle, 1, true) then
		error(message or ("Expected '" .. tostring(haystack) .. "' to contain '" .. tostring(needle) .. "'"))
	end
end

local function expectError(name, fn, expectedCode)
	local ok, err = pcall(fn)
	if ok then
		error(name .. " expected error but succeeded")
	end
	assertContains(tostring(err), expectedCode, name .. " returned unexpected error")
end

local tests = {}
local passed = 0
local failed = 0

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("PASS: " .. name)
		table.insert(tests, { name = name, status = "PASS" })
	else
		failed = failed + 1
		print("FAIL: " .. name .. " :: " .. tostring(err))
		table.insert(tests, { name = name, status = "FAIL", error = tostring(err) })
	end
end

local bootstrap = loadRemoteModule(BASE_URL .. "src/ui/elements/widgets/bootstrap.lua")
local previousClient = _G.__RayfieldApiClient
local previousRoot = _G.__RAYFIELD_RUNTIME_ROOT_URL

test("E_CLIENT_MISSING when ApiClient absent", function()
	_G.__RayfieldApiClient = nil
	expectError("missing client", function()
		bootstrap.bootstrapWidget("widget-test", "src/ui/elements/widgets/index.lua")
	end, "E_CLIENT_MISSING")
end)

test("E_CLIENT_INVALID when fetchAndExecute is not function", function()
	_G.__RayfieldApiClient = {}
	expectError("invalid client", function()
		bootstrap.bootstrapWidget("widget-test", "src/ui/elements/widgets/index.lua")
	end, "E_CLIENT_INVALID")
end)

test("E_ROOT_INVALID when root URL is invalid", function()
	_G.__RayfieldApiClient = {
		fetchAndExecute = function()
			return {}
		end
	}
	_G.__RAYFIELD_RUNTIME_ROOT_URL = "not-url"
	expectError("invalid root", function()
		bootstrap.bootstrapWidget("widget-test", "src/ui/elements/widgets/index.lua")
	end, "E_ROOT_INVALID")
end)

test("E_TARGET_INVALID when target path invalid", function()
	_G.__RayfieldApiClient = {
		fetchAndExecute = function()
			return {}
		end
	}
	_G.__RAYFIELD_RUNTIME_ROOT_URL = BASE_URL
	expectError("invalid target", function()
		bootstrap.bootstrapWidget("widget-test", "   ")
	end, "E_TARGET_INVALID")
end)

test("E_FETCH_FAILED when fetchAndExecute throws", function()
	_G.__RayfieldApiClient = {
		fetchAndExecute = function()
			error("network down")
		end
	}
	_G.__RAYFIELD_RUNTIME_ROOT_URL = BASE_URL
	expectError("fetch failed", function()
		bootstrap.bootstrapWidget("widget-test", "src/ui/elements/widgets/index.lua")
	end, "E_FETCH_FAILED")
end)

test("E_EXPORT_INVALID when export type mismatch", function()
	_G.__RayfieldApiClient = {
		fetchAndExecute = function()
			return "wrong-type"
		end
	}
	_G.__RAYFIELD_RUNTIME_ROOT_URL = BASE_URL
	expectError("export invalid", function()
		bootstrap.bootstrapWidget("widget-test", "src/ui/elements/widgets/index.lua", nil, { expectedType = "table" })
	end, "E_EXPORT_INVALID")
end)

test("Success path returns adapted export", function()
	_G.__RayfieldApiClient = {
		fetchAndExecute = function()
			return { ok = true }
		end
	}
	_G.__RAYFIELD_RUNTIME_ROOT_URL = BASE_URL

	local out = bootstrap.bootstrapWidget("widget-test", "src/ui/elements/widgets/index.lua", function(exported)
		return {
			name = "widget-test",
			index = exported
		}
	end, { expectedType = "table" })

	if type(out) ~= "table" then
		error("Expected table result")
	end
	if out.name ~= "widget-test" then
		error("Unexpected adapter output")
	end
	if type(out.index) ~= "table" or out.index.ok ~= true then
		error("Unexpected adapter payload")
	end
end)

_G.__RayfieldApiClient = previousClient
_G.__RAYFIELD_RUNTIME_ROOT_URL = previousRoot

print(string.format("Widget bootstrap regression: %d passed / %d failed", passed, failed))

return {
	results = tests,
	passed = passed,
	failed = failed
}
