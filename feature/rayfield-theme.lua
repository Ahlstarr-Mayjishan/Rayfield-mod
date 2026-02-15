--[[
	Rayfield Theme System Module
	Extracted from rayfield-modified.lua
	
	This module handles:
	- Theme definitions (Default, Ocean, AmberGlow, Light, Amethyst, Green, Bloom, DarkBlue, Serenity)
	- Theme switching functionality
	- Icon system integration
]]

local ThemeModule = {}

-- Theme Definitions
ThemeModule.Themes = {
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
		PlaceholderColor = Color3.fromRGB(178, 178, 178)
	},

	Ocean = {
		TextColor = Color3.fromRGB(230, 240, 240),

		Background = Color3.fromRGB(20, 30, 30),
		Topbar = Color3.fromRGB(25, 40, 40),
		Shadow = Color3.fromRGB(15, 20, 20),

		NotificationBackground = Color3.fromRGB(25, 35, 35),
		NotificationActionsBackground = Color3.fromRGB(230, 240, 240),

		TabBackground = Color3.fromRGB(40, 60, 60),
		TabStroke = Color3.fromRGB(50, 70, 70),
		TabBackgroundSelected = Color3.fromRGB(100, 180, 180),
		TabTextColor = Color3.fromRGB(210, 230, 230),
		SelectedTabTextColor = Color3.fromRGB(20, 50, 50),

		ElementBackground = Color3.fromRGB(30, 50, 50),
		ElementBackgroundHover = Color3.fromRGB(40, 60, 60),
		SecondaryElementBackground = Color3.fromRGB(30, 45, 45),
		ElementStroke = Color3.fromRGB(45, 70, 70),
		SecondaryElementStroke = Color3.fromRGB(40, 65, 65),

		SliderBackground = Color3.fromRGB(0, 110, 110),
		SliderProgress = Color3.fromRGB(0, 140, 140),
		SliderStroke = Color3.fromRGB(0, 160, 160),

		ToggleBackground = Color3.fromRGB(30, 50, 50),
		ToggleEnabled = Color3.fromRGB(0, 130, 130),
		ToggleDisabled = Color3.fromRGB(70, 90, 90),
		ToggleEnabledStroke = Color3.fromRGB(0, 160, 160),
		ToggleDisabledStroke = Color3.fromRGB(85, 105, 105),
		ToggleEnabledOuterStroke = Color3.fromRGB(50, 100, 100),
		ToggleDisabledOuterStroke = Color3.fromRGB(45, 65, 65),

		DropdownSelected = Color3.fromRGB(30, 60, 60),
		DropdownUnselected = Color3.fromRGB(25, 40, 40),

		InputBackground = Color3.fromRGB(30, 50, 50),
		InputStroke = Color3.fromRGB(50, 70, 70),
		PlaceholderColor = Color3.fromRGB(140, 160, 160)
	},

	AmberGlow = {
		TextColor = Color3.fromRGB(255, 245, 230),

		Background = Color3.fromRGB(45, 30, 20),
		Topbar = Color3.fromRGB(55, 40, 25),
		Shadow = Color3.fromRGB(35, 25, 15),

		NotificationBackground = Color3.fromRGB(50, 35, 25),
		NotificationActionsBackground = Color3.fromRGB(245, 230, 215),

		TabBackground = Color3.fromRGB(75, 50, 35),
		TabStroke = Color3.fromRGB(90, 60, 45),
		TabBackgroundSelected = Color3.fromRGB(230, 180, 100),
		TabTextColor = Color3.fromRGB(250, 220, 200),
		SelectedTabTextColor = Color3.fromRGB(50, 30, 10),

		ElementBackground = Color3.fromRGB(60, 45, 35),
		ElementBackgroundHover = Color3.fromRGB(70, 50, 40),
		SecondaryElementBackground = Color3.fromRGB(55, 40, 30),
		ElementStroke = Color3.fromRGB(85, 60, 45),
		SecondaryElementStroke = Color3.fromRGB(75, 50, 35),

		SliderBackground = Color3.fromRGB(220, 130, 60),
		SliderProgress = Color3.fromRGB(250, 150, 75),
		SliderStroke = Color3.fromRGB(255, 170, 85),

		ToggleBackground = Color3.fromRGB(55, 40, 30),
		ToggleEnabled = Color3.fromRGB(240, 130, 30),
		ToggleDisabled = Color3.fromRGB(90, 70, 60),
		ToggleEnabledStroke = Color3.fromRGB(255, 160, 50),
		ToggleDisabledStroke = Color3.fromRGB(110, 85, 75),
		ToggleEnabledOuterStroke = Color3.fromRGB(200, 100, 50),
		ToggleDisabledOuterStroke = Color3.fromRGB(75, 60, 55),

		DropdownSelected = Color3.fromRGB(70, 50, 40),
		DropdownUnselected = Color3.fromRGB(55, 40, 30),

		InputBackground = Color3.fromRGB(60, 45, 35),
		InputStroke = Color3.fromRGB(90, 65, 50),
		PlaceholderColor = Color3.fromRGB(190, 150, 130)
	},
}

	Light = {
		TextColor = Color3.fromRGB(40, 40, 40),

		Background = Color3.fromRGB(245, 245, 245),
		Topbar = Color3.fromRGB(230, 230, 230),
		Shadow = Color3.fromRGB(200, 200, 200),

		NotificationBackground = Color3.fromRGB(250, 250, 250),
		NotificationActionsBackground = Color3.fromRGB(240, 240, 240),

		TabBackground = Color3.fromRGB(235, 235, 235),
		TabStroke = Color3.fromRGB(215, 215, 215),
		TabBackgroundSelected = Color3.fromRGB(255, 255, 255),
		TabTextColor = Color3.fromRGB(80, 80, 80),
		SelectedTabTextColor = Color3.fromRGB(0, 0, 0),

		ElementBackground = Color3.fromRGB(240, 240, 240),
		ElementBackgroundHover = Color3.fromRGB(225, 225, 225),
		SecondaryElementBackground = Color3.fromRGB(235, 235, 235),
		ElementStroke = Color3.fromRGB(210, 210, 210),
		SecondaryElementStroke = Color3.fromRGB(210, 210, 210),

		SliderBackground = Color3.fromRGB(150, 180, 220),
		SliderProgress = Color3.fromRGB(100, 150, 200),
		SliderStroke = Color3.fromRGB(120, 170, 220),

		ToggleBackground = Color3.fromRGB(220, 220, 220),
		ToggleEnabled = Color3.fromRGB(0, 146, 214),
		ToggleDisabled = Color3.fromRGB(150, 150, 150),
		ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
		ToggleDisabledStroke = Color3.fromRGB(170, 170, 170),
		ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
		ToggleDisabledOuterStroke = Color3.fromRGB(180, 180, 180),

		DropdownSelected = Color3.fromRGB(230, 230, 230),
		DropdownUnselected = Color3.fromRGB(220, 220, 220),

		InputBackground = Color3.fromRGB(240, 240, 240),
		InputStroke = Color3.fromRGB(180, 180, 180),
		PlaceholderColor = Color3.fromRGB(140, 140, 140)
	},

	Amethyst = {
		TextColor = Color3.fromRGB(240, 240, 240),

		Background = Color3.fromRGB(30, 20, 40),
		Topbar = Color3.fromRGB(40, 25, 50),
		Shadow = Color3.fromRGB(20, 15, 30),

		NotificationBackground = Color3.fromRGB(35, 20, 40),
		NotificationActionsBackground = Color3.fromRGB(240, 240, 250),

		TabBackground = Color3.fromRGB(60, 40, 80),
		TabStroke = Color3.fromRGB(70, 45, 90),
		TabBackgroundSelected = Color3.fromRGB(180, 140, 200),
		TabTextColor = Color3.fromRGB(230, 230, 240),
		SelectedTabTextColor = Color3.fromRGB(50, 20, 50),

		ElementBackground = Color3.fromRGB(45, 30, 60),
		ElementBackgroundHover = Color3.fromRGB(50, 35, 70),
		SecondaryElementBackground = Color3.fromRGB(40, 30, 55),
		ElementStroke = Color3.fromRGB(70, 50, 85),
		SecondaryElementStroke = Color3.fromRGB(65, 45, 80),

		SliderBackground = Color3.fromRGB(100, 60, 150),
		SliderProgress = Color3.fromRGB(130, 80, 180),
		SliderStroke = Color3.fromRGB(150, 100, 200),

		ToggleBackground = Color3.fromRGB(45, 30, 55),
		ToggleEnabled = Color3.fromRGB(120, 60, 150),
		ToggleDisabled = Color3.fromRGB(94, 47, 117),
		ToggleEnabledStroke = Color3.fromRGB(140, 80, 170),
		ToggleDisabledStroke = Color3.fromRGB(124, 71, 150),
		ToggleEnabledOuterStroke = Color3.fromRGB(90, 40, 120),
		ToggleDisabledOuterStroke = Color3.fromRGB(80, 50, 110),

		DropdownSelected = Color3.fromRGB(50, 35, 70),
		DropdownUnselected = Color3.fromRGB(35, 25, 50),

		InputBackground = Color3.fromRGB(45, 30, 60),
		InputStroke = Color3.fromRGB(80, 50, 110),
		PlaceholderColor = Color3.fromRGB(178, 150, 200)
	},

	Green = {
		TextColor = Color3.fromRGB(30, 60, 30),

		Background = Color3.fromRGB(235, 245, 235),
		Topbar = Color3.fromRGB(210, 230, 210),
		Shadow = Color3.fromRGB(200, 220, 200),

		NotificationBackground = Color3.fromRGB(240, 250, 240),
		NotificationActionsBackground = Color3.fromRGB(220, 235, 220),

		TabBackground = Color3.fromRGB(215, 235, 215),
		TabStroke = Color3.fromRGB(190, 210, 190),
		TabBackgroundSelected = Color3.fromRGB(245, 255, 245),
		TabTextColor = Color3.fromRGB(50, 80, 50),
		SelectedTabTextColor = Color3.fromRGB(20, 60, 20),

		ElementBackground = Color3.fromRGB(225, 240, 225),
		ElementBackgroundHover = Color3.fromRGB(210, 225, 210),
		SecondaryElementBackground = Color3.fromRGB(235, 245, 235),
		ElementStroke = Color3.fromRGB(180, 200, 180),
		SecondaryElementStroke = Color3.fromRGB(180, 200, 180),

		SliderBackground = Color3.fromRGB(90, 160, 90),
		SliderProgress = Color3.fromRGB(70, 130, 70),
		SliderStroke = Color3.fromRGB(100, 180, 100),

		ToggleBackground = Color3.fromRGB(215, 235, 215),
		ToggleEnabled = Color3.fromRGB(60, 130, 60),
		ToggleDisabled = Color3.fromRGB(150, 175, 150),
		ToggleEnabledStroke = Color3.fromRGB(80, 150, 80),
		ToggleDisabledStroke = Color3.fromRGB(130, 150, 130),
		ToggleEnabledOuterStroke = Color3.fromRGB(100, 160, 100),
		ToggleDisabledOuterStroke = Color3.fromRGB(160, 180, 160),

		DropdownSelected = Color3.fromRGB(225, 240, 225),
		DropdownUnselected = Color3.fromRGB(210, 225, 210),

		InputBackground = Color3.fromRGB(235, 245, 235),
		InputStroke = Color3.fromRGB(180, 200, 180),
		PlaceholderColor = Color3.fromRGB(120, 140, 120)
	},

	Bloom = {
		TextColor = Color3.fromRGB(60, 40, 50),

		Background = Color3.fromRGB(255, 240, 245),
		Topbar = Color3.fromRGB(250, 220, 225),
		Shadow = Color3.fromRGB(230, 190, 195),

		NotificationBackground = Color3.fromRGB(255, 235, 240),
		NotificationActionsBackground = Color3.fromRGB(245, 215, 225),

		TabBackground = Color3.fromRGB(240, 210, 220),
		TabStroke = Color3.fromRGB(230, 200, 210),
		TabBackgroundSelected = Color3.fromRGB(255, 225, 235),
		TabTextColor = Color3.fromRGB(80, 40, 60),
		SelectedTabTextColor = Color3.fromRGB(50, 30, 50),

		ElementBackground = Color3.fromRGB(255, 235, 240),
		ElementBackgroundHover = Color3.fromRGB(245, 220, 230),
		SecondaryElementBackground = Color3.fromRGB(255, 235, 240),
		ElementStroke = Color3.fromRGB(230, 200, 210),
		SecondaryElementStroke = Color3.fromRGB(230, 200, 210),

		SliderBackground = Color3.fromRGB(240, 130, 160),
		SliderProgress = Color3.fromRGB(250, 160, 180),
		SliderStroke = Color3.fromRGB(255, 180, 200),

		ToggleBackground = Color3.fromRGB(240, 210, 220),
		ToggleEnabled = Color3.fromRGB(255, 140, 170),
		ToggleDisabled = Color3.fromRGB(200, 180, 185),
		ToggleEnabledStroke = Color3.fromRGB(250, 160, 190),
		ToggleDisabledStroke = Color3.fromRGB(210, 180, 190),
		ToggleEnabledOuterStroke = Color3.fromRGB(220, 160, 180),
		ToggleDisabledOuterStroke = Color3.fromRGB(190, 170, 180),

		DropdownSelected = Color3.fromRGB(250, 220, 225),
		DropdownUnselected = Color3.fromRGB(240, 210, 220),

		InputBackground = Color3.fromRGB(255, 235, 240),
		InputStroke = Color3.fromRGB(220, 190, 200),
		PlaceholderColor = Color3.fromRGB(170, 130, 140)
	},

	DarkBlue = {
		TextColor = Color3.fromRGB(230, 230, 230),

		Background = Color3.fromRGB(20, 25, 30),
		Topbar = Color3.fromRGB(30, 35, 40),
		Shadow = Color3.fromRGB(15, 20, 25),

		NotificationBackground = Color3.fromRGB(25, 30, 35),
		NotificationActionsBackground = Color3.fromRGB(45, 50, 55),

		TabBackground = Color3.fromRGB(35, 40, 45),
		TabStroke = Color3.fromRGB(45, 50, 60),
		TabBackgroundSelected = Color3.fromRGB(40, 70, 100),
		TabTextColor = Color3.fromRGB(200, 200, 200),
		SelectedTabTextColor = Color3.fromRGB(255, 255, 255),

		ElementBackground = Color3.fromRGB(30, 35, 40),
		ElementBackgroundHover = Color3.fromRGB(40, 45, 50),
		SecondaryElementBackground = Color3.fromRGB(35, 40, 45),
		ElementStroke = Color3.fromRGB(45, 50, 60),
		SecondaryElementStroke = Color3.fromRGB(40, 45, 55),

		SliderBackground = Color3.fromRGB(0, 90, 180),
		SliderProgress = Color3.fromRGB(0, 120, 210),
		SliderStroke = Color3.fromRGB(0, 150, 240),

		ToggleBackground = Color3.fromRGB(35, 40, 45),
		ToggleEnabled = Color3.fromRGB(0, 120, 210),
		ToggleDisabled = Color3.fromRGB(70, 70, 80),
		ToggleEnabledStroke = Color3.fromRGB(0, 150, 240),
		ToggleDisabledStroke = Color3.fromRGB(75, 75, 85),
		ToggleEnabledOuterStroke = Color3.fromRGB(20, 100, 180),
		ToggleDisabledOuterStroke = Color3.fromRGB(55, 55, 65),

		DropdownSelected = Color3.fromRGB(30, 70, 90),
		DropdownUnselected = Color3.fromRGB(25, 30, 35),

		InputBackground = Color3.fromRGB(25, 30, 35),
		InputStroke = Color3.fromRGB(45, 50, 60),
		PlaceholderColor = Color3.fromRGB(150, 150, 160)
	},

	Serenity = {
		TextColor = Color3.fromRGB(50, 55, 60),
		Background = Color3.fromRGB(240, 245, 250),
		Topbar = Color3.fromRGB(215, 225, 235),
		Shadow = Color3.fromRGB(200, 210, 220),

		NotificationBackground = Color3.fromRGB(210, 220, 230),
		NotificationActionsBackground = Color3.fromRGB(225, 230, 240),

		TabBackground = Color3.fromRGB(200, 210, 220),
		TabStroke = Color3.fromRGB(180, 190, 200),
		TabBackgroundSelected = Color3.fromRGB(175, 185, 200),
		TabTextColor = Color3.fromRGB(50, 55, 60),
		SelectedTabTextColor = Color3.fromRGB(30, 35, 40),

		ElementBackground = Color3.fromRGB(210, 220, 230),
		ElementBackgroundHover = Color3.fromRGB(220, 230, 240),
		SecondaryElementBackground = Color3.fromRGB(200, 210, 220),
		ElementStroke = Color3.fromRGB(190, 200, 210),
		SecondaryElementStroke = Color3.fromRGB(180, 190, 200),

		SliderBackground = Color3.fromRGB(200, 220, 235),
		SliderProgress = Color3.fromRGB(70, 130, 180),
		SliderStroke = Color3.fromRGB(150, 180, 220),

		ToggleBackground = Color3.fromRGB(210, 220, 230),
		ToggleEnabled = Color3.fromRGB(70, 160, 210),
		ToggleDisabled = Color3.fromRGB(180, 180, 180),
		ToggleEnabledStroke = Color3.fromRGB(60, 150, 200),
		ToggleDisabledStroke = Color3.fromRGB(140, 140, 140),
		ToggleEnabledOuterStroke = Color3.fromRGB(100, 120, 140),
		ToggleDisabledOuterStroke = Color3.fromRGB(120, 120, 130),

		DropdownSelected = Color3.fromRGB(220, 230, 240),
		DropdownUnselected = Color3.fromRGB(200, 210, 220),

		InputBackground = Color3.fromRGB(220, 230, 240),
		InputStroke = Color3.fromRGB(180, 190, 200),
		PlaceholderColor = Color3.fromRGB(150, 150, 150)
	},
}

