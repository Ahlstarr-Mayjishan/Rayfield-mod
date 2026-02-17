local Logger = {}

function Logger.new(config)
	config = config or {}
	local enabled = config.enabled == true
	local prefix = config.prefix or "[Rayfield]"
	return {
		info = function(_, ...)
			if enabled then
				print(prefix, ...)
			end
		end,
		warn = function(_, ...)
			if enabled then
				warn(prefix, ...)
			end
		end
	}
end

return Logger
