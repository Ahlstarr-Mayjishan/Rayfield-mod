--[[
	Rayfield Element Expansion regression
	Validates Element Expansion Pack v1 APIs and basic runtime behavior.

	Usage:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/tests/regression/test-element-expansion-pack.lua"))()
]]

local BASE_URL = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local function assertTrue(condition, message)
	if not condition then
		error(message or "assertTrue failed")
	end
end

local function compileChunk(source)
	local compileString = loadstring or load
	if not compileString then
		error("No Lua compiler function available (loadstring/load)")
	end
	local fn, err = compileString(source)
	if not fn then
		error("compile failed: " .. tostring(err))
	end
	return fn
end

local function loadRemote(url)
	local source = game:HttpGet(url)
	source = source:gsub("^\239\187\191", "")
	source = source:gsub("^\0+", "")
	return compileChunk(source)()
end

if type(_G.__RayfieldApiModuleCache) == "table" then
	table.clear(_G.__RayfieldApiModuleCache)
end
if type(_G.RayfieldCache) == "table" then
	table.clear(_G.RayfieldCache)
end
_G.Rayfield = nil
_G.RayfieldUI = nil

local Rayfield = loadRemote(BASE_URL .. "Main%20loader/rayfield-modified.lua")
assertTrue(type(Rayfield) == "table", "Rayfield load failed")

local Window = Rayfield:CreateWindow({
	Name = "Element Expansion Regression",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false }
})
assertTrue(type(Window) == "table", "CreateWindow failed")

local Tab = Window:CreateTab("Element Expansion", 4483362458)
assertTrue(type(Tab) == "table", "CreateTab failed")

assertTrue(type(Tab.CreateChart) == "function", "CreateChart missing")
assertTrue(type(Tab.CreateLogConsole) == "function", "CreateLogConsole missing")
assertTrue(type(Tab.CreateNumberStepper) == "function", "CreateNumberStepper missing")
assertTrue(type(Tab.CreateConfirmButton) == "function", "CreateConfirmButton missing")
assertTrue(type(Tab.CreateCollapsibleSection) == "function", "CreateCollapsibleSection missing")
assertTrue(type(Tab.CreateGallery) == "function", "CreateGallery missing")
assertTrue(type(Tab.CreateImage) == "function", "CreateImage missing")

local dropdown = Tab:CreateDropdown({
	Name = "Search Dropdown",
	Options = {"Alpha", "Beta", "Gamma"},
	SearchEnabled = true,
	CurrentOption = {"Alpha"},
	MultipleOptions = false,
	Callback = function() end
})
assertTrue(type(dropdown.SetSearchQuery) == "function", "Dropdown:SetSearchQuery missing")
assertTrue(type(dropdown.GetSearchQuery) == "function", "Dropdown:GetSearchQuery missing")
assertTrue(type(dropdown.ClearSearch) == "function", "Dropdown:ClearSearch missing")
dropdown:SetSearchQuery("ga")
assertTrue(dropdown:GetSearchQuery() == "ga", "Dropdown search query mismatch")
dropdown:ClearSearch()

local section = Tab:CreateCollapsibleSection({
	Name = "Advanced",
	Id = "advanced",
	Collapsed = false
})
assertTrue(type(section.Collapse) == "function", "CollapsibleSection:Collapse missing")
assertTrue(type(section.Expand) == "function", "CollapsibleSection:Expand missing")
assertTrue(type(section.Toggle) == "function", "CollapsibleSection:Toggle missing")

local stepper = Tab:CreateNumberStepper({
	Name = "Precision",
	CurrentValue = 1.25,
	Step = 0.01,
	Precision = 2,
	ParentSection = section,
	Callback = function() end
})
assertTrue(type(stepper.Get) == "function", "NumberStepper:Get missing")
assertTrue(type(stepper.Increment) == "function", "NumberStepper:Increment missing")
stepper:Increment()

local confirmButton = Tab:CreateConfirmButton({
	Name = "Danger Action",
	ConfirmMode = "either",
	Callback = function() end
})
assertTrue(type(confirmButton.SetMode) == "function", "ConfirmButton:SetMode missing")
assertTrue(type(confirmButton.SetHoldDuration) == "function", "ConfirmButton:SetHoldDuration missing")
assertTrue(type(confirmButton.SetDoubleWindow) == "function", "ConfirmButton:SetDoubleWindow missing")
confirmButton:SetMode("double")

local gallery = Tab:CreateGallery({
	Name = "Gallery",
	SelectionMode = "multi",
	Items = {
		{id = "a", name = "Alpha"},
		{id = "b", name = "Beta"}
	},
	Callback = function() end
})
assertTrue(type(gallery.SetItems) == "function", "Gallery:SetItems missing")
assertTrue(type(gallery.GetSelection) == "function", "Gallery:GetSelection missing")
gallery:SetSelection({"a"})

local image = Tab:CreateImage({
	Name = "Preview",
	Source = "rbxassetid://4483362458",
	Caption = "Sample"
})
assertTrue(type(image.SetSource) == "function", "Image:SetSource missing")
assertTrue(type(image.SetFitMode) == "function", "Image:SetFitMode missing")
assertTrue(type(image.SetCaption) == "function", "Image:SetCaption missing")
image:SetFitMode("fit")

local chart = Tab:CreateChart({
	Name = "Chart",
	MaxPoints = 32,
	UpdateHz = 10,
	Callback = function() end
})
assertTrue(type(chart.AddPoint) == "function", "Chart:AddPoint missing")
assertTrue(type(chart.SetData) == "function", "Chart:SetData missing")
assertTrue(type(chart.GetData) == "function", "Chart:GetData missing")
assertTrue(type(chart.Zoom) == "function", "Chart:Zoom missing")
assertTrue(type(chart.Pan) == "function", "Chart:Pan missing")
chart:AddPoint(10)
chart:AddPoint(12)
chart:Zoom(1.1)

local logConsole = Tab:CreateLogConsole({
	Name = "Logs",
	CaptureMode = "manual"
})
assertTrue(type(logConsole.Log) == "function", "LogConsole:Log missing")
assertTrue(type(logConsole.SetCaptureMode) == "function", "LogConsole:SetCaptureMode missing")
assertTrue(type(logConsole.GetEntries) == "function", "LogConsole:GetEntries missing")
logConsole:Info("hello")
logConsole:SetCaptureMode("both")

local okTooltip = select(1, stepper:SetTooltip("Tooltip text"))
assertTrue(okTooltip == true, "Element:SetTooltip failed")
assertTrue(type(stepper.ClearTooltip) == "function", "Element:ClearTooltip missing")
stepper:ClearTooltip()

print("Element Expansion regression: PASS")

return {
	status = "PASS"
}
