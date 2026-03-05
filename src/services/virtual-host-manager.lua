-- Rayfield Virtual Host Manager
-- Tracks host registration/lifecycle for viewport virtualization.

local VirtualHostManager = {}

local function identityWarn(message)
	warn("Rayfield | VirtualHostManager " .. tostring(message))
end

function VirtualHostManager.create(options)
	options = type(options) == "table" and options or {}

	local config = type(options.config) == "table" and options.config or {}
	local safeDisconnect = type(options.safeDisconnect) == "function" and options.safeDisconnect or function() end
	local taskLib = type(options.taskLib) == "table" and options.taskLib or task
	local warnFn = type(options.warn) == "function" and options.warn or identityWarn
	local onAutoUnregister = type(options.onAutoUnregister) == "function" and options.onAutoUnregister or nil

	local hosts = {}
	local hostOrder = {}
	local manager = {}

	local function hasHost(hostId)
		return hosts[hostId] ~= nil
	end

	local function removeHostOrder(hostId)
		for index = #hostOrder, 1, -1 do
			if hostOrder[index] == hostId then
				table.remove(hostOrder, index)
			end
		end
	end

	local function markHostDirty(hostId, reason)
		local host = hosts[hostId]
		if not host then
			return false
		end
		host.dirty = true
		host.lastReason = reason or host.lastReason or "update"
		return true
	end

	function manager.getHost(hostId)
		return hosts[hostId]
	end

	function manager.getHosts()
		return hosts
	end

	function manager.getHostOrder()
		return hostOrder
	end

	function manager.hasHosts()
		return next(hosts) ~= nil
	end

	function manager.countHosts()
		local count = 0
		for _ in pairs(hosts) do
			count = count + 1
		end
		return count
	end

	function manager.markHostDirty(hostId, reason)
		return markHostDirty(hostId, reason)
	end

	function manager.refreshHost(hostId, reason)
		return markHostDirty(hostId, reason or "refresh")
	end

	function manager.setHostSuppressed(hostId, suppressed)
		local host = hosts[hostId]
		if not host then
			return false
		end
		host.paused = suppressed == true
		return true
	end

	function manager.unregisterHost(hostId)
		local host = hosts[hostId]
		if not host then
			return false
		end

		for _, connection in ipairs(host.connections) do
			safeDisconnect(connection)
		end
		table.clear(host.connections)

		hosts[hostId] = nil
		removeHostOrder(hostId)
		return true
	end

	function manager.registerHost(hostId, hostObject, registerOptions)
		if type(hostId) ~= "string" or hostId == "" then
			return false, "invalid_host_id"
		end
		if typeof(hostObject) ~= "Instance" or not hostObject:IsA("GuiObject") then
			return false, "invalid_host_object"
		end

		if hasHost(hostId) then
			manager.unregisterHost(hostId)
		end

		local opts = type(registerOptions) == "table" and registerOptions or {}
		local mode = tostring(opts.mode or "auto")
		if mode == "auto" then
			if hostObject:IsA("ScrollingFrame") then
				mode = "scrolling"
			else
				mode = "clipped"
			end
		end

		local overscan = tonumber(opts.overscan) or tonumber(config.OverscanPx) or 120
		if overscan < 0 then
			overscan = 0
		end

		local host = {
			id = hostId,
			object = hostObject,
			mode = mode,
			overscan = overscan,
			elements = {},
			connections = {},
			dirty = true,
			paused = false,
			resizeInProgress = false,
			resizeToken = 0,
			lastReason = "register"
		}

		local function onResize()
			host.resizeInProgress = true
			host.resizeToken = host.resizeToken + 1
			local resizeToken = host.resizeToken
			markHostDirty(hostId, "resize")
			if config.DisableFadeDuringResize then
				local delaySec = math.max(0, tonumber(config.ResizeDebounceMs) or 0) / 1000
				taskLib.delay(delaySec, function()
					local current = hosts[hostId]
					if current and current.resizeToken == resizeToken then
						current.resizeInProgress = false
						markHostDirty(hostId, "resize_settle")
					end
				end)
			else
				host.resizeInProgress = false
			end
		end

		table.insert(host.connections, hostObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(onResize))
		table.insert(host.connections, hostObject:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			markHostDirty(hostId, "position")
		end))

		if host.mode == "scrolling" and hostObject:IsA("ScrollingFrame") then
			table.insert(host.connections, hostObject:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				markHostDirty(hostId, "scroll")
			end))
			table.insert(host.connections, hostObject:GetPropertyChangedSignal("CanvasSize"):Connect(function()
				markHostDirty(hostId, "canvas")
			end))
		end

		table.insert(host.connections, hostObject.ChildAdded:Connect(function(child)
			if child:IsA("UIListLayout") then
				table.insert(host.connections, child:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					markHostDirty(hostId, "content_size")
				end))
				markHostDirty(hostId, "layout_added")
			end
		end))
		table.insert(host.connections, hostObject.ChildRemoved:Connect(function()
			markHostDirty(hostId, "child_removed")
		end))

		local hasDestroying = false
		local okDestroying = pcall(function()
			hasDestroying = hostObject.Destroying ~= nil
		end)
		if okDestroying and hasDestroying then
			table.insert(host.connections, hostObject.Destroying:Connect(function()
				if onAutoUnregister then
					onAutoUnregister(hostId)
				else
					manager.unregisterHost(hostId)
				end
			end))
		end
		table.insert(host.connections, hostObject.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				if onAutoUnregister then
					onAutoUnregister(hostId)
				else
					manager.unregisterHost(hostId)
				end
			else
				markHostDirty(hostId, "reparent")
			end
		end))

		hosts[hostId] = host
		table.insert(hostOrder, hostId)
		return true, host
	end

	function manager.destroy()
		local hostIds = {}
		for hostId in pairs(hosts) do
			table.insert(hostIds, hostId)
		end
		for _, hostId in ipairs(hostIds) do
			manager.unregisterHost(hostId)
		end
	end

	if type(warnFn) == "function" and type(taskLib.delay) ~= "function" then
		warnFn("task.delay unavailable; resize debounce may be limited.")
	end

	return manager
end

return VirtualHostManager
