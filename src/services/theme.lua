--[[
	Rayfield Theme System Module
	Extracted from rayfield-modified.lua

	This module handles:
	- Theme definitions (Default, Ocean, AmberGlow, Light, Amethyst, Green, Bloom, DarkBlue, Serenity)
	- Theme switching functionality
	- Icon system integration
]]

local ThemeModule = {}

-- Theme preset resolution
ThemeModule.Themes = {}

local FALLBACK_THEME_PRESETS = {
	Default = {
		TextColor = Color3.fromRGB(240, 240, 240),
		Background = Color3.fromRGB(25, 25, 25),
		Topbar = Color3.fromRGB(34, 34, 34),
		Shadow = Color3.fromRGB(20, 20, 20),
		NotificationBackground = Color3.fromRGB(20, 20, 20),
		NotificationActionsBackground = Color3.fromRGB(230, 230, 230),
		TabBackground = Color3.fromRGB(80, 80, 80),
		TabStroke = Color3.fromRGB(85, 85, 85),
		TabBackgroundSelected = Color3.fromRGB(210, 210, 210),
		TabTextColor = Color3.fromRGB(240, 240, 240),
		SelectedTabTextColor = Color3.fromRGB(50, 50, 50),
		ElementBackground = Color3.fromRGB(35, 35, 35),
		ElementBackgroundHover = Color3.fromRGB(40, 40, 40),
		SecondaryElementBackground = Color3.fromRGB(25, 25, 25),
		ElementStroke = Color3.fromRGB(50, 50, 50),
		SecondaryElementStroke = Color3.fromRGB(40, 40, 40),
		SliderBackground = Color3.fromRGB(50, 138, 220),
		SliderProgress = Color3.fromRGB(50, 138, 220),
		SliderStroke = Color3.fromRGB(58, 163, 255),
		ToggleBackground = Color3.fromRGB(30, 30, 30),
		ToggleEnabled = Color3.fromRGB(0, 146, 214),
		ToggleDisabled = Color3.fromRGB(100, 100, 100),
		ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
		ToggleDisabledStroke = Color3.fromRGB(125, 125, 125),
		ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
		ToggleDisabledOuterStroke = Color3.fromRGB(65, 65, 65),
		DropdownSelected = Color3.fromRGB(40, 40, 40),
		DropdownUnselected = Color3.fromRGB(30, 30, 30),
		InputBackground = Color3.fromRGB(30, 30, 30),
		InputStroke = Color3.fromRGB(65, 65, 65),
		PlaceholderColor = Color3.fromRGB(178, 178, 178),
		TooltipBackground = Color3.fromRGB(20, 20, 20),
		TooltipTextColor = Color3.fromRGB(240, 240, 240),
		TooltipStroke = Color3.fromRGB(55, 55, 55),
		ChartLine = Color3.fromRGB(70, 160, 255),
		ChartGrid = Color3.fromRGB(55, 55, 55),
		ChartFill = Color3.fromRGB(45, 110, 180),
		LogInfo = Color3.fromRGB(210, 220, 235),
		LogWarn = Color3.fromRGB(255, 210, 120),
		LogError = Color3.fromRGB(255, 120, 120),
		ConfirmArmed = Color3.fromRGB(180, 110, 40),
		SectionChevron = Color3.fromRGB(220, 220, 220)
	}
}

local function resolveThemePresets(ctx)
	if type(ctx) == "table" then
		local fromCtx = ctx.ThemePresetsModule or ctx.ThemePresets
		if type(fromCtx) == "table" and type(fromCtx.Default) == "table" then
			return fromCtx
		end
		local defaultThemeData = ctx.ThemeDefaultThemesModule or ctx.DefaultThemesModule
		if type(defaultThemeData) == "table" and type(defaultThemeData.Default) == "table" then
			return defaultThemeData
		end
	end

	if type(ThemeModule.Themes) == "table" and type(ThemeModule.Themes.Default) == "table" then
		return ThemeModule.Themes
	end

	return FALLBACK_THEME_PRESETS
end

