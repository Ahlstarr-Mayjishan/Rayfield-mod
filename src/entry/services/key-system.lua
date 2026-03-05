local KeySystemService = {}

local function noop()
	return
end

local function resolveKeyUi(useStudio, scriptRef, requestObjects)
	if useStudio and scriptRef and scriptRef.Parent and type(scriptRef.Parent.FindFirstChild) == "function" then
		return scriptRef.Parent:FindFirstChild("Key")
	end
	if type(requestObjects) ~= "function" then
		return nil
	end
	local okObjects, objectsOrErr = pcall(requestObjects, "rbxassetid://11380036235")
	if not okObjects or type(objectsOrErr) ~= "table" then
		return nil
	end
	return objectsOrErr[1]
end

local function createCloseAnimator(options)
	local animation = options.animation
	local tweenInfo = options.tweenInfo
	local enumTable = options.enumTable

	local function animate(target, duration, style, props)
		if not target or type(target) ~= "userdata" and type(target) ~= "table" then
			return
		end
		if type(animation) ~= "table" or type(animation.Create) ~= "function" then
			return
		end
		if type(tweenInfo) ~= "table" or type(tweenInfo.new) ~= "function" then
			return
		end
		if type(enumTable) ~= "table"
			or type(enumTable.EasingStyle) ~= "table"
			or enumTable.EasingStyle[style] == nil then
			return
		end
		local okTween, tweenOrErr = pcall(animation.Create, animation, target, tweenInfo.new(duration, enumTable.EasingStyle[style]), props)
		if okTween and tweenOrErr and type(tweenOrErr.Play) == "function" then
			pcall(tweenOrErr.Play, tweenOrErr)
		end
	end

	return function(keyMain)
		if not keyMain then
			return
		end
		animate(keyMain, 0.6, "Exponential", { BackgroundTransparency = 1 })
		animate(keyMain, 0.6, "Exponential", { Size = UDim2.new(0, 467, 0, 175) })
		if keyMain.Shadow and keyMain.Shadow.Image then
			animate(keyMain.Shadow.Image, 0.5, "Exponential", { ImageTransparency = 1 })
		end
		if keyMain.Title then
			animate(keyMain.Title, 0.4, "Exponential", { TextTransparency = 1 })
		end
		if keyMain.Subtitle then
			animate(keyMain.Subtitle, 0.5, "Exponential", { TextTransparency = 1 })
		end
		if keyMain.KeyNote then
			animate(keyMain.KeyNote, 0.5, "Exponential", { TextTransparency = 1 })
		end
		if keyMain.Input then
			animate(keyMain.Input, 0.5, "Exponential", { BackgroundTransparency = 1 })
			if keyMain.Input.UIStroke then
				animate(keyMain.Input.UIStroke, 0.5, "Exponential", { Transparency = 1 })
			end
			if keyMain.Input.InputBox then
				animate(keyMain.Input.InputBox, 0.5, "Exponential", { TextTransparency = 1 })
			end
		end
		if keyMain.NoteTitle then
			animate(keyMain.NoteTitle, 0.4, "Exponential", { TextTransparency = 1 })
		end
		if keyMain.NoteMessage then
			animate(keyMain.NoteMessage, 0.4, "Exponential", { TextTransparency = 1 })
		end
		if keyMain.Hide then
			animate(keyMain.Hide, 0.4, "Exponential", { ImageTransparency = 1 })
		end
	end
end

