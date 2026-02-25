local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local function compileChunk(source, label)
	if type(source) ~= "string" then
		error("Invalid Lua source for " .. tostring(label) .. ": " .. type(source))
	end
	source = source:gsub("^\239\187\191", "")
	source = source:gsub("^\0+", "")
	local chunk, err = compileString(source)
	if not chunk then
		error("Failed to compile " .. tostring(label) .. ": " .. tostring(err))
	end
	return chunk
end

local function fetchAndRun(url, label)
	local source = game:HttpGet(url)
	return compileChunk(source, label or url)()
end

local function firstOption(value)
	if type(value) == "table" then
		return tostring(value[1] or "")
	end
	return tostring(value or "")
end

local function sortedThemeNames(rayfield)
	local names = {}
	local seen = {}
	if type(rayfield) == "table" and type(rayfield.Theme) == "table" then
		for name in pairs(rayfield.Theme) do
			if type(name) == "string" and name ~= "" and not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end
	table.sort(names)
	if #names == 0 then
		names = { "Default" }
	end
	return names
end

local root = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local loaded = fetchAndRun(root .. "Main%20loader/rayfield-all-in-one.lua", "Main loader/rayfield-all-in-one.lua")

local UI = nil
if type(loaded) == "table" and loaded.Rayfield then
	UI = loaded
elseif type(loaded) == "table" and type(loaded.quickSetup) == "function" then
	UI = loaded.quickSetup({
		mode = "enhanced",
		errorThreshold = 5,
		rateLimit = 10,
		autoCleanup = true
	})
else
	error("All-in-one loader returned unexpected value: " .. type(loaded))
end

if type(UI) ~= "table" or type(UI.Rayfield) ~= "table" then
	error("All-in-one UI bootstrap failed: Rayfield not available")
end

local Rayfield = UI.Rayfield

local checkState = {
	pass = 0,
	fail = 0,
	logs = {}
}

local function report(pass, name, message)
	if pass then
		checkState.pass += 1
		table.insert(checkState.logs, "[PASS] " .. tostring(name))
	else
		checkState.fail += 1
		table.insert(checkState.logs, "[FAIL] " .. tostring(name) .. " -> " .. tostring(message or "unknown"))
	end
end

local function runCheck(name, checkFn)
	local ok, resultOrErr = pcall(checkFn)
	if not ok then
		report(false, name, resultOrErr)
		return false
	end

	if resultOrErr == false then
		report(false, name, "condition returned false")
		return false
	end

	report(true, name)
	return true
end

local runtimeState = {
	buttonClicks = 0,
	toggle = false,
	slider = 50,
	input = "",
	dropdown = "Alpha",
	keybind = "Q",
	color = Color3.fromRGB(255, 170, 0)
}

local settingsState = {
	uiPreset = "Comfort",
	transitionProfile = "Smooth",
	onboardingSuppressed = false,
	themeBase = "Default",
	themeAccent = Color3.fromRGB(0, 170, 255),
	importCode = "",
	lastExportCode = nil,
	statusPreview = 35,
	trackPreview = 35
}

do
	local okPreset, preset = pcall(Rayfield.GetUIPreset, Rayfield)
	if okPreset and type(preset) == "string" and preset ~= "" then
		settingsState.uiPreset = preset
	end
	local okTransition, transition = pcall(Rayfield.GetTransitionProfile, Rayfield)
	if okTransition and type(transition) == "string" and transition ~= "" then
		settingsState.transitionProfile = transition
	end
	local okSuppressed, suppressed = pcall(Rayfield.IsOnboardingSuppressed, Rayfield)
	if okSuppressed then
		settingsState.onboardingSuppressed = suppressed == true
	end
	local okThemeState, themeState = pcall(Rayfield.GetThemeStudioState, Rayfield)
	if okThemeState and type(themeState) == "table" and type(themeState.baseTheme) == "string" then
		settingsState.themeBase = themeState.baseTheme
	end
end

