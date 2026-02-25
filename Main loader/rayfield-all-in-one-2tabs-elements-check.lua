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
    autoSave = false,
    glassMode = "auto",
    glassIntensity = 0.32,
    audioEnabled = false,
    audioPack = "Default"
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
    
    if type(Rayfield.GetGlassMode) == "function" then
        settingsState.glassMode = Rayfield:GetGlassMode()
    end
    if type(Rayfield.GetGlassIntensity) == "function" then
        settingsState.glassIntensity = Rayfield:GetGlassIntensity() or 0.32
    end
    if type(Rayfield.IsAudioFeedbackEnabled) == "function" then
        settingsState.audioEnabled = Rayfield:IsAudioFeedbackEnabled()
    end
end

local window = Rayfield:CreateWindow({
	Name = "Rayfield Mod | Ultimate",
	LoadingTitle = "Rayfield Mod Bundle",
	LoadingSubtitle = "All-in-One Extreme Pack",
    ToggleUIKeybind = "RightControl",
	ConfigurationSaving = {
		Enabled = true,
        FolderName = "RayfieldModAIO",
        FileName = "Config",
        AutoSave = false
	},
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false
})

local tabMain = window:CreateTab("General", 4483362458)
local tabLayout = window:CreateTab("Layout", 4483362458)
local tabSettings = window:CreateTab("UI Settings", 4483362458)
local tabDeveloper = window:CreateTab("Developer", 4483362458)

-- 1. General Tab
tabMain:CreateSection("Core Input Elements")
local elButton = tabMain:CreateButton({
	Name = "Standard Button",
	Callback = function()
		runtimeState.buttonClicks += 1
        Rayfield:Notify({Title = "Notification", Content = "Clicks: "..runtimeState.buttonClicks, Duration = 2})
	end
})

local elToggle = tabMain:CreateToggle({
	Name = "Feature Toggle",
	CurrentValue = false,
	Callback = function(v) runtimeState.toggle = v end
})

local elSlider = tabMain:CreateSlider({
	Name = "Value Adjuster",
	Range = {0, 100},
	Increment = 1,
	CurrentValue = 50,
	Callback = function(v) runtimeState.slider = v end
})

local elInput = tabMain:CreateInput({
	Name = "Data Input",
	CurrentValue = "",
	PlaceholderText = "Input data here...",
	Callback = function(v) runtimeState.input = v end
})

local elDropdown = tabMain:CreateDropdown({
	Name = "Choice Dropdown",
	Options = {"Alpha", "Beta", "Gamma", "Delta"},
	CurrentOption = "Alpha",
	Callback = function(v) runtimeState.dropdown = firstOption(v) end
})

tabMain:CreateDivider()
tabMain:CreateSection("Complex Control")
local elKeybind = tabMain:CreateKeybind({
	Name = "Trigger Keybind",
	CurrentKeybind = "Q",
	Callback = function(v) runtimeState.keybind = v end
})

local elColor = tabMain:CreateColorPicker({
	Name = "Theme Picker",
	Color = Color3.fromRGB(255, 170, 0),
	Callback = function(v) runtimeState.color = v end
})

-- 2. Layout Tab
tabLayout:CreateSection("Display Elements")
local elLabel = tabLayout:CreateLabel("Static Information Label")
local elParagraph = tabLayout:CreateParagraph({
	Title = "Hub Manual",
	Content = "Welcome to the Ultimate Bundle. Use the Settings tab to customize your experience and the Developer tab to debug systems."
})

tabLayout:CreateDivider()
local layoutCollapsible = tabLayout:CreateCollapsibleSection({
	Name = "Advanced Layout Widgets",
	Collapsed = false
})

local statusP = layoutCollapsible:CreateStatusBar({
	Name = "Engine Load",
	Range = {0, 100},
	CurrentValue = 42,
    ParentSection = layoutCollapsible
})

local trackP = layoutCollapsible:CreateTrackBar({
	Name = "Volume Track",
	Range = {0, 100},
	CurrentValue = 75,
    ParentSection = layoutCollapsible
})

layoutCollapsible:CreateNumberStepper({
	Name = "Step Control",
	CurrentValue = 10,
	Callback = function(v) statusP:Set(v) end,
    ParentSection = layoutCollapsible
})

-- 3. UI Settings Tab
local function settingsLog(level, message)
	print("[UI-Settings][" .. tostring(level) .. "] " .. tostring(message))
end

tabSettings:CreateSection("Visual Customization")
tabSettings:CreateDropdown({
	Name = "Sizing Preset",
	Options = {"Comfort", "Compact", "Focus"},
	CurrentOption = settingsState.uiPreset,
	Callback = function(v) Rayfield:SetUIPreset(firstOption(v)) end
})

