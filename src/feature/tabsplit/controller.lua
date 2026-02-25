-- Rayfield Tab Split Module
-- Handles long-hold tab split into secondary panels (non-float detached windows)

local TabSplitModule = {}
local compileString = loadstring or load
if not compileString then
	error("No Lua compiler function available (loadstring/load)")
end

local MODULE_ROOT_URL = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local function loadSubmodule(localName, relativePath)
	local useStudio = false
	local okRun, runService = pcall(function()
		return game:GetService("RunService")
	end)
	if okRun and runService then
		local okStudio, studio = pcall(function()
			return runService:IsStudio()
		end)
		useStudio = okStudio and studio or false
	end

	if useStudio then
		local okRequire, module = pcall(function()
			return require(script.Parent[localName])
		end)
		if okRequire and module then
			return module
		end
	end

	return compileString(game:HttpGet(MODULE_ROOT_URL .. relativePath))()
end

local TabSplitStateLib = loadSubmodule("state", "src/feature/tabsplit/state.lua")
local TabSplitPanelLib = loadSubmodule("panel", "src/feature/tabsplit/panel.lua")
local TabSplitDragDockLib = loadSubmodule("dragdock", "src/feature/tabsplit/dragdock.lua")
local TabSplitReorderLib = loadSubmodule("reorder_tab_split", "src/feature/tabsplit/reorder_tab_split.lua")