local window = Rayfield:CreateWindow({
	Name = "Rayfield AIO Elements + Settings Check",
	LoadingTitle = "Rayfield Mod",
	LoadingSubtitle = "All-in-One 3 Tabs (5:5 + Settings)",
	ConfigurationSaving = {
		Enabled = false
	},
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true
})

local tabA = window:CreateTab("Elements A", 4483362458)
local tabB = window:CreateTab("Elements B", 4483362458)
local tabSettings = window:CreateTab("Settings", 4483362458)

-- Tab A: 5 elements
local elButton = tabA:CreateButton({
	Name = "A1 Button",
	Callback = function()
		runtimeState.buttonClicks += 1
	end
})

local elToggle = tabA:CreateToggle({
	Name = "A2 Toggle",
	CurrentValue = false,
	Callback = function(value)
		runtimeState.toggle = value == true
	end
})

local elSlider = tabA:CreateSlider({
	Name = "A3 Slider",
	Range = {0, 100},
	Increment = 1,
	CurrentValue = 50,
	Callback = function(value)
		runtimeState.slider = tonumber(value) or 0
	end
})

local elInput = tabA:CreateInput({
	Name = "A4 Input",
	CurrentValue = "",
	PlaceholderText = "Type value",
	RemoveTextAfterFocusLost = false,
	Callback = function(text)
		runtimeState.input = tostring(text or "")
	end
})

local elDropdown = tabA:CreateDropdown({
	Name = "A5 Dropdown",
	Options = {"Alpha", "Beta", "Gamma"},
	CurrentOption = "Alpha",
	Callback = function(optionTable)
		if type(optionTable) == "table" and optionTable[1] then
			runtimeState.dropdown = tostring(optionTable[1])
		end
	end
})

-- Tab B: 5 elements
local elKeybind = tabB:CreateKeybind({
	Name = "B1 Keybind",
	CurrentKeybind = "Q",
	CallOnChange = true,
	Callback = function(binding)
		runtimeState.keybind = tostring(binding or "")
	end
})

local elColor = tabB:CreateColorPicker({
	Name = "B2 ColorPicker",
	Color = Color3.fromRGB(255, 170, 0),
	Callback = function(value)
		runtimeState.color = value
	end
})

local elLabel = tabB:CreateLabel("B3 Label")

local elParagraph = tabB:CreateParagraph({
	Title = "B4 Paragraph",
	Content = "Paragraph content"
})

local elSection = tabB:CreateSection("B5 Section")

-- Settings tab: custom UI + share code + all element families
local settingsLogConsole = nil
local function settingsLog(level, message)
	local safeLevel = tostring(level or "info")
	local safeMessage = tostring(message or "")
	print("[AIO-Settings][" .. safeLevel .. "] " .. safeMessage)

	if settingsLogConsole then
		if safeLevel == "warn" and type(settingsLogConsole.Warn) == "function" then
			settingsLogConsole:Warn(safeMessage)
		elseif safeLevel == "error" and type(settingsLogConsole.Error) == "function" then
			settingsLogConsole:Error(safeMessage)
		elseif type(settingsLogConsole.Info) == "function" then
			settingsLogConsole:Info(safeMessage)
		end
	end
end

tabSettings:CreateLabel("Settings Center: Custom UI + Share Code + Advanced Elements")
tabSettings:CreateParagraph({
	Title = "Purpose",
	Content = "Tab nay dung de custom UI, xuat/nhap share code va test logic cac element nang cao."
})
tabSettings:CreateDivider()

tabSettings:CreateSection("UI Customization")
local presetDropdown = tabSettings:CreateDropdown({
	Name = "UI Preset",
	Options = {"Comfort", "Compact", "Focus"},
	CurrentOption = settingsState.uiPreset,
	Callback = function(option)
		local selected = firstOption(option)
		if selected == "" then
			return
		end
		local okSet, status = Rayfield:SetUIPreset(selected)
		settingsLog(okSet and "info" or "error", "SetUIPreset(" .. selected .. ") => " .. tostring(status))
		if okSet then
			settingsState.uiPreset = selected
		end
	end
})

