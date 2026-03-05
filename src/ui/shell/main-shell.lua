local MainShell = {}

function MainShell.applyReactiveTheme(options)
	options = type(options) == "table" and options or {}
	local main = options.Main
	local topbar = options.Topbar
	local bindTheme = options.bindTheme
	if type(bindTheme) ~= "function" or not main or not topbar then
		return false
	end

	bindTheme(main, "BackgroundColor3", "Background")

	-- Ensure Main container has rounded corners (UICorner)
	if main and main:IsA("GuiObject") then
		local mainCorner = main:FindFirstChildOfClass("UICorner")
		if not mainCorner then
			local newCorner = Instance.new("UICorner")
			newCorner.Name = "MainCorner"
			newCorner.CornerRadius = UDim.new(0, 12)
			newCorner.Parent = main
		end
	end

	bindTheme(topbar, "BackgroundColor3", "Topbar")

	local cornerRepair = topbar:FindFirstChild("CornerRepair")
	if cornerRepair then
		bindTheme(cornerRepair, "BackgroundColor3", "Topbar")
	end

	local shadow = main:FindFirstChild("Shadow")
	if shadow and shadow:FindFirstChild("Image") then
		bindTheme(shadow.Image, "ImageColor3", "Shadow")
	end

	local changeSizeButton = topbar:FindFirstChild("ChangeSize")
	if changeSizeButton then
		bindTheme(changeSizeButton, "ImageColor3", "TextColor")
	end
	local hideButton = topbar:FindFirstChild("Hide")
	if hideButton then
		bindTheme(hideButton, "ImageColor3", "TextColor")
	end
	local searchButton = topbar:FindFirstChild("Search")
	if searchButton then
		bindTheme(searchButton, "ImageColor3", "TextColor")
	end
	local settingsButton = topbar:FindFirstChild("Settings")
	if settingsButton then
		bindTheme(settingsButton, "ImageColor3", "TextColor")
		local divider = topbar:FindFirstChild("Divider")
		if divider then
			bindTheme(divider, "BackgroundColor3", "ElementStroke")
		end
	end

	local searchFrame = main:FindFirstChild("Search")
	if searchFrame then
		bindTheme(searchFrame, "BackgroundColor3", "TextColor")
		local searchShadow = searchFrame:FindFirstChild("Shadow")
		if searchShadow then
			bindTheme(searchShadow, "ImageColor3", "TextColor")
		end
		local searchIcon = searchFrame:FindFirstChild("Search")
		if searchIcon then
			bindTheme(searchIcon, "ImageColor3", "TextColor")
		end
		local searchInput = searchFrame:FindFirstChild("Input")
		if searchInput then
			bindTheme(searchInput, "PlaceholderColor3", "TextColor")
		end
		local searchStroke = searchFrame:FindFirstChild("UIStroke")
		if searchStroke then
			bindTheme(searchStroke, "Color", "SecondaryElementStroke")
		end
	end

	return true
end

return MainShell
