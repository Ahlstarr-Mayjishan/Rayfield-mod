local LayoutFreeDrag = {}

function LayoutFreeDrag.clampToViewport(position, size, viewportSize, margin)
	margin = margin or 8
	local x = math.clamp(position.X.Offset, margin, math.max(margin, viewportSize.X - size.X.Offset - margin))
	local y = math.clamp(position.Y.Offset, margin, math.max(margin, viewportSize.Y - size.Y.Offset - margin))
	return UDim2.new(0, x, 0, y)
end

return LayoutFreeDrag