local transitionDropdown = tabSettings:CreateDropdown({
	Name = "Transition Profile",
	Options = {"Smooth", "Snappy", "Minimal", "Off"},
	CurrentOption = settingsState.transitionProfile,
	Callback = function(option)
		local selected = firstOption(option)
		if selected == "" then
			return
		end
		local okSet, status = Rayfield:SetTransitionProfile(selected)
		settingsLog(okSet and "info" or "error", "SetTransitionProfile(" .. selected .. ") => " .. tostring(status))
		if okSet then
			settingsState.transitionProfile = selected
		end
	end
})

local onboardingToggle = tabSettings:CreateToggle({
	Name = "Suppress Onboarding",
	CurrentValue = settingsState.onboardingSuppressed,
	Callback = function(value)
		local okSet, status = Rayfield:SetOnboardingSuppressed(value == true)
		settingsLog(okSet and "info" or "error", "SetOnboardingSuppressed(" .. tostring(value) .. ") => " .. tostring(status))
		if okSet then
			settingsState.onboardingSuppressed = value == true
		end
	end
})

local themeNames = sortedThemeNames(Rayfield)
local themeBaseDropdown = tabSettings:CreateDropdown({
	Name = "Theme Base",
	Options = themeNames,
	CurrentOption = settingsState.themeBase,
	Callback = function(option)
		local selected = firstOption(option)
		if selected == "" then
			return
		end
		settingsState.themeBase = selected
		local okTheme, status = Rayfield:ApplyThemeStudioTheme(selected)
		settingsLog(okTheme and "info" or "error", "ApplyThemeStudioTheme(" .. selected .. ") => " .. tostring(status))
	end
})

local themeAccentPicker = tabSettings:CreateColorPicker({
	Name = "Accent Color",
	Color = settingsState.themeAccent,
	Callback = function(value)
		settingsState.themeAccent = value
	end
})

tabSettings:CreateButton({
	Name = "Apply Accent To UI",
	Callback = function()
		local accent = settingsState.themeAccent
		local okTheme, status = Rayfield:ApplyThemeStudioTheme({
			SliderBackground = accent,
			SliderProgress = accent,
			SliderStroke = accent,
			ToggleEnabled = accent,
			ToggleEnabledStroke = accent,
			ToggleEnabledOuterStroke = accent,
			TabBackgroundSelected = accent,
			SelectedTabTextColor = Color3.fromRGB(20, 20, 20)
		})
		settingsLog(okTheme and "info" or "error", "ApplyThemeStudioTheme(custom) => " .. tostring(status))
	end
})

tabSettings:CreateButton({
	Name = "Replay Onboarding",
	Callback = function()
		local okShow, status = Rayfield:ShowOnboarding(true)
		settingsLog(okShow and "info" or "error", "ShowOnboarding(true) => " .. tostring(status))
	end
})

tabSettings:CreateButton({
	Name = "Reset Theme Studio",
	Callback = function()
		local okReset, status = Rayfield:ResetThemeStudio()
		settingsLog(okReset and "info" or "error", "ResetThemeStudio() => " .. tostring(status))
	end
})

tabSettings:CreateSection("Share Code / Export")
local importCodeInput = tabSettings:CreateInput({
	Name = "Import Code Buffer",
	CurrentValue = "",
	PlaceholderText = "RFSC1:....",
	RemoveTextAfterFocusLost = false,
	Callback = function(text)
		settingsState.importCode = tostring(text or "")
	end
})

