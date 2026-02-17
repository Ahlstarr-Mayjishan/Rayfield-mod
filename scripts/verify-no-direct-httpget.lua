-- Verify that direct HttpGet usage is restricted
-- Usage: lua scripts/verify-no-direct-httpget.lua

local ALLOWLIST = {
	["src/api/client.lua"] = true,
	["src/api/loader.lua"] = true,
	["src/legacy/forward.lua"] = true,
	["src/entry/rayfield-modified.entry.lua"] = true,
	["src/entry/rayfield-modified.runtime.lua"] = true,
	["src/entry/rayfield-all-in-one.entry.lua"] = true,
	["src/entry/rayfield-enhanced.entry.lua"] = true,
	["src/feature/drag/controller.lua"] = true,
	["src/feature/tabsplit/controller.lua"] = true
}

local function listSrcFiles()
	local p = io.popen("rg --files src", "r")
	if not p then
		error("Failed to list src files")
	end
	local files = {}
	for line in p:lines() do
		if #line > 0 then
			line = line:gsub("\\", "/")
			table.insert(files, line)
		end
	end
	p:close()
	return files
end

local function readLines(path)
	local lines = {}
	local f, err = io.open(path, "r")
	if not f then
		error("Failed to read " .. path .. ": " .. tostring(err))
	end
	for line in f:lines() do
		table.insert(lines, line)
	end
	f:close()
	return lines
end

local violations = {}
for _, path in ipairs(listSrcFiles()) do
	if not ALLOWLIST[path] then
		local lines = readLines(path)
		for i, line in ipairs(lines) do
			local code = line:gsub("%-%-.*$", "")
			if code:find("game:HttpGet", 1, true) or code:find("game%.HttpGet", 1, false) then
				table.insert(violations, string.format("%s:%d", path, i))
			end
		end
	end
end

if #violations > 0 then
	io.stderr:write("verify-no-direct-httpget: FAILED\n")
	for _, v in ipairs(violations) do
		io.stderr:write(" - " .. v .. "\n")
	end
	os.exit(1)
end

print("verify-no-direct-httpget: OK")
