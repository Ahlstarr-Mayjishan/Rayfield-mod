local Container = {}

function Container.new(seed)
	local registry = seed or {}
	return {
		set = function(_, key, value)
			registry[key] = value
		end,
		get = function(_, key)
			return registry[key]
		end,
		all = function()
			return registry
		end
	}
end

return Container
