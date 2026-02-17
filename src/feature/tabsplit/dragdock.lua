local TabSplitDragDock = {}

function TabSplitDragDock.attachPanelDrag(panelData, opts)
	local state = {
		pressing = false,
		dragging = false,
		pressInput = nil,
		startPointer = nil,
		startPosition = nil,
		pointer = nil
	}

	local function resetState()
		state.pressing = false
		state.dragging = false
		state.pressInput = nil
		state.startPointer = nil
		state.startPosition = nil
		state.pointer = nil
		panelData.Dragging = false
		opts.setPanelHoverState(panelData, panelData.HoverActive, false)
	end

	local function beginPress(input)
		if opts.isBlocked() or not (panelData.Frame and panelData.Frame.Parent) then
			return
		end

		local pointer = opts.getInputPosition(input)
		if opts.isPointInside(panelData.DockButton, pointer, 0) then
			return
		end

		state.pressing = true
		state.dragging = false
		state.pressInput = input
		state.startPointer = pointer
		state.pointer = pointer
		if panelData.ManualPosition then
			state.startPosition = panelData.ManualPosition
		else
			state.startPosition = Vector2.new(panelData.Frame.AbsolutePosition.X, panelData.Frame.AbsolutePosition.Y)
		end

		opts.bringPanelToFront(panelData)
	end

	local function finishPress(input)
		if not state.pressInput then
			return
		end

		local sameTouch = input == state.pressInput
		local mouseEnded = state.pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
		if not sameTouch and not mouseEnded then
			return
		end

		local wasDragging = state.dragging
		local dropPoint = state.pointer or opts.getInputPosition(input)
		resetState()

		if not wasDragging then
			return
		end

		if opts.isPointInsideTabList(dropPoint) then
			opts.dockTab(panelData.TabRecord)
			return
		end

		local root = opts.ensureSplitRoot()
		local panelSize = opts.getPanelSize(root)
		local currentPosition = panelData.ManualPosition or Vector2.new(panelData.Frame.AbsolutePosition.X, panelData.Frame.AbsolutePosition.Y)
		local clamped = opts.clampPositionToViewport(root, currentPosition, panelSize)
		panelData.ManualPosition = clamped
		panelData.Frame.Position = UDim2.fromOffset(clamped.X, clamped.Y)
		opts.layoutPanels()
	end

	table.insert(panelData.Cleanup, panelData.Header.InputBegan:Connect(function(input)
		local inputType = input.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end
		beginPress(input)
	end))

	opts.registerSharedInput(panelData.InputId, function(input)
		if not state.pressing or not state.pressInput then
			return
		end

		local sameTouch = input == state.pressInput
		local mouseMove = state.pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
		if not sameTouch and not mouseMove then
			return
		end

		state.pointer = opts.getInputPosition(input)
		local delta = state.pointer - state.startPointer
		if not state.dragging and delta.Magnitude >= opts.dragThreshold then
			state.dragging = true
			panelData.Dragging = true
			opts.setPanelHoverState(panelData, true, false)
		end

		if state.dragging then
			local root = opts.ensureSplitRoot()
			local panelSize = opts.getPanelSize(root)
			local desired = state.startPosition + delta
			local clamped = opts.clampPositionToViewport(root, desired, panelSize)
			panelData.ManualPosition = clamped
			panelData.Frame.Position = UDim2.fromOffset(clamped.X, clamped.Y)
		end
	end, finishPress)

	table.insert(panelData.Cleanup, resetState)
end

return TabSplitDragDock
