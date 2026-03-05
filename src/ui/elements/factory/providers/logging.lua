local LoggingProvider = {}

function LoggingProvider.create(options)
	options = type(options) == "table" and options or {}
	local logService = options.logService

	local provider = {
		connection = nil,
		subscribers = {}
	}

	local function ensureConnected()
		if not logService or provider.connection then
			return
		end
		provider.connection = logService.MessageOut:Connect(function(message, messageType)
			local level = "info"
			if messageType == Enum.MessageType.MessageWarning then
				level = "warn"
			elseif messageType == Enum.MessageType.MessageError then
				level = "error"
			end
			for callback in pairs(provider.subscribers) do
				local ok = pcall(callback, level, tostring(message or ""))
				if not ok then
					provider.subscribers[callback] = nil
				end
			end
		end)
	end

	function provider.subscribe(callback)
		if type(callback) ~= "function" then
			return function() end
		end
		provider.subscribers[callback] = true
		ensureConnected()
		local disposed = false
		return function()
			if disposed then
				return
			end
			disposed = true
			provider.subscribers[callback] = nil
			if not next(provider.subscribers) and provider.connection then
				provider.connection:Disconnect()
				provider.connection = nil
			end
		end
	end

	function provider.destroy()
		for callback in pairs(provider.subscribers) do
			provider.subscribers[callback] = nil
		end
		if provider.connection then
			provider.connection:Disconnect()
			provider.connection = nil
		end
	end

	return provider
end

return LoggingProvider
