local Dispatcher = {}

function Dispatcher.new(UserInputService)
	local changed = {}
	local ended = {}
	local conChanged = UserInputService.InputChanged:Connect(function(input)
		for _, cb in pairs(changed) do
			cb(input)
		end
	end)
	local conEnded = UserInputService.InputEnded:Connect(function(input)
		for _, cb in pairs(ended) do
			cb(input)
		end
	end)

	return {
		register = function(_, id, onChanged, onEnded)
			if onChanged then changed[id] = onChanged end
			if onEnded then ended[id] = onEnded end
		end,
		unregister = function(_, id)
			changed[id] = nil
			ended[id] = nil
		end,
		destroy = function()
			table.clear(changed)
			table.clear(ended)
			conChanged:Disconnect()
			conEnded:Disconnect()
		end
	}
end

return Dispatcher
