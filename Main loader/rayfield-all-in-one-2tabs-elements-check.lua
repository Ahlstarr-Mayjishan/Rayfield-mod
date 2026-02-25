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

local function isReadyUI(candidate)
	if type(candidate) ~= "table" or type(candidate.Rayfield) ~= "table" then
		return false
	end
	if type(candidate.Rayfield.IsDestroyed) == "function" then
		local okDestroyed, destroyed = pcall(candidate.Rayfield.IsDestroyed, candidate.Rayfield)
		if okDestroyed and destroyed then
			return false
		end
	end
	return true
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
if isReadyUI(loaded) then
	UI = loaded
elseif isReadyUI(_G and _G.RayfieldUI) then
	UI = _G.RayfieldUI
elseif type(loaded) == "table" and type(loaded.quickSetup) == "function" then
	UI = loaded.quickSetup({
		mode = "enhanced",
		errorThreshold = 5,
		rateLimit = 10,
		autoCleanup = true,
		forceReload = false
	})
else
	error("All-in-one loader returned unexpected value: " .. type(loaded))
end

if not isReadyUI(UI) then
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
	Name = "Rayfield Mod | Full UI Sample",
	LoadingTitle = "Rayfield Mod Bundle",
	LoadingSubtitle = "All-in-One Full Controls",
	ConfigurationSaving = {
		Enabled = false
	},
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true
})

local tabCore = window:CreateTab("Core", 4483362458)
local tabAdvanced = window:CreateTab("Advanced", 4483362458)
local tabSettings = window:CreateTab("Settings", 4483362458)
local tabSystem = window:CreateTab("System", 4483362458)

local sampleLogConsole = nil
local function sampleLog(level, message)
	local safeLevel = tostring(level or "info")
	local safeMessage = tostring(message or "")
	print("[AIO-Sample][" .. safeLevel .. "] " .. safeMessage)
	if sampleLogConsole then
		if safeLevel == "warn" and type(sampleLogConsole.Warn) == "function" then
			sampleLogConsole:Warn(safeMessage)
		elseif safeLevel == "error" and type(sampleLogConsole.Error) == "function" then
			sampleLogConsole:Error(safeMessage)
		elseif type(sampleLogConsole.Info) == "function" then
			sampleLogConsole:Info(safeMessage)
		end
	end
end

-- Core tab
local elButton = tabCore:CreateButton({
	Name = "Standard Button",
	Callback = function()
		runtimeState.buttonClicks += 1
		Rayfield:Notify({
			Title = "Rayfield Sample",
			Content = "Button clicked " .. tostring(runtimeState.buttonClicks) .. " times",
			Duration = 2
		})
	end
})

local elToggle = tabCore:CreateToggle({
	Name = "Feature Toggle",
	CurrentValue = false,
	Callback = function(value)
		runtimeState.toggle = value == true
	end
})

local elSlider = tabCore:CreateSlider({
	Name = "Value Adjuster",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = 50,
	Callback = function(value)
		runtimeState.slider = tonumber(value) or 0
	end
})

local elInput = tabCore:CreateInput({
	Name = "Data Input",
	CurrentValue = "",
	PlaceholderText = "Input data here...",
	RemoveTextAfterFocusLost = false,
	Callback = function(value)
		runtimeState.input = tostring(value or "")
	end
})

local elDropdown = tabCore:CreateDropdown({
	Name = "Choice Dropdown",
	Options = { "Alpha", "Beta", "Gamma", "Delta" },
	CurrentOption = "Alpha",
	Callback = function(value)
		runtimeState.dropdown = firstOption(value)
	end
})

tabCore:CreateDivider()

local elKeybind = tabCore:CreateKeybind({
	Name = "Trigger Keybind",
	CurrentKeybind = "Q",
	CallOnChange = true,
	Callback = function(value)
		runtimeState.keybind = tostring(value or "")
	end
})

local elColor = tabCore:CreateColorPicker({
	Name = "Theme Picker",
	Color = Color3.fromRGB(255, 170, 0),
	Callback = function(value)
		runtimeState.color = value
	end
})

-- Advanced tab
local elLabel = tabAdvanced:CreateLabel("Static Information Label")
local elParagraph = tabAdvanced:CreateParagraph({
	Title = "Hub Manual",
	Content = "This sample loader includes core, advanced, settings, and system controls."
})
local elSection = tabAdvanced:CreateSection("Advanced Widgets")

tabAdvanced:CreateDivider()

local advancedSection = tabAdvanced:CreateCollapsibleSection({
	Name = "Interactive Widgets",
	Id = "sample-advanced-controls",
	Collapsed = false
})