function TabSplitModule.init(ctx)
	local self = {}

	self.UserInputService = ctx.UserInputService
	self.RunService = ctx.RunService
	self.TweenService = ctx.TweenService
	self.Animation = ctx.Animation or ctx.TweenService
	self.HttpService = ctx.HttpService
	self.Rayfield = ctx.Rayfield
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.TabList = ctx.TabList
	self.Elements = ctx.Elements
	self.getSelectedTheme = ctx.getSelectedTheme
	self.rayfieldDestroyed = ctx.rayfieldDestroyed
	self.useMobileSizing = ctx.useMobileSizing
	self.Notify = ctx.Notify
	self.getBlockedState = ctx.getBlockedState

	local enabled = ctx.enabled ~= false
	local holdDuration = tonumber(ctx.holdDuration) or 3
	if holdDuration < 0.5 then
		holdDuration = 0.5
	end

	local allowSettingsSplit = ctx.allowSettingsSplit == true
	local maxSplitTabs = tonumber(ctx.maxSplitTabs)
	if maxSplitTabs and maxSplitTabs < 1 then
		maxSplitTabs = nil
	end

	local splitRoot = nil
	local splitPanels = {}
	local tabToPanel = {}
	local panelOrder = {}
	local tabRecords = {}
	local tabGestureCleanup = {}
	local splitHidden = false
	local splitMinimized = false
	local splitIndex = 0
	local layoutDirtyCallback = type(ctx.onLayoutDirty) == "function" and ctx.onLayoutDirty or nil
	local viewportVirtualization = ctx.ViewportVirtualization

	local rootConnections = {}
	local tabZIndexState = setmetatable({}, { __mode = "k" })

	local DRAG_THRESHOLD = 4
	local PANEL_MARGIN = 8
	local TAB_GHOST_FOLLOW_SPEED = 0.24
	local TAB_CUE_HOVER_TRANSPARENCY = 0.52
	local TAB_CUE_HOLD_TRANSPARENCY = 0.34
	local TAB_CUE_READY_TRANSPARENCY = 0.24
	local TAB_CUE_IDLE_THICKNESS = 1
	local TAB_CUE_HOVER_THICKNESS = 1.35
	local TAB_CUE_HOLD_THICKNESS = 1.9
	local TAB_CUE_READY_THICKNESS = 2.2
	local REDUCED_EFFECTS = self.useMobileSizing == true

	local function notifyLayoutDirty(reason)
		if type(layoutDirtyCallback) ~= "function" then
			return
		end
		pcall(layoutDirtyCallback, "tabsplit", reason or "tabsplit_layout_changed")
	end

	local stateManager = TabSplitStateLib.create({
		UserInputService = self.UserInputService,
		Main = self.Main,
		TabList = self.TabList
	})

	local function isDestroyed()
		return self.rayfieldDestroyed and self.rayfieldDestroyed()
	end

	local function isBlocked()
		if isDestroyed() then
			return true
		end
		if type(self.getBlockedState) == "function" then
			local ok, result = pcall(self.getBlockedState)
			if ok and result then
				return true
			end
		end
		return false
	end

	local function safeNotify(data)
		if type(self.Notify) == "function" then
			pcall(self.Notify, data)
		end
	end

	local function ensureSharedInput()
		stateManager.ensureSharedInput()
	end

	local function registerSharedInput(id, onChanged, onEnded)
		stateManager.registerSharedInput(id, onChanged, onEnded)
	end

	local function unregisterSharedInput(id)
		stateManager.unregisterSharedInput(id)
	end

	local function disconnectSharedInput()
		stateManager.disconnectSharedInput()
	end

	local function getInputPosition(input)
		return stateManager.getInputPosition(input)
	end

	local function isPointInside(guiObject, point, padding)
		return stateManager.isPointInside(guiObject, point, padding)
	end

	local function isPointInsideMain(point)
		return stateManager.isPointInsideMain(point)
	end

	local function isPointInsideTabList(point)
		return stateManager.isPointInsideTabList(point)
	end

	local function clampPositionToViewport(root, desiredPosition, panelSize)
		return stateManager.clampPositionToViewport(root, desiredPosition, panelSize, PANEL_MARGIN)
	end

	local function hasZIndex(guiObject)
		return stateManager.hasZIndex(guiObject)
	end

	local function getOriginalZState(tabRecord)
		local state = tabZIndexState[tabRecord]
		if state then
			return state
		end

		state = {
			Original = setmetatable({}, { __mode = "k" }),
			DescendantConn = nil,
			LastBaseZ = 200,
			LastAppliedBase = nil
		}
		tabZIndexState[tabRecord] = state
		return state
	end

	local function captureOriginalZIndex(tabRecord)
		if not (tabRecord and tabRecord.TabPage) then
			return
		end

		local state = getOriginalZState(tabRecord)
		local objects = { tabRecord.TabPage }
		for _, descendant in ipairs(tabRecord.TabPage:GetDescendants()) do
			table.insert(objects, descendant)
		end

		for _, object in ipairs(objects) do
			if hasZIndex(object) and state.Original[object] == nil then
				state.Original[object] = object.ZIndex
			end
		end
	end

	local function applySplitZIndex(tabRecord, zBase)
		if not (tabRecord and tabRecord.TabPage) then
			return
		end

		local state = getOriginalZState(tabRecord)
		local nextBase = zBase or state.LastBaseZ or 200
		state.LastBaseZ = nextBase

		captureOriginalZIndex(tabRecord)

		if state.LastAppliedBase ~= nextBase then
			for object, original in pairs(state.Original) do
				if object and object.Parent and hasZIndex(object) then
					object.ZIndex = nextBase + original
				end
			end
			state.LastAppliedBase = nextBase
		end

		if not state.DescendantConn then
			state.DescendantConn = tabRecord.TabPage.DescendantAdded:Connect(function(descendant)
				if not tabRecord.IsSplit then
					return
				end
				if not hasZIndex(descendant) then
					return
				end
				if state.Original[descendant] == nil then
					state.Original[descendant] = descendant.ZIndex
				end
				descendant.ZIndex = state.LastBaseZ + state.Original[descendant]
			end)
		end
	end

	local function restoreOriginalZIndex(tabRecord)
		local state = tabZIndexState[tabRecord]
		if not state then
			return
		end

		if state.DescendantConn then
			state.DescendantConn:Disconnect()
			state.DescendantConn = nil
		end

		for object, original in pairs(state.Original) do
			if object and object.Parent and hasZIndex(object) then
				object.ZIndex = original
			end
		end

		tabZIndexState[tabRecord] = nil
	end

	local function getPanelSize(root)
		local viewport = root.AbsoluteSize
		local mainSize = self.Main.AbsoluteSize

		local panelWidth = math.clamp(math.floor(mainSize.X * 0.68), 250, 420)
		local panelHeight = math.clamp(math.floor(mainSize.Y), 180, math.max(180, viewport.Y - 12))
		return Vector2.new(panelWidth, panelHeight)
	end

	local function setPanelLayer(panelData, baseZ)
		panelData.LayerZ = baseZ
		panelData.Frame.ZIndex = baseZ
		panelData.Header.ZIndex = baseZ + 1
		panelData.Content.ZIndex = baseZ + 1
		panelData.Title.ZIndex = baseZ + 2
		panelData.DockButton.ZIndex = baseZ + 2
		applySplitZIndex(panelData.TabRecord, baseZ + 2)
	end

	local setPanelHoverState
	local applyPanelTheme

	local function ensureSplitRoot()
		if splitRoot and splitRoot.Parent then
			return splitRoot
		end

		splitRoot = Instance.new("Frame")
		splitRoot.Name = "TabSplitRoot"
		splitRoot.BackgroundTransparency = 1
		splitRoot.BorderSizePixel = 0
		splitRoot.Size = UDim2.fromScale(1, 1)
		splitRoot.ZIndex = 180
		splitRoot.Visible = (not splitHidden) and (not splitMinimized)
		splitRoot.Parent = self.Rayfield

		table.insert(rootConnections, self.Main:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			self.layoutPanels()
		end))
		table.insert(rootConnections, self.Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self.layoutPanels()
		end))
		table.insert(rootConnections, self.Rayfield:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self.layoutPanels()
		end))
		table.insert(rootConnections, self.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			for _, panelData in pairs(splitPanels) do
				if panelData then
					applyPanelTheme(panelData)
				end
			end
		end))

		return splitRoot
	end

	local function refreshRootVisibility()
		if splitRoot and splitRoot.Parent then
			splitRoot.Visible = (not splitHidden) and (not splitMinimized)
		end
	end

	if enabled then
		task.defer(function()
			if isDestroyed() then
				return
			end
			ensureSplitRoot()
			refreshRootVisibility()
		end)
	end

	local function createGhost(text, position)
		local root = ensureSplitRoot()
		local theme = self.getSelectedTheme and self.getSelectedTheme()

		local ghost = Instance.new("Frame")
		ghost.Name = "TabSplitGhost"
		ghost.BackgroundColor3 = (theme and theme.ElementBackground) or Color3.fromRGB(35, 35, 35)
		ghost.BackgroundTransparency = 0.18
		ghost.BorderSizePixel = 0
		ghost.Size = UDim2.fromOffset(170, 28)
		ghost.Position = UDim2.fromOffset(position.X - 85, position.Y - 14)
		ghost.ZIndex = 240
		ghost.Parent = root

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = ghost

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.2
		stroke.Transparency = 0.2
		stroke.Color = (theme and theme.ElementStroke) or Color3.fromRGB(90, 90, 90)
		stroke.Parent = ghost

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -10, 1, 0)
		label.Position = UDim2.new(0, 5, 0, 0)
		label.Text = text
		label.Font = Enum.Font.GothamSemibold
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = (theme and theme.TextColor) or Color3.fromRGB(255, 255, 255)
		label.ZIndex = ghost.ZIndex + 1
		label.Parent = ghost

		return ghost
	end

	local function updateGhostPosition(ghost, point)
		if ghost and ghost.Parent and point then
			ghost.Position = UDim2.fromOffset(point.X - math.floor(ghost.AbsoluteSize.X / 2), point.Y - math.floor(ghost.AbsoluteSize.Y / 2))
		end
	end

	local function clearGhost(ghost)
		if ghost and ghost.Parent then
			self.Animation:Create(ghost, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1
			}):Play()
			task.delay(0.09, function()
				if ghost and ghost.Parent then
					ghost:Destroy()
				end
			end)
		end
	end

	if enabled then
		task.defer(function()
			if isDestroyed() then
				return
			end
			local warmGhost = createGhost("", Vector2.new(-9999, -9999))
			if warmGhost then
				warmGhost:Destroy()
			end
		end)
	end

	local function getSplitPanelCount()
		return #panelOrder
	end

	local function canSplitTab(tabRecord)
		if not enabled then
			return false, "Tab split is disabled for this window."
		end
		if isBlocked() then
			return false, "Tab split is temporarily blocked while UI is busy."
		end
		if not tabRecord then
			return false, "Rayfield Mod: Invalid Tab ID in Splitter"
		end
		if tabRecord.IsSplit then
			return false, "This tab is already split."
		end
		if tabRecord.Name == "Rayfield Settings" and tabRecord.Ext and not allowSettingsSplit then
			return false, "Splitting Rayfield Settings is disabled."
		end
		if maxSplitTabs and getSplitPanelCount() >= maxSplitTabs then
			return false, "Reached max split tabs: " .. tostring(maxSplitTabs)
		end
		local dockedCount = 0
		for _, record in ipairs(tabRecords) do
			if not record.IsSplit and record.TabPage and record.TabPage.Parent == self.Elements then
				dockedCount += 1
			end
		end
		if dockedCount <= 1 then
			return false, "At least one tab must remain in main UI."
		end
		return true
	end

	local function chooseFallbackTab(excluded)
		for _, record in ipairs(tabRecords) do
			if record ~= excluded and not record.IsSplit and record.TabPage and record.TabPage.Parent == self.Elements then
				return record
			end
		end
		return nil
	end

	local function getTabPersistenceId(tabRecord)
		if not tabRecord then
			return nil
		end
		if type(tabRecord.PersistenceId) == "string" and tabRecord.PersistenceId ~= "" then
			return tabRecord.PersistenceId
		end
		if type(tabRecord.Name) == "string" and tabRecord.Name ~= "" then
			return tabRecord.Name
		end
		return nil
	end

	local function getVirtualHostId(tabRecord)
		local persistenceId = getTabPersistenceId(tabRecord)
		if not persistenceId then
			return nil
		end
		return "tab:" .. tostring(persistenceId)
	end

	local function virtualRegisterHost(tabRecord)
		if not (viewportVirtualization and type(viewportVirtualization.registerHost) == "function") then
			return
		end
		local hostId = getVirtualHostId(tabRecord)
		if hostId and tabRecord and tabRecord.TabPage and tabRecord.TabPage.Parent then
			pcall(viewportVirtualization.registerHost, hostId, tabRecord.TabPage, {
				mode = "auto"
			})
		end
	end

	local function virtualUnregisterHost(tabRecord)
		if not (viewportVirtualization and type(viewportVirtualization.unregisterHost) == "function") then
			return
		end
		local hostId = getVirtualHostId(tabRecord)
		if hostId then
			pcall(viewportVirtualization.unregisterHost, hostId)
		end
	end

	local function virtualRefreshHost(tabRecord, reason)
		if not (viewportVirtualization and type(viewportVirtualization.refreshHost) == "function") then
			return
		end
		local hostId = getVirtualHostId(tabRecord)
		if hostId then
			pcall(viewportVirtualization.refreshHost, hostId, reason or "tabsplit_refresh")
		end
	end

	local function virtualSetHostSuppressed(tabRecord, suppressed, reason)
		if not (viewportVirtualization and type(viewportVirtualization.setHostSuppressed) == "function") then
			return
		end
		local hostId = getVirtualHostId(tabRecord)
		if hostId then
			pcall(viewportVirtualization.setHostSuppressed, hostId, suppressed == true)
			if suppressed ~= true then
				pcall(viewportVirtualization.refreshHost, hostId, reason or "tabsplit_unsuppress")
			end
		end
	end

	setPanelHoverState = function(panelData, active, instant)
		if not (panelData and panelData.Frame and panelData.Frame.Parent) then
			return
		end

		panelData.HoverActive = active and true or false

		local theme = self.getSelectedTheme and self.getSelectedTheme()
		local accent = (theme and theme.SliderProgress) or Color3.fromRGB(112, 189, 255)
		local strokeColor = (theme and theme.ElementStroke) or Color3.fromRGB(85, 85, 85)

		if panelData.GlowStroke then
			panelData.GlowStroke.Color = accent
		end
		if panelData.SoftGlowStroke then
			panelData.SoftGlowStroke.Color = accent
		end
		if panelData.Stroke then
			panelData.Stroke.Color = active and accent:Lerp(strokeColor, 0.35) or strokeColor
		end

		local duration = instant and 0 or 0.12
		if panelData.Stroke then
			self.Animation:Create(panelData.Stroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = active and 1.35 or 1,
				Transparency = active and 0.22 or 0.35
			}):Play()
		end
		if panelData.GlowStroke then
			self.Animation:Create(panelData.GlowStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = active and 2.8 or 1.1,
				Transparency = active and 0.62 or 1
			}):Play()
		end
		if panelData.SoftGlowStroke then
			self.Animation:Create(panelData.SoftGlowStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = active and 4.6 or 2.8,
				Transparency = active and 0.84 or 1
			}):Play()
		end
	end

	applyPanelTheme = function(panelData)
		if not panelData then
			return
		end
		local theme = self.getSelectedTheme and self.getSelectedTheme()
		if not theme then
			return
		end

		panelData.Frame.BackgroundColor3 = theme.SecondaryElementBackground or panelData.Frame.BackgroundColor3
		panelData.Header.BackgroundColor3 = theme.Topbar or panelData.Header.BackgroundColor3
		panelData.Title.TextColor3 = theme.TextColor or panelData.Title.TextColor3
		panelData.DockButton.BackgroundColor3 = theme.ElementBackgroundHover or panelData.DockButton.BackgroundColor3
		panelData.DockButton.TextColor3 = theme.TextColor or panelData.DockButton.TextColor3
		setPanelHoverState(panelData, panelData.HoverActive or panelData.Dragging, true)
	end

	local function removePanelOrderEntry(panelId)
		if type(TabSplitReorderLib) == "table" and type(TabSplitReorderLib.removePanel) == "function" then
			local ok, removed = pcall(TabSplitReorderLib.removePanel, panelOrder, panelId)
			if ok then
				return removed == true
			end
		end

		for i = #panelOrder, 1, -1 do
			if panelOrder[i] == panelId then
				table.remove(panelOrder, i)
				return true
			end
		end
		return false
	end

	local function appendPanelOrderEntry(panelId)
		if type(TabSplitReorderLib) == "table" and type(TabSplitReorderLib.appendPanel) == "function" then
			local ok, appended = pcall(TabSplitReorderLib.appendPanel, panelOrder, panelId)
			if ok and appended then
				return true
			end
		end

		removePanelOrderEntry(panelId)
		table.insert(panelOrder, panelId)
		return true
	end

	local function removePanelRecord(panelId)
		removePanelOrderEntry(panelId)
		splitPanels[panelId] = nil
	end

	local function cleanupPanel(panelData)
		if not panelData then
			return
		end

		if panelData.InputId then
			unregisterSharedInput(panelData.InputId)
		end

		if panelData.Cleanup then
			for _, cleanupFn in ipairs(panelData.Cleanup) do
				pcall(cleanupFn)
			end
			table.clear(panelData.Cleanup)
		end

		if panelData.Frame and panelData.Frame.Parent then
			panelData.Frame:Destroy()
		end
	end

	local function bringPanelToFront(panelData)
		if not panelData then
			return
		end

		if type(TabSplitReorderLib) == "table" and type(TabSplitReorderLib.bringToFront) == "function" then
			local ok, moved = pcall(TabSplitReorderLib.bringToFront, panelOrder, panelData.Id)
			if not ok or not moved then
				appendPanelOrderEntry(panelData.Id)
			end
		else
			appendPanelOrderEntry(panelData.Id)
		end
		self.layoutPanels()
	end

	local function attachPanelDrag(panelData)
		TabSplitDragDockLib.attachPanelDrag(panelData, {
			dragThreshold = DRAG_THRESHOLD,
			isBlocked = isBlocked,
			getInputPosition = getInputPosition,
			isPointInside = isPointInside,
			bringPanelToFront = bringPanelToFront,
			setPanelHoverState = setPanelHoverState,
			isPointInsideTabList = isPointInsideTabList,
			dockTab = function(tabRecord)
				self.dockTab(tabRecord)
			end,
			ensureSplitRoot = ensureSplitRoot,
			getPanelSize = getPanelSize,
			clampPositionToViewport = clampPositionToViewport,
			layoutPanels = function()
				self.layoutPanels()
			end,
			registerSharedInput = registerSharedInput
		})
	end

	local function createPanelShell(tabRecord)
		local root = ensureSplitRoot()
		splitIndex += 1
		local panelId = self.HttpService:GenerateGUID(false) .. "-" .. tostring(splitIndex)
		local theme = self.getSelectedTheme and self.getSelectedTheme()
		local panelData = TabSplitPanelLib.createShell({
			root = root,
			panelId = panelId,
			tabRecord = tabRecord,
			theme = theme,
			inputId = self.HttpService:GenerateGUID(false),
			baseZ = 190,
			setPanelHoverState = setPanelHoverState
		})

		table.insert(panelData.Cleanup, panelData.DockButton.MouseButton1Click:Connect(function()
			self.dockTab(tabRecord)
		end))

		applyPanelTheme(panelData)
		attachPanelDrag(panelData)
		return panelData
	end

	function self.layoutPanels()
		if isDestroyed() then
			return
		end

		local root = ensureSplitRoot()
		if not root or not root.Parent then
			return
		end

		if #panelOrder <= 0 then
			return
		end

		local panelSize = getPanelSize(root)
		local mainPos = self.Main.AbsolutePosition
		local mainSize = self.Main.AbsoluteSize

		local rightX = mainPos.X + mainSize.X + 16
		local leftX = mainPos.X - panelSize.X - 16
		local baseX = rightX
		if baseX + panelSize.X > root.AbsoluteSize.X - PANEL_MARGIN then
			baseX = math.max(PANEL_MARGIN, leftX)
		end

		for index, panelId in ipairs(panelOrder) do
			local panelData = splitPanels[panelId]
			if panelData and panelData.Frame and panelData.Frame.Parent then
				local baseZ = 190 + ((index - 1) * 8)
				setPanelLayer(panelData, baseZ)
				panelData.Frame.Size = UDim2.fromOffset(panelSize.X, panelSize.Y)

				if not panelData.Dragging then
					if panelData.ManualPosition then
						local clampedManual = clampPositionToViewport(root, panelData.ManualPosition, panelSize)
						panelData.ManualPosition = clampedManual
						panelData.Frame.Position = UDim2.fromOffset(clampedManual.X, clampedManual.Y)
					else
						local step = index - 1
						local targetX = math.clamp(baseX + ((step % 2) * 18), PANEL_MARGIN, math.max(PANEL_MARGIN, root.AbsoluteSize.X - panelSize.X - PANEL_MARGIN))
						local targetY = math.clamp(mainPos.Y + (step * 26), PANEL_MARGIN, math.max(PANEL_MARGIN, root.AbsoluteSize.Y - panelSize.Y - PANEL_MARGIN))
						self.Animation:Create(panelData.Frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Position = UDim2.fromOffset(targetX, targetY)
						}):Play()
					end
				end
			end
		end

		notifyLayoutDirty("layout_panels")
	end

	function self.splitTab(tabRecord, dropPoint)
		local allowed, reason = canSplitTab(tabRecord)
		if not allowed then
			if reason then
				safeNotify({
					Title = "Tab Split",
					Content = reason,
					Duration = 3
				})
			end
			return false
		end

		if not (tabRecord.TabPage and tabRecord.TabButton and tabRecord.TabPage.Parent) then
			return false
		end

		if isPointInsideMain(dropPoint) then
			return false
		end

		if self.Elements.UIPageLayout.CurrentPage == tabRecord.TabPage then
			local fallback = chooseFallbackTab(tabRecord)
			if fallback and type(fallback.Activate) == "function" then
				fallback.Activate(true)
			end
		end

		local panelData = createPanelShell(tabRecord)
		splitPanels[panelData.Id] = panelData
		appendPanelOrderEntry(panelData.Id)
		tabToPanel[tabRecord] = panelData.Id

		local root = ensureSplitRoot()
		local panelSize = getPanelSize(root)
		local splitDropPoint = dropPoint or getInputPosition()
		local desiredStart = Vector2.new(
			splitDropPoint.X - math.floor(panelSize.X * 0.5),
			splitDropPoint.Y - 14
		)
		panelData.ManualPosition = clampPositionToViewport(root, desiredStart, panelSize)
		panelData.Frame.Position = UDim2.fromOffset(panelData.ManualPosition.X, panelData.ManualPosition.Y)

		tabRecord.IsSplit = true
		tabRecord.SplitPanelId = panelData.Id

		tabRecord.TabButton.Visible = false
		local interact = tabRecord.TabButton:FindFirstChild("Interact")
		if interact then
			interact.Visible = false
		end

		tabRecord.TabPage.Parent = panelData.Content
		tabRecord.TabPage.AnchorPoint = Vector2.zero
		tabRecord.TabPage.Position = UDim2.new(0, 0, 0, 0)
		tabRecord.TabPage.Size = UDim2.new(1, 0, 1, 0)
		tabRecord.TabPage.Visible = true
		tabRecord.TabPage.Active = true
		panelData.Content.Active = true
		panelData.Content.ClipsDescendants = true
		virtualSetHostSuppressed(tabRecord, splitHidden or splitMinimized, "tab_split")
		virtualRefreshHost(tabRecord, "tab_split")

		captureOriginalZIndex(tabRecord)
		bringPanelToFront(panelData)
		self.layoutPanels()
		refreshRootVisibility()
		self.syncMinimized(splitMinimized)
		notifyLayoutDirty("tab_split")

		return true
	end

	function self.dockTab(tabRecord)
		if not tabRecord then
			return false, "Rayfield Mod: Invalid Tab ID in Splitter"
		end

		local panelId = tabToPanel[tabRecord] or tabRecord.SplitPanelId
		if not panelId then
			return false, "Rayfield Mod: Tab is not currently split"
		end

		local panelData = splitPanels[panelId]
		if not panelData then
			tabRecord.IsSplit = false
			tabRecord.SplitPanelId = nil
			tabToPanel[tabRecord] = nil
			restoreOriginalZIndex(tabRecord)
			return false, "Rayfield Mod: Invalid Tab ID in Splitter (stale split panel)"
		end

		if tabRecord.TabPage then
			tabRecord.TabPage.Parent = self.Elements
			tabRecord.TabPage.AnchorPoint = Vector2.zero
			tabRecord.TabPage.Position = UDim2.new(0, 0, 0, 0)
			tabRecord.TabPage.Size = UDim2.new(1, 0, 1, 0)
			tabRecord.TabPage.Visible = true
			tabRecord.TabPage.Active = true
			virtualSetHostSuppressed(tabRecord, false, "tab_dock")
			virtualRefreshHost(tabRecord, "tab_dock")
		end

		restoreOriginalZIndex(tabRecord)

		if tabRecord.TabButton then
			local shouldBeVisible = tabRecord.DefaultVisible
			if shouldBeVisible == nil then
				shouldBeVisible = true
			end
			tabRecord.TabButton.Visible = shouldBeVisible
			local interact = tabRecord.TabButton:FindFirstChild("Interact")
			if interact then
				interact.Visible = shouldBeVisible
			end
		end

		tabRecord.IsSplit = false
		tabRecord.SplitPanelId = nil
		tabToPanel[tabRecord] = nil

		removePanelRecord(panelId)
		cleanupPanel(panelData)

		if type(tabRecord.Activate) == "function" then
			tabRecord.Activate(true)
		end

		self.layoutPanels()
		notifyLayoutDirty("tab_dock")
		return true
	end

	local function unregisterTab(tabRecord)
		local cleanup = tabGestureCleanup[tabRecord]
		if not cleanup then
			return
		end

		if cleanup.InputId then
			unregisterSharedInput(cleanup.InputId)
		end
		if cleanup.Connections then
			for _, connection in ipairs(cleanup.Connections) do
				if connection then
					connection:Disconnect()
				end
			end
			table.clear(cleanup.Connections)
		end
		if cleanup.ClearVisuals then
			pcall(cleanup.ClearVisuals)
		end

		tabGestureCleanup[tabRecord] = nil
		for i = #tabRecords, 1, -1 do
			if tabRecords[i] == tabRecord then
				table.remove(tabRecords, i)
				break
			end
		end
		virtualUnregisterHost(tabRecord)
	end

	function self.registerTab(tabRecord)
		if not tabRecord or tabGestureCleanup[tabRecord] then
			return
		end
		if not (tabRecord.TabButton and tabRecord.TabButton.Parent) then
			return
		end

		table.insert(tabRecords, tabRecord)
		tabRecord.IsSplit = false
		tabRecord.SplitPanelId = nil
		tabRecord.SuppressNextClick = false
		virtualRegisterHost(tabRecord)
		virtualSetHostSuppressed(tabRecord, splitHidden or splitMinimized, "tab_register")
		virtualRefreshHost(tabRecord, "tab_register")
		captureOriginalZIndex(tabRecord)

		local interact = tabRecord.TabButton:FindFirstChild("Interact")
		if not interact then
			return
		end

		local inputId = self.HttpService:GenerateGUID(false)
		local connections = {}
		local state = {
			pressing = false,
			dragArmed = false,
			pressInput = nil,
			pointer = nil,
			holdToken = 0,
			ghost = nil,
			ghostTarget = nil,
			ghostFollowConnection = nil,
			hoverCounter = 0,
			hoverActive = false,
			cueFrame = nil,
			cueStroke = nil,
			cueGlowStroke = nil,
			cueBlurStroke = nil,
			cueThemeConnection = nil
		}

		local function getCueColor()
			local theme = self.getSelectedTheme and self.getSelectedTheme()
			return (theme and theme.SliderProgress) or Color3.fromRGB(112, 189, 255)
		end

		local function ensureCue()
			if isDestroyed() or not (tabRecord.TabButton and tabRecord.TabButton.Parent) then
				return false
			end

			if state.cueFrame
				and state.cueFrame.Parent
				and state.cueStroke
				and state.cueGlowStroke
				and (REDUCED_EFFECTS or state.cueBlurStroke)
			then
				return true
			end

			if state.cueThemeConnection then
				state.cueThemeConnection:Disconnect()
				state.cueThemeConnection = nil
			end

			state.cueFrame = Instance.new("Frame")
			state.cueFrame.Name = "TabSplitCue"
			state.cueFrame.BackgroundTransparency = 1
			state.cueFrame.BorderSizePixel = 0
			state.cueFrame.Size = UDim2.fromScale(1, 1)
			state.cueFrame.Position = UDim2.fromOffset(0, 0)
			state.cueFrame.ZIndex = tabRecord.TabButton.ZIndex + 8
			state.cueFrame.Active = false
			state.cueFrame.Parent = tabRecord.TabButton

			local sourceCorner = tabRecord.TabButton:FindFirstChildOfClass("UICorner")
			if sourceCorner then
				local cueCorner = Instance.new("UICorner")
				cueCorner.CornerRadius = sourceCorner.CornerRadius
				cueCorner.Parent = state.cueFrame
			end

			state.cueStroke = Instance.new("UIStroke")
			state.cueStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			state.cueStroke.Color = getCueColor()
			state.cueStroke.Thickness = TAB_CUE_IDLE_THICKNESS
			state.cueStroke.Transparency = 1
			state.cueStroke.Parent = state.cueFrame

			state.cueGlowStroke = Instance.new("UIStroke")
			state.cueGlowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			state.cueGlowStroke.Color = getCueColor()
			state.cueGlowStroke.Thickness = TAB_CUE_IDLE_THICKNESS + 1.4
			state.cueGlowStroke.Transparency = 1
			state.cueGlowStroke.Parent = state.cueFrame

			if not REDUCED_EFFECTS then
				state.cueBlurStroke = Instance.new("UIStroke")
				state.cueBlurStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				state.cueBlurStroke.Color = getCueColor()
				state.cueBlurStroke.Thickness = TAB_CUE_IDLE_THICKNESS + 3.2
				state.cueBlurStroke.Transparency = 1
				state.cueBlurStroke.Parent = state.cueFrame
			else
				state.cueBlurStroke = nil
			end

			state.cueThemeConnection = self.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
				local cueColor = getCueColor()
				if state.cueStroke and state.cueStroke.Parent then
					state.cueStroke.Color = cueColor
				end
				if state.cueGlowStroke and state.cueGlowStroke.Parent then
					state.cueGlowStroke.Color = cueColor
				end
				if state.cueBlurStroke and state.cueBlurStroke.Parent then
					state.cueBlurStroke.Color = cueColor
				end
			end)

			return true
		end

		local function setCue(transparency, thickness, duration)
			if not ensureCue() or not (state.cueStroke and state.cueStroke.Parent) then
				return
			end

			local glowTransparency = (transparency >= 0.99)
				and 1
				or math.clamp(transparency + 0.34, 0.45, 0.98)
			local glowThickness = thickness + 1.4
			local blurTransparency = (transparency >= 0.99)
				and 1
				or math.clamp(transparency + 0.52, 0.7, 0.995)
			local blurThickness = thickness + 3.2

			if not duration or duration <= 0 then
				state.cueStroke.Transparency = transparency
				state.cueStroke.Thickness = thickness
				if state.cueGlowStroke and state.cueGlowStroke.Parent then
					state.cueGlowStroke.Transparency = glowTransparency
					state.cueGlowStroke.Thickness = glowThickness
				end
				if (not REDUCED_EFFECTS) and state.cueBlurStroke and state.cueBlurStroke.Parent then
					state.cueBlurStroke.Transparency = blurTransparency
					state.cueBlurStroke.Thickness = blurThickness
				end
				return
			end

			self.Animation:Create(state.cueStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = transparency,
				Thickness = thickness
			}):Play()

			if state.cueGlowStroke and state.cueGlowStroke.Parent then
				self.Animation:Create(state.cueGlowStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = glowTransparency,
					Thickness = glowThickness
				}):Play()
			end
			if (not REDUCED_EFFECTS) and state.cueBlurStroke and state.cueBlurStroke.Parent then
				self.Animation:Create(state.cueBlurStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = blurTransparency,
					Thickness = blurThickness
				}):Play()
			end
		end

		local function refreshCue()
			if tabRecord.IsSplit then
				setCue(1, TAB_CUE_IDLE_THICKNESS, 0.08)
				return
			end

			if state.dragArmed then
				setCue(TAB_CUE_READY_TRANSPARENCY, TAB_CUE_READY_THICKNESS, 0.08)
				return
			end

			if state.pressing then
				setCue(TAB_CUE_HOLD_TRANSPARENCY, TAB_CUE_HOLD_THICKNESS, 0.08)
				return
			end

			if state.hoverActive then
				setCue(TAB_CUE_HOVER_TRANSPARENCY, TAB_CUE_HOVER_THICKNESS, 0.12)
			else
				setCue(1, TAB_CUE_IDLE_THICKNESS, 0.12)
			end
		end

		local function runCueProgress(token)
			local started = os.clock()
			while state.pressing and state.holdToken == token and not state.dragArmed and not tabRecord.IsSplit do
				local progress = math.clamp((os.clock() - started) / holdDuration, 0, 1)
				local transparency = TAB_CUE_HOVER_TRANSPARENCY + ((TAB_CUE_HOLD_TRANSPARENCY - TAB_CUE_HOVER_TRANSPARENCY) * progress)
				local thickness = TAB_CUE_HOVER_THICKNESS + ((TAB_CUE_HOLD_THICKNESS - TAB_CUE_HOVER_THICKNESS) * progress)
				setCue(transparency, thickness, 0)
				task.wait()
			end
		end

		local function cleanupCue()
			if state.cueThemeConnection then
				state.cueThemeConnection:Disconnect()
				state.cueThemeConnection = nil
			end
			if state.cueFrame and state.cueFrame.Parent then
				state.cueFrame:Destroy()
			end
			state.cueFrame = nil
			state.cueStroke = nil
			state.cueGlowStroke = nil
			state.cueBlurStroke = nil
		end

		local function stopGhostFollow()
			if state.ghostFollowConnection then
				state.ghostFollowConnection:Disconnect()
				state.ghostFollowConnection = nil
			end
		end

		local function startGhostFollow()
			stopGhostFollow()
			state.ghostFollowConnection = self.RunService.RenderStepped:Connect(function(deltaTime)
				if not (state.ghost and state.ghost.Parent and state.ghostTarget) then
					return
				end

				local halfWidth = math.floor(state.ghost.AbsoluteSize.X * 0.5)
				local halfHeight = math.floor(state.ghost.AbsoluteSize.Y * 0.5)
				local desired = Vector2.new(state.ghostTarget.X - halfWidth, state.ghostTarget.Y - halfHeight)
				local current = Vector2.new(state.ghost.Position.X.Offset, state.ghost.Position.Y.Offset)
				local alpha = math.clamp(deltaTime * (TAB_GHOST_FOLLOW_SPEED * 60), 0, 1)
				local nextPosition = current:Lerp(desired, alpha)

				state.ghost.Position = UDim2.fromOffset(math.floor(nextPosition.X + 0.5), math.floor(nextPosition.Y + 0.5))
			end)
		end

		local function clearVisuals()
			stopGhostFollow()
			clearGhost(state.ghost)
			state.ghost = nil
			state.ghostTarget = nil
			cleanupCue()
		end

		local function beginPress(input)
			if isBlocked() then
				return
			end

			state.pressing = true
			state.dragArmed = false
			state.pressInput = input
			state.pointer = getInputPosition(input)
			state.ghostTarget = state.pointer
			state.holdToken += 1
			local token = state.holdToken

			refreshCue()
			task.spawn(runCueProgress, token)

			task.delay(holdDuration, function()
				if token ~= state.holdToken or not state.pressing then
					return
				end

				local allowed, reason = canSplitTab(tabRecord)
				if not allowed then
					if reason and reason ~= "This tab is already split." then
						safeNotify({
							Title = "Tab Split",
							Content = reason,
							Duration = 2.8
						})
					end
					tabRecord.SuppressNextClick = true
					refreshCue()
					return
				end

				state.dragArmed = true
				tabRecord.SuppressNextClick = true
				refreshCue()
				state.ghost = createGhost("Split: " .. tostring(tabRecord.Name), state.pointer)
				state.ghostTarget = state.pointer
				startGhostFollow()
			end)
		end

		local function finishPress(input)
			if not state.pressInput then
				return
			end

			local sameTouch = input == state.pressInput
			local mouseEnded = state.pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
			if not sameTouch and not mouseEnded then
				return
			end

			state.pressing = false
			state.pressInput = nil
			state.holdToken += 1

			if state.dragArmed then
				state.dragArmed = false
				stopGhostFollow()
				local dropPoint = state.pointer or getInputPosition(input)
				clearGhost(state.ghost)
				state.ghost = nil
				state.ghostTarget = nil
				tabRecord.SuppressNextClick = true

				if not isPointInsideMain(dropPoint) then
					self.splitTab(tabRecord, dropPoint)
				end
			else
				stopGhostFollow()
				clearGhost(state.ghost)
				state.ghost = nil
				state.ghostTarget = nil
			end

			refreshCue()
		end

		table.insert(connections, interact.InputBegan:Connect(function(input)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end
			beginPress(input)
		end))

		table.insert(connections, tabRecord.TabButton.AncestryChanged:Connect(function()
			if not tabRecord.TabButton:IsDescendantOf(game) then
				unregisterTab(tabRecord)
			end
		end))

		table.insert(connections, interact.MouseEnter:Connect(function()
			if tabRecord.IsSplit then
				return
			end
			state.hoverCounter += 1
			state.hoverActive = state.hoverCounter > 0
			refreshCue()
		end))

		table.insert(connections, interact.MouseLeave:Connect(function()
			state.hoverCounter = math.max(0, state.hoverCounter - 1)
			state.hoverActive = state.hoverCounter > 0
			if not state.pressing and not state.dragArmed then
				refreshCue()
			end
		end))

		registerSharedInput(inputId, function(input)
			if not state.pressing or not state.pressInput then
				return
			end

			local sameTouch = input == state.pressInput
			local mouseMove = state.pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
			if not sameTouch and not mouseMove then
				return
			end

			state.pointer = getInputPosition(input)
			if state.dragArmed and state.ghost then
				state.ghostTarget = state.pointer
				updateGhostPosition(state.ghost, state.pointer)
			end
		end, finishPress)

		refreshCue()

		tabGestureCleanup[tabRecord] = {
			InputId = inputId,
			Connections = connections,
			ClearVisuals = clearVisuals
		}
	end

	function self.setLayoutDirtyCallback(callback)
		layoutDirtyCallback = type(callback) == "function" and callback or nil
	end

	function self.getLayoutSnapshot()
		local snapshot = {
			version = 1,
			panels = {}
		}

		for tabRecord, panelId in pairs(tabToPanel) do
			local persistenceId = getTabPersistenceId(tabRecord)
			local panelData = panelId and splitPanels[panelId] or nil
			if persistenceId and panelData and panelData.Frame and panelData.Frame.Parent then
				local frame = panelData.Frame
				local pos = frame.Position
				local size = frame.Size
				snapshot.panels[persistenceId] = {
					position = {
						x = pos.X.Offset,
						y = pos.Y.Offset
					},
					size = {
						x = size.X.Offset,
						y = size.Y.Offset
					}
				}
			end
		end

		return snapshot
	end

	function self.applyLayoutSnapshot(snapshot)
		if type(snapshot) ~= "table" then
			return false
		end

		local panels = snapshot.panels
		if type(panels) ~= "table" then
			return false
		end

		for _, tabRecord in ipairs(tabRecords) do
			local persistenceId = getTabPersistenceId(tabRecord)
			local panelLayout = persistenceId and panels[persistenceId] or nil
			if type(panelLayout) == "table" and panelLayout.position and not tabRecord.IsSplit then
				local size = panelLayout.size or {}
				local width = tonumber(size.x) or 300
				local height = tonumber(size.y) or 220
				local x = tonumber(panelLayout.position.x) or 0
				local y = tonumber(panelLayout.position.y) or 0
				local dropPoint = Vector2.new(
					x + math.floor(width * 0.5),
					y + 16
				)
				local splitOk = self.splitTab(tabRecord, dropPoint)
				if splitOk then
					local panelId = tabToPanel[tabRecord]
					local panelData = panelId and splitPanels[panelId] or nil
					if panelData and panelData.Frame and panelData.Frame.Parent then
						local root = ensureSplitRoot()
						local targetWidth = math.max(math.floor(width), 250)
						local targetHeight = math.max(math.floor(height), 180)
						local targetSize = Vector2.new(targetWidth, targetHeight)
						local clamped = clampPositionToViewport(root, Vector2.new(x, y), targetSize)
						panelData.ManualPosition = clamped
						panelData.Frame.Size = UDim2.fromOffset(targetWidth, targetHeight)
						panelData.Frame.Position = UDim2.fromOffset(clamped.X, clamped.Y)
					end
				end
			elseif panelLayout == nil and tabRecord.IsSplit then
				self.dockTab(tabRecord)
			end
		end

		self.layoutPanels()
		refreshRootVisibility()
		return true
	end

	function self.syncHidden(isHidden)
		splitHidden = isHidden and true or false
		refreshRootVisibility()
		for tabRecord, panelId in pairs(tabToPanel) do
			if panelId then
				virtualSetHostSuppressed(tabRecord, splitHidden or splitMinimized, "sync_hidden")
				if not splitHidden and not splitMinimized then
					virtualRefreshHost(tabRecord, "sync_hidden_visible")
				end
			end
		end
	end

	function self.syncMinimized(isMinimized)
		splitMinimized = isMinimized and true or false
		refreshRootVisibility()
		for _, panelData in pairs(splitPanels) do
			if panelData and panelData.Frame and panelData.Frame.Parent then
				panelData.Frame.Visible = (not splitHidden) and (not splitMinimized)
				if splitHidden or splitMinimized then
					panelData.HoverPanel = false
					panelData.HoverHeader = false
					panelData.HoverDock = false
					panelData.HoverActive = false
					panelData.Dragging = false
					setPanelHoverState(panelData, false, true)
				end
			end
		end
		for tabRecord, panelId in pairs(tabToPanel) do
			if panelId then
				virtualSetHostSuppressed(tabRecord, splitHidden or splitMinimized, "sync_minimized")
				if not splitHidden and not splitMinimized then
					virtualRefreshHost(tabRecord, "sync_minimized_visible")
				end
			end
		end
	end

	function self.destroy()
		for tabRecord, panelId in pairs(tabToPanel) do
			if panelId then
				restoreOriginalZIndex(tabRecord)
			end
		end

		for tabRecord, _ in pairs(tabGestureCleanup) do
			unregisterTab(tabRecord)
		end

		for _, panelData in pairs(splitPanels) do
			cleanupPanel(panelData)
		end

		for _, tabRecord in ipairs(tabRecords) do
			virtualUnregisterHost(tabRecord)
		end

		table.clear(splitPanels)
		table.clear(tabToPanel)
		table.clear(panelOrder)
		table.clear(tabRecords)

		local zRecords = {}
		for tabRecord, _ in pairs(tabZIndexState) do
			table.insert(zRecords, tabRecord)
		end
		for _, tabRecord in ipairs(zRecords) do
			restoreOriginalZIndex(tabRecord)
		end

		for _, connection in ipairs(rootConnections) do
			if connection then
				connection:Disconnect()
			end
		end
		table.clear(rootConnections)

		disconnectSharedInput()

		if splitRoot and splitRoot.Parent then
			splitRoot:Destroy()
		end
		splitRoot = nil
	end

	return self
end

return TabSplitModule
