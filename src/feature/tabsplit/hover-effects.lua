local HoverEffects = {}

function HoverEffects.resolveAccent(theme)
	theme = theme or {}
	return theme.SliderProgress or theme.TabStroke or Color3.fromRGB(110, 175, 240)
end

function HoverEffects.getHoverStrokeState(isHovered)
	if isHovered then
		return {
			thickness = 1.2,
			transparency = 0.35
		}
	end
	return {
		thickness = 1,
		transparency = 0.5
	}
end

return HoverEffects