local THEME_FALLBACK_KEYS = {
	TooltipBackground = {"SecondaryElementBackground", "ElementBackground", "Background"},
	TooltipTextColor = {"TextColor"},
	TooltipStroke = {"SecondaryElementStroke", "ElementStroke"},
	LoadingSpinner = {"SliderProgress", "ToggleEnabled"},
	LoadingTrack = {"SliderBackground", "SecondaryElementBackground"},
	LoadingBar = {"SliderProgress", "ToggleEnabled"},
	LoadingText = {"TextColor"},
	GlassTint = {"Topbar", "Background"},
	GlassStroke = {"ElementStroke", "TabStroke"},
	GlassAccent = {"SliderProgress", "ToggleEnabled"},
	ChartLine = {"SliderProgress", "SliderBackground"},
	ChartGrid = {"ElementStroke", "SecondaryElementStroke"},
	ChartFill = {"SliderBackground", "ChartLine"},
	LogInfo = {"TextColor"},
	LogWarn = {"SliderStroke", "SliderProgress"},
	LogError = {"ToggleEnabled", "SliderStroke"},
	ConfirmArmed = {"ToggleEnabled", "SliderProgress"},
	SectionChevron = {"TextColor", "TabTextColor"}
}

local function cloneThemeTable(theme)
	local out = {}
	if type(theme) ~= "table" then
		return out
	end
	for key, value in pairs(theme) do
		out[key] = value
	end
	return out
end

local function resolveThemeWithFallback(theme)
	local defaultTheme = ThemeModule.Themes.Default or {}
	local resolved = cloneThemeTable(theme)

	for key, fallbackChain in pairs(THEME_FALLBACK_KEYS) do
		if resolved[key] == nil then
			local fallbackValue = nil
			if type(fallbackChain) == "table" then
				for _, fallbackKey in ipairs(fallbackChain) do
					if resolved[fallbackKey] ~= nil then
						fallbackValue = resolved[fallbackKey]
						break
					end
					if defaultTheme[fallbackKey] ~= nil then
						fallbackValue = defaultTheme[fallbackKey]
						break
					end
				end
			end
			if fallbackValue == nil then
				fallbackValue = defaultTheme[key]
			end
			if fallbackValue ~= nil then
				resolved[key] = fallbackValue
			end
		end
	end

	for key, defaultValue in pairs(defaultTheme) do
		if resolved[key] == nil then
			resolved[key] = defaultValue
		end
	end

	return resolved
end

