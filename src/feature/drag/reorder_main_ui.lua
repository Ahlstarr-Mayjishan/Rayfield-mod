local MainUiReorder = {}

local function cloneStateSnapshot(state)
	if type(state) ~= "table" then
		return nil
	end

	return {
		Parent = state.Parent,
		AnchorPoint = state.AnchorPoint,
		Position = state.Position,
		Size = state.Size,
		LayoutOrder = state.LayoutOrder,
		SiblingIndex = state.SiblingIndex,
		PreviousSibling = state.PreviousSibling,
		NextSibling = state.NextSibling
	}
end

function MainUiReorder.apply(params)
	if type(params) ~= "table" then
		return false, nil
	end

	local detached = params.detached == true
	local guiObject = params.guiObject
	local point = params.point
	local requestedInsertIndex = params.requestedInsertIndex
	local currentTabPage = params.currentTabPage
	local parentUsesLayoutOrder = params.parentUsesLayoutOrder
	local getOrderedMainDockChildren = params.getOrderedMainDockChildren
	local calculateMainInsertIndex = params.calculateMainInsertIndex
	local normalizeOrderedGuiLayout = params.normalizeOrderedGuiLayout
	local captureCurrentElementState = params.captureCurrentElementState
	local resyncElement = params.resyncElement
	local rememberedState = params.rememberedState

	if detached then
		return false, rememberedState
	end
	if not (guiObject and guiObject.Parent) then
		return false, rememberedState
	end
	if not (currentTabPage and currentTabPage.Parent) then
		return false, rememberedState
	end
	if currentTabPage ~= guiObject.Parent then
		return false, rememberedState
	end
	if type(parentUsesLayoutOrder) ~= "function" or not parentUsesLayoutOrder(currentTabPage) then
		return false, rememberedState
	end
	if type(getOrderedMainDockChildren) ~= "function"
		or type(calculateMainInsertIndex) ~= "function"
		or type(normalizeOrderedGuiLayout) ~= "function"
	then
		return false, rememberedState
	end

	local ordered = getOrderedMainDockChildren(currentTabPage, guiObject)
	local insertIndex = tonumber(requestedInsertIndex)
	if type(insertIndex) == "number" then
		insertIndex = math.floor(insertIndex)
	else
		insertIndex = nil
	end

	if type(insertIndex) ~= "number" then
		local calculated, calculatedOrdered = calculateMainInsertIndex(currentTabPage, point, guiObject)
		insertIndex = calculated
		if type(calculatedOrdered) == "table" then
			ordered = calculatedOrdered
		end
	end

	if type(insertIndex) ~= "number" then
		return false, rememberedState
	end

	insertIndex = math.clamp(insertIndex, 1, #ordered + 1)
	table.insert(ordered, insertIndex, guiObject)
	normalizeOrderedGuiLayout(ordered)

	local nextRememberedState = rememberedState
	if type(captureCurrentElementState) == "function" then
		nextRememberedState = cloneStateSnapshot(captureCurrentElementState())
	end

	if type(resyncElement) == "function" then
		resyncElement("reorder_main")
	end

	return true, nextRememberedState
end

return MainUiReorder
