-- Root wrapper for canonical smoke test script.

local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
return compileString(game:HttpGet(root .. "tests/smoke/rayfield-smoke-test.lua"))()
