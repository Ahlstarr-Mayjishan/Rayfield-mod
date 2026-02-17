local UI = {}
UI.__index = UI

function UI.new(engine, target)
	local self = setmetatable({}, UI)
	self._engine = engine
	self._target = target
	return self
end

function UI:_play(info, goals, opts)
	return self._engine:Play(self._target, info, goals, opts)
end

function UI:FadeIn(duration)
	if self._target and self._target:IsA("GuiObject") then
		self._target.Visible = true
	end
	return self:_play(
		TweenInfo.new(duration or 0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	)
end

function UI:FadeOut(duration, hideAfter)
	local tween = self:_play(
		TweenInfo.new(duration or 0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	if tween and hideAfter ~= false and self._target and self._target:IsA("GuiObject") then
		tween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				self._target.Visible = false
			end
		end)
	end
	return tween
end

function UI:Pop(duration, scaleMultiplier)
	if not (self._target and self._target:IsA("GuiObject")) then
		return nil
	end

	local original = self._target.Size
	local multiplier = tonumber(scaleMultiplier) or 1.05
	local targetSize = UDim2.new(
		original.X.Scale * multiplier,
		math.floor(original.X.Offset * multiplier + 0.5),
		original.Y.Scale * multiplier,
		math.floor(original.Y.Offset * multiplier + 0.5)
	)

	local tweenOut = self:_play(
		TweenInfo.new((duration or 0.2) * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = targetSize }
	)

	if tweenOut then
		tweenOut.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				self:_play(
					TweenInfo.new((duration or 0.2) * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Size = original }
				)
			end
		end)
	end

	return tweenOut
end

function UI:SlideIn(direction, duration)
	if not (self._target and self._target:IsA("GuiObject")) then
		return nil
	end

	local original = self._target.Position
	local from = original
	local moveDirection = (type(direction) == "string" and string.lower(direction)) or "left"

	if moveDirection == "left" then
		from = UDim2.new(-1, 0, original.Y.Scale, original.Y.Offset)
	elseif moveDirection == "right" then
		from = UDim2.new(2, 0, original.Y.Scale, original.Y.Offset)
	elseif moveDirection == "top" then
		from = UDim2.new(original.X.Scale, original.X.Offset, -1, 0)
	else
		from = UDim2.new(original.X.Scale, original.X.Offset, 2, 0)
	end

	self._target.Position = from
	self._target.Visible = true
	return self:_play(
		TweenInfo.new(duration or 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = original }
	)
end

function UI:SlideOut(direction, duration)
	if not (self._target and self._target:IsA("GuiObject")) then
		return nil
	end

	local original = self._target.Position
	local to = original
	local moveDirection = (type(direction) == "string" and string.lower(direction)) or "left"

	if moveDirection == "left" then
		to = UDim2.new(-1, 0, original.Y.Scale, original.Y.Offset)
	elseif moveDirection == "right" then
		to = UDim2.new(2, 0, original.Y.Scale, original.Y.Offset)
	elseif moveDirection == "top" then
		to = UDim2.new(original.X.Scale, original.X.Offset, -1, 0)
	else
		to = UDim2.new(original.X.Scale, original.X.Offset, 2, 0)
	end

	return self:_play(
		TweenInfo.new(duration or 0.28, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{ Position = to }
	)
end

return UI
