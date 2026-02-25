-- Rayfield Drag Detacher Module

local DetacherModule = {}

function DetacherModule.create(ctx)
	local self = ctx.self
	local DragDockLib = ctx.DragDockLib
	local registerSharedInput = ctx.registerSharedInput
	local unregisterSharedInput = ctx.unregisterSharedInput
	local registerDetachedWindow = ctx.registerDetachedWindow
	local unregisterDetachedWindow = ctx.unregisterDetachedWindow
	local isPointNearFrame = ctx.isPointNearFrame
	local findMergeTargetWindow = ctx.findMergeTargetWindow
	local ensureDetachedLayer = ctx.ensureDetachedLayer
	local getInputPosition = ctx.getInputPosition
	local clampDetachedPosition = ctx.clampDetachedPosition
	local isOutsideMain = ctx.isOutsideMain
	local isInsideMain = ctx.isInsideMain
	local makeFloatingDraggable = ctx.makeFloatingDraggable
	local notifyLayoutDirty = ctx.notifyLayoutDirty or function() end
	local onVirtualHostCreate = type(ctx.onVirtualHostCreate) == "function" and ctx.onVirtualHostCreate or function() end
	local onVirtualHostDestroy = type(ctx.onVirtualHostDestroy) == "function" and ctx.onVirtualHostDestroy or function() end
	local onVirtualHostRefresh = type(ctx.onVirtualHostRefresh) == "function" and ctx.onVirtualHostRefresh or function() end
	local onVirtualElementMove = type(ctx.onVirtualElementMove) == "function" and ctx.onVirtualElementMove or function() end
	local onVirtualElementBusy = type(ctx.onVirtualElementBusy) == "function" and ctx.onVirtualElementBusy or function() end
	local ReorderMainUILib = ctx.ReorderMainUILib
	local ReorderFloatingWindowsLib = ctx.ReorderFloatingWindowsLib
	local detacherRegistry = ctx.detacherRegistry or {}

	if type(self) ~= "table" then
		error("DetacherModule.create: missing 'self' context")
	end
	if type(DragDockLib) ~= "table" or type(DragDockLib.create) ~= "function" then
		error("DetacherModule.create: missing DragDockLib.create")
	end

	local constants = ctx.constants or {}
	local DETACH_HOLD_DURATION = constants.DETACH_HOLD_DURATION or 3
	local DETACH_HEADER_HEIGHT = constants.DETACH_HEADER_HEIGHT or 28
	local DETACH_MIN_WIDTH = constants.DETACH_MIN_WIDTH or 250
	local DETACH_MIN_HEIGHT = constants.DETACH_MIN_HEIGHT or 90
	local DETACH_GHOST_FOLLOW_SPEED = constants.DETACH_GHOST_FOLLOW_SPEED or 0.22
	local DETACH_WINDOW_DRAG_FOLLOW_SPEED = constants.DETACH_WINDOW_DRAG_FOLLOW_SPEED or 0.28
	local DETACH_POP_IN_DURATION = constants.DETACH_POP_IN_DURATION or 0.2
	local DETACH_POP_OUT_DURATION = constants.DETACH_POP_OUT_DURATION or 0.14
	local DETACH_CUE_HOVER_TRANSPARENCY = constants.DETACH_CUE_HOVER_TRANSPARENCY or 0.52
	local DETACH_CUE_HOLD_TRANSPARENCY = constants.DETACH_CUE_HOLD_TRANSPARENCY or 0.34
	local DETACH_CUE_READY_TRANSPARENCY = constants.DETACH_CUE_READY_TRANSPARENCY or 0.24
	local DETACH_CUE_IDLE_THICKNESS = constants.DETACH_CUE_IDLE_THICKNESS or 1
	local DETACH_CUE_HOVER_THICKNESS = constants.DETACH_CUE_HOVER_THICKNESS or 1.35
	local DETACH_CUE_HOLD_THICKNESS = constants.DETACH_CUE_HOLD_THICKNESS or 1.9
	local DETACH_CUE_READY_THICKNESS = constants.DETACH_CUE_READY_THICKNESS or 2.2
	local DETACH_MERGE_DETECT_PADDING = constants.DETACH_MERGE_DETECT_PADDING or 56
	local MERGE_INDICATOR_HEIGHT = constants.MERGE_INDICATOR_HEIGHT or 3
	local MERGE_INDICATOR_MARGIN = constants.MERGE_INDICATOR_MARGIN or 8
	local MERGE_INDICATOR_TWEEN_DURATION = constants.MERGE_INDICATOR_TWEEN_DURATION or 0.12

	local function resolveReducedEffects()
		if self.useMobileSizing then
			return true
		end
		if type(self.getSetting) == "function" then
			local okReduced, reduced = pcall(self.getSetting, "System", "reducedEffects")
			if okReduced and reduced == true then
				return true
			end
			local okPerf, performanceMode = pcall(self.getSetting, "System", "performanceMode")
			if okPerf and performanceMode == true then
				return true
			end
		end
		return false
	end

	local REDUCED_EFFECTS = resolveReducedEffects()

	local function createElementDetacher(guiObject, elementName, elementType)
		if not guiObject or not guiObject:IsA("GuiObject") then
			return nil
		end
	
		if elementType == "Section" or elementType == "Divider" then
			return nil
		end
	
		local dragInputSources = {}
		local adaptiveHoldDuration = DETACH_HOLD_DURATION
		local hoverCounter = 0
	
		local function addDragInputSource(source)
			if not (source and source:IsA("GuiObject")) then
				return
			end
			if table.find(dragInputSources, source) then
				return
			end
			source.Active = true
			table.insert(dragInputSources, source)
		end
	
		if elementType == "Button" then
			adaptiveHoldDuration = 2.2
		elseif elementType == "Dropdown" then
			adaptiveHoldDuration = 1.85
		elseif elementType == "Input" then
			adaptiveHoldDuration = 1.7
		end
	
		-- Prefer Interact for elements like Button/Toggle, then Title, then fallback to full element.
		addDragInputSource(guiObject:FindFirstChild("Interact"))
		addDragInputSource(guiObject:FindFirstChild("Title"))
		if elementType == "Dropdown" then
			addDragInputSource(guiObject:FindFirstChild("Selected"))
		end
		if elementType == "Input" then
			local inputFrame = guiObject:FindFirstChild("InputFrame")
			addDragInputSource(inputFrame)
			if inputFrame then
				addDragInputSource(inputFrame:FindFirstChild("InputBox"))
			end
		end
		if elementType ~= "Input" and elementType ~= "Dropdown" then
			addDragInputSource(guiObject)
		end
		if #dragInputSources == 0 then
			addDragInputSource(guiObject)
		end
	
		local detached = false
		local floatingWindow = nil
		local floatingContent = nil
		local floatingWindowWidth = nil
		local floatingDragCleanup = nil
		local floatingTitleBar = nil
		local floatingStroke = nil
		local floatingTitleLabel = nil
		local floatingDockButton = nil

		local function resyncElement(reason)
			if not (guiObject and guiObject.GetAttribute and self.ElementSync and type(self.ElementSync.resync) == "function") then
				return
			end
			local syncToken = guiObject:GetAttribute("RayfieldElementSyncToken")
			if type(syncToken) ~= "string" or syncToken == "" then
				return
			end
			pcall(self.ElementSync.resync, syncToken, reason or "drag_update")
		end
		local detachedPlaceholder = nil
		local windowRecord = nil
		local windowConnections = {}
		local eventConnections = {}
		local originalState = nil
		local rememberedState = nil
		local detacherId = self.HttpService:GenerateGUID(false)
		local persistenceMeta = {
			flag = nil,
			tabId = nil,
			virtualHostId = nil,
			elementName = elementName,
			elementType = elementType
		}
	
		local pressInput = nil
		local pressToken = 0
		local pressing = false
		local dragArmed = false
		local pointerPosition = nil
		local dragGhost = nil
		local ghostTargetPosition = nil
		local ghostFollowConnection = nil
		local hoverActive = false
		local cueFrame = nil
		local cueStroke = nil
		local cueGlowStroke = nil
		local cueBlurStroke = nil
		local cueThemeConnection = nil
		local mergePreviewRecord = nil
		local clearMergePreview = nil
		local destroyDragGhost
		local mergeIndicator = nil
		local mergeIndicatorRecord = nil
		local mergeIndicatorTween = nil
		local lastMergeUpdateTime = 0
		local lastMergeInsertIndex = nil
		local mainDropIndicator = nil
		local mainDropIndicatorTween = nil
		local lastMainDropInsertIndex = nil
		local MERGE_UPDATE_INTERVAL = REDUCED_EFFECTS and 0.08 or 0.05 -- ~20fps default, lower update cost in reduced-effects mode
		local getOrderedMainDockChildren
		local calculateMainInsertIndex
		local reorderInMainAt
		local isGuiActiveInCurrentPage
		local isPointInsideGui
		local syncCueHoverFromPointer
		local resetDragState

		local function resolveTabVirtualHostId()
			if type(persistenceMeta.virtualHostId) == "string" and persistenceMeta.virtualHostId ~= "" then
				return persistenceMeta.virtualHostId
			end
			if type(persistenceMeta.tabId) == "string" and persistenceMeta.tabId ~= "" then
				return "tab:" .. tostring(persistenceMeta.tabId)
			end
			return nil
		end

		local function setInteractionBusy(busy)
			local nextBusy = busy == true
			if guiObject and guiObject.SetAttribute then
				pcall(guiObject.SetAttribute, guiObject, "RayfieldInteractionBusy", nextBusy)
			end
			onVirtualElementBusy(guiObject, nextBusy)
		end
	
		local function getDetachCueColor()
			return self.getSelectedTheme().SliderProgress or self.getSelectedTheme().TextColor or Color3.fromRGB(120, 170, 255)
		end
	
		local function ensureDetachCue()
			if self.rayfieldDestroyed() or not (guiObject and guiObject.Parent) or not (self.Main and self.Main.Parent) then
				if cueThemeConnection then
					cueThemeConnection:Disconnect()
					cueThemeConnection = nil
				end
				if cueFrame then
					cueFrame:Destroy()
					cueFrame = nil
					cueStroke = nil
					cueGlowStroke = nil
					cueBlurStroke = nil
				end
				return false
			end
	
			if cueFrame
				and cueFrame.Parent
				and cueStroke
				and cueStroke.Parent
				and cueGlowStroke
				and cueGlowStroke.Parent
				and (REDUCED_EFFECTS or (cueBlurStroke and cueBlurStroke.Parent))
			then
				return true
			end
	
			if cueThemeConnection then
				cueThemeConnection:Disconnect()
				cueThemeConnection = nil
			end
	
			cueFrame = Instance.new("Frame")
			cueFrame.Name = "DetachCue"
			cueFrame.BackgroundTransparency = 1
			cueFrame.BorderSizePixel = 0
			cueFrame.Size = UDim2.fromScale(1, 1)
			cueFrame.Position = UDim2.fromOffset(0, 0)
			cueFrame.ZIndex = (guiObject.ZIndex or 1) + 6
			cueFrame.Active = false
			cueFrame.Parent = guiObject
	
			local sourceCorner = guiObject:FindFirstChildOfClass("UICorner")
			if sourceCorner then
				local cueCorner = Instance.new("UICorner")
				cueCorner.CornerRadius = sourceCorner.CornerRadius
				cueCorner.Parent = cueFrame
			end
	
			cueStroke = Instance.new("UIStroke")
			cueStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			cueStroke.Color = getDetachCueColor()
			cueStroke.Thickness = DETACH_CUE_IDLE_THICKNESS
			cueStroke.Transparency = 1
			cueStroke.Parent = cueFrame

			cueGlowStroke = Instance.new("UIStroke")
			cueGlowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			cueGlowStroke.Color = getDetachCueColor()
			cueGlowStroke.Thickness = DETACH_CUE_IDLE_THICKNESS + 1.4
			cueGlowStroke.Transparency = 1
			cueGlowStroke.Parent = cueFrame

			if not REDUCED_EFFECTS then
				cueBlurStroke = Instance.new("UIStroke")
				cueBlurStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				cueBlurStroke.Color = getDetachCueColor()
				cueBlurStroke.Thickness = DETACH_CUE_IDLE_THICKNESS + 3.2
				cueBlurStroke.Transparency = 1
				cueBlurStroke.Parent = cueFrame
			else
				cueBlurStroke = nil
			end
	
			cueThemeConnection = self.Main:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
				if cueStroke and cueStroke.Parent then
					cueStroke.Color = getDetachCueColor()
				end
				if cueGlowStroke and cueGlowStroke.Parent then
					cueGlowStroke.Color = getDetachCueColor()
				end
				if cueBlurStroke and cueBlurStroke.Parent then
					cueBlurStroke.Color = getDetachCueColor()
				end
			end)
	
			return true
		end
	
		local function setDetachCue(transparency, thickness, duration)
			if not cueStroke or not cueStroke.Parent then
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
				cueStroke.Transparency = transparency
				cueStroke.Thickness = thickness
				if cueGlowStroke and cueGlowStroke.Parent then
					cueGlowStroke.Transparency = glowTransparency
					cueGlowStroke.Thickness = glowThickness
				end
				if (not REDUCED_EFFECTS) and cueBlurStroke and cueBlurStroke.Parent then
					cueBlurStroke.Transparency = blurTransparency
					cueBlurStroke.Thickness = blurThickness
				end
				return
			end
	
			self.Animation:Create(cueStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = transparency,
				Thickness = thickness
			}):Play()
			if cueGlowStroke and cueGlowStroke.Parent then
				self.Animation:Create(cueGlowStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = glowTransparency,
					Thickness = glowThickness
				}):Play()
			end
			if (not REDUCED_EFFECTS) and cueBlurStroke and cueBlurStroke.Parent then
				self.Animation:Create(cueBlurStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = blurTransparency,
					Thickness = blurThickness
				}):Play()
			end
		end
	
		local function refreshDetachCue()
			if not ensureDetachCue() then
				return
			end
			if detached then
				setDetachCue(1, DETACH_CUE_IDLE_THICKNESS, 0.1)
				return
			end
	
			if dragArmed then
				setDetachCue(DETACH_CUE_READY_TRANSPARENCY, DETACH_CUE_READY_THICKNESS, 0.08)
				return
			end
	
			if pressing then
				setDetachCue(DETACH_CUE_HOLD_TRANSPARENCY, DETACH_CUE_HOLD_THICKNESS, 0.08)
				return
			end
	
			if hoverActive then
				setDetachCue(DETACH_CUE_HOVER_TRANSPARENCY, DETACH_CUE_HOVER_THICKNESS, 0.12)
			else
				setDetachCue(1, DETACH_CUE_IDLE_THICKNESS, 0.12)
			end
		end

		isGuiActiveInCurrentPage = function(targetGui)
			if not targetGui or not targetGui.Parent then
				return false
			end
			if detached then
				return false
			end
			if not targetGui.Visible then
				return false
			end
			local currentPage = self.Elements and self.Elements.UIPageLayout and self.Elements.UIPageLayout.CurrentPage
			if not currentPage or not currentPage.Parent then
				return false
			end
			return targetGui:IsDescendantOf(currentPage)
		end

		isPointInsideGui = function(point, targetGui)
			if not point or not targetGui or not targetGui.Parent then
				return false
			end
			if targetGui.AbsoluteSize.X <= 0 or targetGui.AbsoluteSize.Y <= 0 then
				return false
			end
			local pos = targetGui.AbsolutePosition
			local size = targetGui.AbsoluteSize
			return point.X >= pos.X
				and point.Y >= pos.Y
				and point.X <= (pos.X + size.X)
				and point.Y <= (pos.Y + size.Y)
		end

		syncCueHoverFromPointer = function(point, force)
			local pointer = point
			if not pointer then
				pointer = self.UserInputService:GetMouseLocation()
			end

			local shouldHover = false
			local currentPage = self.Elements and self.Elements.UIPageLayout and self.Elements.UIPageLayout.CurrentPage
			if currentPage and isGuiActiveInCurrentPage(guiObject) then
				for _, source in ipairs(dragInputSources) do
					if source and source.Parent and source.Visible and source:IsDescendantOf(guiObject) and source:IsDescendantOf(currentPage) then
						if isPointInsideGui(pointer, source) then
							shouldHover = true
							break
						end
					end
				end
			end

			if force or hoverActive ~= shouldHover then
				hoverCounter = shouldHover and 1 or 0
				hoverActive = shouldHover
				if not pressing and not dragArmed then
					refreshDetachCue()
				end
			end
		end

		resetDragState = function(reason)
			if reason then
				-- No-op hook kept for lightweight diagnostics if needed later.
			end
			setInteractionBusy(false)
			pressing = false
			pressInput = nil
			dragArmed = false
			pressToken += 1
			if clearMergePreview then
				clearMergePreview(false)
			end
			if destroyDragGhost then
				destroyDragGhost(true)
			end
			hoverCounter = 0
			hoverActive = false
			refreshDetachCue()
		end
	
		local function runHoldCueProgress(token)
			local started = os.clock()
			while pressing and pressToken == token and not dragArmed and not detached do
				local progress = math.clamp((os.clock() - started) / adaptiveHoldDuration, 0, 1)
				local transparency = DETACH_CUE_HOVER_TRANSPARENCY + ((DETACH_CUE_HOLD_TRANSPARENCY - DETACH_CUE_HOVER_TRANSPARENCY) * progress)
				local thickness = DETACH_CUE_HOVER_THICKNESS + ((DETACH_CUE_HOLD_THICKNESS - DETACH_CUE_HOVER_THICKNESS) * progress)
				setDetachCue(transparency, thickness, 0)
				task.wait()
			end
		end
	
		local function cleanupDetachCue()
			if cueThemeConnection then
				cueThemeConnection:Disconnect()
				cueThemeConnection = nil
			end
			if cueFrame then
				cueFrame:Destroy()
				cueFrame = nil
				cueStroke = nil
				cueGlowStroke = nil
				cueBlurStroke = nil
			end
		end
	
		local function cleanupWindowConnections()
			for _, connection in ipairs(windowConnections) do
				if connection then
					connection:Disconnect()
				end
			end
			table.clear(windowConnections)
		end

		local dockManager = DragDockLib.create()
	
		local function getOrderedGuiChildren(parent, excludeA, excludeB)
			return dockManager.getOrderedGuiChildren(parent, excludeA, excludeB)
		end
	
		local function normalizeOrderedGuiLayout(ordered)
			dockManager.normalizeOrderedGuiLayout(ordered)
		end
	
		local function parentUsesLayoutOrder(parent)
			return dockManager.parentUsesLayoutOrder(parent)
		end
	
		local function resolveInsertIndexFromState(parent, state, ordered)
			return dockManager.resolveInsertIndexFromState(parent, state, ordered)
		end
	
		local function captureCurrentElementState()
			local parent = guiObject.Parent
			local siblingIndex = nil
			local previousSibling = nil
			local nextSibling = nil
	
			if parent and parentUsesLayoutOrder(parent) then
				local ordered = getOrderedGuiChildren(parent)
				for index, child in ipairs(ordered) do
					if child == guiObject then
						siblingIndex = index
						previousSibling = ordered[index - 1]
						nextSibling = ordered[index + 1]
						break
					end
				end
			end
	
			return {
				Parent = parent,
				AnchorPoint = guiObject.AnchorPoint,
				Position = guiObject.Position,
				Size = guiObject.Size,
				LayoutOrder = guiObject.LayoutOrder,
				SiblingIndex = siblingIndex,
				PreviousSibling = previousSibling,
				NextSibling = nextSibling
			}
		end
	
		local function updateDetachedPlaceholder()
			if not detachedPlaceholder then
				return
			end
	
			local height = math.max(guiObject.AbsoluteSize.Y, 36)
			detachedPlaceholder.Size = UDim2.new(1, 0, 0, height)
		end
	
		local function destroyDetachedPlaceholder()
			if detachedPlaceholder then
				detachedPlaceholder:Destroy()
				detachedPlaceholder = nil
			end
		end
	
		local function createDetachedPlaceholder()
			if detachedPlaceholder or not originalState or not originalState.Parent then
				return
			end
	
			detachedPlaceholder = Instance.new("Frame")
			detachedPlaceholder.Name = "DetachPlaceholder"
			detachedPlaceholder.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
			detachedPlaceholder.BackgroundTransparency = 0.82
			detachedPlaceholder.BorderSizePixel = 0
			detachedPlaceholder.LayoutOrder = originalState.LayoutOrder
			detachedPlaceholder.Parent = originalState.Parent
	
			if parentUsesLayoutOrder(originalState.Parent) then
				local ordered = getOrderedGuiChildren(originalState.Parent, detachedPlaceholder)
				local insertIndex = resolveInsertIndexFromState(originalState.Parent, originalState, ordered)
				if type(insertIndex) ~= "number" then
					insertIndex = #ordered + 1
				end
				insertIndex = math.clamp(insertIndex, 1, #ordered + 1)
				table.insert(ordered, insertIndex, detachedPlaceholder)
				normalizeOrderedGuiLayout(ordered)
				detachedPlaceholder:SetAttribute("DetachSlotIndex", insertIndex)
			else
				detachedPlaceholder:SetAttribute("DetachSlotIndex", nil)
			end
	
			local sourceCorner = guiObject:FindFirstChildOfClass("UICorner")
			if sourceCorner then
				local placeholderCorner = Instance.new("UICorner")
				placeholderCorner.CornerRadius = sourceCorner.CornerRadius
				placeholderCorner.Parent = detachedPlaceholder
			end
	
			local placeholderStroke = Instance.new("UIStroke")
			placeholderStroke.Color = self.getSelectedTheme().SliderProgress or self.getSelectedTheme().ElementStroke
			placeholderStroke.Thickness = 1.2
			placeholderStroke.Transparency = 0.35
			placeholderStroke.Parent = detachedPlaceholder
	
			local placeholderLabel = Instance.new("TextLabel")
			placeholderLabel.Name = "Hint"
			placeholderLabel.BackgroundTransparency = 1
			placeholderLabel.Size = UDim2.new(1, -12, 1, 0)
			placeholderLabel.Position = UDim2.new(0, 6, 0, 0)
			placeholderLabel.Text = "Detached slot (origin): " .. tostring(elementName)
			placeholderLabel.TextColor3 = self.getSelectedTheme().TextColor
			placeholderLabel.TextTransparency = 0.35
			placeholderLabel.TextSize = 11
			placeholderLabel.Font = Enum.Font.Gotham
			placeholderLabel.TextXAlignment = Enum.TextXAlignment.Left
			placeholderLabel.Parent = detachedPlaceholder
	
			updateDetachedPlaceholder()
		end
	
		destroyDragGhost = function(instant)
			if clearMergePreview then
				clearMergePreview(true)
			end
	
			if ghostFollowConnection then
				ghostFollowConnection:Disconnect()
				ghostFollowConnection = nil
			end
	
			if not dragGhost then
				ghostTargetPosition = nil
				return
			end
	
			local ghost = dragGhost
			dragGhost = nil
			ghostTargetPosition = nil
	
			if instant then
				ghost:Destroy()
				return
			end
	
			local shrinkWidth = math.max(math.floor(ghost.AbsoluteSize.X * 0.9), 120)
			local shrinkHeight = math.max(math.floor(ghost.AbsoluteSize.Y * 0.88), 26)
			self.Animation:Create(ghost, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(shrinkWidth, shrinkHeight)
			}):Play()
	
			for _, child in ipairs(ghost:GetChildren()) do
				if child:IsA("TextLabel") then
					self.Animation:Create(child, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
				elseif child:IsA("UIStroke") then
					self.Animation:Create(child, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
				end
			end
	
			task.delay(DETACH_POP_OUT_DURATION + 0.03, function()
				if ghost and ghost.Parent then
					ghost:Destroy()
				end
			end)
		end
	
		local function updateGhostPosition()
			if not dragGhost or not pointerPosition then
				return
			end
	
			local size = dragGhost.AbsoluteSize
			ghostTargetPosition = Vector2.new(
				pointerPosition.X - (size.X / 2),
				pointerPosition.Y - (size.Y / 2)
			)
		end
	
		local function createDragGhost()
			if dragGhost then
				return
			end
	
			local layer = ensureDetachedLayer()
			local targetSize = Vector2.new(
				math.max(guiObject.AbsoluteSize.X, 160),
				math.max(guiObject.AbsoluteSize.Y, 34)
			)
			local startSize = Vector2.new(
				math.max(math.floor(targetSize.X * 0.9), 120),
				math.max(math.floor(targetSize.Y * 0.88), 26)
			)
	
			dragGhost = Instance.new("Frame")
			dragGhost.Name = "DetachGhost"
			dragGhost.Size = UDim2.fromOffset(startSize.X, startSize.Y)
			dragGhost.BorderSizePixel = 0
			dragGhost.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
			dragGhost.BackgroundTransparency = 1
			dragGhost.ZIndex = 250
			dragGhost.Parent = layer
	
			local ghostCorner = Instance.new("UICorner")
			ghostCorner.CornerRadius = UDim.new(0, 8)
			ghostCorner.Parent = dragGhost
	
			local ghostStroke = Instance.new("UIStroke")
			ghostStroke.Thickness = 1.5
			ghostStroke.Color = self.getSelectedTheme().ElementStroke
			ghostStroke.Transparency = 1
			ghostStroke.Parent = dragGhost
	
			local ghostLabel = Instance.new("TextLabel")
			ghostLabel.BackgroundTransparency = 1
			ghostLabel.Size = UDim2.new(1, -14, 1, 0)
			ghostLabel.Position = UDim2.new(0, 7, 0, 0)
			ghostLabel.Text = "Detach: " .. tostring(elementName)
			ghostLabel.TextSize = 12
			ghostLabel.Font = Enum.Font.Gotham
			ghostLabel.TextColor3 = self.getSelectedTheme().TextColor
			ghostLabel.TextTransparency = 1
			ghostLabel.TextXAlignment = Enum.TextXAlignment.Left
			ghostLabel.ZIndex = 251
			ghostLabel.Parent = dragGhost
	
			updateGhostPosition()
			if ghostTargetPosition then
				dragGhost.Position = UDim2.fromOffset(ghostTargetPosition.X, ghostTargetPosition.Y)
			end
	
			ghostFollowConnection = self.RunService.RenderStepped:Connect(function(deltaTime)
				if not dragGhost or not ghostTargetPosition then
					return
				end
	
				local current = Vector2.new(dragGhost.Position.X.Offset, dragGhost.Position.Y.Offset)
				local alpha = math.clamp(deltaTime * (DETACH_GHOST_FOLLOW_SPEED * 60), 0, 1)
				local nextPosition = current:Lerp(ghostTargetPosition, alpha)
				dragGhost.Position = UDim2.fromOffset(math.floor(nextPosition.X + 0.5), math.floor(nextPosition.Y + 0.5))
			end)
	
			self.Animation:Create(dragGhost, TweenInfo.new(DETACH_POP_IN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(targetSize.X, targetSize.Y),
				BackgroundTransparency = 0.25
			}):Play()
			self.Animation:Create(ghostStroke, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
			self.Animation:Create(ghostLabel, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
		end
	
		local function clearMergeIndicator(instant)
			if mergeIndicatorTween then
				pcall(function() mergeIndicatorTween:Cancel() end)
				mergeIndicatorTween = nil
			end
	
			if mergeIndicator then
				local indicator = mergeIndicator
				mergeIndicator = nil
				mergeIndicatorRecord = nil
	
				if instant then
					indicator:Destroy()
					return
				end
	
				self.Animation:Create(indicator, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1
				}):Play()
				for _, child in ipairs(indicator:GetChildren()) do
					if child:IsA("TextLabel") then
						self.Animation:Create(child, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							TextTransparency = 1,
							BackgroundTransparency = 1
						}):Play()
					end
				end
				task.delay(0.09, function()
					if indicator and indicator.Parent then
						indicator:Destroy()
					end
				end)
			else
				mergeIndicatorRecord = nil
			end
		end
	
		local function calculateRecordInsertIndex(record, point)
			if type(ReorderFloatingWindowsLib) == "table" and type(ReorderFloatingWindowsLib.calculateInsertIndex) == "function" then
				local ok, insertIndex, ordered = pcall(
					ReorderFloatingWindowsLib.calculateInsertIndex,
					record,
					point,
					getOrderedGuiChildren
				)
				if ok then
					return insertIndex, ordered
				end
			end

			if not (record and record.content and record.content.Parent and point) then
				return nil
			end
	
			local ordered = getOrderedGuiChildren(record.content)
			local insertIndex = #ordered + 1
	
			for index, child in ipairs(ordered) do
				local childCenterY = child.AbsolutePosition.Y + (child.AbsoluteSize.Y * 0.5)
				if point.Y <= childCenterY then
					insertIndex = index
					break
				end
			end
	
			return insertIndex, ordered
		end
	
		local function getMergeSiblingNameForPreview(child)
			if not (child and child:IsA("GuiObject")) then
				return nil
			end
	
			local title = child:FindFirstChild("Title")
			if title and title:IsA("TextLabel") then
				local text = tostring(title.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
				if text ~= "" then
					return text
				end
			end
	
			return tostring(child.Name or "")
		end
	
		local function computeIndicatorY(record, insertIndex, ordered)
			local content = record.content
			if not ordered or #ordered == 0 then
				return content.AbsolutePosition.Y + 4
			end
	
			if insertIndex <= 1 then
				local first = ordered[1]
				return first.AbsolutePosition.Y - 2
			end
	
			if insertIndex > #ordered then
				local last = ordered[#ordered]
				return last.AbsolutePosition.Y + last.AbsoluteSize.Y + 2
			end
	
			local before = ordered[insertIndex - 1]
			local after = ordered[insertIndex]
			local beforeBottom = before.AbsolutePosition.Y + before.AbsoluteSize.Y
			local afterTop = after.AbsolutePosition.Y
			return (beforeBottom + afterTop) / 2
		end
	
		local function ensureMergeIndicator(record, insertIndex, ordered)
			if not (record and record.content and record.content.Parent) then
				clearMergeIndicator(true)
				return
			end
	
			-- Recycle: just update record reference, no destroy/recreate needed
			mergeIndicatorRecord = record
	
			local layer = ensureDetachedLayer()
			-- Convert screen-space AbsolutePosition to layer-local coordinates
			-- This handles IgnoreGuiInset correctly regardless of setting
			local layerOffset = layer.AbsolutePosition
			local contentX = record.content.AbsolutePosition.X - layerOffset.X
			local contentW = record.content.AbsoluteSize.X
			local indicatorW = math.max(contentW - (MERGE_INDICATOR_MARGIN * 2), 20)
			local indicatorX = contentX + MERGE_INDICATOR_MARGIN
			local indicatorY = computeIndicatorY(record, insertIndex, ordered) - layerOffset.Y - math.floor(MERGE_INDICATOR_HEIGHT / 2)
	
			if not mergeIndicator then
				mergeIndicator = Instance.new("Frame")
				mergeIndicator.Name = "MergeIndicator"
				mergeIndicator.BackgroundColor3 = getDetachCueColor()
				mergeIndicator.BackgroundTransparency = 0.05
				mergeIndicator.BorderSizePixel = 0
				mergeIndicator.Size = UDim2.fromOffset(indicatorW, MERGE_INDICATOR_HEIGHT)
				mergeIndicator.Position = UDim2.fromOffset(indicatorX, indicatorY)
				mergeIndicator.ZIndex = 210
				mergeIndicator.Parent = layer
	
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 2)
				corner.Parent = mergeIndicator
	
				local label = Instance.new("TextLabel")
				label.Name = "ReviewLabel"
				label.BackgroundColor3 = getDetachCueColor()
				label.BackgroundTransparency = 0.08
				label.BorderSizePixel = 0
				label.Size = UDim2.fromOffset(0, 16)
				label.AutomaticSize = Enum.AutomaticSize.X
				label.Position = UDim2.fromOffset(0, -18)
				label.Font = Enum.Font.GothamBold
				label.TextSize = 10
				label.TextColor3 = self.getSelectedTheme().TextColor
				label.TextTransparency = 0.05
				label.Text = ""
				label.Parent = mergeIndicator
	
				local labelPadding = Instance.new("UIPadding")
				labelPadding.PaddingLeft = UDim.new(0, 5)
				labelPadding.PaddingRight = UDim.new(0, 5)
				labelPadding.Parent = label
	
				local labelCorner = Instance.new("UICorner")
				labelCorner.CornerRadius = UDim.new(0, 4)
				labelCorner.Parent = label
			end
	
			-- Update label text
			local orderedCount = ordered and #ordered or 0
			local indexNumber = math.clamp(math.floor(tonumber(insertIndex) or 1), 1, orderedCount + 1)
			local hint = "at end"
			local targetSibling = type(ordered) == "table" and ordered[indexNumber] or nil
			if targetSibling then
				local siblingName = getMergeSiblingNameForPreview(targetSibling)
				if siblingName and siblingName ~= "" then
					hint = "before " .. siblingName
				else
					hint = "before next"
				end
			end
	
			local reviewLabel = mergeIndicator:FindFirstChild("ReviewLabel")
			if reviewLabel and reviewLabel:IsA("TextLabel") then
				reviewLabel.Text = string.format("#%d · %s", indexNumber, hint)
				reviewLabel.BackgroundColor3 = getDetachCueColor()
			end
	
			-- Update indicator color/size in case theme changed
			mergeIndicator.BackgroundColor3 = getDetachCueColor()
			mergeIndicator.Size = UDim2.fromOffset(indicatorW, MERGE_INDICATOR_HEIGHT)
	
			-- Tween to new position
			local targetPos = UDim2.fromOffset(indicatorX, indicatorY)
	
			if mergeIndicatorTween then
				pcall(function() mergeIndicatorTween:Cancel() end)
				mergeIndicatorTween = nil
			end
	
			local tween = self.Animation:Create(mergeIndicator, TweenInfo.new(
				MERGE_INDICATOR_TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
			), { Position = targetPos })
			mergeIndicatorTween = tween
			tween.Completed:Connect(function()
				if mergeIndicatorTween == tween then
					mergeIndicatorTween = nil
				end
			end)
			tween:Play()
		end
	
		getOrderedMainDockChildren = function(tabPage, excludeA, excludeB)
			if not (tabPage and tabPage.Parent) then
				return {}
			end

			local rawChildren = tabPage:GetChildren()
			local insertionOrder = {}
			for index, child in ipairs(rawChildren) do
				insertionOrder[child] = index
			end

			local function isDockCandidate(child)
				if not (child and child:IsA("GuiObject")) then
					return false
				end
				if child == excludeA or child == excludeB then
					return false
				end
				if not child.Visible then
					return false
				end

				local childName = tostring(child.Name)
				if childName == "Placeholder"
					or childName == "DetachPlaceholder"
					or childName == "SearchTitle-fsefsefesfsefesfesfThanks" then
					return false
				end

				return true
			end

			local ordered = {}
			for _, child in ipairs(rawChildren) do
				if isDockCandidate(child) then
					table.insert(ordered, child)
				end
			end

			table.sort(ordered, function(a, b)
				if a.LayoutOrder ~= b.LayoutOrder then
					return a.LayoutOrder < b.LayoutOrder
				end
				return (insertionOrder[a] or 0) < (insertionOrder[b] or 0)
			end)

			return ordered
		end

		calculateMainInsertIndex = function(tabPage, point, excludeA, excludeB)
			if not (tabPage and tabPage.Parent and point) then
				return nil, {}
			end

			local ordered = getOrderedMainDockChildren(tabPage, excludeA, excludeB)
			local insertIndex = #ordered + 1
			for index, child in ipairs(ordered) do
				local childCenterY = child.AbsolutePosition.Y + (child.AbsoluteSize.Y * 0.5)
				if point.Y <= childCenterY then
					insertIndex = index
					break
				end
			end
			return insertIndex, ordered
		end
	
		local function computeMainIndicatorY(tabPage, insertIndex, ordered)
			if not ordered or #ordered == 0 then
				return tabPage.AbsolutePosition.Y + 4
			end
			if insertIndex <= 1 then
				return ordered[1].AbsolutePosition.Y - 2
			end
			if insertIndex > #ordered then
				local last = ordered[#ordered]
				return last.AbsolutePosition.Y + last.AbsoluteSize.Y + 2
			end
			local before = ordered[insertIndex - 1]
			local after = ordered[insertIndex]
			return (before.AbsolutePosition.Y + before.AbsoluteSize.Y + after.AbsolutePosition.Y) / 2
		end
	
		local function clearMainDropPreview(instant)
			if mainDropIndicatorTween then
				pcall(function() mainDropIndicatorTween:Cancel() end)
				mainDropIndicatorTween = nil
			end
			lastMainDropInsertIndex = nil
			if mainDropIndicator then
				local indicator = mainDropIndicator
				mainDropIndicator = nil
				if instant then
					indicator:Destroy()
					return
				end
				self.Animation:Create(indicator, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1
				}):Play()
				for _, child in ipairs(indicator:GetChildren()) do
					if child:IsA("TextLabel") then
						self.Animation:Create(child, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							TextTransparency = 1,
							BackgroundTransparency = 1
						}):Play()
					end
				end
				task.delay(0.09, function()
					if indicator and indicator.Parent then
						indicator:Destroy()
					end
				end)
			end
		end
	
		local function showMainDropPreview(point)
			local currentTabPage = self.Elements.UIPageLayout.CurrentPage
			if not (currentTabPage and currentTabPage.Parent) then
				clearMainDropPreview(false)
				return
			end
			local targetState = originalState or rememberedState
			if targetState and targetState.Parent and currentTabPage ~= targetState.Parent then
				clearMainDropPreview(false)
				return
			end
			local excludeSelf = (not detached) and guiObject or nil
			local insertIndex, ordered = calculateMainInsertIndex(currentTabPage, point, excludeSelf)
			if not insertIndex then
				clearMainDropPreview(false)
				return
			end
			lastMainDropInsertIndex = insertIndex
	
			local layer = ensureDetachedLayer()
			local layerOffset = layer.AbsolutePosition
			local contentX = currentTabPage.AbsolutePosition.X - layerOffset.X
			local contentW = currentTabPage.AbsoluteSize.X
			local indicatorW = math.max(contentW - (MERGE_INDICATOR_MARGIN * 2), 20)
			local indicatorX = contentX + MERGE_INDICATOR_MARGIN
			local indicatorY = computeMainIndicatorY(currentTabPage, insertIndex, ordered) - layerOffset.Y - math.floor(MERGE_INDICATOR_HEIGHT / 2)
	
			if not mainDropIndicator then
				mainDropIndicator = Instance.new("Frame")
				mainDropIndicator.Name = "MainDropIndicator"
				mainDropIndicator.BackgroundColor3 = getDetachCueColor()
				mainDropIndicator.BackgroundTransparency = 0.05
				mainDropIndicator.BorderSizePixel = 0
				mainDropIndicator.Size = UDim2.fromOffset(indicatorW, MERGE_INDICATOR_HEIGHT)
				mainDropIndicator.Position = UDim2.fromOffset(indicatorX, indicatorY)
				mainDropIndicator.ZIndex = 210
				mainDropIndicator.Parent = layer
	
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 2)
				corner.Parent = mainDropIndicator
	
				local label = Instance.new("TextLabel")
				label.Name = "ReviewLabel"
				label.BackgroundColor3 = getDetachCueColor()
				label.BackgroundTransparency = 0.08
				label.BorderSizePixel = 0
				label.Size = UDim2.fromOffset(0, 16)
				label.AutomaticSize = Enum.AutomaticSize.X
				label.Position = UDim2.fromOffset(0, -18)
				label.Font = Enum.Font.GothamBold
				label.TextSize = 10
				label.TextColor3 = self.getSelectedTheme().TextColor
				label.TextTransparency = 0.05
				label.Text = ""
				label.Parent = mainDropIndicator
	
				local labelPadding = Instance.new("UIPadding")
				labelPadding.PaddingLeft = UDim.new(0, 5)
				labelPadding.PaddingRight = UDim.new(0, 5)
				labelPadding.Parent = label
	
				local labelCorner = Instance.new("UICorner")
				labelCorner.CornerRadius = UDim.new(0, 4)
				labelCorner.Parent = label
			end
	
			local orderedCount = #ordered
			local indexNumber = math.clamp(insertIndex, 1, orderedCount + 1)
			local hint = "at end"
			local targetSibling = ordered[indexNumber]
			if targetSibling then
				local siblingName = getMergeSiblingNameForPreview(targetSibling)
				if siblingName and siblingName ~= "" then
					hint = "before " .. siblingName
				else
					hint = "before next"
				end
			end
	
			local reviewLabel = mainDropIndicator:FindFirstChild("ReviewLabel")
			if reviewLabel and reviewLabel:IsA("TextLabel") then
				reviewLabel.Text = string.format("Dock #%d · %s", indexNumber, hint)
				reviewLabel.BackgroundColor3 = getDetachCueColor()
			end
	
			mainDropIndicator.BackgroundColor3 = getDetachCueColor()
			mainDropIndicator.Size = UDim2.fromOffset(indicatorW, MERGE_INDICATOR_HEIGHT)
	
			local targetPos = UDim2.fromOffset(indicatorX, indicatorY)
			if mainDropIndicatorTween then
				pcall(function() mainDropIndicatorTween:Cancel() end)
				mainDropIndicatorTween = nil
			end
			local tween = self.Animation:Create(mainDropIndicator, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos })
			mainDropIndicatorTween = tween
			tween.Completed:Connect(function()
				if mainDropIndicatorTween == tween then
					mainDropIndicatorTween = nil
				end
			end)
			tween:Play()
		end
	
		clearMergePreview = function(instant)
			local previous = mergePreviewRecord
			mergePreviewRecord = nil
			lastMergeInsertIndex = nil
			clearMergeIndicator(instant)
			clearMainDropPreview(instant)
	
			if not previous or not previous.stroke or not previous.stroke.Parent then
				return
			end
	
			local targetThickness = 1.5
			local targetColor = self.getSelectedTheme().ElementStroke
			if instant then
				previous.stroke.Thickness = targetThickness
				previous.stroke.Color = targetColor
				return
			end
	
			self.Animation:Create(previous.stroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = targetThickness,
				Color = targetColor
			}):Play()
		end
	
		local function updateMergePreview(point)
			if not dragArmed or not point then
				clearMergePreview(false)
				return
			end
	
			-- Throttle: cap at ~20 updates/sec to avoid per-pixel recalculation
			local now = os.clock()
			if now - lastMergeUpdateTime < MERGE_UPDATE_INTERVAL then
				return
			end
			lastMergeUpdateTime = now
	
			local excludeRecord = detached and windowRecord or nil
			local targetRecord = findMergeTargetWindow(point, excludeRecord)
			if targetRecord ~= mergePreviewRecord then
				local previous = mergePreviewRecord
				mergePreviewRecord = nil
				lastMergeInsertIndex = nil
	
				if previous and previous.stroke and previous.stroke.Parent then
					self.Animation:Create(previous.stroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Thickness = 1.5,
						Color = self.getSelectedTheme().ElementStroke
					}):Play()
				end
	
				if targetRecord and targetRecord.stroke and targetRecord.stroke.Parent then
					mergePreviewRecord = targetRecord
					self.Animation:Create(targetRecord.stroke, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Thickness = 2.35,
						Color = self.getSelectedTheme().SliderProgress or self.getSelectedTheme().TextColor
					}):Play()
				end
			end
	
			if targetRecord then
				clearMainDropPreview(false)
				local insertIndex, ordered = calculateRecordInsertIndex(targetRecord, point)
				lastMergeInsertIndex = insertIndex
				ensureMergeIndicator(targetRecord, insertIndex, ordered)
			elseif isInsideMain(point) and (detached or isGuiActiveInCurrentPage(guiObject)) then
				clearMergeIndicator(false)
				lastMergeInsertIndex = nil
				showMainDropPreview(point)
			else
				clearMergeIndicator(false)
				clearMainDropPreview(false)
				lastMergeInsertIndex = nil
			end
		end
	
		local function getWindowElementCount(record)
			if not (record and record.elements) then
				return 0
			end
			local count = 0
			for _ in pairs(record.elements) do
				count += 1
			end
			return count
		end
	
		local function updateWindowRecordLayout(record)
			if not (record and record.frame and record.frame.Parent) then
				return
			end
	
			local count = getWindowElementCount(record)
			if count <= 0 then
				return
			end
	
			local contentHeight = ((record.layout and record.layout.AbsoluteContentSize.Y) or 0) + 8
			local windowHeight = math.max(contentHeight + DETACH_HEADER_HEIGHT + 12, DETACH_MIN_HEIGHT)
			record.frame.Size = UDim2.fromOffset(record.width or DETACH_MIN_WIDTH, windowHeight)
			record.content.Size = UDim2.new(1, -10, 1, -(DETACH_HEADER_HEIGHT + 10))
	
			if record.titleLabel then
				if count == 1 then
					for _, entry in pairs(record.elements) do
						record.titleLabel.Text = tostring(entry.name or elementName)
						break
					end
				else
					record.titleLabel.Text = string.format("Merged (%d)", count)
				end
			end
	
			if record.dockButton then
				if count > 1 then
					record.dockButton.Size = UDim2.fromOffset(64, 20)
					record.dockButton.Position = UDim2.new(1, -70, 0.5, -10)
					record.dockButton.Text = "DockAll"
				else
					record.dockButton.Size = UDim2.fromOffset(48, 20)
					record.dockButton.Position = UDim2.new(1, -54, 0.5, -10)
					record.dockButton.Text = "Dock"
				end
			end
		end
	
		local function destroyWindowRecord(record)
			if not record then
				return
			end
	
			if record.dragCleanup then
				record.dragCleanup()
				record.dragCleanup = nil
			end
	
			if record.connections then
				for _, connection in ipairs(record.connections) do
					if connection then
						connection:Disconnect()
					end
				end
				table.clear(record.connections)
			end
	
			unregisterDetachedWindow(record)
			onVirtualHostDestroy("floating:" .. tostring(record.id))

			if record.frame then
				record.frame:Destroy()
			end
	
			if windowRecord == record then
				windowRecord = nil
			end
		end
	
		local function cleanupFloatingWindow()
			if floatingDragCleanup then
				floatingDragCleanup()
				floatingDragCleanup = nil
			end
	
			cleanupWindowConnections()
	
			local record = windowRecord
			if record and record.elements then
				record.elements[detacherId] = nil
				if getWindowElementCount(record) <= 0 then
					destroyWindowRecord(record)
				else
					updateWindowRecordLayout(record)
				end
			end
	
			windowRecord = nil
			destroyDetachedPlaceholder()
			floatingWindow = nil
			floatingContent = nil
			floatingWindowWidth = nil
			floatingTitleBar = nil
			floatingStroke = nil
			floatingTitleLabel = nil
			floatingDockButton = nil
		end
	
		local dockBack
		local dockBackToPosition
		local moveToWindowRecord
		local moveDetachedAt

		reorderInMainAt = function(point, requestedInsertIndex)
			if type(ReorderMainUILib) == "table" and type(ReorderMainUILib.apply) == "function" then
				local ok, reordered, nextRememberedState = pcall(ReorderMainUILib.apply, {
					detached = detached,
					guiObject = guiObject,
					point = point,
					requestedInsertIndex = requestedInsertIndex,
					currentTabPage = self.Elements.UIPageLayout.CurrentPage,
					parentUsesLayoutOrder = parentUsesLayoutOrder,
					getOrderedMainDockChildren = getOrderedMainDockChildren,
					calculateMainInsertIndex = calculateMainInsertIndex,
					normalizeOrderedGuiLayout = normalizeOrderedGuiLayout,
					captureCurrentElementState = captureCurrentElementState,
					resyncElement = resyncElement,
					rememberedState = rememberedState
				})
				if ok then
					if reordered and nextRememberedState then
						rememberedState = nextRememberedState
					end
					return reordered == true
				end
			end

			if detached then
				return false
			end
			if not (guiObject and guiObject.Parent) then
				return false
			end

			local currentTabPage = self.Elements.UIPageLayout.CurrentPage
			if not currentTabPage or currentTabPage ~= guiObject.Parent then
				return false
			end
			if not parentUsesLayoutOrder(currentTabPage) then
				return false
			end

			local ordered = getOrderedMainDockChildren(currentTabPage, guiObject)
			local insertIndex = tonumber(requestedInsertIndex)
			if type(insertIndex) == "number" then
				insertIndex = math.floor(insertIndex)
			else
				insertIndex = nil
			end
			if type(insertIndex) ~= "number" then
				local calculated
				calculated, ordered = calculateMainInsertIndex(currentTabPage, point, guiObject)
				insertIndex = calculated
			end
			if type(insertIndex) ~= "number" then
				return false
			end

			insertIndex = math.clamp(insertIndex, 1, #ordered + 1)
			table.insert(ordered, insertIndex, guiObject)
			normalizeOrderedGuiLayout(ordered)

			local latestState = captureCurrentElementState()
			rememberedState = {
				Parent = latestState.Parent,
				AnchorPoint = latestState.AnchorPoint,
				Position = latestState.Position,
				Size = latestState.Size,
				LayoutOrder = latestState.LayoutOrder,
				SiblingIndex = latestState.SiblingIndex,
				PreviousSibling = latestState.PreviousSibling,
				NextSibling = latestState.NextSibling
			}
			resyncElement("reorder_main")
			return true
		end
	
		local function reorderElementInRecord(record, requestedInsertIndex)
			if type(ReorderFloatingWindowsLib) == "table" and type(ReorderFloatingWindowsLib.apply) == "function" then
				local ok, reordered = pcall(ReorderFloatingWindowsLib.apply, {
					record = record,
					guiObject = guiObject,
					requestedInsertIndex = requestedInsertIndex,
					getOrderedGuiChildren = getOrderedGuiChildren,
					normalizeOrderedGuiLayout = normalizeOrderedGuiLayout,
					updateWindowRecordLayout = updateWindowRecordLayout,
					resyncElement = resyncElement,
					notifyLayoutDirty = notifyLayoutDirty
				})
				if ok then
					return reordered == true
				end
			end

			if not (record and record.content and record.content.Parent) then
				return false
			end
	
			local ordered = getOrderedGuiChildren(record.content)
			local currentIndex = nil
			for index, child in ipairs(ordered) do
				if child == guiObject then
					currentIndex = index
					break
				end
			end
			if not currentIndex then
				return false
			end
	
			local insertIndex = tonumber(requestedInsertIndex)
			if type(insertIndex) == "number" then
				insertIndex = math.floor(insertIndex)
			else
				insertIndex = currentIndex
			end
	
			table.remove(ordered, currentIndex)
			insertIndex = math.clamp(insertIndex, 1, #ordered + 1)
			table.insert(ordered, insertIndex, guiObject)
			normalizeOrderedGuiLayout(ordered)
			record.nextOrder = (#ordered + 1) * 10
			updateWindowRecordLayout(record)
			resyncElement("reorder_detached")
			notifyLayoutDirty("floating_reorder")
			return true
		end
	
		local function attachToWindowRecord(record, requestedInsertIndex)
			if not (record and record.content and record.content.Parent) then
				return false
			end
	
			windowRecord = record
			floatingWindow = record.frame
			floatingContent = record.content
			floatingWindowWidth = record.width
			floatingTitleBar = record.titleBar
			floatingStroke = record.stroke
			floatingTitleLabel = record.titleLabel
			floatingDockButton = record.dockButton
			floatingDragCleanup = nil
	
			local elementHeight = math.max(guiObject.AbsoluteSize.Y, 36)
	
			guiObject.Parent = record.content
			guiObject.AnchorPoint = Vector2.zero
			guiObject.Position = UDim2.new(0, 0, 0, 0)
			guiObject.Size = UDim2.new(1, 0, 0, elementHeight)
			onVirtualElementMove(guiObject, "floating:" .. tostring(record.id), "detach_attach")

			local ordered = getOrderedGuiChildren(record.content, guiObject)
			local insertIndex = tonumber(requestedInsertIndex)
			if type(insertIndex) == "number" then
				insertIndex = math.clamp(math.floor(insertIndex), 1, #ordered + 1)
			else
				insertIndex = #ordered + 1
			end
			table.insert(ordered, insertIndex, guiObject)
			normalizeOrderedGuiLayout(ordered)
			record.nextOrder = (#ordered + 1) * 10
	
			record.elements[detacherId] = {
				name = elementName,
				dock = function(skipAnimation)
					return dockBack(skipAnimation)
				end,
				mergeTo = function(targetRecord)
					return moveToWindowRecord(targetRecord)
				end
			}
	
			createDetachedPlaceholder()
	
			cleanupWindowConnections()
			table.insert(windowConnections, guiObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				updateWindowRecordLayout(record)
				updateDetachedPlaceholder()
			end))
	
			detached = true
			updateWindowRecordLayout(record)
			updateDetachedPlaceholder()
			onVirtualHostRefresh("floating:" .. tostring(record.id), "detach_attach")
			resyncElement("detach_attach")
			notifyLayoutDirty("floating_attach")
			return true
		end
	
		moveToWindowRecord = function(targetRecord, requestedInsertIndex)
			if not detached then
				return false
			end
			if not (targetRecord and targetRecord.content and targetRecord.content.Parent) then
				return false
			end
			if targetRecord == windowRecord then
				return reorderElementInRecord(targetRecord, requestedInsertIndex)
			end
	
			local previousRecord = windowRecord
			cleanupWindowConnections()
	
			if previousRecord and previousRecord.elements then
				previousRecord.elements[detacherId] = nil
			end
	
			local attached = attachToWindowRecord(targetRecord, requestedInsertIndex)
			if not attached then
				if previousRecord and previousRecord.content and previousRecord.content.Parent then
					attachToWindowRecord(previousRecord)
				end
				return false
			end
	
			if previousRecord then
				if getWindowElementCount(previousRecord) <= 0 then
					destroyWindowRecord(previousRecord)
				else
					updateWindowRecordLayout(previousRecord)
				end
			end

			notifyLayoutDirty("floating_merge")

			return true
		end
	
		moveDetachedAt = function(point)
			if not detached then
				return false
			end
	
			local currentRecord = windowRecord
			if not (currentRecord and currentRecord.content and currentRecord.content.Parent) then
				return false
			end
	
			local targetRecord = findMergeTargetWindow(point, currentRecord)
	
			-- Float → Float: merge into another floating window (takes priority over self.Main)
			if targetRecord then
				local targetInsertIndex = nil
				if mergeIndicatorRecord == targetRecord and lastMergeInsertIndex then
					targetInsertIndex = lastMergeInsertIndex
				end
				if type(targetInsertIndex) ~= "number" then
					targetInsertIndex = calculateRecordInsertIndex(targetRecord, point)
				end
				return moveToWindowRecord(targetRecord, targetInsertIndex)
			end
	
			-- Float → self.Main: dock back to a specific position in the self.Main UI
			if isInsideMain(point) then
				local targetInsertIndex = lastMainDropInsertIndex
				local targetState = originalState or rememberedState
				if type(targetInsertIndex) ~= "number" then
					local currentTabPage = self.Elements.UIPageLayout.CurrentPage
					if targetState and targetState.Parent and currentTabPage == targetState.Parent then
						targetInsertIndex = calculateMainInsertIndex(currentTabPage, point)
					end
				end
				if type(targetInsertIndex) == "number" then
					return dockBackToPosition(targetInsertIndex)
				end
				return dockBack()
			end
	
			-- Float → same window: reorder within current window
			if not isPointNearFrame(point, currentRecord.frame, DETACH_MERGE_DETECT_PADDING) then
				return false
			end
			local targetInsertIndex = nil
			if mergeIndicatorRecord == currentRecord and lastMergeInsertIndex then
				targetInsertIndex = lastMergeInsertIndex
			end
			if type(targetInsertIndex) ~= "number" then
				targetInsertIndex = calculateRecordInsertIndex(currentRecord, point)
			end
	
			return moveToWindowRecord(currentRecord, targetInsertIndex)
		end
	
		local function createWindowRecord(point, windowWidth, windowHeight)
			local layer = ensureDetachedLayer()
			local desiredPosition = Vector2.new(point.X - (windowWidth / 2), point.Y - (DETACH_HEADER_HEIGHT / 2))
			local clampedPosition = clampDetachedPosition(desiredPosition, Vector2.new(windowWidth, windowHeight))
			local finalPosition = Vector2.new(clampedPosition.X, clampedPosition.Y)
	
			local startSize = Vector2.new(
				math.max(math.floor(windowWidth * 0.92), 140),
				math.max(math.floor(windowHeight * 0.9), 70)
			)
			local startPosition = Vector2.new(
				finalPosition.X + math.floor((windowWidth - startSize.X) / 2),
				finalPosition.Y + 8
			)
	
			local record = {
				id = self.HttpService:GenerateGUID(false),
				frame = nil,
				titleBar = nil,
				content = nil,
				layout = nil,
				stroke = nil,
				titleLabel = nil,
				dockButton = nil,
				width = windowWidth,
				elements = {},
				nextOrder = 1,
				connections = {},
				dragCleanup = nil
			}
	
			record.frame = Instance.new("Frame")
			record.frame.Name = "Detached-" .. guiObject.Name
			record.frame.Size = UDim2.fromOffset(startSize.X, startSize.Y)
			record.frame.Position = UDim2.fromOffset(startPosition.X, startPosition.Y)
			record.frame.BackgroundColor3 = self.getSelectedTheme().SecondaryElementBackground
			record.frame.BackgroundTransparency = 1
			record.frame.BorderSizePixel = 0
			record.frame.ZIndex = 200
			record.frame.Parent = layer
	
			local floatingCorner = Instance.new("UICorner")
			floatingCorner.CornerRadius = UDim.new(0, 9)
			floatingCorner.Parent = record.frame
	
			record.stroke = Instance.new("UIStroke")
			record.stroke.Color = self.getSelectedTheme().ElementStroke
			record.stroke.Thickness = 1.5
			record.stroke.Transparency = 1
			record.stroke.Parent = record.frame
	
			record.titleBar = Instance.new("Frame")
			record.titleBar.Name = "TitleBar"
			record.titleBar.Size = UDim2.new(1, 0, 0, DETACH_HEADER_HEIGHT)
			record.titleBar.BackgroundColor3 = self.getSelectedTheme().ElementBackground
			record.titleBar.BackgroundTransparency = 1
			record.titleBar.BorderSizePixel = 0
			record.titleBar.ZIndex = 201
			record.titleBar.Parent = record.frame
	
			record.titleLabel = Instance.new("TextLabel")
			record.titleLabel.Name = "Title"
			record.titleLabel.BackgroundTransparency = 1
			record.titleLabel.Size = UDim2.new(1, -72, 1, 0)
			record.titleLabel.Position = UDim2.new(0, 10, 0, 0)
			record.titleLabel.Text = tostring(elementName)
			record.titleLabel.TextColor3 = self.getSelectedTheme().TextColor
			record.titleLabel.TextSize = 12
			record.titleLabel.TextTransparency = 1
			record.titleLabel.Font = Enum.Font.GothamSemibold
			record.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
			record.titleLabel.ZIndex = 202
			record.titleLabel.Parent = record.titleBar
	
			record.dockButton = Instance.new("TextButton")
			record.dockButton.Name = "DockButton"
			record.dockButton.Size = UDim2.fromOffset(48, 20)
			record.dockButton.Position = UDim2.new(1, -54, 0.5, -10)
			record.dockButton.BackgroundColor3 = self.getSelectedTheme().ElementBackgroundHover
			record.dockButton.BackgroundTransparency = 1
			record.dockButton.BorderSizePixel = 0
			record.dockButton.Text = "Dock"
			record.dockButton.TextColor3 = self.getSelectedTheme().TextColor
			record.dockButton.TextSize = 10
			record.dockButton.TextTransparency = 1
			record.dockButton.Font = Enum.Font.GothamBold
			record.dockButton.ZIndex = 202
			record.dockButton.Parent = record.titleBar
	
			local dockCorner = Instance.new("UICorner")
			dockCorner.CornerRadius = UDim.new(0, 6)
			dockCorner.Parent = record.dockButton
	
			record.content = Instance.new("Frame")
			record.content.Name = "Content"
			record.content.BackgroundTransparency = 1
			record.content.BorderSizePixel = 0
			record.content.Size = UDim2.new(1, -10, 1, -(DETACH_HEADER_HEIGHT + 10))
			record.content.Position = UDim2.fromOffset(5, DETACH_HEADER_HEIGHT + 5)
			record.content.ClipsDescendants = true
			record.content.ZIndex = 201
			record.content.Parent = record.frame
	
			record.layout = Instance.new("UIListLayout")
			record.layout.Padding = UDim.new(0, 6)
			record.layout.SortOrder = Enum.SortOrder.LayoutOrder
			record.layout.Parent = record.content

			onVirtualHostCreate("floating:" .. tostring(record.id), record.content, {
				mode = "clipped"
			})

			record.dragCleanup = makeFloatingDraggable(record.frame, record.titleBar, function(releasePoint)
				if not (record.frame and record.frame.Parent) then
					return
				end
				notifyLayoutDirty("floating_move")
	
				local point = releasePoint
				if not point then
					local absPos = record.frame.AbsolutePosition
					local absSize = record.frame.AbsoluteSize
					point = Vector2.new(absPos.X + (absSize.X * 0.5), absPos.Y + (absSize.Y * 0.5))
				end
	
				local targetRecord = findMergeTargetWindow(point, record)
				if not targetRecord then
					return
				end
	
				local mergeHandlers = {}
				for _, entry in pairs(record.elements) do
					if entry and entry.mergeTo then
						table.insert(mergeHandlers, entry.mergeTo)
					end
				end
	
				for _, mergeFn in ipairs(mergeHandlers) do
					pcall(function()
						mergeFn(targetRecord)
					end)
				end
			end)
	
			table.insert(record.connections, record.dockButton.MouseButton1Click:Connect(function()
				local docks = {}
				for _, entry in pairs(record.elements) do
					if entry and entry.dock then
						table.insert(docks, entry.dock)
					end
				end
				for _, dockFn in ipairs(docks) do
					pcall(function()
						dockFn(true)
					end)
				end
			end))
	
			registerDetachedWindow(record)
	
			self.Animation:Create(record.frame, TweenInfo.new(DETACH_POP_IN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(windowWidth, windowHeight),
				Position = UDim2.fromOffset(finalPosition.X, finalPosition.Y),
				BackgroundTransparency = 0
			}):Play()
			self.Animation:Create(record.stroke, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
			self.Animation:Create(record.titleBar, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
			self.Animation:Create(record.titleLabel, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
			self.Animation:Create(record.dockButton, TweenInfo.new(DETACH_POP_IN_DURATION * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
				TextTransparency = 0
			}):Play()
	
			return record
		end
	
		dockBack = function(skipWindowAnimation)
			if not detached then
				return false
			end
	
			local targetState = originalState or rememberedState
			local targetParent = targetState and targetState.Parent
			if not targetParent or not targetParent.Parent then
				cleanupFloatingWindow()
				detached = false
				originalState = nil
				return false
			end
	
			local record = windowRecord
			local recordCountBefore = getWindowElementCount(record)
			local shouldCollapse = (not skipWindowAnimation) and record and record.frame and record.frame.Parent and recordCountBefore <= 1
	
			if shouldCollapse then
				local collapseWidth = math.max(math.floor(record.frame.Size.X.Offset * 0.94), 120)
				local collapseHeight = math.max(math.floor(record.frame.Size.Y.Offset * 0.92), 70)
				self.Animation:Create(record.frame, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(collapseWidth, collapseHeight)
				}):Play()
				if record.stroke then
					self.Animation:Create(record.stroke, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
				end
				if record.titleBar then
					self.Animation:Create(record.titleBar, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
				end
				if record.titleLabel then
					self.Animation:Create(record.titleLabel, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
				end
				if record.dockButton then
					self.Animation:Create(record.dockButton, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						BackgroundTransparency = 1,
						TextTransparency = 1
					}):Play()
				end
				task.wait(DETACH_POP_OUT_DURATION)
			end
	
			local placeholder = detachedPlaceholder
			guiObject.Parent = targetParent
			guiObject.AnchorPoint = targetState.AnchorPoint
			guiObject.Position = targetState.Position
			guiObject.Size = targetState.Size
			local tabVirtualHostId = resolveTabVirtualHostId()
			if tabVirtualHostId then
				onVirtualElementMove(guiObject, tabVirtualHostId, "dock_back")
				onVirtualHostRefresh(tabVirtualHostId, "dock_back")
			end
	
			if parentUsesLayoutOrder(targetParent) then
				local ordered = getOrderedGuiChildren(targetParent, guiObject, placeholder)
				local slotIndex = nil
	
				if placeholder and placeholder.Parent == targetParent then
					slotIndex = placeholder:GetAttribute("DetachSlotIndex")
				end
				if type(slotIndex) ~= "number" then
					slotIndex = resolveInsertIndexFromState(targetParent, targetState, ordered)
				end
	
				if type(slotIndex) == "number" then
					slotIndex = math.clamp(slotIndex, 1, #ordered + 1)
					table.insert(ordered, slotIndex, guiObject)
					normalizeOrderedGuiLayout(ordered)
				else
					guiObject.LayoutOrder = targetState.LayoutOrder
				end
			else
				guiObject.LayoutOrder = targetState.LayoutOrder
			end
	
			destroyDetachedPlaceholder()
	
			if record and record.elements then
				record.elements[detacherId] = nil
				if getWindowElementCount(record) <= 0 then
					destroyWindowRecord(record)
				else
					updateWindowRecordLayout(record)
				end
			end
	
			windowRecord = nil
			floatingWindow = nil
			floatingContent = nil
			floatingWindowWidth = nil
			floatingTitleBar = nil
			floatingStroke = nil
			floatingTitleLabel = nil
			floatingDockButton = nil
			cleanupWindowConnections()
	
			detached = false
			originalState = nil
			hoverCounter = 0
			hoverActive = false
			refreshDetachCue()
			resyncElement("dock_back")
			notifyLayoutDirty("element_docked")
			return true
		end
	
		dockBackToPosition = function(insertIndex)
			if not detached then
				return false
			end
	
			local targetState = originalState or rememberedState
			if not targetState then
				return dockBack()
			end
	
			local currentTabPage = self.Elements.UIPageLayout.CurrentPage
			if not (currentTabPage and currentTabPage.Parent) then
				return dockBack()
			end
	
			-- Only allow position-aware dock to the original parent tab page
			local targetParent = targetState.Parent
			if targetParent ~= currentTabPage then
				return dockBack()
			end
	
			local record = windowRecord
			local recordCountBefore = getWindowElementCount(record)
			local shouldCollapse = record and record.frame and record.frame.Parent and recordCountBefore <= 1
	
			if shouldCollapse then
				local collapseWidth = math.max(math.floor(record.frame.Size.X.Offset * 0.94), 120)
				local collapseHeight = math.max(math.floor(record.frame.Size.Y.Offset * 0.92), 70)
				self.Animation:Create(record.frame, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(collapseWidth, collapseHeight)
				}):Play()
				if record.stroke then
					self.Animation:Create(record.stroke, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
				end
				if record.titleBar then
					self.Animation:Create(record.titleBar, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
				end
				if record.titleLabel then
					self.Animation:Create(record.titleLabel, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
				end
				if record.dockButton then
					self.Animation:Create(record.dockButton, TweenInfo.new(DETACH_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						BackgroundTransparency = 1,
						TextTransparency = 1
					}):Play()
				end
				task.wait(DETACH_POP_OUT_DURATION)
			end
	
			local placeholder = detachedPlaceholder
			guiObject.Parent = targetParent
			guiObject.AnchorPoint = targetState.AnchorPoint
			guiObject.Position = targetState.Position
			guiObject.Size = targetState.Size
			local tabVirtualHostId = resolveTabVirtualHostId()
			if tabVirtualHostId then
				onVirtualElementMove(guiObject, tabVirtualHostId, "dock_back_to_position")
				onVirtualHostRefresh(tabVirtualHostId, "dock_back_to_position")
			end
	
			if parentUsesLayoutOrder(targetParent) then
				local ordered
				if targetParent == currentTabPage then
					ordered = getOrderedMainDockChildren(targetParent, guiObject, placeholder)
				else
					ordered = getOrderedGuiChildren(targetParent, guiObject, placeholder)
				end
				local clampedIndex = math.clamp(insertIndex, 1, #ordered + 1)
				table.insert(ordered, clampedIndex, guiObject)
				normalizeOrderedGuiLayout(ordered)
			else
				guiObject.LayoutOrder = targetState.LayoutOrder
			end
	
			destroyDetachedPlaceholder()
	
			if record and record.elements then
				record.elements[detacherId] = nil
				if getWindowElementCount(record) <= 0 then
					destroyWindowRecord(record)
				else
					updateWindowRecordLayout(record)
				end
			end
	
			windowRecord = nil
			floatingWindow = nil
			floatingContent = nil
			floatingWindowWidth = nil
			floatingTitleBar = nil
			floatingStroke = nil
			floatingTitleLabel = nil
			floatingDockButton = nil
			cleanupWindowConnections()
	
			detached = false
			originalState = nil
			hoverCounter = 0
			hoverActive = false
			refreshDetachCue()
			resyncElement("dock_back_to_position")
			notifyLayoutDirty("element_docked_positioned")
			return true
		end
	
		local function detachAt(point)
			if detached or not guiObject.Parent then
				return false
			end
	
			originalState = captureCurrentElementState()
			rememberedState = {
				Parent = originalState.Parent,
				AnchorPoint = originalState.AnchorPoint,
				Position = originalState.Position,
				Size = originalState.Size,
				LayoutOrder = originalState.LayoutOrder,
				SiblingIndex = originalState.SiblingIndex,
				PreviousSibling = originalState.PreviousSibling,
				NextSibling = originalState.NextSibling
			}
	
			if not originalState.Parent then
				return false
			end
	
			local elementHeight = math.max(guiObject.AbsoluteSize.Y, 36)
			local windowWidth = math.max(guiObject.AbsoluteSize.X + 20, DETACH_MIN_WIDTH)
			local windowHeight = math.max(elementHeight + DETACH_HEADER_HEIGHT + 12, DETACH_MIN_HEIGHT)
	
			local targetRecord = findMergeTargetWindow(point, nil)
			local targetInsertIndex = nil
			if targetRecord then
				if mergeIndicatorRecord == targetRecord and lastMergeInsertIndex then
					targetInsertIndex = lastMergeInsertIndex
				end
				if type(targetInsertIndex) ~= "number" then
					targetInsertIndex = calculateRecordInsertIndex(targetRecord, point)
				end
			end
			if not targetRecord then
				targetRecord = createWindowRecord(point, windowWidth, windowHeight)
			end
			if not targetRecord then
				return false
			end
	
			local attached = attachToWindowRecord(targetRecord, targetInsertIndex)
			if not attached then
				return false
			end
	
			if targetRecord.stroke then
				local baseThickness = targetRecord.stroke.Thickness
				targetRecord.stroke.Thickness = baseThickness + 0.9
				self.Animation:Create(targetRecord.stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Thickness = baseThickness
				}):Play()
			end

			refreshDetachCue()
			local tabVirtualHostId = resolveTabVirtualHostId()
			if tabVirtualHostId then
				onVirtualHostRefresh(tabVirtualHostId, "element_detached")
			end
			resyncElement("detach")
			notifyLayoutDirty("element_detached")
			return true
		end

		local function getDetachedLayoutSnapshot()
			if not detached then
				return nil
			end
			if not (windowRecord and windowRecord.frame and windowRecord.frame.Parent) then
				return nil
			end

			local frame = windowRecord.frame
			local position = frame.Position
			local size = frame.Size
			return {
				detached = true,
				position = {
					x = position.X.Offset,
					y = position.Y.Offset
				},
				size = {
					x = size.X.Offset,
					y = size.Y.Offset
				},
				tabId = persistenceMeta.tabId,
				elementType = persistenceMeta.elementType
			}
		end

		local function applyDetachedLayout(layout)
			if type(layout) ~= "table" then
				return false
			end
			if not (windowRecord and windowRecord.frame and windowRecord.frame.Parent) then
				return false
			end

			local frame = windowRecord.frame
			local sizeSpec = layout.size
			local width = sizeSpec and tonumber(sizeSpec.x)
			local height = sizeSpec and tonumber(sizeSpec.y)
			if not width then
				width = frame.Size.X.Offset
			end
			if not height then
				height = frame.Size.Y.Offset
			end
			width = math.max(math.floor(width), DETACH_MIN_WIDTH)
			height = math.max(math.floor(height), DETACH_MIN_HEIGHT)

			local positionSpec = layout.position
			local posX = positionSpec and tonumber(positionSpec.x)
			local posY = positionSpec and tonumber(positionSpec.y)
			if not posX then
				posX = frame.Position.X.Offset
			end
			if not posY then
				posY = frame.Position.Y.Offset
			end

			local clamped = clampDetachedPosition(Vector2.new(posX, posY), Vector2.new(width, height))
			frame.Size = UDim2.fromOffset(width, height)
			frame.Position = UDim2.fromOffset(clamped.X, clamped.Y)
			windowRecord.width = width
			updateWindowRecordLayout(windowRecord)
			notifyLayoutDirty("floating_layout_applied")
			return true
		end
	
		local function handleDetachHoverEnter()
			if detached then
				return
			end
			hoverCounter = 1
			hoverActive = true
			syncCueHoverFromPointer(self.UserInputService:GetMouseLocation(), true)
		end
	
		local function handleDetachHoverLeave()
			hoverCounter = 0
			hoverActive = false
			syncCueHoverFromPointer(self.UserInputService:GetMouseLocation(), true)
		end
	
		local function handleDetachInputBegan(input)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end
			if elementType == "Input" and self.UserInputService:GetFocusedTextBox() then
				return
			end
			if pressing or dragArmed then
				return
			end
	
			ensureDetachCue()
			pressing = true
			pressInput = input
			pressToken += 1
			dragArmed = false
			setInteractionBusy(true)
			pointerPosition = getInputPosition(input)
			local token = pressToken
			refreshDetachCue()
			task.spawn(runHoldCueProgress, token)
	
			task.delay(adaptiveHoldDuration, function()
				if pressToken ~= token or not pressing then
					return
				end
				dragArmed = true
				refreshDetachCue()
				createDragGhost()
			end)
		end
	
		for _, source in ipairs(dragInputSources) do
			table.insert(eventConnections, source.MouseEnter:Connect(handleDetachHoverEnter))
			table.insert(eventConnections, source.MouseLeave:Connect(handleDetachHoverLeave))
			table.insert(eventConnections, source.InputBegan:Connect(handleDetachInputBegan))
		end

		local currentPageSignal = self.Elements and self.Elements.UIPageLayout and self.Elements.UIPageLayout:GetPropertyChangedSignal("CurrentPage")
		if currentPageSignal then
			table.insert(eventConnections, currentPageSignal:Connect(function()
				local pointer = self.UserInputService:GetMouseLocation()
				syncCueHoverFromPointer(pointer, true)
				if pressing and not isGuiActiveInCurrentPage(guiObject) then
					resetDragState("page_changed")
				end
			end))
		end

		table.insert(eventConnections, guiObject:GetPropertyChangedSignal("Visible"):Connect(function()
			syncCueHoverFromPointer(self.UserInputService:GetMouseLocation(), true)
		end))
	
		-- Use shared global dispatcher instead of per-element InputChanged/InputEnded
		registerSharedInput(detacherId, function(input) -- InputChanged
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				pointerPosition = getInputPosition(input)
				if not pressing then
					syncCueHoverFromPointer(pointerPosition, false)
				end
			end

			if not pressing or not pressInput then
				return
			end
	
			local matchesTouch = input == pressInput
			local matchesMouse = pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
			if not matchesTouch and not matchesMouse then
				return
			end
	
			pointerPosition = getInputPosition(input)
			if dragArmed then
				updateGhostPosition()
				updateMergePreview(pointerPosition)
			end
		end, function(input) -- InputEnded
			if not pressInput then
				return
			end
	
			local sameTouch = input == pressInput
			local mouseEnded = pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
			if not sameTouch and not mouseEnded then
				return
			end
	
			pressing = false
			pressInput = nil
			pressToken += 1
			setInteractionBusy(false)
	
			-- Snapshot cached insert indices before clearMergePreview wipes them
			local cachedMainDropIndex = lastMainDropInsertIndex
			local cachedMergeInsertIndex = lastMergeInsertIndex
			clearMergePreview(false)
	
			local dropPoint = pointerPosition or self.UserInputService:GetMouseLocation()
			if dragArmed then
				dragArmed = false
				destroyDragGhost()
				if detached then
					if dropPoint then
						-- Restore cached index so moveDetachedAt can use the indicator's value
						lastMainDropInsertIndex = cachedMainDropIndex
						lastMergeInsertIndex = cachedMergeInsertIndex
						if not moveDetachedAt(dropPoint) then
							refreshDetachCue()
						end
						lastMainDropInsertIndex = nil
						lastMergeInsertIndex = nil
					else
						refreshDetachCue()
					end
				else
					local hasMergeTarget = dropPoint and findMergeTargetWindow(dropPoint, nil) ~= nil
					local canReorderInMain = dropPoint and isInsideMain(dropPoint) and isGuiActiveInCurrentPage(guiObject)
					if canReorderInMain then
						lastMainDropInsertIndex = cachedMainDropIndex
						local reordered = reorderInMainAt(dropPoint, lastMainDropInsertIndex)
						lastMainDropInsertIndex = nil
						if not reordered then
							if dropPoint and (isOutsideMain(dropPoint) or hasMergeTarget) then
								if not detachAt(dropPoint) then
									refreshDetachCue()
								end
							else
								refreshDetachCue()
							end
						else
							syncCueHoverFromPointer(dropPoint, true)
						end
					elseif dropPoint and (isOutsideMain(dropPoint) or hasMergeTarget) then
						if not detachAt(dropPoint) then
							refreshDetachCue()
						end
					else
						refreshDetachCue()
					end
				end
			else
				destroyDragGhost()
				refreshDetachCue()
			end
		end)
	
		local function fullCleanup()
			setInteractionBusy(false)
			detacherRegistry[detacherId] = nil
			unregisterSharedInput(detacherId)
			destroyDragGhost(true)
			cleanupFloatingWindow()
			cleanupDetachCue()
			for _, connection in ipairs(eventConnections) do
				if connection then
					connection:Disconnect()
				end
			end
			table.clear(eventConnections)
		end
	
		local function connectIfAvailable(signalName, callback)
			local ok, signal = pcall(function()
				return guiObject[signalName]
			end)
			if ok and signal and signal.Connect then
				table.insert(eventConnections, signal:Connect(callback))
			end
		end

		-- Cleanup when guiObject is destroyed
		connectIfAvailable("Destroying", fullCleanup)
	
		-- Safety net: cleanup if element leaves the DataModel without being destroyed
		-- (e.g. parent set to nil, or ancestor removed)
		connectIfAvailable("AncestryChanged", function()
			if not guiObject:IsDescendantOf(game) then
				task.defer(function()
					-- Re-check after defer in case of rapid reparent
					if not guiObject:IsDescendantOf(game) then
						fullCleanup()
					end
				end)
			else
				task.defer(function()
					if guiObject and guiObject.Parent then
						syncCueHoverFromPointer(self.UserInputService:GetMouseLocation(), true)
						if pressing and not isGuiActiveInCurrentPage(guiObject) then
							resetDragState("reparent")
						end
					end
				end)
			end
		end)

		task.defer(function()
			if guiObject and guiObject.Parent then
				syncCueHoverFromPointer(self.UserInputService:GetMouseLocation(), true)
			end
		end)
	
		local detacherApi = {
			Detach = function(position)
				local pos = position or self.UserInputService:GetMouseLocation()
				return detachAt(pos)
			end,
			Dock = function()
				return dockBack()
			end,
			GetRememberedState = function()
				if not rememberedState then
					return nil
				end
				return {
					Parent = rememberedState.Parent,
					AnchorPoint = rememberedState.AnchorPoint,
					Position = rememberedState.Position,
					Size = rememberedState.Size,
					LayoutOrder = rememberedState.LayoutOrder,
					SiblingIndex = rememberedState.SiblingIndex,
					PreviousSibling = rememberedState.PreviousSibling,
					NextSibling = rememberedState.NextSibling
				}
			end,
			IsDetached = function()
				return detached
			end,
			SetPersistenceMetadata = function(metadata)
				if type(metadata) ~= "table" then
					return
				end
				if type(metadata.flag) == "string" and metadata.flag ~= "" then
					persistenceMeta.flag = metadata.flag
				end
				if type(metadata.tabId) == "string" and metadata.tabId ~= "" then
					persistenceMeta.tabId = metadata.tabId
				end
				if type(metadata.virtualHostId) == "string" and metadata.virtualHostId ~= "" then
					persistenceMeta.virtualHostId = metadata.virtualHostId
				end
				if type(metadata.elementName) == "string" and metadata.elementName ~= "" then
					persistenceMeta.elementName = metadata.elementName
				end
				if type(metadata.elementType) == "string" and metadata.elementType ~= "" then
					persistenceMeta.elementType = metadata.elementType
				end
			end,
			GetLayoutSnapshot = function()
				return getDetachedLayoutSnapshot()
			end,
			ApplyLayoutSnapshot = function(layout)
				if type(layout) ~= "table" then
					return false
				end
				if layout.detached ~= true then
					if detached then
						return dockBack()
					end
					return true
				end
				local position = layout.position
				local targetX = position and tonumber(position.x)
				local targetY = position and tonumber(position.y)
				local size = layout.size
				local targetWidth = size and tonumber(size.x)
				local targetHeight = size and tonumber(size.y)
				local detachPoint = Vector2.new(
					(targetX or 0) + math.floor((targetWidth or DETACH_MIN_WIDTH) / 2),
					(targetY or 0) + math.floor((targetHeight or DETACH_MIN_HEIGHT) / 2)
				)
				if not detached then
					local detachedNow = detachAt(detachPoint)
					if not detachedNow then
						return false
					end
				end
				return applyDetachedLayout(layout)
			end,
			Destroy = fullCleanup
		}

		detacherRegistry[detacherId] = {
			id = detacherId,
			meta = persistenceMeta,
			api = detacherApi
		}
		return detacherApi
	end


	return createElementDetacher
end

return DetacherModule
