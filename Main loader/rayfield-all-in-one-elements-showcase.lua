local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local function createShowcaseLogger()
	local logger = {
		enabled = true,
		fileEnabled = false,
		folder = "Rayfield/Logs",
		activeFolder = nil,
		path = nil,
		latestPath = nil,
		reason = "init"
	}

	if type(_G) == "table" then
		if _G.__RAYFIELD_SHOWCASE_FILE_LOG == false then
			logger.enabled = false
		end
		if type(_G.__RAYFIELD_SHOWCASE_LOG_FOLDER) == "string" and _G.__RAYFIELD_SHOWCASE_LOG_FOLDER ~= "" then
			logger.folder = _G.__RAYFIELD_SHOWCASE_LOG_FOLDER
		end
	end

	local appendFn = type(appendfile) == "function" and appendfile or nil
	local writeFn = type(writefile) == "function" and writefile or nil
	local isFolderFn = type(isfolder) == "function" and isfolder or nil
	local makeFolderFn = type(makefolder) == "function" and makefolder or nil
	local ring = {}
	local runId = tostring(type(os.time) == "function" and os.time() or math.floor(os.clock() * 1000))

	local function setTargets(folderPath)
		local fileName = "elements-showcase-" .. runId .. ".log"
		local latestName = "elements-showcase-latest.log"
		if type(folderPath) == "string" and folderPath ~= "" then
			logger.activeFolder = folderPath
			logger.path = folderPath .. "/" .. fileName
			logger.latestPath = folderPath .. "/" .. latestName
		else
			logger.activeFolder = nil
			logger.path = fileName
			logger.latestPath = latestName
		end
	end

	setTargets(logger.folder)

	local function ensureFolderPath(path)
		if type(path) ~= "string" or path == "" then
			return true, nil
		end
		if not makeFolderFn then
			return false, "makefolder_unavailable"
		end

		local normalized = string.gsub(path, "\\", "/")
		local current = ""
		for part in string.gmatch(normalized, "[^/]+") do
			current = current == "" and part or (current .. "/" .. part)
			local exists = false
			if isFolderFn then
				local okExists, result = pcall(isFolderFn, current)
				exists = okExists and result == true
			end
			if not exists then
				local okMake = pcall(makeFolderFn, current)
				if not okMake then
					if isFolderFn then
						local okExistsAfter, resultAfter = pcall(isFolderFn, current)
						if not (okExistsAfter and resultAfter == true) then
							return false, "makefolder_failed:" .. tostring(current)
						end
					else
						return false, "makefolder_failed:" .. tostring(current)
					end
				end
			end
		end
		return true, nil
	end

	local function flushWholeFile(path)
		if not writeFn then
			return
		end
		pcall(writeFn, path, table.concat(ring, "\n") .. "\n")
	end

	local function appendLine(path, lineText)
		if appendFn then
			local ok = pcall(appendFn, path, lineText .. "\n")
			return ok
		end
		if writeFn then
			flushWholeFile(path)
			return true
		end
		return false
	end

	if logger.enabled and (appendFn or writeFn) then
		local folderOk, folderErr = ensureFolderPath(logger.folder)
		if folderOk then
			logger.fileEnabled = true
			logger.reason = "folder_ready"
		else
			-- Fallback to root workspace when nested folder creation fails.
			setTargets(nil)
			logger.fileEnabled = true
			logger.reason = "root_fallback:" .. tostring(folderErr)
		end
	else
		logger.reason = logger.enabled and "file_api_unavailable" or "file_log_disabled"
	end

	function logger.log(level, message)
		local stamp = type(os.date) == "function" and os.date("%Y-%m-%d %H:%M:%S") or tostring(os.clock())
		local line = string.format("[%s][%s] %s", stamp, tostring(level or "INFO"), tostring(message or ""))
		table.insert(ring, line)
		if #ring > 1200 then
			table.remove(ring, 1)
		end
		if type(_G) == "table" then
			_G.__RAYFIELD_SHOWCASE_LOG_BUFFER = ring
			_G.__RAYFIELD_SHOWCASE_LOG_FILE = logger.path
			_G.__RAYFIELD_SHOWCASE_LOG_INFO = {
				enabled = logger.enabled,
				fileEnabled = logger.fileEnabled,
				requestedFolder = logger.folder,
				activeFolder = logger.activeFolder,
				path = logger.path,
				latestPath = logger.latestPath,
				reason = logger.reason
			}
		end
		if not logger.fileEnabled then
			return
		end
		local okWrite = appendLine(logger.path, line)
		if not okWrite and logger.activeFolder ~= nil then
			-- Runtime fallback in case folder writes fail unexpectedly.
			setTargets(nil)
			logger.reason = "runtime_root_fallback"
			if type(_G) == "table" then
				_G.__RAYFIELD_SHOWCASE_LOG_FILE = logger.path
			end
			okWrite = appendLine(logger.path, line)
		end
		if not okWrite then
			logger.fileEnabled = false
			logger.reason = "write_failed_all_targets"
			return
		end
		if writeFn and logger.latestPath then
			flushWholeFile(logger.latestPath)
		end
	end

	return logger