tabSettings:CreateButton({
	Name = "Export Settings Code",
	Callback = function()
		local code, status = Rayfield:ExportSettings()
		if type(code) == "string" and code ~= "" then
			settingsState.lastExportCode = code
			settingsState.importCode = code
			importCodeInput:Set(code)
			settingsLog("info", "ExportSettings => " .. tostring(status) .. " (len=" .. tostring(#code) .. ")")
		else
			settingsLog("error", "ExportSettings failed => " .. tostring(status))
		end
	end
})

tabSettings:CreateButton({
	Name = "Import From Buffer",
	Callback = function()
		if settingsState.importCode == "" then
			settingsLog("warn", "Import buffer is empty.")
			return
		end
		local okImport, status = Rayfield:ImportCode(settingsState.importCode)
		settingsLog(okImport and "info" or "error", "ImportCode(buffer) => " .. tostring(status))
	end
})

tabSettings:CreateButton({
	Name = "Import Last Export",
	Callback = function()
		if type(settingsState.lastExportCode) ~= "string" or settingsState.lastExportCode == "" then
			settingsLog("warn", "No exported code cached yet.")
			return
		end
		local okImport, status = Rayfield:ImportCode(settingsState.lastExportCode)
		settingsLog(okImport and "info" or "error", "ImportCode(lastExport) => " .. tostring(status))
	end
})

tabSettings:CreateButton({
	Name = "Copy Share Code",
	Callback = function()
		local okCopy, status = Rayfield:CopyShareCode()
		settingsLog(okCopy and "info" or "error", "CopyShareCode => " .. tostring(status))
	end
})

tabSettings:CreateButton({
	Name = "Import Active Settings",
	Callback = function()
		local okImport, status = Rayfield:ImportSettings()
		settingsLog(okImport and "info" or "error", "ImportSettings => " .. tostring(status))
	end
})

tabSettings:CreateButton({
	Name = "Print Controls Snapshot",
	Callback = function()
		local controls = Rayfield:ListControls()
		settingsLog("info", "ListControls count = " .. tostring(type(controls) == "table" and #controls or 0))
	end
})

tabSettings:CreateDivider()
local advancedSection = tabSettings:CreateCollapsibleSection({
	Name = "Advanced Controls",
	Id = "settings-advanced-controls",
	Collapsed = false
})

local statusPreview = tabSettings:CreateStatusBar({
	Name = "Status Preview",
	Range = {0, 100},
	Increment = 1,
	CurrentValue = settingsState.statusPreview,
	TextFormatter = function(current, max, percent)
		return string.format("UI %.0f%% (%d/%d)", percent, current, max)
	end,
	Callback = function(value)
		settingsState.statusPreview = tonumber(value) or 0
	end,
	ParentSection = advancedSection
})

local trackPreview = tabSettings:CreateTrackBar({
	Name = "Track Preview",
	Range = {0, 100},
	Increment = 1,
	CurrentValue = settingsState.trackPreview,
	Callback = function(value)
		settingsState.trackPreview = tonumber(value) or 0
	end,
	ParentSection = advancedSection
})

local stepper = tabSettings:CreateNumberStepper({
	Name = "Value Stepper",
	CurrentValue = 35,
	Min = 0,
	Max = 100,
	Step = 1,
	Precision = 0,
	ParentSection = advancedSection,
	Callback = function(value)
		local numeric = tonumber(value) or 0
		if statusPreview and statusPreview.Set then
			statusPreview:Set(numeric)
		end
		if trackPreview and trackPreview.Set then
			trackPreview:Set(numeric)
		end
	end
})

local confirmReset = tabSettings:CreateConfirmButton({
	Name = "Confirm Reset Theme",
	ConfirmMode = "either",
	HoldDuration = 1.0,
	DoubleWindow = 0.4,
	Callback = function()
		local okReset, status = Rayfield:ResetThemeStudio()
		settingsLog(okReset and "info" or "error", "Confirm ResetThemeStudio => " .. tostring(status))
	end,
	ParentSection = advancedSection
})

local wrapperToggle = tabSettings:CreateToggleBind({
	Name = "ToggleBind Example",
	CurrentValue = false,
	Keybind = {
		CurrentKeybind = "LeftControl+1"
	},
	Callback = function(value)
		settingsLog("info", "ToggleBind => " .. tostring(value))
	end
})

local hotToggle = tabSettings:CreateHotToggle({
	Name = "HotToggle Example",
	CurrentValue = false,
	Keybind = {
		CurrentKeybind = "LeftControl+2"
	},
	Callback = function(value)
		settingsLog("info", "HotToggle => " .. tostring(value))
	end
})

local settingsImage = tabSettings:CreateImage({
	Name = "UI Preview Image",
	Source = "rbxassetid://4483362458",
	FitMode = "fill",
	Height = 110,
	Caption = "Rayfield Icon"
})

local settingsGallery = tabSettings:CreateGallery({
	Name = "Settings Gallery",
	SelectionMode = "multi",
	Columns = "auto",
	Items = {
		{id = "a", name = "Item A", image = "rbxassetid://4483362458"},
		{id = "b", name = "Item B", image = "rbxassetid://4483362458"},
		{id = "c", name = "Item C", image = "rbxassetid://4483362458"}
	},
	Callback = function(selection)
		local count = type(selection) == "table" and #selection or 0
		settingsLog("info", "Gallery selection count => " .. tostring(count))
	end
})

local settingsChart = tabSettings:CreateChart({
	Name = "Settings Chart",
	MaxPoints = 180,
	UpdateHz = 8,
	Preset = "fps",
	ShowAreaFill = true
})
settingsChart:AddPoint(35)
settingsChart:AddPoint(45)
settingsChart:AddPoint(55)

settingsLogConsole = tabSettings:CreateLogConsole({
	Name = "Settings Logs",
	CaptureMode = "manual",
	MaxEntries = 120,
	ShowTimestamp = true
})
settingsLog("info", "Settings tab initialized.")

-- Feature + logic checks
runCheck("All-in-one services ready", function()
	return type(UI.ErrorManager) == "table"
		and type(UI.GarbageCollector) == "table"
		and type(UI.RemoteProtection) == "table"
		and type(UI.MemoryLeakDetector) == "table"
		and type(UI.Profiler) == "table"
end)

runCheck("Tab A element count = 5", function()
	local list = tabA:GetElements()
	return type(list) == "table" and #list == 5
end)

runCheck("Tab B element count = 5", function()
	local list = tabB:GetElements()
	return type(list) == "table" and #list == 5
end)

runCheck("Settings tab has rich controls", function()
	local list = tabSettings:GetElements()
	return type(list) == "table" and #list >= 20
end)

runCheck("UI API methods available", function()
	return type(Rayfield.SetUIPreset) == "function"
		and type(Rayfield.SetTransitionProfile) == "function"
		and type(Rayfield.ShowOnboarding) == "function"
		and type(Rayfield.ApplyThemeStudioTheme) == "function"
		and type(Rayfield.ResetThemeStudio) == "function"
		and type(Rayfield.ExportSettings) == "function"
		and type(Rayfield.ImportCode) == "function"
		and type(Rayfield.CopyShareCode) == "function"
end)

runCheck("Toggle Set/Get works", function()
	elToggle:Set(true)
	if elToggle:Get() ~= true then
		return false
	end
	elToggle:Set(false)
	return elToggle:Get() == false
end)

runCheck("Slider Set works", function()
	elSlider:Set(75)
	local current = tonumber(elSlider.CurrentValue)
	return current ~= nil and math.abs(current - 75) <= 0.001
end)

runCheck("Input Set works", function()
	elInput:Set("Rayfield-AIO")
	return tostring(elInput.CurrentValue or "") == "Rayfield-AIO"
end)

runCheck("Dropdown Set/Clear works", function()
	elDropdown:Set("Beta")
	local current = elDropdown.CurrentOption
	if type(current) ~= "table" or current[1] ~= "Beta" then
		return false
	end
	elDropdown:Clear()
	return type(elDropdown.CurrentOption) == "table"
end)

runCheck("Keybind Set works", function()
	elKeybind:Set("LeftControl+K>LeftShift+M")
	return tostring(elKeybind.CurrentKeybind or "") == "LeftControl+K>LeftShift+M"
end)

runCheck("ColorPicker Set works", function()
	elColor:Set(Color3.fromRGB(0, 255, 150))
	local color = elColor.Color
	if typeof(color) ~= "Color3" then
		return false
	end
	return math.abs(color.G - 1) <= 0.001 and math.abs(color.R - 0) <= 0.001
end)

runCheck("Label/Paragraph/Section Set works", function()
	elLabel:Set("B3 Label Updated")
	elParagraph:Set({
		Title = "B4 Paragraph Updated",
		Content = "Paragraph content updated"
	})
	elSection:Set("B5 Section Updated")
	return true
end)

runCheck("Extended API exists (Pin/Tooltip)", function()
	return type(elButton.Pin) == "function"
		and type(elButton.Unpin) == "function"
		and type(elButton.SetTooltip) == "function"
		and type(elButton.ClearTooltip) == "function"
end)

runCheck("ExportSettings returns code", function()
	local code, _ = Rayfield:ExportSettings()
	if type(code) ~= "string" or code == "" then
		return false
	end
	settingsState.lastExportCode = code
	settingsState.importCode = code
	importCodeInput:Set(code)
	return true
end)

runCheck("Feature scope + task tracking works", function()
	if type(Rayfield.CreateFeatureScope) ~= "function"
		or type(Rayfield.TrackFeatureTask) ~= "function"
		or type(Rayfield.CleanupFeatureScope) ~= "function" then
		return false
	end

	local scopeId = select(1, Rayfield:CreateFeatureScope("loader-task-scope"))
	if type(scopeId) ~= "string" or scopeId == "" then
		return false
	end

	local worker = task.spawn(function()
		while true do
			task.wait(1)
		end
	end)

	local okTrack = select(1, Rayfield:TrackFeatureTask(scopeId, worker))
	if okTrack ~= true then
		return false
	end

	local okCleanup = select(1, Rayfield:CleanupFeatureScope(scopeId, false))
	return okCleanup == true
end)

runCheck("Control registry includes >= 30 controls", function()
	local controls = Rayfield:ListControls()
	return type(controls) == "table" and #controls >= 30
end)

local summary = string.format("Checks: %d pass / %d fail", checkState.pass, checkState.fail)
if checkState.fail == 0 then
	Rayfield:Notify({
		Title = "AIO 3-Tab Check",
		Content = summary,
		Duration = 8
	})
else
	Rayfield:Notify({
		Title = "AIO 3-Tab Check",
		Content = summary .. " (see console)",
		Duration = 10
	})
end

for _, line in ipairs(checkState.logs) do
	print(line)
end

return {
	UI = UI,
	Rayfield = Rayfield,
	Window = window,
	Tabs = {
		A = tabA,
		B = tabB,
		Settings = tabSettings
	},
	Elements = {
		TabA = {
			Button = elButton,
			Toggle = elToggle,
			Slider = elSlider,
			Input = elInput,
			Dropdown = elDropdown
		},
		TabB = {
			Keybind = elKeybind,
			ColorPicker = elColor,
			Label = elLabel,
			Paragraph = elParagraph,
			Section = elSection
		},
		Settings = {
			PresetDropdown = presetDropdown,
			TransitionDropdown = transitionDropdown,
			OnboardingToggle = onboardingToggle,
			ThemeBaseDropdown = themeBaseDropdown,
			ThemeAccentPicker = themeAccentPicker,
			ImportCodeInput = importCodeInput,
			AdvancedSection = advancedSection,
			StatusPreview = statusPreview,
			TrackPreview = trackPreview,
			Stepper = stepper,
			ConfirmReset = confirmReset,
			WrapperToggle = wrapperToggle,
			HotToggle = hotToggle,
			Image = settingsImage,
			Gallery = settingsGallery,
			Chart = settingsChart,
			LogConsole = settingsLogConsole
		}
	},
	CheckState = checkState,
	RuntimeState = runtimeState,
	SettingsState = settingsState
}
