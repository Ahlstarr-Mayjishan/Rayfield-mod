local FloatingWindowReorder = {}

function FloatingWindowReorder.calculateInsertIndex(record, point, getOrderedGuiChildren)
	if not (record and record.content and record.content.Parent and point) then
		return nil, {}
	end
	if type(getOrderedGuiChildren) ~= "function" then
		return nil, {}
	end

	local ordered = getOrderedGuiChildren(record.content)
	local insertIndex = #ordered + 1

	for index, child in ipairs(ordered) do
		local childCenterY = child.AbsolutePosition.Y + (child.AbsoluteSize.Y * 0.5)
		if point.Y <= childCenterY then
			insertIndex = index
			break
		end
	end

	return insertIndex, ordered
end

function FloatingWindowReorder.apply(params)
	if type(params) ~= "table" then
		return false
	end

	local record = params.record
	local guiObject = params.guiObject
	local requestedInsertIndex = params.requestedInsertIndex
	local getOrderedGuiChildren = params.getOrderedGuiChildren
	local normalizeOrderedGuiLayout = params.normalizeOrderedGuiLayout
	local updateWindowRecordLayout = params.updateWindowRecordLayout
	local resyncElement = params.resyncElement
	local notifyLayoutDirty = params.notifyLayoutDirty

	if not (record and record.content and record.content.Parent) then
		return false
	end
	if type(getOrderedGuiChildren) ~= "function" or type(normalizeOrderedGuiLayout) ~= "function" then
		return false
	end

	local ordered = getOrderedGuiChildren(record.content)
	local currentIndex = nil
	for index, child in ipairs(ordered) do
		if child == guiObject then
			currentIndex = index
			break
		end
	end

	if not currentIndex then
		return false
	end

	local insertIndex = tonumber(requestedInsertIndex)
	if type(insertIndex) == "number" then
		insertIndex = math.floor(insertIndex)
	else
		insertIndex = currentIndex
	end

	table.remove(ordered, currentIndex)
	insertIndex = math.clamp(insertIndex, 1, #ordered + 1)
	table.insert(ordered, insertIndex, guiObject)
	normalizeOrderedGuiLayout(ordered)

	record.nextOrder = (#ordered + 1) * 10

	if type(updateWindowRecordLayout) == "function" then
		updateWindowRecordLayout(record)
	end
	if type(resyncElement) == "function" then
		resyncElement("reorder_detached")
	end
	if type(notifyLayoutDirty) == "function" then
		notifyLayoutDirty("floating_reorder")
	end

	return true
end

return FloatingWindowReorder