tabSettings:CreateDropdown({
	Name = "Animation Profile",
	Options = {"Smooth", "Snappy", "Minimal", "Off"},
	CurrentOption = settingsState.transitionProfile,
	Callback = function(v) Rayfield:SetTransitionProfile(firstOption(v)) end
})

local themeNames = sortedThemeNames(Rayfield)
tabSettings:CreateDropdown({
	Name = "Base Theme",
	Options = themeNames,
	CurrentOption = settingsState.themeBase,
	Callback = function(v) Rayfield:ApplyThemeStudioTheme(firstOption(v)) end
})

tabSettings:CreateColorPicker({
	Name = "Accent Highlight",
	Color = settingsState.themeAccent,
	Callback = function(value)
        Rayfield:ApplyThemeStudioTheme({
			SliderBackground = value, SliderProgress = value, SliderStroke = value,
			ToggleEnabled = value, ToggleEnabledStroke = value, ToggleEnabledOuterStroke = value,
			TabBackgroundSelected = value, SelectedTabTextColor = Color3.fromRGB(20, 20, 20)
		})
	end
})

tabSettings:CreateSection("Premium UX (Engine)")
tabSettings:CreateDropdown({
	Name = "Glass Rendering",
	Options = {"auto", "off", "canvas", "fallback"},
	CurrentOption = settingsState.glassMode,
	Callback = function(v) Rayfield:SetGlassMode(firstOption(v)) end
})

tabSettings:CreateSlider({
	Name = "Glass Intensity",
	Range = {0, 100},
	CurrentValue = math.floor(settingsState.glassIntensity * 100),
	Callback = function(v) Rayfield:SetGlassIntensity(v / 100) end
})

tabSettings:CreateToggle({
	Name = "Audio Feedback",
	CurrentValue = settingsState.audioEnabled,
	Callback = function(v) Rayfield:SetAudioFeedbackEnabled(v) end
})

tabSettings:CreateDropdown({
	Name = "Audio Sound Pack",
	Options = {"Default", "Classic", "Modern", "Ghost"},
	CurrentOption = "Default",
	Callback = function(v) Rayfield:SetAudioFeedbackPack(firstOption(v)) end
})

tabSettings:CreateButton({
	Name = "Test Sound Cue",
	Callback = function() Rayfield:PlayUICue("success") end
})

-- 4. Developer Tab
tabDeveloper:CreateSection("Configuration & State")
tabDeveloper:CreateToggle({
	Name = "Autosave UI State",
	CurrentValue = false,
	Callback = function(v) if Rayfield.ConfigurationSaving then Rayfield.ConfigurationSaving.AutoSave = v end end
})

tabDeveloper:CreateButton({
	Name = "Save Configuration Now",
	Callback = function() Rayfield:SaveConfiguration() Rayfield:Notify({Title="Saved", Content="Config persisted to Disk.", Duration=2}) end
})

tabDeveloper:CreateSection("Data Exchange")
local codeInput = tabDeveloper:CreateInput({
	Name = "Settings Code",
	PlaceholderText = "RFSC Code...",
	Callback = function(v) settingsState.importCode = v end
})

tabDeveloper:CreateButton({
	Name = "Export Hub Code",
	Callback = function()
		local code = Rayfield:ExportSettings()
		if code then codeInput:Set(code) end
	end
})

tabDeveloper:CreateButton({
	Name = "Import from Code",
	Callback = function() if settingsState.importCode then Rayfield:ImportCode(settingsState.importCode) end end
})

tabDeveloper:CreateSection("System Monitor")
local devChart = tabDeveloper:CreateChart({
	Name = "Performance Stats",
	Preset = "fps"
})

local devLogs = tabDeveloper:CreateLogConsole({
	Name = "Runtime Logs",
	MaxEntries = 100
})

tabDeveloper:CreateSection("Maintenance")
tabDeveloper:CreateButton({
	Name = "Replay Guided Tour",
	Callback = function() Rayfield:ShowOnboarding(true) end
})

tabDeveloper:CreateConfirmButton({
	Name = "Factory Reset UI",
	ConfirmMode = "hold",
	Callback = function() Rayfield:ResetThemeStudio() end
})

-- Final logic checks
runCheck("API Validation", function()
	return type(Rayfield.SetUIPreset) == "function" 
		and type(Rayfield.SetAudioFeedbackEnabled) == "function"
		and type(Rayfield.ExportSettings) == "function"
end)

Rayfield:Notify({
    Title = "Ultimate Bundle Active",
    Content = "4 Tabs / All Elements Loaded.",
    Duration = 5
})

return {
	Rayfield = Rayfield,
	Window = window,
	Tabs = {Main = tabMain, Layout = tabLayout, Settings = tabSettings, Developer = tabDeveloper}
}
