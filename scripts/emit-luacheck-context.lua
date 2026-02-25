-- Build context artifacts from luacheck text output.
-- Usage: lua scripts/emit-luacheck-context.lua <luacheck-report.txt> <output-dir>

local inputPath = arg[1]
local outputDir = arg[2] or "luacheck-context"

if type(inputPath) ~= "string" or inputPath == "" then
	error("Missing luacheck report path. Usage: lua scripts/emit-luacheck-context.lua <report> <output-dir>")
end

local function readFile(path)
	local file, err = io.open(path, "rb")
	if not file then
		error("Failed to read " .. tostring(path) .. ": " .. tostring(err))
	end
	local data = file:read("*a")
	file:close()
	return data
end

local function writeFile(path, data)
	local file, err = io.open(path, "wb")
	if not file then
		error("Failed to write " .. tostring(path) .. ": " .. tostring(err))
	end
	file:write(data)
	file:close()
end

local function splitLines(data)
	local lines = {}
	data = tostring(data or ""):gsub("\r\n", "\n")
	if data:sub(-1) ~= "\n" then
		data = data .. "\n"
	end
	for line in data:gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	return lines
end

local function ensureDir(path)
	local separator = package and package.config and package.config:sub(1, 1) or "/"
	local command
	if separator == "\\" then
		command = "mkdir \"" .. path .. "\" >nul 2>nul"
	else
		command = "mkdir -p \"" .. path .. "\""
	end
	local ok = os.execute(command)
	if ok == false then
		error("Failed to create directory: " .. tostring(path))
	end
end

local function fileExists(path)
	local file = io.open(path, "rb")
	if not file then
		return false
	end
	file:close()
	return true
end

local function sanitizePath(path)
	return (tostring(path)
		:gsub("\\", "/")
		:gsub("[^%w%._%-%/]", "_")
		:gsub("/", "__"))
end

local function formatWithLineNumbers(content)
	local lines = splitLines(content)
	local out = {}
	for index, line in ipairs(lines) do
		out[#out + 1] = string.format("%5d | %s", index, line)
	end
	return table.concat(out, "\n") .. "\n"
end

local function parseIssues(reportText)
	local issuesByFile = {}
	local order = {}

	for _, rawLine in ipairs(splitLines(reportText)) do
		local line = rawLine:match("^%s*(.-)%s*$")
		local path, row, colRange, code, message = line:match("^(.-):(%d+):([%d%-]+):%s*%(([%u]%d+)%)%s*(.+)$")
		if path and row and code and message then
			local normalized = path:gsub("\\", "/")
			if not issuesByFile[normalized] then
				issuesByFile[normalized] = {}
				order[#order + 1] = normalized
			end
			issuesByFile[normalized][#issuesByFile[normalized] + 1] = {
				line = tonumber(row),
				col = tostring(colRange),
				code = tostring(code),
				message = tostring(message)
			}
		end
	end

	table.sort(order)
	return issuesByFile, order
end

local report = readFile(inputPath)
local issuesByFile, fileOrder = parseIssues(report)

ensureDir(outputDir)
ensureDir(outputDir .. "/files")

local indexLines = {
	"# Luacheck Context Report",
	"",
	"Source report: `" .. inputPath .. "`",
	""
}

if #fileOrder == 0 then
	indexLines[#indexLines + 1] = "No luacheck issues were parsed from this report."
	indexLines[#indexLines + 1] = ""
else
	indexLines[#indexLines + 1] = "## Files With Issues"
	indexLines[#indexLines + 1] = ""
end

for _, path in ipairs(fileOrder) do
	local issues = issuesByFile[path]
	local issueCount = #issues
	local safeName = sanitizePath(path) .. ".txt"
	local outPath = outputDir .. "/files/" .. safeName

	local body = {}
	body[#body + 1] = "File: " .. path
	body[#body + 1] = "Issue count: " .. tostring(issueCount)
	body[#body + 1] = ""
	body[#body + 1] = "Issues:"
	for _, issue in ipairs(issues) do
		body[#body + 1] = string.format("- L%d C%s (%s) %s", issue.line, issue.col, issue.code, issue.message)
	end
	body[#body + 1] = ""
	body[#body + 1] = "Full file context:"
	body[#body + 1] = ""

	if fileExists(path) then
		local content = readFile(path)
		body[#body + 1] = formatWithLineNumbers(content)
	else
		body[#body + 1] = "(file not found in workspace)"
		body[#body + 1] = ""
	end

	writeFile(outPath, table.concat(body, "\n"))

	indexLines[#indexLines + 1] = string.format("- `%s` (%d issues) -> `files/%s`", path, issueCount, safeName)
end

indexLines[#indexLines + 1] = ""
writeFile(outputDir .. "/index.md", table.concat(indexLines, "\n"))

print("Luacheck context written to " .. outputDir)