local statusPreview = tabAdvanced:CreateStatusBar({
	Name = "Status Preview",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = settingsState.statusPreview,
	TextFormatter = function(current, max, percent)
		return string.format("Load %.0f%% (%d/%d)", percent, current, max)
	end,
	Callback = function(value)
		settingsState.statusPreview = tonumber(value) or 0
	end,
	ParentSection = advancedSection
})

local trackPreview = tabAdvanced:CreateTrackBar({
	Name = "Track Preview",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = settingsState.trackPreview,
	Callback = function(value)
		settingsState.trackPreview = tonumber(value) or 0
	end,
	ParentSection = advancedSection
})

local stepper = tabAdvanced:CreateNumberStepper({
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

local confirmReset = tabAdvanced:CreateConfirmButton({
	Name = "Confirm Theme Reset",
	ConfirmMode = "either",
	HoldDuration = 1,
	DoubleWindow = 0.4,
	Callback = function()
		local okReset, status = Rayfield:ResetThemeStudio()
		sampleLog(okReset and "info" or "error", "ResetThemeStudio => " .. tostring(status))
	end,
	ParentSection = advancedSection
})

local wrapperToggle = nil
if type(tabAdvanced.CreateToggleBind) == "function" then
	wrapperToggle = tabAdvanced:CreateToggleBind({
		Name = "ToggleBind Example",
		CurrentValue = false,
		Keybind = { CurrentKeybind = "LeftControl+1" },
		Callback = function(value)
			sampleLog("info", "ToggleBind => " .. tostring(value))
		end,
		ParentSection = advancedSection
	})
end

local hotToggle = nil
if type(tabAdvanced.CreateHotToggle) == "function" then
	hotToggle = tabAdvanced:CreateHotToggle({
		Name = "HotToggle Example",
		CurrentValue = false,
		Keybind = { CurrentKeybind = "LeftControl+2" },
		Callback = function(value)
			sampleLog("info", "HotToggle => " .. tostring(value))
		end,
		ParentSection = advancedSection
	})
end

local keybindToggle = nil
if type(tabAdvanced.CreateKeybindToggle) == "function" then
	keybindToggle = tabAdvanced:CreateKeybindToggle({
		Name = "KeybindToggle Example",
		CurrentValue = false,
		Keybind = { CurrentKeybind = "LeftControl+3" },
		Callback = function(value)
			sampleLog("info", "KeybindToggle => " .. tostring(value))
		end,
		ParentSection = advancedSection
	})
end

local loadingSpinner = nil
if type(tabAdvanced.CreateLoadingSpinner) == "function" then
	loadingSpinner = tabAdvanced:CreateLoadingSpinner({
		Name = "Loading Spinner",
		Speed = 1.2,
		AutoStart = true,
		ParentSection = advancedSection
	})
end

local loadingBar = nil
if type(tabAdvanced.CreateLoadingBar) == "function" then
	loadingBar = tabAdvanced:CreateLoadingBar({
		Name = "Loading Bar",
		Mode = "indeterminate",
		AutoStart = true,
		ShowLabel = false,
		ParentSection = advancedSection
	})
end

local settingsImage = nil
if type(tabAdvanced.CreateImage) == "function" then
	settingsImage = tabAdvanced:CreateImage({
		Name = "Preview Image",
		Source = "rbxassetid://4483362458",
		FitMode = "fill",
		Height = 110,
		Caption = "Rayfield Icon"
	})
end

local settingsGallery = nil
if type(tabAdvanced.CreateGallery) == "function" then
	settingsGallery = tabAdvanced:CreateGallery({
		Name = "Sample Gallery",
		SelectionMode = "multi",
		Columns = "auto",
		Items = {
			{ id = "a", name = "Item A", image = "rbxassetid://4483362458" },
			{ id = "b", name = "Item B", image = "rbxassetid://4483362458" },
			{ id = "c", name = "Item C", image = "rbxassetid://4483362458" }
		},
		Callback = function(selection)
			local count = type(selection) == "table" and #selection or 0
			sampleLog("info", "Gallery selection count => " .. tostring(count))
		end
	})
end

local settingsChart = nil
if type(tabAdvanced.CreateChart) == "function" then
	settingsChart = tabAdvanced:CreateChart({
		Name = "Sample Chart",
		MaxPoints = 180,
		UpdateHz = 8,
		Preset = "fps",
		ShowAreaFill = true
	})
	settingsChart:AddPoint(35)
	settingsChart:AddPoint(45)
	settingsChart:AddPoint(55)
end

if type(tabAdvanced.CreateLogConsole) == "function" then
	sampleLogConsole = tabAdvanced:CreateLogConsole({
		Name = "Sample Logs",
		CaptureMode = "manual",
		MaxEntries = 120,
		ShowTimestamp = true
	})
	sampleLog("info", "Advanced tab initialized.")
end

-- Settings tab
local themeNames = sortedThemeNames(Rayfield)
tabSettings:CreateDropdown({
	Name = "UI Preset",
	Options = { "Comfort", "Compact", "Focus" },
	CurrentOption = settingsState.uiPreset,
	Callback = function(value)
		local selected = firstOption(value)
		if selected ~= "" then
			local okSet, status = Rayfield:SetUIPreset(selected)
			sampleLog(okSet and "info" or "error", "SetUIPreset(" .. selected .. ") => " .. tostring(status))
		end
	end
})

tabSettings:CreateDropdown({
	Name = "Transition Profile",
	Options = { "Smooth", "Snappy", "Minimal", "Off" },
	CurrentOption = settingsState.transitionProfile,
	Callback = function(value)
		local selected = firstOption(value)
		if selected ~= "" then
			local okSet, status = Rayfield:SetTransitionProfile(selected)
			sampleLog(okSet and "info" or "error", "SetTransitionProfile(" .. selected .. ") => " .. tostring(status))
		end
	end
})

tabSettings:CreateToggle({
	Name = "Suppress Onboarding",
	CurrentValue = settingsState.onboardingSuppressed,
	Callback = function(value)
		local okSet, status = Rayfield:SetOnboardingSuppressed(value == true)
		sampleLog(okSet and "info" or "error", "SetOnboardingSuppressed(" .. tostring(value) .. ") => " .. tostring(status))
	end
})

tabSettings:CreateDropdown({
	Name = "Theme Base",
	Options = themeNames,
	CurrentOption = settingsState.themeBase,
	Callback = function(value)
		local selected = firstOption(value)
		if selected ~= "" then
			local okTheme, status = Rayfield:ApplyThemeStudioTheme(selected)
			sampleLog(okTheme and "info" or "error", "ApplyThemeStudioTheme(" .. selected .. ") => " .. tostring(status))
		end
	end
})

tabSettings:CreateColorPicker({
	Name = "Accent Color",
	Color = settingsState.themeAccent,
	Callback = function(accent)
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
		sampleLog(okTheme and "info" or "error", "ApplyThemeStudioTheme(custom) => " .. tostring(status))
	end
})

tabSettings:CreateButton({
	Name = "Replay Onboarding",
	Callback = function()
		local okShow, status = Rayfield:ShowOnboarding(true)
		sampleLog(okShow and "info" or "error", "ShowOnboarding(true) => " .. tostring(status))
	end
})

tabSettings:CreateButton({
	Name = "Reset Theme Studio",
	Callback = function()
		local okReset, status = Rayfield:ResetThemeStudio()
		sampleLog(okReset and "info" or "error", "ResetThemeStudio() => " .. tostring(status))
	end
})

-- System tab
local importCodeInput = tabSystem:CreateInput({
	Name = "Settings Code Buffer",
	CurrentValue = "",
	PlaceholderText = "RFSC1:....",
	RemoveTextAfterFocusLost = false,
	Callback = function(text)
		settingsState.importCode = tostring(text or "")
	end
})

tabSystem:CreateButton({
	Name = "Export Settings Code",
	Callback = function()
		local code, status = Rayfield:ExportSettings()
		if type(code) == "string" and code ~= "" then
			settingsState.lastExportCode = code
			settingsState.importCode = code
			importCodeInput:Set(code)
			sampleLog("info", "ExportSettings => " .. tostring(status) .. " (len=" .. tostring(#code) .. ")")
		else
			sampleLog("error", "ExportSettings failed => " .. tostring(status))
		end
	end
})

tabSystem:CreateButton({
	Name = "Import From Buffer",
	Callback = function()
		if settingsState.importCode == "" then
			sampleLog("warn", "Import buffer is empty.")
			return
		end
		local okImport, status = Rayfield:ImportCode(settingsState.importCode)
		sampleLog(okImport and "info" or "error", "ImportCode(buffer) => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Import Last Export",
	Callback = function()
		if type(settingsState.lastExportCode) ~= "string" or settingsState.lastExportCode == "" then
			sampleLog("warn", "No exported code cached yet.")
			return
		end
		local okImport, status = Rayfield:ImportCode(settingsState.lastExportCode)
		sampleLog(okImport and "info" or "error", "ImportCode(lastExport) => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Copy Share Code",
	Callback = function()
		local okCopy, status = Rayfield:CopyShareCode()
		sampleLog(okCopy and "info" or "error", "CopyShareCode => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Import Active Settings",
	Callback = function()
		local okImport, status = Rayfield:ImportSettings()
		sampleLog(okImport and "info" or "error", "ImportSettings => " .. tostring(status))
	end
})

tabSystem:CreateButton({
	Name = "Print Controls Snapshot",
	Callback = function()
		local controls = Rayfield:ListControls()
		sampleLog("info", "ListControls count = " .. tostring(type(controls) == "table" and #controls or 0))
	end
})

-- Checks
runCheck("All-in-one services ready", function()
	return type(UI.ErrorManager) == "table"
		and type(UI.GarbageCollector) == "table"
		and type(UI.RemoteProtection) == "table"
		and type(UI.MemoryLeakDetector) == "table"
		and type(UI.Profiler) == "table"
end)

runCheck("Core tab has baseline controls", function()
	local list = tabCore:GetElements()
	return type(list) == "table" and #list >= 7
end)

runCheck("Advanced tab has rich controls", function()
	local list = tabAdvanced:GetElements()
	return type(list) == "table" and #list >= 12
end)

runCheck("Settings/System tabs populated", function()
	local settingsList = tabSettings:GetElements()
	local systemList = tabSystem:GetElements()
	return type(settingsList) == "table" and #settingsList >= 6
		and type(systemList) == "table" and #systemList >= 6
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

runCheck("Core element Set/Get works", function()
	elToggle:Set(true)
	if elToggle:Get() ~= true then
		return false
	end
	elSlider:Set(75)
	elInput:Set("Rayfield-AIO")
	elDropdown:Set("Beta")
	return tostring(elInput.CurrentValue or "") == "Rayfield-AIO"
		and type(elDropdown.CurrentOption) == "table"
		and elDropdown.CurrentOption[1] == "Beta"
end)

runCheck("Loading controls available (if supported)", function()
	if type(tabAdvanced.CreateLoadingSpinner) ~= "function" or type(tabAdvanced.CreateLoadingBar) ~= "function" then
		return true
	end
	return type(loadingSpinner) == "table"
		and type(loadingSpinner.Start) == "function"
		and type(loadingSpinner.Stop) == "function"
		and type(loadingBar) == "table"
		and type(loadingBar.SetMode) == "function"
		and type(loadingBar.SetProgress) == "function"
end)

runCheck("Loading bar hybrid behavior (if supported)", function()
	if type(loadingBar) ~= "table" then
		return true
	end
	local okProgress = select(1, loadingBar:SetProgress(0.5))
	if okProgress ~= true then
		return false
	end
	if loadingBar:GetMode() ~= "determinate" then
		return false
	end
	local okMode = select(1, loadingBar:SetMode("indeterminate"))
	if okMode ~= true then
		return false
	end
	return select(1, loadingBar:Start()) == true
end)

runCheck("ExportSettings returns code", function()
	local code = select(1, Rayfield:ExportSettings())
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
Rayfield:Notify({
	Title = "AIO Full UI Sample",
	Content = checkState.fail == 0 and summary or (summary .. " (see console)"),
	Duration = checkState.fail == 0 and 8 or 10
})

for _, line in ipairs(checkState.logs) do
	print(line)
end

return {
	UI = UI,
	Rayfield = Rayfield,
	Window = window,
	Tabs = {
		Core = tabCore,
		Advanced = tabAdvanced,
		Settings = tabSettings,
		System = tabSystem
	},
	Elements = {
		Core = {
			Button = elButton,
			Toggle = elToggle,
			Slider = elSlider,
			Input = elInput,
			Dropdown = elDropdown,
			Keybind = elKeybind,
			ColorPicker = elColor
		},
		Advanced = {
			Label = elLabel,
			Paragraph = elParagraph,
			Section = elSection,
			StatusPreview = statusPreview,
			TrackPreview = trackPreview,
			Stepper = stepper,
			ConfirmReset = confirmReset,
			ToggleBind = wrapperToggle,
			HotToggle = hotToggle,
			KeybindToggle = keybindToggle,
			LoadingSpinner = loadingSpinner,
			LoadingBar = loadingBar,
			Image = settingsImage,
			Gallery = settingsGallery,
			Chart = settingsChart,
			LogConsole = sampleLogConsole
		},
		System = {
			ImportCodeInput = importCodeInput
		}
	},
	CheckState = checkState,
	RuntimeState = runtimeState,
	SettingsState = settingsState
}
