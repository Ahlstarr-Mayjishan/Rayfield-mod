local Cleanup = {}

local function safeGet(instance, key)
	local ok, value = pcall(function()
		return instance[key]
	end)
	if ok then
		return true, value
	end
	return false, nil
end

function Cleanup.safeDisconnect(connection)
	if not connection then
		return
	end
	pcall(function()
		connection:Disconnect()
	end)
end

function Cleanup.isAlive(instance)
	return typeof(instance) == "Instance" and instance.Parent ~= nil
end

function Cleanup.isVisibleChain(instance)
	if typeof(instance) ~= "Instance" then
		return false
	end

	local current = instance
	while current do
		local isGuiObject = current:IsA("GuiObject")
		local isLayerCollector = current:IsA("LayerCollector")
		if isGuiObject or isLayerCollector then
			local hasVisible, visible = safeGet(current, "Visible")
			if hasVisible and visible == false then
				return false
			end
		end
		current = current.Parent
	end

	return true
end

function Cleanup.bindDestroy(instance, onRemoved)
	if typeof(instance) ~= "Instance" then
		return function() end
	end

	local removed = false
	local connections = {}

	local function fireOnce()
		if removed then
			return
		end
		removed = true
		if type(onRemoved) == "function" then
			pcall(onRemoved)
		end
	end

	table.insert(connections, instance.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			fireOnce()
		end
	end))

	local hasDestroying = pcall(function()
		return instance.Destroying
	end)
	if hasDestroying then
		table.insert(connections, instance.Destroying:Connect(function()
			fireOnce()
		end))
	end

	return function()
		for _, connection in ipairs(connections) do
			Cleanup.safeDisconnect(connection)
		end
		table.clear(connections)
	end
end

return Cleanup
