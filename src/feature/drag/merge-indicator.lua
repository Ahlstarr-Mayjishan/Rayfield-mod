local MergeIndicator = {}

function MergeIndicator.computeInsertIndex(slotPositions, pointerX)
	local index = #slotPositions + 1
	for i, x in ipairs(slotPositions) do
		if pointerX < x then
			index = i
			break
		end
	end
	return index
end

return MergeIndicator