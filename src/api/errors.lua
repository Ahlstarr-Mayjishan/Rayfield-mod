local Errors = {}

function Errors.tagged(code, message)
	local safeCode = tostring(code or "E_UNKNOWN")
	local safeMessage = tostring(message or "Unknown error")
	return string.format("Rayfield Mod: [%s] %s", safeCode, safeMessage)
end

function Errors.moduleLoadError(moduleName, attempts)
	attempts = attempts or {}
	local msg = {Errors.tagged("E_MODULE_LOAD", "Failed to load module '" .. tostring(moduleName) .. "'")}
	for _, attempt in ipairs(attempts) do
		table.insert(msg, " - " .. tostring(attempt))
	end
	return table.concat(msg, "\n")
end

return Errors