-- Initialize module with dependencies
function ThemeModule.init(ctx)
	local self = {}

	-- Store dependencies from context
	self.Rayfield = ctx.Rayfield
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.Elements = ctx.Elements
	self.Notifications = ctx.Notifications
	self.Icons = ctx.Icons

	-- Current selected theme
	self.SelectedTheme = ThemeModule.Themes.Default

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
		if typeof(Theme) == 'string' then
			self.SelectedTheme = ThemeModule.Themes[Theme]
		elseif typeof(Theme) == 'table' then
			self.SelectedTheme = Theme
		end

		self.Rayfield.Main.BackgroundColor3 = self.SelectedTheme.Background
		self.Rayfield.Main.Topbar.BackgroundColor3 = self.SelectedTheme.Topbar
		self.Rayfield.Main.Topbar.CornerRepair.BackgroundColor3 = self.SelectedTheme.Topbar
		self.Rayfield.Main.Shadow.Image.ImageColor3 = self.SelectedTheme.Shadow

		self.Rayfield.Main.Topbar.ChangeSize.ImageColor3 = self.SelectedTheme.TextColor
		self.Rayfield.Main.Topbar.Hide.ImageColor3 = self.SelectedTheme.TextColor
		self.Rayfield.Main.Topbar.Search.ImageColor3 = self.SelectedTheme.TextColor
		if self.Topbar:FindFirstChild('Settings') then
			self.Rayfield.Main.Topbar.Settings.ImageColor3 = self.SelectedTheme.TextColor
			self.Rayfield.Main.Topbar.Divider.BackgroundColor3 = self.SelectedTheme.ElementStroke
		end

		self.Main.Search.BackgroundColor3 = self.SelectedTheme.TextColor
		self.Main.Search.Shadow.ImageColor3 = self.SelectedTheme.TextColor
		self.Main.Search.Search.ImageColor3 = self.SelectedTheme.TextColor
		self.Main.Search.Input.PlaceholderColor3 = self.SelectedTheme.TextColor
		self.Main.Search.UIStroke.Color = self.SelectedTheme.SecondaryElementStroke

		if self.Main:FindFirstChild('Notice') then
			self.Main.Notice.BackgroundColor3 = self.SelectedTheme.Background
		end

		for _, text in ipairs(self.Rayfield:GetDescendants()) do
			if text.Parent.Parent ~= self.Notifications then
				if text:IsA('TextLabel') or text:IsA('TextBox') then
					text.TextColor3 = self.SelectedTheme.TextColor
				end
			end
		end

		for _, TabPage in ipairs(self.Elements:GetChildren()) do
			for _, Element in ipairs(TabPage:GetChildren()) do
				if Element.ClassName == "Frame" and Element.Name ~= "Placeholder" and Element.Name ~= "SectionSpacing" and Element.Name ~= "Divider" and Element.Name ~= "SectionTitle" and Element.Name ~= "SearchTitle-fsefsefesfsefesfesfThanks" then
					Element.BackgroundColor3 = self.SelectedTheme.ElementBackground
					Element.UIStroke.Color = self.SelectedTheme.ElementStroke
				end
			end
		end
	end

	return self
end

return ThemeModule

