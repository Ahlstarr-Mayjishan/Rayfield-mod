local Easing = {}

Easing.DefaultInfo = TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

Easing.Presets = {
	fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	normal = TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	slow = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	bounce = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

function Easing.resolve(info)
	if typeof(info) == "TweenInfo" then
		return info
	end
	if type(info) == "string" then
		return Easing.Presets[info] or Easing.DefaultInfo
	end
	return Easing.DefaultInfo
end

return Easing
