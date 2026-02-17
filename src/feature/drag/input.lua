local DragInput = {}

function DragInput.create(UserInputService)
	local sharedInputChanged = {}
	local sharedInputEnded = {}
	local sharedInputConnections = nil

	local function ensureSharedInputConnections()
		if sharedInputConnections then
			return
		end
		sharedInputConnections = {
			UserInputService.InputChanged:Connect(function(input)
				for _, cb in pairs(sharedInputChanged) do
					cb(input)
				end
			end),
			UserInputService.InputEnded:Connect(function(input)
				for _, cb in pairs(sharedInputEnded) do
					cb(input)
				end
			end)
		}
	end

	local function registerSharedInput(id, onChanged, onEnded)
		ensureSharedInputConnections()
		if onChanged then
			sharedInputChanged[id] = onChanged
		end
		if onEnded then
			sharedInputEnded[id] = onEnded
		end
	end

	local function unregisterSharedInput(id)
		sharedInputChanged[id] = nil
		sharedInputEnded[id] = nil
	end

	local function disconnectSharedInput()
		table.clear(sharedInputChanged)
		table.clear(sharedInputEnded)
		if sharedInputConnections then
			for _, connection in ipairs(sharedInputConnections) do
				if connection then
					connection:Disconnect()
				end
			end
			sharedInputConnections = nil
		end
	end

	local function getInputPosition(input)
		if input and input.Position then
			return Vector2.new(input.Position.X, input.Position.Y)
		end
		return UserInputService:GetMouseLocation()
	end

	return {
		ensure = ensureSharedInputConnections,
		register = registerSharedInput,
		unregister = unregisterSharedInput,
		disconnect = disconnectSharedInput,
		getInputPosition = getInputPosition
	}
end

return DragInput
