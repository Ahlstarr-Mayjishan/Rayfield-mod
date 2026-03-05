local MathUtils = {}

function MathUtils.clampNumber(value, minimum, maximum, fallback)
	local numberValue = tonumber(value)
	if not numberValue then
		numberValue = tonumber(fallback) or 0
	end
	if minimum ~= nil then
		numberValue = math.max(minimum, numberValue)
	end
	if maximum ~= nil then
		numberValue = math.min(maximum, numberValue)
	end
	return numberValue
end

function MathUtils.roundToPrecision(value, precision)
	local digits = math.max(0, math.floor(tonumber(precision) or 0))
	local scale = 10 ^ digits
	return math.floor((tonumber(value) or 0) * scale + 0.5) / scale
end

function MathUtils.packColor3(colorValue)
	if typeof(colorValue) ~= "Color3" then
		return nil
	end
	return {
		R = math.floor((colorValue.R * 255) + 0.5),
		G = math.floor((colorValue.G * 255) + 0.5),
		B = math.floor((colorValue.B * 255) + 0.5)
	}
end

function MathUtils.unpackColor3(colorValue)
	if type(colorValue) ~= "table" then
		return nil
	end
	local r = tonumber(colorValue.R)
	local g = tonumber(colorValue.G)
	local b = tonumber(colorValue.B)
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(
		math.clamp(math.floor(r + 0.5), 0, 255),
		math.clamp(math.floor(g + 0.5), 0, 255),
		math.clamp(math.floor(b + 0.5), 0, 255)
	)
end

return MathUtils
