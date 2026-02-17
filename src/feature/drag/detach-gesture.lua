local DetachGesture = {}

function DetachGesture.shouldStartHold(startTick, nowTick, holdDuration)
	holdDuration = holdDuration or 3
	return (nowTick - startTick) >= holdDuration
end

function DetachGesture.isDragThresholdExceeded(startPosition, currentPosition, threshold)
	threshold = threshold or 4
	if not startPosition or not currentPosition then
		return false
	end
	return (currentPosition - startPosition).Magnitude >= threshold
end

return DetachGesture