local ThemeBindings = {}

function ThemeBindings.bind(bindThemeFn, target, property, themeKey)
	if type(bindThemeFn) == "function" then
		return bindThemeFn(target, property, themeKey)
	end
end

return ThemeBindings