end

local ShowcaseLogger = createShowcaseLogger()

local function logLine(level, message)
	ShowcaseLogger.log(level, message)
end

logLine("BOOT", "showcase loader start")

local function compileChunk(source, label)
	if type(source) ~= "string" then
		local message = "Invalid Lua source for " .. tostring(label) .. ": " .. type(source)
		logLine("ERROR", message)
		error(message)
	end
	source = source:gsub("^\239\187\191", "")
	source = source:gsub("^\0+", "")
	local chunk, err = compileString(source)
	if not chunk then
		local message = "Failed to compile " .. tostring(label) .. ": " .. tostring(err)
		logLine("ERROR", message)
		error(message)
	end
	return chunk
end

local function fetchAndRun(url, label)
	logLine("FETCH", "HttpGet " .. tostring(url))
	local source = game:HttpGet(url)
	logLine("FETCH", "HttpGet OK " .. tostring(label or url) .. " | bytes=" .. tostring(type(source) == "string" and #source or 0))
	return compileChunk(source, label or url)()
end

local function getBootTimeoutSeconds()
	local configured = type(_G) == "table" and tonumber(_G.__RAYFIELD_SHOWCASE_BOOT_TIMEOUT_SEC) or nil
	if configured and configured > 0 then
		return configured
	end
	return 12
end

local function getQuickSetupTimeoutSeconds()
	local configured = type(_G) == "table" and tonumber(_G.__RAYFIELD_SHOWCASE_QUICKSETUP_TIMEOUT_SEC) or nil
	if configured and configured > 0 then
		return configured
	end
	local bootTimeout = getBootTimeoutSeconds()
	return math.max(20, bootTimeout * 3)
end

local function callWithTimeout(timeoutSeconds, workFn)
	local finished = false
	local ok = false
	local resultOrErr = nil
	local worker = task.spawn(function()
		ok, resultOrErr = pcall(workFn)
		finished = true
	end)

	local startedAt = os.clock()
	while not finished and (os.clock() - startedAt) < timeoutSeconds do
		task.wait()
	end

	if not finished then
		pcall(task.cancel, worker)
		return false, "timeout after " .. tostring(timeoutSeconds) .. "s", "timeout"
	end
	if not ok then
		return false, resultOrErr, "error"
	end
	return true, resultOrErr, "ok"
end

local function tryFetchAndRun(url, label)
	local timeoutSeconds = getBootTimeoutSeconds()
	logLine("BOOT", "tryFetchAndRun start | label=" .. tostring(label) .. " | timeout=" .. tostring(timeoutSeconds) .. "s")
	local okCall, resultOrErr, status = callWithTimeout(timeoutSeconds, function()
		return fetchAndRun(url, label)
	end)
	if not okCall then
		if status == "timeout" then
			local timeoutMsg = "timeout after " .. tostring(timeoutSeconds) .. "s"
			logLine("ERROR", "tryFetchAndRun timeout | label=" .. tostring(label) .. " | url=" .. tostring(url))
			return false, timeoutMsg
		end
		logLine("ERROR", "tryFetchAndRun failed | label=" .. tostring(label) .. " | error=" .. tostring(resultOrErr))
		return false, resultOrErr
	end
	logLine("BOOT", "tryFetchAndRun success | label=" .. tostring(label) .. " | resultType=" .. tostring(type(resultOrErr)))
	return true, resultOrErr
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

local function isReadyRayfield(candidate)
	if type(candidate) ~= "table" or type(candidate.CreateWindow) ~= "function" then
		return false
	end
	if type(candidate.IsDestroyed) == "function" then
		local okDestroyed, destroyed = pcall(candidate.IsDestroyed, candidate)
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

local function ensureTrailingSlash(url)
	if type(url) ~= "string" or url == "" then
		return nil
	end
	if string.sub(url, -1) ~= "/" then
		return url .. "/"
	end
	return url
end

local function resolveRuntimeRoots()
	local roots = {}
	local seen = {}
	local function add(url)
		local normalized = ensureTrailingSlash(url)
		if normalized and not seen[normalized] then
			seen[normalized] = true
			table.insert(roots, normalized)
		end
	end

	if type(_G) == "table" then
		add(_G.__RAYFIELD_RUNTIME_ROOT_URL)
	end

	add("https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Rayfield-mod@main/")
	add("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/")
	return roots
end

local runtimeRoots = resolveRuntimeRoots()
local root = runtimeRoots[1] or "https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Rayfield-mod@main/"

if type(_G) == "table" then
	_G.__RAYFIELD_RUNTIME_ROOT_URL = root
end

logLine("BOOT", "runtime root seed = " .. tostring(root))
logLine("BOOT", "file log path = " .. tostring(ShowcaseLogger.path))

local DEBUG_BOOT = type(_G) == "table" and _G.__RAYFIELD_SHOWCASE_DEBUG == true
local function bootLog(message)
	logLine("BOOT", message)
	if DEBUG_BOOT and type(warn) == "function" then
		warn("[Elements-Showcase][Boot] " .. tostring(message))
	end
end

local function tryFetchAndRunPath(path, label)
	local lastErr = nil
	for _, candidateRoot in ipairs(runtimeRoots) do
		local fullUrl = candidateRoot .. path
		local ok, resultOrErr = tryFetchAndRun(fullUrl, label)
		if ok then
			bootLog("Loaded " .. tostring(path) .. " from " .. tostring(candidateRoot))
			return true, resultOrErr, candidateRoot
		end
		lastErr = resultOrErr
		bootLog("Failed " .. tostring(path) .. " from " .. tostring(candidateRoot) .. " => " .. tostring(resultOrErr))
	end
	return false, lastErr, nil
end

local function wrapRayfieldAsUI(rayfield, mode)
	return {
		Rayfield = rayfield,
		mode = mode or "base"
	}
end

local function tryBootstrapFromBase(reasons)
	local okBase, baseOrErr, selectedRoot = tryFetchAndRunPath(
		"Main%20loader/rayfield-modified.lua",
		"Main loader/rayfield-modified.lua"
	)
	if okBase and isReadyRayfield(baseOrErr) then
		root = selectedRoot or root
		if type(_G) == "table" then
			_G.__RAYFIELD_RUNTIME_ROOT_URL = root
		end
		return wrapRayfieldAsUI(baseOrErr, "base")
	end
	table.insert(reasons, "base loader failed: " .. tostring(baseOrErr))
	return nil
end

local function tryBootstrapFromAllInOne(reasons)
	local okAllInOne, loadedOrErr, selectedRoot = tryFetchAndRunPath(
		"Main%20loader/rayfield-all-in-one.lua",
		"Main loader/rayfield-all-in-one.lua"
	)

	if not okAllInOne then
		table.insert(reasons, "all-in-one fetch/execute failed: " .. tostring(loadedOrErr))
		return nil
	end
	root = selectedRoot or root
	if type(_G) == "table" then
		_G.__RAYFIELD_RUNTIME_ROOT_URL = root
	end

	if isReadyUI(loadedOrErr) then
		return loadedOrErr
	end

	if isReadyUI(_G and _G.RayfieldUI) then
		return _G.RayfieldUI
	end

	if type(loadedOrErr) == "table" and type(loadedOrErr.quickSetup) == "function" then
		bootLog("all-in-one returned loader table; entering quickSetup path")
		if type(loadedOrErr.configure) == "function" then
			local okConfigure, configureErr = pcall(loadedOrErr.configure, {
				autoReload = false,
				autoReloadEnabled = false
			})
			bootLog("all-in-one configure(autoReload=false) => " .. tostring(okConfigure and "ok" or configureErr))
		end

		local commonConfig = {
			mode = "enhanced",
			errorThreshold = 5,
			rateLimit = 10,
			autoCleanup = true
		}

		local function runQuickSetup(forceReload)
			local timeoutSeconds = getQuickSetupTimeoutSeconds()
			bootLog("quickSetup start | forceReload=" .. tostring(forceReload) .. " | timeout=" .. tostring(timeoutSeconds) .. "s")
			local okQuick, uiOrErr, quickStatus = callWithTimeout(timeoutSeconds, function()
				return loadedOrErr.quickSetup({
					mode = commonConfig.mode,
					errorThreshold = commonConfig.errorThreshold,
					rateLimit = commonConfig.rateLimit,
					autoCleanup = commonConfig.autoCleanup,
					forceReload = forceReload
				})
			end)
			if okQuick and isReadyUI(uiOrErr) then
				bootLog("quickSetup success | forceReload=" .. tostring(forceReload))
				return true, uiOrErr
			end
			if isReadyUI(_G and _G.RayfieldUI) then
				bootLog("quickSetup produced global _G.RayfieldUI")
				return true, _G.RayfieldUI
			end
			if isReadyRayfield(_G and _G.Rayfield) then
				bootLog("quickSetup produced global _G.Rayfield")
				return true, wrapRayfieldAsUI(_G.Rayfield, "global")
			end
			local reason = nil
			if not okQuick then
				if quickStatus == "timeout" then
					reason = "quickSetup(forceReload=" .. tostring(forceReload) .. ") timeout after " .. tostring(timeoutSeconds) .. "s"
				else
					reason = "quickSetup(forceReload=" .. tostring(forceReload) .. ") failed: " .. tostring(uiOrErr)
				end
			else
				reason = "quickSetup(forceReload=" .. tostring(forceReload) .. ") returned unusable value: " .. tostring(type(uiOrErr))
			end
			return false, reason
		end

		local okQuick, uiOrReason = runQuickSetup(false)
		if okQuick then
			return uiOrReason
		end
		table.insert(reasons, tostring(uiOrReason))

		okQuick, uiOrReason = runQuickSetup(true)
		if okQuick then
			return uiOrReason
		end
		table.insert(reasons, tostring(uiOrReason))
		return nil
	end

	table.insert(reasons, "all-in-one return type unsupported: " .. tostring(type(loadedOrErr)))
	return nil
end

local function bootstrapUI()
	local reasons = {}
	bootLog("bootstrapUI begin")

	if isReadyUI(_G and _G.RayfieldUI) then
		bootLog("Using existing _G.RayfieldUI")
		return _G.RayfieldUI
	end

	if isReadyRayfield(_G and _G.Rayfield) then
		bootLog("Using existing _G.Rayfield")
		return wrapRayfieldAsUI(_G.Rayfield, "global")
	end

	local preferAllInOne = type(_G) == "table" and _G.__RAYFIELD_SHOWCASE_PREFER_AIO == true
	local ui = nil

	if preferAllInOne then
		bootLog("Bootstrap order: all-in-one -> base")
		ui = tryBootstrapFromAllInOne(reasons)
		if isReadyUI(ui) then
			return ui
		end
		ui = tryBootstrapFromBase(reasons)
		if ui and isReadyUI(ui) then
			return ui
		end
	else
		bootLog("Bootstrap order: base -> all-in-one")
		ui = tryBootstrapFromBase(reasons)
		if ui and isReadyUI(ui) then
			return ui
		end
		ui = tryBootstrapFromAllInOne(reasons)
		if isReadyUI(ui) then
			return ui
		end
	end

	local message = "UI bootstrap failed | " .. table.concat(reasons, " | ")
	logLine("ERROR", message)
	error(message)
end

local UI = bootstrapUI()
logLine("BOOT", "bootstrapUI success | mode=" .. tostring(UI and UI.mode or "unknown"))

local Rayfield = UI.Rayfield

local checkState = {
	pass = 0,
	fail = 0,
	logs = {}
}

local function report(pass, name, message)
	if pass then
		checkState.pass = checkState.pass + 1
		local line = "[PASS] " .. tostring(name)
		table.insert(checkState.logs, line)
		logLine("CHECK", line)
	else
		checkState.fail = checkState.fail + 1
		local line = "[FAIL] " .. tostring(name) .. " -> " .. tostring(message or "unknown")
		table.insert(checkState.logs, line)
		logLine("CHECK", line)
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

local okWindow, windowOrErr = pcall(Rayfield.CreateWindow, Rayfield, {
	Name = "Rayfield Mod | Elements Showcase",
	LoadingTitle = "Rayfield Mod Bundle",
	LoadingSubtitle = "Basic to Advanced Element Gallery",
	ConfigurationSaving = {
		Enabled = false
	},
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true
})
if not okWindow then
	local message = "CreateWindow failed: " .. tostring(windowOrErr)
	logLine("ERROR", message)
	error(message)
end
local window = windowOrErr
logLine("BOOT", "CreateWindow success")

local tabCore = window:CreateTab("Basic Elements", 4483362458)
local tabAdvanced = window:CreateTab("Advanced Elements", 4483362458)
local tabSettings = window:CreateTab("Experience & Theme", 4483362458)
local tabSystem = window:CreateTab("Share & Diagnostics", 4483362458)

local sampleLogConsole = nil
local function sampleLog(level, message)
	local safeLevel = tostring(level or "info")
	local safeMessage = tostring(message or "")
	logLine("LOG/" .. string.upper(safeLevel), safeMessage)
	print("[Elements-Showcase][" .. safeLevel .. "] " .. safeMessage)
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
tabCore:CreateParagraph({
	Title = "Basic Element Pack",
	Content = "This tab showcases the foundational controls: button, toggle, slider, input, dropdown, keybind, color picker, and toggle-with-keybind."
})

local elButton = tabCore:CreateButton({
	Name = "Standard Button",
	Callback = function()
		runtimeState.buttonClicks = runtimeState.buttonClicks + 1
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

local elToggleWithKeybind = tabCore:CreateToggle({
	Name = "Toggle + Embedded Keybind",
	CurrentValue = false,
	Keybind = {
		Enabled = true,
		CurrentKeybind = "LeftControl+T"
	},
	Callback = function(value)
		sampleLog("info", "Embedded keybind toggle => " .. tostring(value))
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
tabAdvanced:CreateParagraph({
	Title = "Advanced Element Pack",
	Content = "This tab covers expansion widgets, loading controls, media/gallery/chart/log widgets, and alias element factories."
})

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

local dragBarAlias = nil
if type(tabAdvanced.CreateDragBar) == "function" then
	dragBarAlias = tabAdvanced:CreateDragBar({
		Name = "DragBar Alias",
		Range = { 0, 100 },
		Increment = 1,
		CurrentValue = 35,
		ParentSection = advancedSection,
		Callback = function(value)
			sampleLog("info", "DragBar Alias => " .. tostring(value))
		end
	})
end

local sliderLiteAlias = nil
if type(tabAdvanced.CreateSliderLite) == "function" then
	sliderLiteAlias = tabAdvanced:CreateSliderLite({
		Name = "SliderLite Alias",
		Range = { 0, 100 },
		Increment = 1,
		CurrentValue = 35,
		ParentSection = advancedSection,
		Callback = function(value)
			sampleLog("info", "SliderLite Alias => " .. tostring(value))
		end
	})
end

local infoBarAlias = nil
if type(tabAdvanced.CreateInfoBar) == "function" then
	infoBarAlias = tabAdvanced:CreateInfoBar({
		Name = "InfoBar Alias",
		Range = { 0, 100 },
		Increment = 1,
		CurrentValue = 35,
		ParentSection = advancedSection,
		Callback = function(value)
			sampleLog("info", "InfoBar Alias => " .. tostring(value))
		end
	})
end

local sliderDisplayAlias = nil
if type(tabAdvanced.CreateSliderDisplay) == "function" then
	sliderDisplayAlias = tabAdvanced:CreateSliderDisplay({
		Name = "SliderDisplay Alias",
		Range = { 0, 100 },
		Increment = 1,
		CurrentValue = 35,
		ParentSection = advancedSection,
		Callback = function(value)
			sampleLog("info", "SliderDisplay Alias => " .. tostring(value))
		end
	})
end

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
		if dragBarAlias and dragBarAlias.Set then
			dragBarAlias:Set(numeric)
		end
		if sliderLiteAlias and sliderLiteAlias.Set then
			sliderLiteAlias:Set(numeric)
		end
		if infoBarAlias and infoBarAlias.Set then
			infoBarAlias:Set(numeric)
		end
		if sliderDisplayAlias and sliderDisplayAlias.Set then
			sliderDisplayAlias:Set(numeric)
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
	sampleLog("info", "Advanced elements tab initialized.")
end

-- Settings tab
tabSettings:CreateParagraph({
	Title = "Experience API Controls",
	Content = "Use this tab to test UI preset, transition profile, onboarding, and Theme Studio integration."
})

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
tabSystem:CreateParagraph({
	Title = "Share Code + Diagnostics",
	Content = "This tab demonstrates export/import share code workflow and control registry diagnostics."
})

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

local function runShowcaseChecks()
	logLine("BOOT", "runShowcaseChecks begin")
	runCheck("All-in-one services ready", function()
		if UI.mode == "base" or UI.mode == "global" then
			return true
		end
		return type(UI.ErrorManager) == "table"
			and type(UI.GarbageCollector) == "table"
			and type(UI.RemoteProtection) == "table"
			and type(UI.MemoryLeakDetector) == "table"
			and type(UI.Profiler) == "table"
	end)

	runCheck("Basic tab has baseline controls", function()
		local list = tabCore:GetElements()
		return type(list) == "table" and #list >= 8
	end)

	runCheck("Advanced tab has rich controls", function()
		local list = tabAdvanced:GetElements()
		return type(list) == "table" and #list >= 12
	end)

	runCheck("Experience/Diagnostics tabs populated", function()
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

	runCheck("Alias element variants available (if supported)", function()
		if type(tabAdvanced.CreateDragBar) ~= "function" then
			return true
		end
		return type(dragBarAlias) == "table"
			and type(sliderLiteAlias) == "table"
			and type(infoBarAlias) == "table"
			and type(sliderDisplayAlias) == "table"
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
			task.wait(30)
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
	logLine("CHECK", summary)
	Rayfield:Notify({
		Title = "Elements Showcase",
		Content = checkState.fail == 0 and summary or (summary .. " (see console)"),
		Duration = checkState.fail == 0 and 8 or 10
	})

	for _, line in ipairs(checkState.logs) do
		print(line)
	end
end

task.spawn(function()
	local ok, err = pcall(runShowcaseChecks)
	if not ok then
		logLine("ERROR", "checks failed: " .. tostring(err))
		warn("[Elements-Showcase] checks failed: " .. tostring(err))
	end
end)

local compactReturn = type(_G) ~= "table" or _G.__RAYFIELD_SHOWCASE_RETURN_FULL ~= true
if compactReturn then
	logLine("BOOT", "return compact payload")
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
		CheckState = checkState,
		RuntimeState = runtimeState,
		SettingsState = settingsState,
		LogPath = ShowcaseLogger.path,
		LatestLogPath = ShowcaseLogger.latestPath,
		LogInfo = type(_G) == "table" and _G.__RAYFIELD_SHOWCASE_LOG_INFO or nil
	}
end

logLine("BOOT", "return full payload")
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
			ToggleWithKeybind = elToggleWithKeybind,
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
			DragBarAlias = dragBarAlias,
			SliderLiteAlias = sliderLiteAlias,
			InfoBarAlias = infoBarAlias,
			SliderDisplayAlias = sliderDisplayAlias,
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
	SettingsState = settingsState,
	LogPath = ShowcaseLogger.path,
	LatestLogPath = ShowcaseLogger.latestPath,
	LogInfo = type(_G) == "table" and _G.__RAYFIELD_SHOWCASE_LOG_INFO or nil
}
