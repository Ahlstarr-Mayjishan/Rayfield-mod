-- Verify registry/module-map/manifest consistency
-- Usage: lua scripts/verify-module-map.lua

local function readFile(path)
	local f, err = io.open(path, "rb")
	if not f then
		error("Failed to read " .. path .. ": " .. tostring(err))
	end
	local data = f:read("*a")
	f:close()
	return data
end

local function loadLuaTable(path)
	local chunk, err = loadfile(path)
	if not chunk then
		error("Failed to compile " .. path .. ": " .. tostring(err))
	end
	return chunk()
end

local function parseManifestPaths(content)
	local paths = {}
	for _, path in content:gmatch('"[%w_%-]+"%s*:%s*"([^"]+)"') do
		if path:match("^src/") then
			paths[path] = true
		end
	end
	return paths
end

local registry = loadLuaTable("src/api/registry.lua")
local moduleMap = loadLuaTable("src/entry/module-map.lua")
local manifestPaths = parseManifestPaths(readFile("src/manifest.json"))

local failures = {}

for name, mapping in pairs(registry) do
	local mapRow = moduleMap[name]
	if not mapRow then
		table.insert(failures, "Missing module-map entry: " .. name)
	else
		if mapRow[1] ~= mapping.canonical then
			table.insert(failures, string.format("Canonical mismatch for %s: registry=%s module-map=%s", name, tostring(mapping.canonical), tostring(mapRow[1])))
		end
	end

	if mapping.canonical and not manifestPaths[mapping.canonical] then
		table.insert(failures, "Manifest missing canonical path: " .. mapping.canonical .. " (" .. name .. ")")
	end
end

for name, mapRow in pairs(moduleMap) do
	if not registry[name] then
		table.insert(failures, "module-map has extra key not in registry: " .. name)
	end
	if mapRow[1] and not manifestPaths[mapRow[1]] then
		table.insert(failures, "Manifest missing module-map canonical path: " .. mapRow[1] .. " (" .. name .. ")")
	end
end

if #failures > 0 then
	io.stderr:write("verify-module-map: FAILED\n")
	for _, msg in ipairs(failures) do
		io.stderr:write(" - " .. msg .. "\n")
	end
	os.exit(1)
end

print("verify-module-map: OK")
