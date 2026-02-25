local TabSplitReorder = {}

function TabSplitReorder.removePanel(panelOrder, panelId)
	if type(panelOrder) ~= "table" or panelId == nil then
		return false
	end

	for i = #panelOrder, 1, -1 do
		if panelOrder[i] == panelId then
			table.remove(panelOrder, i)
			return true
		end
	end
	return false
end

function TabSplitReorder.appendPanel(panelOrder, panelId)
	if type(panelOrder) ~= "table" or panelId == nil then
		return false
	end

	TabSplitReorder.removePanel(panelOrder, panelId)
	table.insert(panelOrder, panelId)
	return true
end

function TabSplitReorder.bringToFront(panelOrder, panelId)
	return TabSplitReorder.appendPanel(panelOrder, panelId)
end

return TabSplitReorder
