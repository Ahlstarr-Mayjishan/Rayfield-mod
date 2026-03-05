local HoverProvider = {}

function HoverProvider.create(options)
	options = options or {}
	local runService = options.RunService
	local userInputService = options.UserInputService
	local httpService = options.HttpService
	local pageLayout = options.PageLayout
	local tabPage = options.TabPage
	local hoverSyncInterval = tonumber(options.HoverSyncInterval) or (1 / 30)
	local onCurrentPageChanged = type(options.onCurrentPageChanged) == "function" and options.onCurrentPageChanged or nil

	local provider = {}
	local hoverBindings = {}
	local hoverSyncConnection = nil
	local hoverSyncAccumulator = 0
	local hoverSyncDirty = true
	local hoverLastPointer = nil
	local hoverLastPage = nil
	local hoverBindingCount = 0
	local currentPageConnection = nil

	local function getPointerLocation()
		local ok, pointer = pcall(function()
			return userInputService:GetMouseLocation()
		end)
		if ok then
			return pointer
		end
		return nil
	end

	local function isPointInsideGui(point, guiObject)
		if not point or not guiObject or not guiObject.Parent then
			return false
		end
		local pos = guiObject.AbsolutePosition
		local size = guiObject.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return false
		end
		return point.X >= pos.X
			and point.Y >= pos.Y
			and point.X <= (pos.X + size.X)
			and point.Y <= (pos.Y + size.Y)
	end

	function provider.markDirty()
		hoverSyncDirty = true
	end

	function provider.getBinding(bindingKey)
		return hoverBindings[bindingKey]
	end

	local function cleanupBinding(bindingKey)
		local binding = hoverBindings[bindingKey]
		if not binding then
			return
		end
		if binding.Hovered and binding.OnLeave then
			pcall(binding.OnLeave)
		end
		binding.Hovered = false
		if binding.DestroyingConnection then
			binding.DestroyingConnection:Disconnect()
			binding.DestroyingConnection = nil
		end
		hoverBindings[bindingKey] = nil
		hoverBindingCount = math.max(0, hoverBindingCount - 1)
		provider.markDirty()
		if hoverBindingCount <= 0 and hoverSyncConnection then
			hoverSyncConnection:Disconnect()
			hoverSyncConnection = nil
		end
	end

	function provider.sync(point, force)
		local pointer = point or getPointerLocation()
		local currentPage = pageLayout and pageLayout.CurrentPage or nil
		local isCurrentTab = currentPage == tabPage

		for _, binding in pairs(hoverBindings) do
			local guiObject = binding.GuiObject
			local shouldHover = false
			if isCurrentTab and guiObject and guiObject.Parent and guiObject.Visible and guiObject:IsDescendantOf(tabPage) then
				shouldHover = isPointInsideGui(pointer, guiObject)
			end

			if force or binding.Hovered ~= shouldHover then
				binding.Hovered = shouldHover
				if shouldHover then
					if binding.OnEnter then
						binding.OnEnter()
					end
				else
					if binding.OnLeave then
						binding.OnLeave()
					end
				end
			end
		end

		hoverLastPointer = pointer
		hoverLastPage = currentPage
		hoverSyncDirty = false
	end

	local function ensureHoverSyncConnection()
		if hoverSyncConnection then
			return
		end
		if not (runService and runService.RenderStepped) then
			return
		end

		hoverSyncConnection = runService.RenderStepped:Connect(function(deltaTime)
			if hoverBindingCount <= 0 then
				return
			end
			hoverSyncAccumulator += deltaTime
			if hoverSyncAccumulator < hoverSyncInterval then
				return
			end

			hoverSyncAccumulator = 0
			local pointer = getPointerLocation()
			local currentPage = pageLayout and pageLayout.CurrentPage or nil
			local shouldSync = hoverSyncDirty
			if not shouldSync then
				if currentPage ~= hoverLastPage then
					shouldSync = true
				elseif pointer and hoverLastPointer then
					if math.abs(pointer.X - hoverLastPointer.X) >= 1 or math.abs(pointer.Y - hoverLastPointer.Y) >= 1 then
						shouldSync = true
					end
				elseif pointer ~= hoverLastPointer then
					shouldSync = true
				end
			end
			if shouldSync then
				provider.sync(pointer, false)
			end
		end)
	end

	function provider.registerBinding(guiObject, onEnter, onLeave, key)
		if not (guiObject and guiObject:IsA("GuiObject")) then
			return nil
		end

		local bindingKey = key
		if type(bindingKey) ~= "string" or bindingKey == "" then
			if httpService and type(httpService.GenerateGUID) == "function" then
				bindingKey = httpService:GenerateGUID(false)
			else
				bindingKey = tostring(guiObject) .. ":" .. tostring(os.clock())
			end
		end

		cleanupBinding(bindingKey)

		local binding = {
			GuiObject = guiObject,
			OnEnter = onEnter,
			OnLeave = onLeave,
			Hovered = false,
			DestroyingConnection = nil
		}

		local destroyingSignal = nil
		local signalOk, signalValue = pcall(function()
			return guiObject.Destroying
		end)
		if signalOk and signalValue and signalValue.Connect then
			destroyingSignal = signalValue
		end
		if destroyingSignal then
			binding.DestroyingConnection = destroyingSignal:Connect(function()
				cleanupBinding(bindingKey)
			end)
		else
			binding.DestroyingConnection = guiObject.AncestryChanged:Connect(function()
				if not guiObject:IsDescendantOf(game) then
					cleanupBinding(bindingKey)
				end
			end)
		end

		hoverBindings[bindingKey] = binding
		hoverBindingCount += 1
		provider.markDirty()
		ensureHoverSyncConnection()

		task.defer(function()
			if hoverBindings[bindingKey] then
				provider.sync(nil, true)
			end
		end)

		return bindingKey
	end

	function provider.cleanupBinding(bindingKey)
		cleanupBinding(bindingKey)
	end

	function provider.cleanupAll()
		for key in pairs(hoverBindings) do
			cleanupBinding(key)
		end
		hoverBindingCount = 0
		if hoverSyncConnection then
			hoverSyncConnection:Disconnect()
			hoverSyncConnection = nil
		end
		provider.markDirty()
	end

	function provider.destroy()
		if currentPageConnection then
			currentPageConnection:Disconnect()
			currentPageConnection = nil
		end
		provider.cleanupAll()
	end

	if pageLayout and pageLayout.GetPropertyChangedSignal then
		currentPageConnection = pageLayout:GetPropertyChangedSignal("CurrentPage"):Connect(function()
			provider.markDirty()
			provider.sync(nil, true)
			if onCurrentPageChanged then
				pcall(onCurrentPageChanged, pageLayout.CurrentPage)
			end
		end)
	end

	return provider
end

return HoverProvider
