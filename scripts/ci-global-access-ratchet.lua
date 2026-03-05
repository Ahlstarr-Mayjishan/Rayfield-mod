local scriptDir = (arg and arg[0] and arg[0]:match("^(.*[\\/])")) or "scripts/"
package.path = scriptDir .. "?.lua;" .. scriptDir .. "?/init.lua;" .. package.path

local Json = require("lib.json")

local APPROVED_PREFIXES = {
	"src/entry/",
	"Main loader/",
	"feature/"
}

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

local function isBoundaryFile(path)
	local normalized = normalizePath(path)
	for _, prefix in ipairs(APPROVED_PREFIXES) do
		if normalized:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function countGlobalAccessTokens(text)
	local normalized = tostring(text or "")
	local count = 0
	for _ in normalized:gmatch("%f[%w_]_G%f[^%w_]") do
		count = count + 1
	end
	return count
end

local function parseBaseline(path)
	local payload = Json.decode(readFile(path))
	if type(payload) ~= "table" or type(payload.files) ~= "table" then
		error("Invalid global access baseline format")
	end
	local baseline = {}
	for _, entry in ipairs(payload.files) do
		if type(entry) == "table" and type(entry.file) == "string" then
			baseline[normalizePath(entry.file)] = tonumber(entry.globalAccessCount) or 0
		end
	end
	return baseline
end

local function sortedKeys(map)
	local keys = {}
	for key in pairs(map) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function writeBaseline(filesPath, baselinePath)
	local entries = {}
	local totals = {
		totalGlobalAccessCount = 0,
		filesWithAccess = 0
	}
	local fileList = parseChangedFiles(filesPath)
	for _, filePath in ipairs(sortedKeys(fileList)) do
		if filePath:match("%.lua$") then
			local okRead, source = pcall(readFile, filePath)
			if okRead then
				local count = countGlobalAccessTokens(source)
				totals.totalGlobalAccessCount = totals.totalGlobalAccessCount + count
				if count > 0 then
					totals.filesWithAccess = totals.filesWithAccess + 1
				end
				entries[#entries + 1] = {
					file = filePath,
					globalAccessCount = count
				}
			end
		end
	end
	local payload = {
		schemaVersion = 1,
		approvedBoundaryPrefixes = APPROVED_PREFIXES,
		files = entries,
		totals = totals
	}
	writeFile(baselinePath, Json.encode(payload) .. "\n")
	print("Wrote global access baseline to " .. tostring(baselinePath))
end

local function runCheck(baselinePath, changedFilesPath, outputPath)
	local changed = parseChangedFiles(changedFilesPath)
	local hasChangedSet = next(changed) ~= nil
	local baseline = parseBaseline(baselinePath)

	local increases = {}
	local boundaryViolations = {}
	local scanned = {}

	local targets = hasChangedSet and changed or {}
	for filePath in pairs(targets) do
		local normalized = normalizePath(filePath)
		if not normalized:match("%.lua$") then
			goto continue
		end
		local okRead, source = pcall(readFile, normalized)
		if not okRead then
			goto continue
		end
		scanned[#scanned + 1] = normalized
		local current = countGlobalAccessTokens(source)
		local previous = baseline[normalized] or 0
		local delta = current - previous
		if delta > 0 then
			increases[#increases + 1] = string.format("%s baseline=%d current=%d delta=+%d", normalized, previous, current, delta)
			if not isBoundaryFile(normalized) then
				boundaryViolations[#boundaryViolations + 1] = string.format("%s introduced %d new direct _G accesses", normalized, delta)
			end
		end
		::continue::
	end

	table.sort(scanned)
	table.sort(increases)
	table.sort(boundaryViolations)

	local lines = {
		"=== Global Access Ratchet Report ===",
		"baseline: " .. tostring(baselinePath),
		"changedFiles: " .. tostring(changedFilesPath or "(none)"),
		"scannedFiles: " .. tostring(#scanned),
		"increases: " .. tostring(#increases),
		"boundaryViolations: " .. tostring(#boundaryViolations),
		""
	}

	if #scanned > 0 then
		lines[#lines + 1] = "Scanned files:"
		for _, filePath in ipairs(scanned) do
			lines[#lines + 1] = "  - " .. tostring(filePath)
		end
		lines[#lines + 1] = ""
	end

	if #increases > 0 then
		lines[#lines + 1] = "Increases:"
		for _, item in ipairs(increases) do
			lines[#lines + 1] = "  * " .. tostring(item)
		end
		lines[#lines + 1] = ""
	end

	if #boundaryViolations > 0 then
		lines[#lines + 1] = "Boundary violations:"
		for _, item in ipairs(boundaryViolations) do
			lines[#lines + 1] = "  * " .. tostring(item)
		end
		lines[#lines + 1] = ""
	end

	lines[#lines + 1] = "result: " .. (#boundaryViolations > 0 and "FAIL" or "PASS")
	local report = table.concat(lines, "\n")
	print(report)
	if outputPath and outputPath ~= "" then
		writeFile(outputPath, report .. "\n")
	end

	if #boundaryViolations > 0 then
		os.exit(1)
	end
end

if arg[1] == "--write-baseline" then
	local filesPath = arg[2]
	local baselinePath = arg[3]
	if not filesPath or not baselinePath then
		error("Usage: lua scripts/ci-global-access-ratchet.lua --write-baseline <all-lua-files.txt> <baseline.json>")
	end
	writeBaseline(filesPath, baselinePath)
	return
end

local baselinePath = arg[1]
local changedFilesPath = arg[2]
local outputPath = arg[3]
if not baselinePath or not changedFilesPath then
	error("Usage: lua scripts/ci-global-access-ratchet.lua <baseline.json> <changed-files.txt> [output-report.txt]")
end

runCheck(baselinePath, changedFilesPath, outputPath)
