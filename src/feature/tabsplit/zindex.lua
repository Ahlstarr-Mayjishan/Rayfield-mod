local ZIndex = {}

function ZIndex.capture(root)
	local map = setmetatable({}, { __mode = "k" })
	if not root then
		return map
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			map[descendant] = descendant.ZIndex
		end
	end
	if root:IsA("GuiObject") then
		map[root] = root.ZIndex
	end
	return map
end

function ZIndex.apply(root, map, zBase)
	if not root or not map then
		return
	end
	zBase = zBase or 20
	for instance, original in pairs(map) do
		if instance and instance.Parent and instance:IsA("GuiObject") then
			instance.ZIndex = math.max(original, zBase)
		end
	end
end

function ZIndex.restore(map)
	if not map then
		return
	end
	for instance, original in pairs(map) do
		if instance and instance.Parent and instance:IsA("GuiObject") then
			instance.ZIndex = original
		end
	end
end

return ZIndex