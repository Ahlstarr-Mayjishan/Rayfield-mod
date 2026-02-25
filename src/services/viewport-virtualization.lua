-- Rayfield Viewport Virtualization Service
-- Event-driven offscreen hibernation with spacer preservation.

local ViewportVirtualization = {}

local DEFAULTS = {
	Enabled = true,
	AlwaysOn = true,
	FullSuspend = true,
	OverscanPx = 120,
	UpdateHz = 30,
	FadeOnScroll = true,
	DisableFadeDuringResize = true,
	ResizeDebounceMs = 100,
	MinElementsToActivate = 0
}

local function getSharedUtils()
	if type(_G) == "table" and type(_G.__RayfieldSharedUtils) == "table" then
		return _G.__RayfieldSharedUtils
	end
	return nil
end

local function cloneTable(value)
	local shared = getSharedUtils()
	if shared and type(shared.cloneTable) == "function" then
		return shared.cloneTable(value)
	end
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, nested in pairs(value) do
		out[key] = cloneTable(nested)
	end
	return out
end

local function mergeDefaults(input)
	local out = cloneTable(DEFAULTS)
	if type(input) ~= "table" then
		return out
	end
	for key, value in pairs(input) do
		out[key] = value
	end

	out.Enabled = out.Enabled ~= false
	out.AlwaysOn = out.AlwaysOn ~= false
	out.FullSuspend = out.FullSuspend ~= false
	out.FadeOnScroll = out.FadeOnScroll ~= false
	out.DisableFadeDuringResize = out.DisableFadeDuringResize ~= false

	local overscan = tonumber(out.OverscanPx)
	if not overscan then
		overscan = DEFAULTS.OverscanPx
	end
	if overscan < 0 then
		overscan = 0
	end
	out.OverscanPx = math.floor(overscan)

	local updateHz = tonumber(out.UpdateHz)
	if not updateHz or updateHz <= 0 then
		updateHz = DEFAULTS.UpdateHz
	end
	out.UpdateHz = math.max(5, math.floor(updateHz))

	local resizeDebounce = tonumber(out.ResizeDebounceMs)
	if not resizeDebounce or resizeDebounce < 0 then
		resizeDebounce = DEFAULTS.ResizeDebounceMs
	end
	out.ResizeDebounceMs = math.max(0, math.floor(resizeDebounce))

	local minElements = tonumber(out.MinElementsToActivate)
	if not minElements or minElements < 0 then
		minElements = 0
	end
	out.MinElementsToActivate = math.floor(minElements)

	return out
end

local function safeDisconnect(connection)
	if not connection then
		return
	end
	pcall(function()
		connection:Disconnect()
	end)
end

local function isAlive(instance)
	return typeof(instance) == "Instance" and instance.Parent ~= nil
end

local function resolveToken(recordsByObject, recordsByToken, tokenOrObject)
	if type(tokenOrObject) == "string" then
		return tokenOrObject, recordsByToken[tokenOrObject]
	end
	if typeof(tokenOrObject) == "Instance" then
		local token = recordsByObject[tokenOrObject]
		if token then
			return token, recordsByToken[token]
		end
	end
	return nil, nil
end

