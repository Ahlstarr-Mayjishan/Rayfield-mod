local scriptDir = (arg and arg[0] and arg[0]:match("^(.*[\\/])")) or "scripts/"
package.path = scriptDir .. "?.lua;" .. scriptDir .. "?/init.lua;" .. package.path

local Json = require("lib.json")

local DEFAULT_MAX_FUNCTION_CCN = 30
local DEFAULT_MAX_FILE_NCSS = 800

local function readFile(path)
	local file, err = io.open(path, "rb")
	if not file then
		error("Failed to read file '" .. tostring(path) .. "': " .. tostring(err))
	end
	local data = file:read("*a")
	file:close()
	return data
end

local function writeFile(path, data)
	local file, err = io.open(path, "wb")
	if not file then
		error("Failed to write file '" .. tostring(path) .. "': " .. tostring(err))
	end
	file:write(data)
	file:close()
end

local function normalizePath(path)
	local output = tostring(path or "")
	output = output:match("^%s*(.-)%s*$")
	output = output:gsub("\\", "/")
	output = output:gsub("^%./", "")
	output = output:gsub("^/+", "")
	return output
end

local function splitLines(text)
	local lines = {}
	local normalized = tostring(text or ""):gsub("\r\n", "\n")
	if normalized:sub(-1) ~= "\n" then
		normalized = normalized .. "\n"
	end
	for line in normalized:gmatch("(.-)\n") do
		lines[#lines + 1] = line
	end
	return lines
end

local function parseChangedFiles(path)
	local changed = {}
	if type(path) ~= "string" or path == "" then
		return changed
	end
	for _, rawLine in ipairs(splitLines(readFile(path))) do
		local trimmed = rawLine:match("^%s*(.-)%s*$")
		if trimmed ~= "" then
			changed[normalizePath(trimmed)] = true
		end
	end
	return changed
end

local function parseLizardXml(xmlText)
	local metricsByFile = {}

	local function ensureFile(filePath)
		local normalized = normalizePath(filePath)
		local entry = metricsByFile[normalized]
		if not entry then
			entry = {
				file = normalized,
				fileNCSS = 0,
				fileCCN = 0,
				functions = 0,
				maxFunctionCCN = 0,
				maxFunctionNCSS = 0
			}
			metricsByFile[normalized] = entry
		end
		return entry
	end

	local functionSection = xmlText:match("<measure type=\"Function\">(.-)</measure>")
	if functionSection then
		for itemName, itemBody in functionSection:gmatch("<item name=\"(.-)\">(.-)</item>") do
			local filePath = itemName:match(" at (.-):%d+$")
			if filePath then
				local entry = ensureFile(filePath)
				local values = {}
				for raw in itemBody:gmatch("<value>(.-)</value>") do
					values[#values + 1] = tonumber(raw) or 0
				end
				local ncss = values[2] or 0
				local ccn = values[3] or 0
				if ccn > entry.maxFunctionCCN then
					entry.maxFunctionCCN = ccn
				end
				if ncss > entry.maxFunctionNCSS then
					entry.maxFunctionNCSS = ncss
				end
			end
		end
	end

	local fileSection = xmlText:match("<measure type=\"File\">(.-)</measure>")
	if fileSection then
		for itemName, itemBody in fileSection:gmatch("<item name=\"(.-)\">(.-)</item>") do
			local entry = ensureFile(itemName)
			local values = {}
			for raw in itemBody:gmatch("<value>(.-)</value>") do
				values[#values + 1] = tonumber(raw) or 0
			end
			entry.fileNCSS = values[2] or 0
			entry.fileCCN = values[3] or 0
			entry.functions = values[4] or 0
		end
	end

	return metricsByFile
end

local function sortedKeys(map)
	local keys = {}
	for key in pairs(map) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function writeBaseline(xmlPath, baselinePath)
	local metricsByFile = parseLizardXml(readFile(xmlPath))
	local files = {}
	for _, filePath in ipairs(sortedKeys(metricsByFile)) do
		files[#files + 1] = metricsByFile[filePath]
	end
	local payload = {
		schemaVersion = 1,
		files = files,
		defaultLimits = {
			maxFunctionCCN = DEFAULT_MAX_FUNCTION_CCN,
			maxFileNCSS = DEFAULT_MAX_FILE_NCSS
		}
	}
	writeFile(baselinePath, Json.encode(payload) .. "\n")
	print("Wrote complexity baseline to " .. tostring(baselinePath))
end

local function loadBaseline(path)
	local payload = Json.decode(readFile(path))
	if type(payload) ~= "table" or type(payload.files) ~= "table" then
		error("Invalid complexity baseline format")
	end
	local baseline = {}
	for _, fileEntry in ipairs(payload.files) do
		if type(fileEntry) == "table" and type(fileEntry.file) == "string" then
			local normalized = normalizePath(fileEntry.file)
			baseline[normalized] = {
				file = normalized,
				fileNCSS = tonumber(fileEntry.fileNCSS) or 0,
				fileCCN = tonumber(fileEntry.fileCCN) or 0,
				functions = tonumber(fileEntry.functions) or 0,
				maxFunctionCCN = tonumber(fileEntry.maxFunctionCCN) or 0,
				maxFunctionNCSS = tonumber(fileEntry.maxFunctionNCSS) or 0
			}
		end
	end
	local limits = payload.defaultLimits or {}
	return baseline, {
		maxFunctionCCN = tonumber(limits.maxFunctionCCN) or DEFAULT_MAX_FUNCTION_CCN,
		maxFileNCSS = tonumber(limits.maxFileNCSS) or DEFAULT_MAX_FILE_NCSS
	}
end

local function runCheck(xmlPath, baselinePath, changedFilesPath, outputPath)
	local changed = parseChangedFiles(changedFilesPath)
	local hasChangedSet = next(changed) ~= nil
	local current = parseLizardXml(readFile(xmlPath))
	local baseline, limits = loadBaseline(baselinePath)

	local failures = {}
	local warnings = {}
	local evaluated = {}

	for filePath, _ in pairs(hasChangedSet and changed or current) do
		if not filePath:match("%.lua$") then
			goto continue
		end

		local currentEntry = current[filePath]
		if not currentEntry then
			goto continue
		end
		evaluated[#evaluated + 1] = filePath

		local baselineEntry = baseline[filePath]
		if baselineEntry then
			if currentEntry.maxFunctionCCN > baselineEntry.maxFunctionCCN then
				failures[#failures + 1] = string.format(
					"%s maxFunctionCCN %d -> %d",
					filePath,
					baselineEntry.maxFunctionCCN,
					currentEntry.maxFunctionCCN
				)
			end
			if currentEntry.fileCCN > baselineEntry.fileCCN then
				failures[#failures + 1] = string.format(
					"%s fileCCN %d -> %d",
					filePath,
					baselineEntry.fileCCN,
					currentEntry.fileCCN
				)
			end
			if currentEntry.fileNCSS > baselineEntry.fileNCSS then
				warnings[#warnings + 1] = string.format(
					"%s fileNCSS %d -> %d",
					filePath,
					baselineEntry.fileNCSS,
					currentEntry.fileNCSS
				)
			end
		else
			if currentEntry.maxFunctionCCN > limits.maxFunctionCCN then
				failures[#failures + 1] = string.format(
					"%s maxFunctionCCN %d exceeds default %d",
					filePath,
					currentEntry.maxFunctionCCN,
					limits.maxFunctionCCN
				)
			end
			if currentEntry.fileNCSS > limits.maxFileNCSS then
				failures[#failures + 1] = string.format(
					"%s fileNCSS %d exceeds default %d",
					filePath,
					currentEntry.fileNCSS,
					limits.maxFileNCSS
				)
			end
		end

		::continue::
	end

	table.sort(evaluated)
	table.sort(failures)
	table.sort(warnings)

	local lines = {
		"=== Complexity Ratchet Report ===",
		"xml: " .. tostring(xmlPath),
		"baseline: " .. tostring(baselinePath),
		"changedFiles: " .. tostring(changedFilesPath or "(none)"),
		"evaluatedFiles: " .. tostring(#evaluated),
		"failures: " .. tostring(#failures),
		"warnings: " .. tostring(#warnings),
		""
	}

	if #evaluated > 0 then
		lines[#lines + 1] = "Evaluated files:"
		for _, filePath in ipairs(evaluated) do
			lines[#lines + 1] = "  - " .. tostring(filePath)
		end
		lines[#lines + 1] = ""
	end

	if #failures > 0 then
		lines[#lines + 1] = "Failures:"
		for _, item in ipairs(failures) do
			lines[#lines + 1] = "  * " .. tostring(item)
		end
		lines[#lines + 1] = ""
	end

	if #warnings > 0 then
		lines[#lines + 1] = "Warnings:"
		for _, item in ipairs(warnings) do
			lines[#lines + 1] = "  * " .. tostring(item)
		end
		lines[#lines + 1] = ""
	end

	lines[#lines + 1] = "result: " .. (#failures > 0 and "FAIL" or "PASS")
	local report = table.concat(lines, "\n")
	print(report)
	if outputPath and outputPath ~= "" then
		writeFile(outputPath, report .. "\n")
	end

	if #failures > 0 then
		os.exit(1)
	end
end

if arg[1] == "--write-baseline" then
	local xmlPath = arg[2]
	local baselinePath = arg[3]
	if not xmlPath or not baselinePath then
		error("Usage: lua scripts/ci-complexity-ratchet.lua --write-baseline <lizard-report.xml> <baseline.json>")
	end
	writeBaseline(xmlPath, baselinePath)
	return
end

local xmlPath = arg[1]
local baselinePath = arg[2]
local changedFilesPath = arg[3]
local outputPath = arg[4]
if not xmlPath or not baselinePath then
	error("Usage: lua scripts/ci-complexity-ratchet.lua <lizard-report.xml> <baseline.json> [changed-files.txt] [output-report.txt]")
end

runCheck(xmlPath, baselinePath, changedFilesPath, outputPath)