function KeySystemService.create(options)
	options = type(options) == "table" and options or {}

	local ensureFolder = options.ensureFolder
	local callSafely = options.callSafely
	local isfileFn = options.isfileFn or isfile
	local readfileFn = options.readfileFn or readfile
	local writefileFn = options.writefileFn or writefile
	local rayfieldFolder = tostring(options.rayfieldFolder or "Rayfield")
	local configurationExtension = tostring(options.configurationExtension or ".rfld")
	local requestHttpGet = options.requestHttpGet
	local requestObjects = options.requestObjects
	local players = options.players
	local coreGui = options.coreGui
	local gameRef = options.gameRef or game
	local animation = options.animation
	local tweenInfo = options.tweenInfo or TweenInfo
	local enumTable = options.enumTable or Enum
	local taskLib = options.taskLib or task
	local printFn = type(options.print) == "function" and options.print or print
	local warnFn = type(options.warn) == "function" and options.warn or warn
	local defaultUseStudio = options.useStudio == true

	local closeKeyMain = createCloseAnimator({
		animation = animation,
		tweenInfo = tweenInfo,
		enumTable = enumTable
	})

	local service = {}

	function service.handle(settings, runtimeOptions)
		settings = type(settings) == "table" and settings or {}
		runtimeOptions = type(runtimeOptions) == "table" and runtimeOptions or {}

		local setPassthrough = type(runtimeOptions.setPassthrough) == "function" and runtimeOptions.setPassthrough or noop
		local useStudio = defaultUseStudio
		if runtimeOptions.useStudio ~= nil then
			useStudio = runtimeOptions.useStudio == true
		end
		local scriptRef = runtimeOptions.scriptRef
		local compatibility = runtimeOptions.compatibility
		local rayfield = runtimeOptions.rayfield
		local rayfieldLibrary = runtimeOptions.rayfieldLibrary

		if settings.KeySystem ~= true then
			return { handled = false }
		end
		if type(settings.KeySettings) ~= "table" then
			setPassthrough(true)
			return {
				handled = true,
				abortWindowCreation = true,
				reason = "missing_key_settings"
			}
		end

		if type(ensureFolder) == "function" then
			ensureFolder(rayfieldFolder .. "/Key System")
		end

		if type(settings.KeySettings.Key) == "string" then
			settings.KeySettings.Key = { settings.KeySettings.Key }
		end
		if type(settings.KeySettings.Key) ~= "table" then
			settings.KeySettings.Key = {}
		end

		if settings.KeySettings.GrabKeyFromSite then
			for index, keyUrl in ipairs(settings.KeySettings.Key) do
				local success, response = pcall(function()
					if type(requestHttpGet) ~= "function" then
						error("HttpGet unavailable")
					end
					local fetched = tostring(requestHttpGet(keyUrl) or "")
					fetched = fetched:gsub("[\n\r]", " ")
					fetched = string.gsub(fetched, " ", "")
					settings.KeySettings.Key[index] = fetched
				end)
				if not success then
					printFn("Rayfield | " .. tostring(keyUrl) .. " Error " .. tostring(response))
					warnFn("Check docs.sirius.menu for help with Rayfield specific development.")
				end
			end
		end

		if not settings.KeySettings.FileName then
			settings.KeySettings.FileName = "No file name specified"
		end

		local keyFilePath = rayfieldFolder .. "/Key System" .. "/" .. settings.KeySettings.FileName .. configurationExtension
		if type(callSafely) == "function" and callSafely(isfileFn, keyFilePath) then
			for _, expectedKey in ipairs(settings.KeySettings.Key) do
				local savedKeys = callSafely(readfileFn, keyFilePath)
				if savedKeys and string.find(savedKeys, expectedKey) then
					setPassthrough(true)
					break
				end
			end
		end

		local keyUi = nil
		local keyMain = nil
		local attemptsRemaining = math.random(2, 5)
		local hasPassthrough = false

		local function updatePassthrough(value)
			hasPassthrough = value == true
			setPassthrough(value == true)
		end

		if not hasPassthrough then
			if type(rayfield) == "table" then
				rayfield.Enabled = false
			end

			keyUi = resolveKeyUi(useStudio, scriptRef, requestObjects)
			if type(keyUi) ~= "table" and type(keyUi) ~= "userdata" then
				updatePassthrough(true)
				return {
					handled = true,
					reason = "missing_key_ui"
				}
			end

			keyUi.Enabled = true

			local keyUiContainer = nil
			if type(compatibility) == "table" and type(compatibility.protectAndParent) == "function" then
				keyUiContainer = compatibility.protectAndParent(keyUi, nil, {
					useStudio = useStudio
				})
			elseif not useStudio and coreGui then
				keyUi.Parent = coreGui
				keyUiContainer = coreGui
			end

			if type(compatibility) == "table" and type(compatibility.dedupeGuiByName) == "function" then
				compatibility.dedupeGuiByName(keyUiContainer, keyUi.Name, keyUi, "-Old")
			elseif not useStudio and keyUiContainer and type(keyUiContainer.GetChildren) == "function" then
				for _, interface in ipairs(keyUiContainer:GetChildren()) do
					if interface.Name == keyUi.Name and interface ~= keyUi then
						interface.Enabled = false
						interface.Name = "KeyUI-Old"
					end
				end
			end

			keyMain = keyUi.Main
			keyMain.Title.Text = settings.KeySettings.Title or settings.Name
			keyMain.Subtitle.Text = settings.KeySettings.Subtitle or "Key System"
			keyMain.NoteMessage.Text = settings.KeySettings.Note or "No instructions"

			keyMain.Size = UDim2.new(0, 467, 0, 175)
			keyMain.BackgroundTransparency = 1
			keyMain.Shadow.Image.ImageTransparency = 1
			keyMain.Title.TextTransparency = 1
			keyMain.Subtitle.TextTransparency = 1
			keyMain.KeyNote.TextTransparency = 1
			keyMain.Input.BackgroundTransparency = 1
			keyMain.Input.UIStroke.Transparency = 1
			keyMain.Input.InputBox.TextTransparency = 1
			keyMain.NoteTitle.TextTransparency = 1
			keyMain.NoteMessage.TextTransparency = 1
			keyMain.Hide.ImageTransparency = 1

			animation:Create(keyMain, tweenInfo.new(0.6, enumTable.EasingStyle.Exponential), { BackgroundTransparency = 0 }):Play()
			animation:Create(keyMain, tweenInfo.new(0.6, enumTable.EasingStyle.Exponential), { Size = UDim2.new(0, 500, 0, 187) }):Play()
			animation:Create(keyMain.Shadow.Image, tweenInfo.new(0.5, enumTable.EasingStyle.Exponential), { ImageTransparency = 0.5 }):Play()
			taskLib.wait(0.05)
			animation:Create(keyMain.Title, tweenInfo.new(0.4, enumTable.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			animation:Create(keyMain.Subtitle, tweenInfo.new(0.5, enumTable.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			taskLib.wait(0.05)
			animation:Create(keyMain.KeyNote, tweenInfo.new(0.5, enumTable.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			animation:Create(keyMain.Input, tweenInfo.new(0.5, enumTable.EasingStyle.Exponential), { BackgroundTransparency = 0 }):Play()
			animation:Create(keyMain.Input.UIStroke, tweenInfo.new(0.5, enumTable.EasingStyle.Exponential), { Transparency = 0 }):Play()
			animation:Create(keyMain.Input.InputBox, tweenInfo.new(0.5, enumTable.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			taskLib.wait(0.05)
			animation:Create(keyMain.NoteTitle, tweenInfo.new(0.4, enumTable.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			animation:Create(keyMain.NoteMessage, tweenInfo.new(0.4, enumTable.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			taskLib.wait(0.15)
			animation:Create(keyMain.Hide, tweenInfo.new(0.4, enumTable.EasingStyle.Exponential), { ImageTransparency = 0.3 }):Play()

			keyUi.Main.Input.InputBox.FocusLost:Connect(function()
				if #keyUi.Main.Input.InputBox.Text == 0 then
					return
				end
				local keyFound = false
				local foundKey = ""
				for _, expectedKey in ipairs(settings.KeySettings.Key) do
					if keyMain.Input.InputBox.Text == expectedKey then
						keyFound = true
						foundKey = expectedKey
					end
				end
				if keyFound then
					closeKeyMain(keyMain)
					taskLib.wait(0.51)
					updatePassthrough(true)
					keyMain.Visible = false
					if settings.KeySettings.SaveKey then
						if type(callSafely) == "function" then
							callSafely(writefileFn, keyFilePath, foundKey)
						end
						if type(rayfieldLibrary) == "table" and type(rayfieldLibrary.Notify) == "function" then
							rayfieldLibrary:Notify({
								Title = "Key System",
								Content = "The key for this script has been saved successfully.",
								Image = 3605522284
							})
						end
					end
				else
					if attemptsRemaining == 0 then
						closeKeyMain(keyMain)
						taskLib.wait(0.45)
						if players and players.LocalPlayer and type(players.LocalPlayer.Kick) == "function" then
							pcall(players.LocalPlayer.Kick, players.LocalPlayer, "No Attempts Remaining")
						end
						if gameRef and type(gameRef.Shutdown) == "function" then
							pcall(gameRef.Shutdown, gameRef)
						end
						return
					end
					keyMain.Input.InputBox.Text = ""
					attemptsRemaining = attemptsRemaining - 1
					animation:Create(keyMain, tweenInfo.new(0.6, enumTable.EasingStyle.Exponential), { Size = UDim2.new(0, 467, 0, 175) }):Play()
					animation:Create(keyMain, tweenInfo.new(0.4, enumTable.EasingStyle.Elastic), { Position = UDim2.new(0.495, 0, 0.5, 0) }):Play()
					taskLib.wait(0.1)
					animation:Create(keyMain, tweenInfo.new(0.4, enumTable.EasingStyle.Elastic), { Position = UDim2.new(0.505, 0, 0.5, 0) }):Play()
					taskLib.wait(0.1)
					animation:Create(keyMain, tweenInfo.new(0.4, enumTable.EasingStyle.Exponential), { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
					animation:Create(keyMain, tweenInfo.new(0.6, enumTable.EasingStyle.Exponential), { Size = UDim2.new(0, 500, 0, 187) }):Play()
				end
			end)

			keyMain.Hide.MouseButton1Click:Connect(function()
				closeKeyMain(keyMain)
				taskLib.wait(0.51)
				if type(rayfieldLibrary) == "table" and type(rayfieldLibrary.Destroy) == "function" then
					rayfieldLibrary:Destroy()
				end
				if keyUi and type(keyUi.Destroy) == "function" then
					keyUi:Destroy()
				end
			end)
		else
			updatePassthrough(true)
		end

		return {
			handled = true,
			abortWindowCreation = false
		}
	end

	return service
end

return KeySystemService
