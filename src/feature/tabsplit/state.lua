local TabSplitState = {}

function TabSplitState.create(ctx)
	local sharedInputChanged = {}
	local sharedInputEnded = {}
	local sharedInputConnections = nil

	local function ensureSharedInput()
		if sharedInputConnections then
			return
		end

		sharedInputConnections = {
			ctx.UserInputService.InputChanged:Connect(function(input)
				for _, cb in pairs(sharedInputChanged) do
					cb(input)
				end
			end),
			ctx.UserInputService.InputEnded:Connect(function(input)
				for _, cb in pairs(sharedInputEnded) do
					cb(input)
				end
			end)
		}
	end

	local function registerSharedInput(id, onChanged, onEnded)
		ensureSharedInput()
		if type(onChanged) == "function" then
			sharedInputChanged[id] = onChanged
		end
		if type(onEnded) == "function" then
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
		return ctx.UserInputService:GetMouseLocation()
	end

	local function isPointInside(guiObject, point, padding)
		if not (guiObject and guiObject.Parent and point) then
			return false
		end

		local pad = padding or 0
		local absPos = guiObject.AbsolutePosition
		local absSize = guiObject.AbsoluteSize
		return point.X >= (absPos.X - pad)
			and point.X <= (absPos.X + absSize.X + pad)
			and point.Y >= (absPos.Y - pad)
			and point.Y <= (absPos.Y + absSize.Y + pad)
	end

	local function isPointInsideMain(point)
		return isPointInside(ctx.Main, point, 0)
	end

	local function isPointInsideTabList(point)
		return isPointInside(ctx.TabList, point, 10)
	end

	local function clampPositionToViewport(root, desiredPosition, panelSize, panelMargin)
		local margin = panelMargin or 8
		local viewport = root.AbsoluteSize
		local clampedX = math.clamp(
			desiredPosition.X,
			margin,
			math.max(margin, viewport.X - panelSize.X - margin)
		)
		local clampedY = math.clamp(
			desiredPosition.Y,
			margin,
			math.max(margin, viewport.Y - panelSize.Y - margin)
		)
		return Vector2.new(clampedX, clampedY)
	end

	local function hasZIndex(guiObject)
		return pcall(function()
			local _ = guiObject.ZIndex
		end)
	end

	return {
		ensureSharedInput = ensureSharedInput,
		registerSharedInput = registerSharedInput,
		unregisterSharedInput = unregisterSharedInput,
		disconnectSharedInput = disconnectSharedInput,
		getInputPosition = getInputPosition,
		isPointInside = isPointInside,
		isPointInsideMain = isPointInsideMain,
		isPointInsideTabList = isPointInsideTabList,
		clampPositionToViewport = clampPositionToViewport,
		hasZIndex = hasZIndex
	}
end

return TabSplitState
