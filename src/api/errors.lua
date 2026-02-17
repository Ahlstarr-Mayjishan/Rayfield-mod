local Errors = {}

function Errors.moduleLoadError(moduleName, attempts)
	attempts = attempts or {}
	local msg = {"Rayfield module load failed: " .. tostring(moduleName)}
	for _, attempt in ipairs(attempts) do
		table.insert(msg, " - " .. tostring(attempt))
	end
	return table.concat(msg, "\n")
end

return Errors
