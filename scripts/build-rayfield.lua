-- Rayfield build manifest generator (100% Lua)
-- Usage: lua scripts/build-rayfield.lua

local function readFile(path)
	local f, err = io.open(path, "rb")
	if not f then
		error("Failed to read " .. path .. ": " .. tostring(err))
	end
	local data = f:read("*a")
	f:close()
	return data
end

local function writeFile(path, data)
	local f, err = io.open(path, "wb")
	if not f then
		error("Failed to write " .. path .. ": " .. tostring(err))
	end
	f:write(data)
	f:close()
end

local function fnv1a32(s)
	local hash = 2166136261
	for i = 1, #s do
		hash = hash ~ string.byte(s, i)
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

local function escapeJson(str)
	return str
		:gsub("\\", "\\\\")
		:gsub('"', '\\"')
		:gsub("\b", "\\b")
		:gsub("\f", "\\f")
		:gsub("\n", "\\n")
		:gsub("\r", "\\r")
		:gsub("\t", "\\t")
end

local function listSrcFiles()
	local cmd = "rg --files src"
	local p = io.popen(cmd, "r")
	if not p then
		error("Failed to execute: " .. cmd)
	end
	local files = {}
	for line in p:lines() do
		if #line > 0 then
			table.insert(files, line:gsub("\\", "/"))
		end
	end
	p:close()
	table.sort(files)
	return files
end

local function loadModuleMap()
	local chunk, err = loadfile("src/entry/module-map.lua")
	if not chunk then
		error("Failed to compile src/entry/module-map.lua: " .. tostring(err))
	end
	return chunk()
end

local function buildModulesObject(moduleMap)
	local modules = {
		apiClient = "src/api/client.lua",
		apiLoader = "src/api/loader.lua",
		apiRegistry = "src/api/registry.lua",
		modifiedEntry = "src/entry/rayfield-modified.entry.lua",
		allInOneEntry = "src/entry/rayfield-all-in-one.entry.lua",
		enhancedEntry = "src/entry/rayfield-enhanced.entry.lua"
	}

	for key, row in pairs(moduleMap) do
		modules[key] = row[1]
	end

	modules.modifiedRuntime = "src/entry/rayfield-modified.runtime.lua"
	modules.runtimeEnv = "src/core/runtime-env.lua"
	modules.windowController = "src/core/window-controller.lua"
	modules.windowUI = "src/ui/window/init.lua"
	modules.topbarUI = "src/ui/topbar/init.lua"
	modules.tabsUI = "src/ui/tabs/init.lua"
	modules.notificationsUI = "src/ui/notifications/init.lua"
	modules.dragController = "src/feature/drag/controller.lua"
	modules.tabSplitController = "src/feature/tabsplit/controller.lua"
	modules.miniWindowController = "src/feature/mini-window/controller.lua"
	modules.enhancedCore = "src/feature/enhanced/create-enhanced-rayfield.lua"

	return modules
end

local function buildManifest()
	local files = listSrcFiles()
	local hashes = {}
	for _, path in ipairs(files) do
		hashes[path] = fnv1a32(readFile(path))
	end

	local moduleMap = loadModuleMap()
	local modules = buildModulesObject(moduleMap)

	local moduleKeys = {}
	for key in pairs(modules) do
		table.insert(moduleKeys, key)
	end
	table.sort(moduleKeys)

	local lines = {}
	table.insert(lines, "{")
	table.insert(lines, '  "version": "1.1.0",')
	table.insert(lines, '  "generatedAt": "' .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. '",')
	table.insert(lines, '  "algorithm": "fnv1a32",')
	table.insert(lines, '  "modules": {')

	for i, key in ipairs(moduleKeys) do
		local suffix = (i < #moduleKeys) and "," or ""
		table.insert(lines, string.format('    "%s": "%s"%s', escapeJson(key), escapeJson(modules[key]), suffix))
	end

	table.insert(lines, '  },')
	table.insert(lines, '  "hashes": {')

	for i, path in ipairs(files) do
		local suffix = (i < #files) and "," or ""
		table.insert(lines, '    "' .. escapeJson(path) .. '": "' .. hashes[path] .. '"' .. suffix)
	end

	table.insert(lines, "  }")
	table.insert(lines, "}")
	return table.concat(lines, "\n") .. "\n"
end

local manifest = buildManifest()
writeFile("src/manifest.json", manifest)
print("Updated manifest: src/manifest.json")