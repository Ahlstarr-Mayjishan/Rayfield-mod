-- Verify that direct TweenService tween creation is centralized
-- Usage: lua scripts/verify-no-direct-tweencreate.lua

local ALLOWLIST = {
	["src/core/animation/engine.lua"] = true
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
		for lineNo, line in ipairs(readLines(path)) do
			local code = line:gsub("%-%-.*$", "")
			if code:find("TweenService:Create", 1, true) or code:find("TweenService%.Create%(", 1, false) then
				table.insert(violations, string.format("%s:%d", path, lineNo))
			end
		end
	end
end

if #violations > 0 then
	io.stderr:write("verify-no-direct-tweencreate: FAILED\n")
	for _, violation in ipairs(violations) do
		io.stderr:write(" - " .. violation .. "\n")
	end
	os.exit(1)
end

print("verify-no-direct-tweencreate: OK")
