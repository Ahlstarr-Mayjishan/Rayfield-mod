-- Rayfield Viewport Virtualization Service
-- Event-driven offscreen hibernation with spacer preservation.

local ViewportVirtualization = {}

local function safeDisconnect(connection)
	if not connection then
		return
	end
	pcall(function()
		connection:Disconnect()
	end)
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

	local engineModule = ctx.VirtualizationEngineModule
	if type(engineModule) ~= "table" or type(engineModule.mergeDefaults) ~= "function" then
		error("Rayfield | ViewportVirtualization missing VirtualizationEngineModule")
	end

	local hostManagerModule = ctx.VirtualHostManagerModule
	if type(hostManagerModule) ~= "table" or type(hostManagerModule.create) ~= "function" then
		error("Rayfield | ViewportVirtualization missing VirtualHostManagerModule")
	end

	self.Config = engineModule.mergeDefaults(ctx.Settings)
	self.RunService = ctx.RunService or game:GetService("RunService")
	self.TweenService = ctx.TweenService or game:GetService("TweenService")
	self.UserInputService = ctx.UserInputService or game:GetService("UserInputService")
	self.AnimationEngine = ctx.AnimationEngine
	self.RootGui = ctx.RootGui
	self.warn = type(ctx.warn) == "function" and ctx.warn or function(message)
		warn("Rayfield | ViewportVirtualization " .. tostring(message))
	end

	local records = {}
	local recordsByObject = setmetatable({}, { __mode = "k" })
	local tokenCounter = 0
	local updateConnection = nil
	local updateAccumulator = 0
	local updateInterval = 1 / self.Config.UpdateHz
	local storageRoot = nil
	local hostManager = nil
	hostManager = hostManagerModule.create({
		config = self.Config,
		safeDisconnect = safeDisconnect,
		taskLib = task,
		warn = self.warn,
		onAutoUnregister = function(hostId)
			if type(self.unregisterHost) == "function" then
				self.unregisterHost(hostId)
			elseif hostManager then
				hostManager.unregisterHost(hostId)
			end
		end
	})
	local hosts = hostManager.getHosts()
	local hostOrder = hostManager.getHostOrder()

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
		return engineModule.countHostElements(host, records)
	end

	local function shouldUseFade(host)
		return engineModule.shouldUseFade(self.Config, host)
	end

	local function markHostDirty(hostId, reason)
		return hostManager.markHostDirty(hostId, reason)
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
		if not engineModule.isAlive(guiObject) then
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
		engineModule.updateCachedHeight(record, targetObject)
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
		if not engineModule.isAlive(guiObject) then
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
		return engineModule.computeViewport(host)
	end

	local function computeBounds(host, record)
		return engineModule.computeBounds(host, record)
	end

	local function evaluateHost(hostId)
		local host = hosts[hostId]
		if not host then
			return
		end
		if not engineModule.isAlive(host.object) then
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
			updateAccumulator = updateAccumulator + deltaTime
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
		if hostManager.hasHosts() then
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
		local existingHost = hostManager.getHost(hostId)
		if existingHost then
			previousTokens = {}
			for token in pairs(existingHost.elements) do
				table.insert(previousTokens, token)
			end
		end
		self.unregisterHost(hostId)

		local okRegister = hostManager.registerHost(hostId, hostObject, options)
		if not okRegister then
			return false
		end
		local host = hostManager.getHost(hostId)
		if previousTokens and host then
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
		local host = hostManager.getHost(hostId)
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

		hostManager.unregisterHost(hostId)

		disconnectUpdateLoopIfIdle()
		return true
	end

	self.refreshHost = function(hostId, reason)
		return hostManager.refreshHost(hostId, reason)
	end

	self.setHostSuppressed = function(hostId, suppressed)
		local host = hostManager.getHost(hostId)
		if not host then
			return false
		end
		hostManager.setHostSuppressed(hostId, suppressed == true)
		host = hostManager.getHost(hostId)
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
		local host = hostManager.getHost(hostId)
		if not host then
			return nil
		end
		if typeof(guiObject) ~= "Instance" or not guiObject:IsA("GuiObject") then
			return nil
		end

		tokenCounter = tokenCounter + 1
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
		local token, record = resolveToken(recordsByObject, records, tokenOrObject)
		if not token or not record then
			return false
		end
		return unregisterRecord(token)
	end

	self.moveElementToHost = function(tokenOrObject, hostId, reason)
		local host = hostManager.getHost(hostId)
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
		local previousHost = previousHostId and hostManager.getHost(previousHostId) or nil
		if previousHost then
			previousHost.elements[token] = nil
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
		local hostCount = hostManager.countHosts()
		local elementCount = 0
		for _ in pairs(records) do
			elementCount = elementCount + 1
		end
		local sleepingCount = 0
		for _, record in pairs(records) do
			if record.sleeping then
				sleepingCount = sleepingCount + 1
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

		hostManager.destroy()

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
