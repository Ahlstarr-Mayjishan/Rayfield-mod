local ReorderEngine = {}

local function getOrderedGuiChildren(parent, excludes)
	excludes = excludes or {}
	local deny = {}
	for _, obj in ipairs(excludes) do
		deny[obj] = true
	end

	local rawChildren = parent and parent:GetChildren() or {}
	local insertionOrder = {}
	for index, child in ipairs(rawChildren) do
		insertionOrder[child] = index
	end

	local ordered = {}
	for _, child in ipairs(rawChildren) do
		if child:IsA("GuiObject") and not deny[child] then
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

local function normalizeOrderedGuiLayout(ordered, step)
	step = step or 10
	for index, child in ipairs(ordered) do
		child.LayoutOrder = index * step
	end
end

local function calculateInsertIndex(ordered, point)
	if not point then
		return #ordered + 1
	end
	local insertIndex = #ordered + 1
	for index, child in ipairs(ordered) do
		local centerY = child.AbsolutePosition.Y + (child.AbsoluteSize.Y * 0.5)
		if point.Y <= centerY then
			insertIndex = index
			break
		end
	end
	return insertIndex
end

function ReorderEngine.init()
	return {
		getOrderedGuiChildren = getOrderedGuiChildren,
		normalizeOrderedGuiLayout = normalizeOrderedGuiLayout,
		calculateInsertIndex = calculateInsertIndex
	}
end

return ReorderEngine
