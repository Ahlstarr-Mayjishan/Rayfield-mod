local scriptDir = (arg and arg[0] and arg[0]:match("^(.*[\\/])")) or "scripts/"
package.path = scriptDir .. "?.lua;" .. scriptDir .. "?/init.lua;" .. package.path

local Json = require("lib.json")

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
	output = output:gsub("^/+","")
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

local function makeIssueKey(filePath, code)
	return normalizePath(filePath) .. "|" .. tostring(code or "")
end

local function parseLuacheckReport(reportText)
	local counts = {}
	local total = 0
	for _, rawLine in ipairs(splitLines(reportText)) do
		local line = rawLine:match("^%s*(.-)%s*$")
		local path, code = line:match("^(.-):%d+:[%d%-]+:%s*%(([%u]%d+)%)%s+.+$")
		if path and code then
			local key = makeIssueKey(path, code)
			counts[key] = (counts[key] or 0) + 1
			total = total + 1
		end
	end
	return counts, total
end

local function sortedKeys(map)
	local keys = {}
	for key in pairs(map) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function parseChangedFiles(path)
	local changed = {}
	if type(path) ~= "string" or path == "" then
		return changed
	end
	local content = readFile(path)
	for _, rawLine in ipairs(splitLines(content)) do
		local trimmed = rawLine:match("^%s*(.-)%s*$")
		if trimmed ~= "" then
			changed[normalizePath(trimmed)] = true
		end
	end
	return changed
end

local function parseBaseline(path)
	local payload = Json.decode(readFile(path))
	if type(payload) ~= "table" or type(payload.issues) ~= "table" then
		error("Invalid luacheck baseline format")
	end
	local baseline = {}
	for _, issue in ipairs(payload.issues) do
		if type(issue) == "table" then
			local filePath = normalizePath(issue.file)
			local code = tostring(issue.code or "")
			local count = tonumber(issue.count) or 0
			baseline[makeIssueKey(filePath, code)] = math.max(0, math.floor(count))
		end
	end
	return baseline
end

local function buildBaselinePayload(counts)
	local issues = {}
	local total = 0
	for _, key in ipairs(sortedKeys(counts)) do
		local filePath, code = key:match("^(.-)|([^|]+)$")
		local count = counts[key] or 0
		total = total + count
		issues[#issues + 1] = {
			file = filePath,
			code = code,
			count = count
		}
	end
	return {
		schemaVersion = 1,
		scope = { "src", "feature", "Main loader", "tests", "scripts" },
		issues = issues,
		totals = {
			issueCount = total,
			distinctKeys = #issues
		}
	}
end

local function writeBaseline(reportPath, baselinePath)
	local counts = parseLuacheckReport(readFile(reportPath))
	local payload = buildBaselinePayload(counts)
	writeFile(baselinePath, Json.encode(payload) .. "\n")
	print("Wrote luacheck baseline to " .. tostring(baselinePath))
end

local function isTargetedCode(code)
	return code == "E033" or code == "W113" or code == "W143"
end

local function runCheck(reportPath, baselinePath, changedFilesPath, outputPath)
	local reportText = readFile(reportPath)
	local currentCounts, currentTotal = parseLuacheckReport(reportText)
	local baselineCounts = parseBaseline(baselinePath)
	local changed = parseChangedFiles(changedFilesPath)
	local hasChangedSet = next(changed) ~= nil

	local increases = {}
	local decreases = {}
	local touchedErrors = {}
	local touchedTargeted = {}

	local baselineTotal = 0
	for _, value in pairs(baselineCounts) do
		baselineTotal = baselineTotal + (tonumber(value) or 0)
	end

	local allKeys = {}
	for key in pairs(baselineCounts) do
		allKeys[key] = true
	end
	for key in pairs(currentCounts) do
		allKeys[key] = true
	end

	for _, key in ipairs(sortedKeys(allKeys)) do
		local baselineCount = baselineCounts[key] or 0
		local currentCount = currentCounts[key] or 0
		local delta = currentCount - baselineCount
		if delta ~= 0 then
			local filePath, code = key:match("^(.-)|([^|]+)$")
			if delta > 0 then
				increases[#increases + 1] = {
					file = filePath,
					code = code,
					delta = delta,
					current = currentCount,
					baseline = baselineCount
				}
				if hasChangedSet and changed[filePath] then
					if code:sub(1, 1) == "E" then
						touchedErrors[#touchedErrors + 1] = filePath .. " (" .. code .. ") +" .. tostring(delta)
					end
					if isTargetedCode(code) then
						touchedTargeted[#touchedTargeted + 1] = filePath .. " (" .. code .. ") +" .. tostring(delta)
					end
				end
			else
				decreases[#decreases + 1] = {
					file = filePath,
					code = code,
					delta = delta
				}
			end
		end
	end

	local lines = {
		"=== Luacheck Ratchet Report ===",
		"report: " .. tostring(reportPath),
		"baseline: " .. tostring(baselinePath),
		"changedFiles: " .. tostring(changedFilesPath or "(none)"),
		string.format("totalCurrent=%d totalBaseline=%d delta=%+d", currentTotal, baselineTotal, currentTotal - baselineTotal),
		""
	}

	lines[#lines + 1] = "Increases: " .. tostring(#increases)
	for _, entry in ipairs(increases) do
		lines[#lines + 1] = string.format(
			"+ %s (%s): baseline=%d current=%d delta=+%d",
			tostring(entry.file),
			tostring(entry.code),
			tonumber(entry.baseline) or 0,
			tonumber(entry.current) or 0,
			tonumber(entry.delta) or 0
		)
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "Decreases: " .. tostring(#decreases)
	for _, entry in ipairs(decreases) do
		lines[#lines + 1] = string.format(
			"- %s (%s): delta=%d",
			tostring(entry.file),
			tostring(entry.code),
			tonumber(entry.delta) or 0
		)
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "Touched files new E*: " .. tostring(#touchedErrors)
	for _, value in ipairs(touchedErrors) do
		lines[#lines + 1] = "  * " .. tostring(value)
	end

	lines[#lines + 1] = "Touched files new E033/W113/W143: " .. tostring(#touchedTargeted)
	for _, value in ipairs(touchedTargeted) do
		lines[#lines + 1] = "  * " .. tostring(value)
	end

	local fail = (#increases > 0) or (#touchedErrors > 0) or (#touchedTargeted > 0)
	lines[#lines + 1] = ""
	lines[#lines + 1] = "result: " .. (fail and "FAIL" or "PASS")

	if type(outputPath) == "string" and outputPath ~= "" then
		writeFile(outputPath, table.concat(lines, "\n") .. "\n")
	end

	print(table.concat(lines, "\n"))
	if fail then
		os.exit(1)
	end
end

local mode = arg[1]
if mode == "--write-baseline" then
	local reportPath = arg[2]
	local baselinePath = arg[3]
	if not reportPath or not baselinePath then
		error("Usage: lua scripts/ci-luacheck-ratchet.lua --write-baseline <luacheck-report.txt> <baseline.json>")
	end
	writeBaseline(reportPath, baselinePath)
	return
end

local reportPath = arg[1]
local baselinePath = arg[2]
local changedFilesPath = arg[3]
local outputPath = arg[4]

if not reportPath or not baselinePath then
	error("Usage: lua scripts/ci-luacheck-ratchet.lua <luacheck-report.txt> <baseline.json> [changed-files.txt] [output-report.txt]")
end

runCheck(reportPath, baselinePath, changedFilesPath, outputPath)
