-- Rayfield Configuration Management Module
-- Handles configuration save/load and color packing

local ConfigModule = {}

function ConfigModule.init(ctx)
	local self = {}

	-- Inject dependencies
	self.HttpService = ctx.HttpService
	self.TweenService = ctx.TweenService
	self.RayfieldLibrary = ctx.RayfieldLibrary
	self.callSafely = ctx.callSafely
	self.ConfigurationFolder = ctx.ConfigurationFolder
	self.ConfigurationExtension = ctx.ConfigurationExtension
	self.getCFileName = ctx.getCFileName
	self.getCEnabled = ctx.getCEnabled
	self.getGlobalLoaded = ctx.getGlobalLoaded
	self.getLayoutSnapshot = ctx.getLayoutSnapshot
	self.applyLayoutSnapshot = ctx.applyLayoutSnapshot
	self.getElementsSystem = ctx.getElementsSystem
	self.layoutKey = tostring(ctx.layoutKey or "__rayfield_layout")
	self.useStudio = ctx.useStudio
	self.debugX = ctx.debugX

	-- Config load smoothing defaults
	local LOAD_CHUNK_THRESHOLD = 42
	local LOAD_BATCH_SIZE = 12
	local LOAD_BATCH_DELAY_SEC = 0.02
	local LOAD_TAB_GAP_DELAY_SEC = 0.03
	local LOAD_FADE_DURATION_SEC = 0.12
	local LOAD_FADE_DESCENDANT_LIMIT = 8

	-- Color packing/unpacking utilities
	local function PackColor(Color)
		return { R = Color.R * 255, G = Color.G * 255, B = Color.B * 255 }
	end

	local function UnpackColor(Color)
		return Color3.fromRGB(Color.R, Color.G, Color.B)
	end

	local function cloneValue(value)
		local shared = type(_G) == "table" and _G.__RayfieldSharedUtils or nil
		if type(shared) == "table" and type(shared.cloneTable) == "function" then
			return shared.cloneTable(value)
		end
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for key, nested in pairs(value) do
			out[key] = cloneValue(nested)
		end
		return out
	end

	local function valuesEqual(left, right)
		local shared = type(_G) == "table" and _G.__RayfieldSharedUtils or nil
		if type(shared) == "table" and type(shared.deepEqual) == "function" then
			return shared.deepEqual(left, right)
		end
		if left == right then
			return true
		end
		if type(left) ~= "table" or type(right) ~= "table" then
			return false
		end
		for key, value in pairs(left) do
			if not valuesEqual(value, right[key]) then
				return false
			end
		end
		for key in pairs(right) do
			if left[key] == nil then
				return false
			end
		end
		return true
	end

	local function getPersistValue(flag)
		if type(flag) ~= "table" then
			return nil
		end

		if flag.Type == "ColorPicker" and flag.Color then
			return PackColor(flag.Color)
		end

		if type(flag.GetPersistValue) == "function" then
			local ok, value = pcall(flag.GetPersistValue, flag)
			if ok then
				return cloneValue(value)
			end
		end

		local value = flag.CurrentValue
		if value == nil then
			value = flag.CurrentKeybind or flag.CurrentOption or flag.Color
		end
		return cloneValue(value)
	end

	local function resolveTabId(flag)
		if type(flag) ~= "table" then
			return "__global"
		end
		local tabId = rawget(flag, "__TabPersistenceId") or rawget(flag, "__TabId")
		if tabId == nil then
			return "__global"
		end
		return tostring(tabId)
	end

	local function resolveTabOrder(flag, tabId)
		if type(flag) == "table" then
			local tabOrder = tonumber(rawget(flag, "__TabLayoutOrder"))
			if tabOrder then
				return tabOrder
			end
		end
		if type(self.getElementsSystem) == "function" then
			local elementsSystem = self.getElementsSystem()
			if elementsSystem and type(elementsSystem.getTabLayoutOrderByPersistenceId) == "function" then
				local okOrder, tabOrder = pcall(elementsSystem.getTabLayoutOrderByPersistenceId, tabId)
				if okOrder and type(tabOrder) == "number" then
					return tabOrder
				end
			end
		end
		return math.huge
	end

	local function resolveElementOrder(flag)
		if type(flag) ~= "table" then
			return math.huge
		end
		return tonumber(rawget(flag, "__ElementLayoutOrder")) or math.huge
	end

	local function resolveFlagGuiObject(flag)
		if type(flag) ~= "table" then
			return nil
		end
		local guiObject = rawget(flag, "__GuiObject")
		if guiObject and guiObject.Parent then
			return guiObject
		end
		return nil
	end

	local function tweenProperty(instance, propertyName, fromValue, toValue, tweenInfo)
		if fromValue == nil or toValue == nil then
			return
		end
		local okSetFrom = pcall(function()
			instance[propertyName] = fromValue
		end)
		if not okSetFrom then
			return
		end
		local okTween, tween = pcall(function()
			return self.TweenService:Create(instance, tweenInfo, {
				[propertyName] = toValue
			})
		end)
		if okTween and tween then
			tween:Play()
		end
	end

	local function fadeElementVisual(guiObject)
		if not (self.TweenService and type(self.TweenService.Create) == "function") then
			return
		end
		if not (guiObject and guiObject.Parent and guiObject:IsA("GuiObject")) then
			return
		end
		if guiObject.Visible == false then
			return
		end

		local tweenInfo = TweenInfo.new(LOAD_FADE_DURATION_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local okBg, bgTransparency = pcall(function()
			return guiObject.BackgroundTransparency
		end)
		if okBg and type(bgTransparency) == "number" and bgTransparency < 1 then
			local startValue = math.clamp(bgTransparency + 0.2, 0, 1)
			tweenProperty(guiObject, "BackgroundTransparency", startValue, bgTransparency, tweenInfo)
		end

		local function applyDescendantFade(descendant)
			if descendant:IsA("UIStroke") then
				local okStroke, strokeTransparency = pcall(function()
					return descendant.Transparency
				end)
				if okStroke and type(strokeTransparency) == "number" and strokeTransparency < 1 then
					local startValue = math.clamp(strokeTransparency + 0.35, 0, 1)
					tweenProperty(descendant, "Transparency", startValue, strokeTransparency, tweenInfo)
					return true
				end
			elseif descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
				local okText, textTransparency = pcall(function()
					return descendant.TextTransparency
				end)
				if okText and type(textTransparency) == "number" and textTransparency < 1 then
					local startValue = math.clamp(textTransparency + 0.35, 0, 1)
					tweenProperty(descendant, "TextTransparency", startValue, textTransparency, tweenInfo)
					return true
				end
			elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
				local okImage, imageTransparency = pcall(function()
					return descendant.ImageTransparency
				end)
				if okImage and type(imageTransparency) == "number" and imageTransparency < 1 then
					local startValue = math.clamp(imageTransparency + 0.35, 0, 1)
					tweenProperty(descendant, "ImageTransparency", startValue, imageTransparency, tweenInfo)
					return true
				end
			end
			return false
		end

		local processedDescendants = 0
		for _, child in ipairs(guiObject:GetChildren()) do
			if processedDescendants >= LOAD_FADE_DESCENDANT_LIMIT then
				break
			end
			if applyDescendantFade(child) then
				processedDescendants += 1
			end
			if processedDescendants >= LOAD_FADE_DESCENDANT_LIMIT then
				break
			end
			for _, grandChild in ipairs(child:GetChildren()) do
				if processedDescendants >= LOAD_FADE_DESCENDANT_LIMIT then
					break
				end
				if applyDescendantFade(grandChild) then
					processedDescendants += 1
				end
			end
		end
	end

	local function collectLoadEntries(Data)
		local entries = {}

		for FlagName, Flag in pairs(self.RayfieldLibrary.Flags) do
			local FlagValue = Data[FlagName]
			if FlagValue ~= nil then
				local tabId = resolveTabId(Flag)
				table.insert(entries, {
					flagName = FlagName,
					flag = Flag,
					rawValue = FlagValue,
					tabId = tabId,
					tabOrder = resolveTabOrder(Flag, tabId),
					elementOrder = resolveElementOrder(Flag),
					guiObject = resolveFlagGuiObject(Flag)
				})
			else
				warn("Rayfield | Unable to find '" .. tostring(FlagName) .. "' in the save file.")
				print("The error above may not be an issue if new elements have been added or not been set values.")
			end
		end

		table.sort(entries, function(left, right)
			if left.tabOrder ~= right.tabOrder then
				return left.tabOrder < right.tabOrder
			end
			if left.tabId ~= right.tabId then
				return tostring(left.tabId) < tostring(right.tabId)
			end
			if left.elementOrder ~= right.elementOrder then
				return left.elementOrder < right.elementOrder
			end
			return tostring(left.flagName) < tostring(right.flagName)
		end)

		return entries
	end

	local function groupEntriesByTab(entries)
		local groupsByTab = {}
		local groups = {}

		for _, entry in ipairs(entries) do
			local group = groupsByTab[entry.tabId]
			if not group then
				group = {
					tabId = entry.tabId,
					tabOrder = entry.tabOrder,
					entries = {}
				}
				groupsByTab[entry.tabId] = group
				table.insert(groups, group)
			end
			table.insert(group.entries, entry)
		end

		table.sort(groups, function(left, right)
			if left.tabOrder ~= right.tabOrder then
				return left.tabOrder < right.tabOrder
			end
			return tostring(left.tabId) < tostring(right.tabId)
		end)

		return groups
	end

	local function applyFlagValue(entry)
		local flagName = entry.flagName
		local flag = entry.flag
		local flagValue = entry.rawValue
		local beforeValue = getPersistValue(flag)
		local nextValue = cloneValue(flagValue)
		if flag.Type == "ColorPicker" and type(flagValue) == "table" then
			nextValue = UnpackColor(flagValue)
		end
		if type(flag.Set) == "function" then
			local okSet, errSet = pcall(flag.Set, flag, nextValue)
			if not okSet then
				warn("Rayfield | Failed to apply flag '" .. tostring(flagName) .. "': " .. tostring(errSet))
			end
		else
			warn("Rayfield | Flag '" .. tostring(flagName) .. "' is missing Set()")
		end
		local afterValue = getPersistValue(flag)
		return not valuesEqual(beforeValue, afterValue)
	end

	local function applyConfigurationData(Data)
		if type(Data) ~= "table" then
			warn("Rayfield | Configuration data must be a table.")
			return false
		end

		local changed = false
		local entries = collectLoadEntries(Data)
		local groupedByTab = groupEntriesByTab(entries)
		local heavyLoad = #entries >= LOAD_CHUNK_THRESHOLD
		local processedInBatch = 0

		for _, group in ipairs(groupedByTab) do
			for _, entry in ipairs(group.entries) do
				if applyFlagValue(entry) then
					changed = true
				end
				fadeElementVisual(entry.guiObject)

				if heavyLoad then
					processedInBatch += 1
					if processedInBatch >= LOAD_BATCH_SIZE then
						processedInBatch = 0
						task.wait(LOAD_BATCH_DELAY_SEC)
					end
				end
			end

			if heavyLoad then
				task.wait(LOAD_TAB_GAP_DELAY_SEC)
			end
		end

		if type(self.applyLayoutSnapshot) == "function" then
			local LayoutData = Data[self.layoutKey]
			if type(LayoutData) == "table" then
				local okLayout, layoutErr = pcall(self.applyLayoutSnapshot, LayoutData)
				if not okLayout then
					warn("Rayfield | Failed to apply layout data: " .. tostring(layoutErr))
				end
			end
		end

		return changed
	end

	-- Load configuration from JSON string
	local function LoadConfiguration(Configuration)
		local success, Data = pcall(function()
			return self.HttpService:JSONDecode(Configuration)
		end)

		if not success then
			warn("Rayfield had an issue decoding the configuration file, please try delete the file and reopen Rayfield.")
			return
		end

		return applyConfigurationData(Data)
	end

	local function buildConfigurationData()
		local Data = {}
		for flagName, flag in pairs(self.RayfieldLibrary.Flags) do
			Data[flagName] = getPersistValue(flag)
		end

		if type(self.getLayoutSnapshot) == "function" then
			local okLayout, layoutSnapshot = pcall(self.getLayoutSnapshot)
			if okLayout and type(layoutSnapshot) == "table" then
				Data[self.layoutKey] = cloneValue(layoutSnapshot)
			end
		end

		return Data
	end

	local function persistConfigurationData(Data)
		local okEncode, encodedOrErr = pcall(function()
			return self.HttpService:JSONEncode(Data)
		end)
		if not okEncode then
			warn("Rayfield | Failed to encode configuration data: " .. tostring(encodedOrErr))
			return false
		end

		local encoded = tostring(encodedOrErr)

		if self.useStudio then
			if script.Parent:FindFirstChild("configuration") then
				script.Parent.configuration:Destroy()
			end

			local ScreenGui = Instance.new("ScreenGui")
			ScreenGui.Parent = script.Parent
			ScreenGui.Name = "configuration"

			local TextBox = Instance.new("TextBox")
			TextBox.Parent = ScreenGui
			TextBox.Size = UDim2.new(0, 800, 0, 50)
			TextBox.AnchorPoint = Vector2.new(0.5, 0)
			TextBox.Position = UDim2.new(0.5, 0, 0, 30)
			TextBox.Text = encoded
			TextBox.ClearTextOnFocus = false
		end

		if self.debugX then
			warn(encoded)
		end

		if type(writefile) ~= "function" then
			return self.useStudio == true
		end

		if isfolder and makefolder and not self.callSafely(isfolder, self.ConfigurationFolder) then
			self.callSafely(makefolder, self.ConfigurationFolder)
		end

		local writeResult = self.callSafely(
			writefile,
			self.ConfigurationFolder .. "/" .. self.getCFileName() .. self.ConfigurationExtension,
			encoded
		)
		return writeResult ~= false
	end

	local function ExportConfigurationData()
		return cloneValue(buildConfigurationData())
	end

	local function ImportConfigurationData(dataTable)
		if type(dataTable) ~= "table" then
			return false, "Configuration data must be a table."
		end

		local okApply, changedOrErr = pcall(function()
			return applyConfigurationData(cloneValue(dataTable))
		end)
		if not okApply then
			return false, tostring(changedOrErr)
		end

		return true, changedOrErr == true
	end

	-- Save configuration to file
	local function SaveConfiguration()
		if not self.getCEnabled() or not self.getGlobalLoaded() then
			return
		end

		if self.debugX then
			print("Saving")
		end

		local Data = buildConfigurationData()
		persistConfigurationData(Data)
	end

	local function SaveConfigurationForced()
		local Data = buildConfigurationData()
		return persistConfigurationData(Data)
	end

	-- Export functions
	self.PackColor = PackColor
	self.UnpackColor = UnpackColor
	self.LoadConfiguration = LoadConfiguration
	self.SaveConfiguration = SaveConfiguration
	self.ExportConfigurationData = ExportConfigurationData
	self.ImportConfigurationData = ImportConfigurationData
	self.SaveConfigurationForced = SaveConfigurationForced
	self.setLayoutHandlers = function(getSnapshotFn, applySnapshotFn, layoutKey)
		self.getLayoutSnapshot = getSnapshotFn
		self.applyLayoutSnapshot = applySnapshotFn
		if type(layoutKey) == "string" and layoutKey ~= "" then
			self.layoutKey = layoutKey
		end
	end

	return self
end

return ConfigModule