-- Initialize module with dependencies
function ThemeModule.init(ctx)
	local self = {}
	ctx = type(ctx) == "table" and ctx or {}

	ThemeModule.Themes = resolveThemePresets(ctx)

	-- Store dependencies from context
	self.Rayfield = ctx.Rayfield
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.Elements = ctx.Elements
	self.Notifications = ctx.Notifications
	self.Icons = ctx.Icons

	-- Current selected theme
	self.SelectedTheme = resolveThemeWithFallback(ThemeModule.Themes.Default)

	-- Reactive Theme System
	local ThemeValues = Instance.new("Folder")
	ThemeValues.Name = "ThemeValues"
	ThemeValues.Parent = self.Main

	local activeBindings = setmetatable({}, {__mode = "k"}) -- [object] = { [property] = record }
	local objectWatchers = setmetatable({}, {__mode = "k"}) -- [object] = { destroyConn?, ancestryConn? }
	local values = {}

	local function disconnectConnection(connection)
		if connection and typeof(connection) == "RBXScriptConnection" and connection.Connected then
			connection:Disconnect()
		end
	end

	local function cleanupObjectBindings(object)
		local bindingMap = activeBindings[object]
		if bindingMap then
			for _, record in pairs(bindingMap) do
				disconnectConnection(record.connection)
			end
			activeBindings[object] = nil
		end

		local watcher = objectWatchers[object]
		if watcher then
			disconnectConnection(watcher.destroying)
			disconnectConnection(watcher.ancestry)
			objectWatchers[object] = nil
		end
	end

	local function ensureObjectWatcher(object)
		if not object or objectWatchers[object] then
			return
		end

		local watcher = {}
		local okDestroying, destroyingSignal = pcall(function()
			return object.Destroying
		end)
		if okDestroying and destroyingSignal and destroyingSignal.Connect then
			watcher.destroying = destroyingSignal:Connect(function()
				cleanupObjectBindings(object)
			end)
		else
			watcher.ancestry = object.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					cleanupObjectBindings(object)
				end
			end)
		end

		objectWatchers[object] = watcher
	end

	local function unbindTheme(object, property)
		if not object then
			return
		end

		local bindingMap = activeBindings[object]
		if not bindingMap then
			return
		end

		if property then
			local record = bindingMap[property]
			if record then
				disconnectConnection(record.connection)
				bindingMap[property] = nil
			end
			if next(bindingMap) == nil then
				cleanupObjectBindings(object)
			end
			return
		end

		cleanupObjectBindings(object)
	end

	-- Initialize ValueObjects for all theme properties
	for key, value in pairs(ThemeModule.Themes.Default) do
		local colorValue = Instance.new("Color3Value")
		colorValue.Name = key
		colorValue.Value = value
		colorValue.Parent = ThemeValues
		values[key] = colorValue
	end

	-- Helper to bind an object's property to a theme color
	function self.bindTheme(object, property, themeKey)
		if not object then
			return
		end

		unbindTheme(object, property)

		local valueObj = values[themeKey]
		if not valueObj then
			-- During teardown/reload, values table can be cleared before late bind calls.
			-- Skip noisy warnings when the key itself is valid in theme schema.
			if ThemeModule.Themes.Default and ThemeModule.Themes.Default[themeKey] ~= nil then
				return
			end
			warn("Rayfield | Theme key not found: " .. tostring(themeKey))
			return
		end

		-- Set initial value
		local ok = pcall(function()
			object[property] = valueObj.Value
		end)
		if not ok then
			return
		end

		-- Listen for changes
		local connection = valueObj.Changed:Connect(function(newColor)
			pcall(function()
				object[property] = newColor
			end)
		end)

		activeBindings[object] = activeBindings[object] or {}
		activeBindings[object][property] = {
			connection = connection,
			themeKey = themeKey
		}
		ensureObjectWatcher(object)

		return connection
	end

	function self.unbindTheme(object, property)
		unbindTheme(object, property)
	end

	function self.cleanupObjectBindings(object)
		cleanupObjectBindings(object)
	end

	function self.GetBindingStats()
		local objectsBound = 0
		local propertiesBound = 0
		for _, bindingMap in pairs(activeBindings) do
			if type(bindingMap) == "table" and next(bindingMap) ~= nil then
				objectsBound = objectsBound + 1
				for _ in pairs(bindingMap) do
					propertiesBound = propertiesBound + 1
				end
			end
		end
		return {
			objectsBound = objectsBound,
			propertiesBound = propertiesBound
		}
	end

	-- Get icon from Lucide icon library
	function self.getIcon(name)
		if not self.Icons then
			warn("Lucide Icons: Cannot use icons as icons library is not loaded")
			return
		end
		name = string.match(string.lower(name), "^%s*(.*)%s*$")
		local sizedicons = self.Icons['48px']
		local r = sizedicons[name]
		if not r then
			error("Lucide Icons: Failed to find icon by the name of \"" .. name .. "\"", 2)
		end

		local rirs = r[2]
		local riro = r[3]

		return {
			id = r[1],
			imageRectSize = Vector2.new(rirs[1], rirs[2]),
			imageRectOffset = Vector2.new(riro[1], riro[2])
		}
	end

	-- Change theme function
	function self.ChangeTheme(Theme)
		local selected = nil
		if typeof(Theme) == 'string' then
			selected = ThemeModule.Themes[Theme]
		elseif typeof(Theme) == 'table' then
			selected = Theme
		end

		if not selected then return end

		self.SelectedTheme = resolveThemeWithFallback(selected)

		-- Update all ValueObjects - this triggers listeners in all elements
		for key, value in pairs(self.SelectedTheme) do
			if values[key] then
				values[key].Value = value
			end
		end

		-- Special case for search which isn't fully reactive yet or has complex mapping
		if self.Main:FindFirstChild('Notice') then
			self.Main.Notice.BackgroundColor3 = self.SelectedTheme.Background
		end
	end

	-- Cleanup function to prevent memory leaks on Rayfield:Destroy() + reload
	function self.cleanup()
		for object in pairs(activeBindings) do
			cleanupObjectBindings(object)
		end
		for object, watcher in pairs(objectWatchers) do
			disconnectConnection(watcher.destroying)
			disconnectConnection(watcher.ancestry)
			objectWatchers[object] = nil
		end

		-- Destroy the ThemeValues folder
		if ThemeValues and ThemeValues.Parent then
			ThemeValues:Destroy()
		end
		table.clear(values)
	end

	return self
end

return ThemeModule
