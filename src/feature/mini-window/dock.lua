local MiniWindowDock = {}

function MiniWindowDock.shouldDock(dropPosition, dockBounds)
	if not dropPosition or not dockBounds then
		return false
	end
	return dropPosition.X >= dockBounds.X and dropPosition.X <= (dockBounds.X + dockBounds.Width)
		and dropPosition.Y >= dockBounds.Y and dropPosition.Y <= (dockBounds.Y + dockBounds.Height)
end

return MiniWindowDock