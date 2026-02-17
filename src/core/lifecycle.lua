local Lifecycle = {}

function Lifecycle.new()
	local cleanups = {}
	return {
		add = function(_, fn)
			if type(fn) == "function" then
				table.insert(cleanups, fn)
			end
		end,
		destroy = function()
			for i = #cleanups, 1, -1 do
				pcall(cleanups[i])
			end
			table.clear(cleanups)
		end
	}
end

return Lifecycle
