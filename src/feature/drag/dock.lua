local DragDock = {}

local function getOrderedGuiChildren(parent, excludeA, excludeB)
	if not parent then
		return {}
	end

	local rawChildren = parent:GetChildren()
	local insertionOrder = {}
	for index, child in ipairs(rawChildren) do
		insertionOrder[child] = index
	end

	local ordered = {}
	for _, child in ipairs(rawChildren) do
		if child:IsA("GuiObject") and child ~= excludeA and child ~= excludeB then
			table.insert(ordered, child)
		end
	end

	table.sort(ordered, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return (insertionOrder[a] or 0) < (insertionOrder[b] or 0)
	end)

	return ordered
end

local function normalizeOrderedGuiLayout(ordered)
	for index, child in ipairs(ordered) do
		child.LayoutOrder = index * 10
	end
end

local function parentUsesLayoutOrder(parent)
	if not parent then
		return false
	end
	local listLayout = parent:FindFirstChildOfClass("UIListLayout")
	return listLayout ~= nil and listLayout.SortOrder == Enum.SortOrder.LayoutOrder
end

local function resolveInsertIndexFromState(parent, state, ordered)
	if not (parent and state) then
		return nil
	end

	local candidates = ordered or getOrderedGuiChildren(parent)

	if state.NextSibling and state.NextSibling.Parent == parent then
		for index, child in ipairs(candidates) do
			if child == state.NextSibling then
				return index
			end
		end
	end

	if state.PreviousSibling and state.PreviousSibling.Parent == parent then
		for index, child in ipairs(candidates) do
			if child == state.PreviousSibling then
				return index + 1
			end
		end
	end

	if type(state.SiblingIndex) == "number" then
		return math.floor(state.SiblingIndex)
	end

	return nil
end

function DragDock.create()
	return {
		getOrderedGuiChildren = getOrderedGuiChildren,
		normalizeOrderedGuiLayout = normalizeOrderedGuiLayout,
		parentUsesLayoutOrder = parentUsesLayoutOrder,
		resolveInsertIndexFromState = resolveInsertIndexFromState
	}
end

return DragDock
