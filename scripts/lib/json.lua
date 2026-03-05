local Json = {}

local function decodeError(message, position)
	error(string.format("JSON decode error at position %d: %s", position or 0, tostring(message)))
end

local function skipWhitespace(text, position)
	local index = position
	while true do
		local ch = string.sub(text, index, index)
		if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" then
			index = index + 1
		else
			return index
		end
	end
end

local function parseString(text, position)
	local index = position + 1
	local output = {}
	while true do
		local ch = string.sub(text, index, index)
		if ch == "" then
			decodeError("unterminated string", index)
		end
		if ch == "\"" then
			return table.concat(output), index + 1
		end
		if ch == "\\" then
			local esc = string.sub(text, index + 1, index + 1)
			if esc == "" then
				decodeError("unterminated escape sequence", index)
			end
			if esc == "\"" or esc == "\\" or esc == "/" then
				output[#output + 1] = esc
				index = index + 2
			elseif esc == "b" then
				output[#output + 1] = "\b"
				index = index + 2
			elseif esc == "f" then
				output[#output + 1] = "\f"
				index = index + 2
			elseif esc == "n" then
				output[#output + 1] = "\n"
				index = index + 2
			elseif esc == "r" then
				output[#output + 1] = "\r"
				index = index + 2
			elseif esc == "t" then
				output[#output + 1] = "\t"
				index = index + 2
			elseif esc == "u" then
				local hex = string.sub(text, index + 2, index + 5)
				if not string.match(hex, "^%x%x%x%x$") then
					decodeError("invalid unicode escape", index)
				end
				local codepoint = tonumber(hex, 16)
				local okUtf8, value = pcall(utf8.char, codepoint)
				output[#output + 1] = okUtf8 and value or "?"
				index = index + 6
			else
				decodeError("invalid escape character '" .. tostring(esc) .. "'", index)
			end
		else
			output[#output + 1] = ch
			index = index + 1
		end
	end
end

local function parseLiteral(text, position, literal, value)
	local fragment = string.sub(text, position, position + #literal - 1)
	if fragment ~= literal then
		decodeError("expected '" .. literal .. "'", position)
	end
	return value, position + #literal
end

local function parseNumber(text, position)
	local fragment = string.match(string.sub(text, position), "^%-?%d+%.?%d*[eE]?[%+%-]?%d*")
	if not fragment or fragment == "" or fragment == "-" then
		decodeError("invalid number", position)
	end
	local value = tonumber(fragment)
	if not value then
		decodeError("invalid number '" .. tostring(fragment) .. "'", position)
	end
	return value, position + #fragment
end

local parseValue

local function parseArray(text, position)
	local index = skipWhitespace(text, position + 1)
	local output = {}
	if string.sub(text, index, index) == "]" then
		return output, index + 1
	end

	while true do
		local value
		value, index = parseValue(text, index)
		output[#output + 1] = value
		index = skipWhitespace(text, index)
		local ch = string.sub(text, index, index)
		if ch == "]" then
			return output, index + 1
		end
		if ch ~= "," then
			decodeError("expected ',' or ']'", index)
		end
		index = skipWhitespace(text, index + 1)
	end
end

local function parseObject(text, position)
	local index = skipWhitespace(text, position + 1)
	local output = {}
	if string.sub(text, index, index) == "}" then
		return output, index + 1
	end

	while true do
		if string.sub(text, index, index) ~= "\"" then
			decodeError("expected object key string", index)
		end
		local key
		key, index = parseString(text, index)
		index = skipWhitespace(text, index)
		if string.sub(text, index, index) ~= ":" then
			decodeError("expected ':' after object key", index)
		end
		index = skipWhitespace(text, index + 1)
		local value
		value, index = parseValue(text, index)
		output[key] = value
		index = skipWhitespace(text, index)
		local ch = string.sub(text, index, index)
		if ch == "}" then
			return output, index + 1
		end
		if ch ~= "," then
			decodeError("expected ',' or '}'", index)
		end
		index = skipWhitespace(text, index + 1)
	end
end

parseValue = function(text, position)
	local index = skipWhitespace(text, position)
	local ch = string.sub(text, index, index)
	if ch == "\"" then
		return parseString(text, index)
	end
	if ch == "{" then
		return parseObject(text, index)
	end
	if ch == "[" then
		return parseArray(text, index)
	end
	if ch == "t" then
		return parseLiteral(text, index, "true", true)
	end
	if ch == "f" then
		return parseLiteral(text, index, "false", false)
	end
	if ch == "n" then
		return parseLiteral(text, index, "null", Json.null)
	end
	return parseNumber(text, index)
end

function Json.decode(text)
	if type(text) ~= "string" then
		error("Json.decode expected string")
	end
	local value, position = parseValue(text, 1)
	position = skipWhitespace(text, position)
	if position <= #text then
		decodeError("trailing characters", position)
	end
	return value
end

local function isArray(value)
	if type(value) ~= "table" then
		return false
	end
	local maxIndex = 0
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key <= 0 or key % 1 ~= 0 then
			return false
		end
		if key > maxIndex then
			maxIndex = key
		end
		count = count + 1
	end
	if count == 0 then
		return true
	end
	return maxIndex == count
end

local function encodeString(value)
	local escaped = tostring(value)
	escaped = escaped:gsub("\\", "\\\\")
	escaped = escaped:gsub("\"", "\\\"")
	escaped = escaped:gsub("\b", "\\b")
	escaped = escaped:gsub("\f", "\\f")
	escaped = escaped:gsub("\n", "\\n")
	escaped = escaped:gsub("\r", "\\r")
	escaped = escaped:gsub("\t", "\\t")
	return "\"" .. escaped .. "\""
end

local encodeValue

local function encodeArray(value)
	local output = {}
	for index = 1, #value do
		output[#output + 1] = encodeValue(value[index])
	end
	return "[" .. table.concat(output, ",") .. "]"
end

local function encodeObject(value)
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local output = {}
	for _, key in ipairs(keys) do
		output[#output + 1] = encodeString(key) .. ":" .. encodeValue(value[key])
	end
	return "{" .. table.concat(output, ",") .. "}"
end

encodeValue = function(value)
	local valueType = type(value)
	if value == Json.null then
		return "null"
	end
	if valueType == "nil" then
		return "null"
	end
	if valueType == "boolean" then
		return value and "true" or "false"
	end
	if valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			error("Cannot encode non-finite number")
		end
		return tostring(value)
	end
	if valueType == "string" then
		return encodeString(value)
	end
	if valueType == "table" then
		if isArray(value) then
			return encodeArray(value)
		end
		return encodeObject(value)
	end
	error("Unsupported JSON value type: " .. valueType)
end

function Json.encode(value)
	return encodeValue(value)
end

return Json
