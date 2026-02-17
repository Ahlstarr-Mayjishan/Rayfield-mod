local MiniWindowDrag = {}

function MiniWindowDrag.clamp(position, viewport, size)
	local x = math.clamp(position.X, 0, math.max(0, viewport.X - size.X))
	local y = math.clamp(position.Y, 0, math.max(0, viewport.Y - size.Y))
	return Vector2.new(x, y)
end

return MiniWindowDrag