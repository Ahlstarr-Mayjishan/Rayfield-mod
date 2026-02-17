local DragWindow = {}

function DragWindow.create(ctx)
	local detachedScreenGui = nil
	local detachedLayer = nil
	local detachedCleanupBound = false
	local detachedWindowsRegistry = {}

	local function getInputPosition(input)
		if type(ctx.getInputPosition) == "function" then
			return ctx.getInputPosition(input)
		end
		if input and input.Position then
			return Vector2.new(input.Position.X, input.Position.Y)
		end
		return ctx.UserInputService:GetMouseLocation()
	end

	local function registerDetachedWindow(record)
		if not record then
			return
		end
		table.insert(detachedWindowsRegistry, record)
	end

	local function unregisterDetachedWindow(record)
		for i = #detachedWindowsRegistry, 1, -1 do
			if detachedWindowsRegistry[i] == record then
				table.remove(detachedWindowsRegistry, i)
				break
			end
		end
	end

	local function isPointNearFrame(point, frame, padding)
		if not (point and frame and frame.Parent) then
			return false
		end

		local pad = padding or 0
		local framePosition = frame.AbsolutePosition
		local frameSize = frame.AbsoluteSize
		local minX = framePosition.X - pad
		local minY = framePosition.Y - pad
		local maxX = framePosition.X + frameSize.X + pad
		local maxY = framePosition.Y + frameSize.Y + pad
		return point.X >= minX and point.X <= maxX and point.Y >= minY and point.Y <= maxY
	end

	local function findMergeTargetWindow(point, excludeRecord)
		for _, record in ipairs(detachedWindowsRegistry) do
			if record ~= excludeRecord and record.frame and record.frame.Parent and isPointNearFrame(point, record.frame, ctx.mergeDetectPadding) then
				return record
			end
		end
		return nil
	end

	local function ensureDetachedLayer()
		if detachedLayer and detachedLayer.Parent then
			return detachedLayer
		end

		if detachedScreenGui and not detachedScreenGui.Parent then
			detachedScreenGui = nil
			detachedLayer = nil
		end

		if not detachedScreenGui then
			local existing = ctx.Rayfield.Parent and ctx.Rayfield.Parent:FindFirstChild("self.Rayfield-DetachedWindows")
			if existing and existing:IsA("ScreenGui") then
				detachedScreenGui = existing
			else
				detachedScreenGui = Instance.new("ScreenGui")
				detachedScreenGui.Name = "self.Rayfield-DetachedWindows"
				detachedScreenGui.ResetOnSpawn = false
				detachedScreenGui.IgnoreGuiInset = ctx.Rayfield.IgnoreGuiInset
				detachedScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
				detachedScreenGui.DisplayOrder = math.max((ctx.Rayfield.DisplayOrder or 100) + 1, 101)
				detachedScreenGui.Parent = ctx.Rayfield.Parent
			end
		end

		detachedLayer = detachedScreenGui:FindFirstChild("WindowLayer")
		if not detachedLayer then
			detachedLayer = Instance.new("Frame")
			detachedLayer.Name = "WindowLayer"
			detachedLayer.BackgroundTransparency = 1
			detachedLayer.BorderSizePixel = 0
			detachedLayer.Size = UDim2.fromScale(1, 1)
			detachedLayer.Parent = detachedScreenGui
		end

		if not detachedCleanupBound then
			detachedCleanupBound = true
			ctx.Rayfield.Destroying:Connect(function()
				if detachedScreenGui then
					detachedScreenGui:Destroy()
					detachedScreenGui = nil
					detachedLayer = nil
				end
				table.clear(detachedWindowsRegistry)
				if type(ctx.onDestroyInput) == "function" then
					ctx.onDestroyInput()
				end
			end)
		end

		return detachedLayer
	end

	local function prewarmDetachedLayer()
		task.defer(function()
			if ctx.rayfieldDestroyed and ctx.rayfieldDestroyed() then
				return
			end
			pcall(ensureDetachedLayer)
		end)
	end

	local function clampDetachedPosition(desiredPosition, windowSize)
		local layer = ensureDetachedLayer()
		local layerSize = layer.AbsoluteSize
		local maxX = math.max(layerSize.X - windowSize.X, 0)
		local maxY = math.max(layerSize.Y - windowSize.Y, 0)
		return Vector2.new(
			math.clamp(desiredPosition.X, 0, maxX),
			math.clamp(desiredPosition.Y, 0, maxY)
		)
	end

	local function isOutsideMain(point)
		local mainPosition = ctx.Main.AbsolutePosition
		local mainSize = ctx.Main.AbsoluteSize
		return point.X < mainPosition.X
			or point.Y < mainPosition.Y
			or point.X > (mainPosition.X + mainSize.X)
			or point.Y > (mainPosition.Y + mainSize.Y)
	end

	local function isInsideMain(point)
		return not isOutsideMain(point)
	end

	local function makeFloatingDraggable(frame, dragHandle, onDragEnd)
		local dragging = false
		local dragInput = nil
		local dragStartPointer = nil
		local dragStartFramePosition = nil
		local targetPosition = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
		local connections = {}
		local dragId = ctx.HttpService and ctx.HttpService:GenerateGUID(false) or tostring(math.random())

		dragHandle.Active = true

		table.insert(connections, dragHandle.InputBegan:Connect(function(input)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end

			dragging = true
			dragInput = input
			dragStartPointer = getInputPosition(input)
			dragStartFramePosition = targetPosition
		end))

		ctx.registerSharedInput(dragId, function(input)
			if not dragging or not dragInput then
				return
			end

			local matchesTouch = input == dragInput
			local matchesMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
			if not matchesTouch and not matchesMouse then
				return
			end

			local currentPointer = getInputPosition(input)
			local delta = currentPointer - dragStartPointer
			local desired = dragStartFramePosition + delta
			targetPosition = clampDetachedPosition(desired, frame.AbsoluteSize)
		end, function(input)
			if not dragging or not dragInput then
				return
			end

			local mouseEnded = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
			if input == dragInput or mouseEnded then
				local releasePoint = getInputPosition(input)
				dragging = false
				dragInput = nil
				if typeof(onDragEnd) == "function" then
					task.defer(onDragEnd, releasePoint, frame)
				end
			end
		end)

		table.insert(connections, ctx.RunService.RenderStepped:Connect(function(deltaTime)
			if not dragging then
				targetPosition = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
				return
			end

			local current = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
			local alpha = math.clamp(deltaTime * ((ctx.followSpeed or 0.28) * 60), 0, 1)
			local nextPosition = current:Lerp(targetPosition, alpha)
			frame.Position = UDim2.fromOffset(math.floor(nextPosition.X + 0.5), math.floor(nextPosition.Y + 0.5))
		end))

		return function()
			ctx.unregisterSharedInput(dragId)
			for _, connection in ipairs(connections) do
				if connection then
					connection:Disconnect()
				end
			end
			table.clear(connections)
		end
	end

	return {
		registerDetachedWindow = registerDetachedWindow,
		unregisterDetachedWindow = unregisterDetachedWindow,
		isPointNearFrame = isPointNearFrame,
		findMergeTargetWindow = findMergeTargetWindow,
		ensureDetachedLayer = ensureDetachedLayer,
		prewarmDetachedLayer = prewarmDetachedLayer,
		clampDetachedPosition = clampDetachedPosition,
		isOutsideMain = isOutsideMain,
		isInsideMain = isInsideMain,
		makeFloatingDraggable = makeFloatingDraggable
	}
end

return DragWindow