function ViewportVirtualization.init(ctx)
	local self = {}
	ctx = ctx or {}

	self.Config = mergeDefaults(ctx.Settings)
	self.RunService = ctx.RunService or game:GetService("RunService")
	self.TweenService = ctx.TweenService or game:GetService("TweenService")
	self.UserInputService = ctx.UserInputService or game:GetService("UserInputService")
	self.AnimationEngine = ctx.AnimationEngine
	self.RootGui = ctx.RootGui
	self.warn = type(ctx.warn) == "function" and ctx.warn or function(message)
		warn("Rayfield | ViewportVirtualization " .. tostring(message))
	end

	local hosts = {}
	local hostOrder = {}
	local records = {}
	local recordsByObject = setmetatable({}, { __mode = "k" })
	local tokenCounter = 0
	local updateConnection = nil
	local updateAccumulator = 0
	local updateInterval = 1 / self.Config.UpdateHz
	local storageRoot = nil

	local function ensureStorageRoot()
		if storageRoot and storageRoot.Parent then
			return storageRoot
		end
		local parentGui = self.RootGui
		if not parentGui or not parentGui.Parent then
			return nil
		end
		local frame = Instance.new("Frame")
		frame.Name = "ViewportVirtualizationStorage"
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromOffset(0, 0)
		frame.Position = UDim2.fromOffset(-10000, -10000)
		frame.Visible = false
		frame.Parent = parentGui
		storageRoot = frame
		return storageRoot
	end

	local function clearStorageRoot()
		if storageRoot then
			pcall(function()
				storageRoot:Destroy()
			end)
		end
		storageRoot = nil
	end

	local function countHostElements(host)
		local count = 0
		for token in pairs(host.elements) do
			if records[token] then
				count += 1
			end
		end
		return count
	end

	local function shouldUseFade(host)
		if not self.Config.FadeOnScroll then
			return false
		end
		if self.Config.DisableFadeDuringResize and host.resizeInProgress then
			return false
		end
		return host.lastReason == "scroll"
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

	local function suspendObjectAnimations(guiObject)
		if self.Config.FullSuspend ~= true then
			return
		end
		local engine = self.AnimationEngine
		if type(engine) ~= "table" then
			return
		end
		local function stopTarget(target)
			if type(engine.CancelObject) == "function" then
				pcall(engine.CancelObject, engine, target)
			end
			if type(engine.StopTextForObject) == "function" then
				pcall(engine.StopTextForObject, engine, target)
			end
		end
		stopTarget(guiObject)
		for _, descendant in ipairs(guiObject:GetDescendants()) do
			if descendant:IsA("GuiObject") then
				stopTarget(descendant)
			end
		end
	end

	local function applyFade(guiObject, fadeOut)
		local targetAlpha = fadeOut and 1 or 0
		if not isAlive(guiObject) then
			return
		end
		if type(self.AnimationEngine) == "table" and type(self.AnimationEngine.AnimateProperty) == "function" then
			pcall(self.AnimationEngine.AnimateProperty, self.AnimationEngine, guiObject, "BackgroundTransparency", targetAlpha, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
				pcall(self.AnimationEngine.AnimateProperty, self.AnimationEngine, guiObject, "TextTransparency", targetAlpha, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
			if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
				pcall(self.AnimationEngine.AnimateProperty, self.AnimationEngine, guiObject, "ImageTransparency", targetAlpha, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
		end
	end

	local function updateCachedHeight(record, targetObject)
		local height = nil
		if targetObject and targetObject.Parent then
			height = tonumber(targetObject.AbsoluteSize.Y)
		end
		if not height or height <= 0 then
			height = record.cachedHeight
		end
		if not height or height <= 0 then
			height = 32
		end
		record.cachedHeight = math.max(1, math.floor(height + 0.5))
	end

	local function ensureSpacer(record)
		local guiObject = record.guiObject
		if not guiObject or not guiObject.Parent then
			return nil
		end

		updateCachedHeight(record, guiObject)
		local spacer = Instance.new("Frame")
		spacer.Name = "ViewportSpacer-" .. tostring(guiObject.Name)
		spacer.BackgroundTransparency = 1
		spacer.BorderSizePixel = 0
		spacer.Size = UDim2.new(guiObject.Size.X.Scale, guiObject.Size.X.Offset, 0, record.cachedHeight)
		spacer.LayoutOrder = guiObject.LayoutOrder
		spacer.ZIndex = guiObject.ZIndex
		spacer.Parent = guiObject.Parent
		return spacer
	end

	local function wakeRecord(token, reason, options)
		local record = records[token]
		if not record or not record.sleeping then
			return false
		end

		local guiObject = record.guiObject
		if not guiObject then
			return false
		end

		local targetParent = (record.spacer and record.spacer.Parent) or record.originalParent
		if targetParent and targetParent.Parent then
			guiObject.Parent = targetParent
			if record.originalLayoutOrder ~= nil then
				guiObject.LayoutOrder = record.originalLayoutOrder
			end
			guiObject.Visible = true
			updateCachedHeight(record, guiObject)
		end

		if record.spacer then
			pcall(function()
				record.spacer:Destroy()
			end)
			record.spacer = nil
		end

		if guiObject.SetAttribute then
			pcall(guiObject.SetAttribute, guiObject, "RayfieldViewportSleeping", false)
		end

		record.sleeping = false
		record.originalParent = nil
		record.originalLayoutOrder = nil

		local fadeAllowed = options and options.fade == true
		if fadeAllowed then
			applyFade(guiObject, false)
		end

		if type(record.onWake) == "function" then
			pcall(record.onWake, {
				reason = reason or "wake",
				token = token
			})
		end
		return true
	end

	local function sleepRecord(token, reason, options)
		local record = records[token]
		if not record or record.sleeping then
			return false
		end
		local guiObject = record.guiObject
		if not isAlive(guiObject) then
			return false
		end
		if record.busy then
			return false
		end
		local busyAttribute = false
		if guiObject.GetAttribute then
			local okAttr, value = pcall(guiObject.GetAttribute, guiObject, "RayfieldInteractionBusy")
			busyAttribute = okAttr and value == true
		end
		if busyAttribute then
			return false
		end

		local storage = ensureStorageRoot()
		if not storage then
			return false
		end

		local spacer = ensureSpacer(record)
		if not spacer then
			return false
		end

		record.originalParent = guiObject.Parent
		record.originalLayoutOrder = guiObject.LayoutOrder
		record.spacer = spacer

		local fadeAllowed = options and options.fade == true
		if fadeAllowed then
			applyFade(guiObject, true)
		end

		suspendObjectAnimations(guiObject)
		guiObject.Visible = false
		guiObject.Parent = storage
		record.sleeping = true
		if guiObject.SetAttribute then
			pcall(guiObject.SetAttribute, guiObject, "RayfieldViewportSleeping", true)
		end
		if type(record.onSleep) == "function" then
			pcall(record.onSleep, {
				reason = reason or "sleep",
				token = token
			})
		end
		return true
	end

	local function computeViewport(host)
		local hostObject = host.object
		if not (hostObject and hostObject.Parent) then
			return nil
		end

		local overscan = host.overscan
		if host.mode == "scrolling" then
			local scrollY = hostObject.CanvasPosition.Y
			local viewHeight = hostObject.AbsoluteSize.Y
			return scrollY - overscan, scrollY + viewHeight + overscan, scrollY
		end

		local viewHeight = hostObject.AbsoluteSize.Y
		return 0 - overscan, viewHeight + overscan, 0
	end

	local function computeBounds(host, record)
		local hostObject = host.object
		if not (hostObject and hostObject.Parent) then
			return nil, nil
		end

		local target = record.sleeping and record.spacer or record.guiObject
		if not (target and target.Parent) then
			return nil, nil
		end

		updateCachedHeight(record, target)

		local top
		if host.mode == "scrolling" then
			top = (target.AbsolutePosition.Y - hostObject.AbsolutePosition.Y) + hostObject.CanvasPosition.Y
		else
			top = target.AbsolutePosition.Y - hostObject.AbsolutePosition.Y
		end
		local bottom = top + math.max(1, record.cachedHeight or 1)
		return top, bottom
	end

	local function evaluateHost(hostId)
		local host = hosts[hostId]
		if not host then
			return
		end
		if not isAlive(host.object) then
			self.unregisterHost(hostId)
			return
		end

		local elementCount = countHostElements(host)
		if host.paused then
			for token in pairs(host.elements) do
				sleepRecord(token, "host_paused", { fade = false })
			end
			host.dirty = false
			host.lastReason = nil
			return
		end
		if elementCount <= self.Config.MinElementsToActivate then
			for token in pairs(host.elements) do
				wakeRecord(token, "below_threshold", { fade = false })
			end
			host.dirty = false
			host.lastReason = nil
			return
		end

		local viewportTop, viewportBottom = computeViewport(host)
		if viewportTop == nil then
			host.dirty = false
			host.lastReason = nil
			return
		end

		local fadeAllowed = shouldUseFade(host)
		for token in pairs(host.elements) do
			local record = records[token]
			if not record then
				host.elements[token] = nil
			else
				if record.hostId ~= hostId then
					host.elements[token] = nil
				else
					local busy = record.busy
					if not busy and record.guiObject and record.guiObject.GetAttribute then
						local okAttr, value = pcall(record.guiObject.GetAttribute, record.guiObject, "RayfieldInteractionBusy")
						busy = okAttr and value == true
					end
					if busy then
						wakeRecord(token, "busy", { fade = false })
					else
						local top, bottom = computeBounds(host, record)
						if top ~= nil and bottom ~= nil then
							local visible = bottom >= viewportTop and top <= viewportBottom
							if visible then
								wakeRecord(token, "visible", {
									fade = fadeAllowed
								})
							else
								sleepRecord(token, "offscreen", {
									fade = fadeAllowed
								})
							end
						end
					end
				end
			end
		end

		host.dirty = false
		host.lastReason = nil
	end

	local function ensureUpdateLoop()
		if updateConnection or self.Config.Enabled ~= true then
			return
		end
		updateConnection = self.RunService.RenderStepped:Connect(function(deltaTime)
			updateAccumulator += deltaTime
			if updateAccumulator < updateInterval then
				return
			end
			updateAccumulator = 0
			for _, hostId in ipairs(hostOrder) do
				local host = hosts[hostId]
				if host and host.dirty then
					evaluateHost(hostId)
				end
			end
		end)
	end

	local function disconnectUpdateLoopIfIdle()
		if next(hosts) ~= nil then
			return
		end
		if updateConnection then
			safeDisconnect(updateConnection)
			updateConnection = nil
		end
	end

	local function unregisterRecord(token)
		local record = records[token]
		if not record then
			return false
		end

		wakeRecord(token, "unregister", { fade = false })

		for _, connection in ipairs(record.connections) do
			safeDisconnect(connection)
		end
		table.clear(record.connections)

		local guiObject = record.guiObject
		if guiObject and guiObject.SetAttribute then
			pcall(guiObject.SetAttribute, guiObject, "RayfieldVirtualToken", nil)
			pcall(guiObject.SetAttribute, guiObject, "RayfieldViewportSleeping", false)
		end

		if guiObject then
			recordsByObject[guiObject] = nil
		end

		local host = hosts[record.hostId]
		if host then
			host.elements[token] = nil
			markHostDirty(record.hostId, "element_unregister")
		end

		records[token] = nil
		return true
	end

	self.registerHost = function(hostId, hostObject, options)
		if self.Config.Enabled ~= true then
			return false
		end
		if type(hostId) ~= "string" or hostId == "" then
			return false
		end
		if typeof(hostObject) ~= "Instance" or not hostObject:IsA("GuiObject") then
			return false
		end

		local previousTokens = nil
		local existingHost = hosts[hostId]
		if existingHost then
			previousTokens = {}
			for token in pairs(existingHost.elements) do
				table.insert(previousTokens, token)
			end
		end
		self.unregisterHost(hostId)

		local opts = options or {}
		local mode = tostring(opts.mode or "auto")
		if mode == "auto" then
			if hostObject:IsA("ScrollingFrame") then
				mode = "scrolling"
			else
				mode = "clipped"
			end
		end

		local host = {
			id = hostId,
			object = hostObject,
			mode = mode,
			overscan = tonumber(opts.overscan) or self.Config.OverscanPx,
			elements = {},
			connections = {},
			dirty = true,
			paused = false,
			resizeInProgress = false,
			resizeToken = 0,
			lastReason = "register"
		}
		if host.overscan < 0 then
			host.overscan = 0
		end

		local function onResize()
			host.resizeInProgress = true
			host.resizeToken += 1
			local token = host.resizeToken
			markHostDirty(hostId, "resize")
			if self.Config.DisableFadeDuringResize then
				local delaySec = math.max(0, self.Config.ResizeDebounceMs) / 1000
				task.delay(delaySec, function()
					local current = hosts[hostId]
					if current and current.resizeToken == token then
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
				self.unregisterHost(hostId)
			end))
		end
		table.insert(host.connections, hostObject.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				self.unregisterHost(hostId)
			else
				markHostDirty(hostId, "reparent")
			end
		end))

		hosts[hostId] = host
		table.insert(hostOrder, hostId)
		if previousTokens then
			for _, token in ipairs(previousTokens) do
				local record = records[token]
				if record then
					record.hostId = hostId
					host.elements[token] = true
				end
			end
		end
		ensureUpdateLoop()
		markHostDirty(hostId, "register")
		return true
	end

	self.unregisterHost = function(hostId)
		local host = hosts[hostId]
		if not host then
			return false
		end

		for token in pairs(host.elements) do
			local record = records[token]
			if record and record.hostId == hostId then
				wakeRecord(token, "host_unregister", { fade = false })
				record.hostId = nil
			end
		end

		for _, connection in ipairs(host.connections) do
			safeDisconnect(connection)
		end
		table.clear(host.connections)
		hosts[hostId] = nil

		for index = #hostOrder, 1, -1 do
			if hostOrder[index] == hostId then
				table.remove(hostOrder, index)
			end
		end

		disconnectUpdateLoopIfIdle()
		return true
	end

	self.refreshHost = function(hostId, reason)
		return markHostDirty(hostId, reason or "refresh")
	end

	self.setHostSuppressed = function(hostId, suppressed)
		local host = hosts[hostId]
		if not host then
			return false
		end
		host.paused = suppressed == true
		if host.paused then
			for token in pairs(host.elements) do
				sleepRecord(token, "host_suppressed", { fade = false })
			end
			host.dirty = false
			host.lastReason = nil
		else
			markHostDirty(hostId, "host_unsuppressed")
		end
		return true
	end

	self.registerElement = function(hostId, guiObject, options)
		if self.Config.Enabled ~= true then
			return nil
		end
		local host = hosts[hostId]
		if not host then
			return nil
		end
		if typeof(guiObject) ~= "Instance" or not guiObject:IsA("GuiObject") then
			return nil
		end

		tokenCounter += 1
		local token = "viewport_element_" .. tostring(tokenCounter)
		local opts = options or {}
		local record = {
			token = token,
			guiObject = guiObject,
			hostId = hostId,
			sleeping = false,
			spacer = nil,
			originalParent = nil,
			originalLayoutOrder = nil,
			cachedHeight = math.max(1, math.floor(guiObject.AbsoluteSize.Y + 0.5)),
			busy = false,
			onWake = opts.onWake,
			onSleep = opts.onSleep,
			meta = opts.meta,
			connections = {}
		}

		records[token] = record
		recordsByObject[guiObject] = token
		host.elements[token] = true

		if guiObject.SetAttribute then
			pcall(guiObject.SetAttribute, guiObject, "RayfieldVirtualToken", token)
		end

		table.insert(record.connections, guiObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			updateCachedHeight(record, guiObject)
			markHostDirty(record.hostId, "element_size")
		end))
		table.insert(record.connections, guiObject:GetPropertyChangedSignal("Visible"):Connect(function()
			markHostDirty(record.hostId, "element_visibility")
		end))
		table.insert(record.connections, guiObject.AncestryChanged:Connect(function(_, parent)
			if parent == nil and not record.sleeping then
				unregisterRecord(token)
				return
			end
			if record.hostId then
				markHostDirty(record.hostId, "element_reparent")
			end
		end))

		local okDestroying, destroyingSignal = pcall(function()
			return guiObject.Destroying
		end)
		if okDestroying and destroyingSignal and destroyingSignal.Connect then
			table.insert(record.connections, destroyingSignal:Connect(function()
				unregisterRecord(token)
			end))
		end

		ensureUpdateLoop()
		markHostDirty(hostId, "element_register")
		return token
	end

	self.unregisterElement = function(tokenOrObject)
		local token = nil
		local record = nil
		token, record = resolveToken(recordsByObject, records, tokenOrObject)
		if not token or not record then
			return false
		end
		return unregisterRecord(token)
	end

	self.moveElementToHost = function(tokenOrObject, hostId, reason)
		local host = hosts[hostId]
		if not host then
			return false
		end

		local token, record = resolveToken(recordsByObject, records, tokenOrObject)
		if not token or not record then
			return false
		end

		local previousHostId = record.hostId
		if previousHostId == hostId then
			markHostDirty(hostId, reason or "move_same_host")
			return true
		end

		wakeRecord(token, "move_host", { fade = false })
		if previousHostId and hosts[previousHostId] then
			hosts[previousHostId].elements[token] = nil
			markHostDirty(previousHostId, "element_moved")
		end

		record.hostId = hostId
		host.elements[token] = true
		markHostDirty(hostId, reason or "element_moved")
		return true
	end

	self.setElementBusy = function(tokenOrObject, busy)
		local token, record = resolveToken(recordsByObject, records, tokenOrObject)
		if not token or not record then
			return false
		end
		record.busy = busy == true
		if record.busy then
			wakeRecord(token, "busy", { fade = false })
		end
		if record.hostId then
			markHostDirty(record.hostId, "element_busy")
		end
		return true
	end

	self.notifyElementHostChanged = function(tokenOrObject, reason)
		local _, record = resolveToken(recordsByObject, records, tokenOrObject)
		if not record then
			return false
		end
		if record.hostId then
			markHostDirty(record.hostId, reason or "host_changed")
		end
		return true
	end

	self.getStats = function()
		local hostCount = 0
		for _ in pairs(hosts) do
			hostCount += 1
		end
		local elementCount = 0
		for _ in pairs(records) do
			elementCount += 1
		end
		local sleepingCount = 0
		for _, record in pairs(records) do
			if record.sleeping then
				sleepingCount += 1
			end
		end
		return {
			hosts = hostCount,
			elements = elementCount,
			sleeping = sleepingCount
		}
	end

	self.destroy = function()
		for token in pairs(records) do
			unregisterRecord(token)
		end

		local hostIds = {}
		for hostId in pairs(hosts) do
			table.insert(hostIds, hostId)
		end
		for _, hostId in ipairs(hostIds) do
			self.unregisterHost(hostId)
		end

		if updateConnection then
			safeDisconnect(updateConnection)
			updateConnection = nil
		end
		updateAccumulator = 0
		clearStorageRoot()
	end

	return self
end

return ViewportVirtualization
