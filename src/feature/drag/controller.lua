-- Rayfield Drag/Detach System Module
-- Handles element detachment, mini windows, drag preview, and dock/undock logic

local DragModule = {}
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

local DragInputLib = loadSubmodule("input", "src/feature/drag/input.lua")
local DragWindowLib = loadSubmodule("window", "src/feature/drag/window.lua")
local DragDockLib = loadSubmodule("dock", "src/feature/drag/dock.lua")
local DragDetacherLib = loadSubmodule("detacher", "src/feature/drag/detacher.lua")
local DragReorderMainUiLib = loadSubmodule("reorder_main_ui", "src/feature/drag/reorder_main_ui.lua")
local DragReorderFloatingWindowsLib = loadSubmodule("reorder_floating_windows", "src/feature/drag/reorder_floating_windows.lua")

-- Initialize module with dependencies
function DragModule.init(ctx)
	local self = {}

	-- Inject dependencies
	self.UserInputService = ctx.UserInputService
	self.TweenService = ctx.TweenService
	self.Animation = ctx.Animation or ctx.TweenService
	self.RunService = ctx.RunService
	self.HttpService = ctx.HttpService
	self.Main = ctx.Main
	self.Topbar = ctx.Topbar
	self.Elements = ctx.Elements
	self.Rayfield = ctx.Rayfield
	self.Icons = ctx.Icons
	self.getIcon = ctx.getIcon
	self.getAssetUri = ctx.getAssetUri
	self.getSelectedTheme = ctx.getSelectedTheme
	self.rayfieldDestroyed = ctx.rayfieldDestroyed
	self.ElementSync = ctx.ElementSync
	self.getSetting = ctx.getSetting
	self.useMobileSizing = ctx.useMobileSizing
	self.getViewportVirtualization = ctx.getViewportVirtualization
	self.getDetachEnabled = ctx.getDetachEnabled
	self.enableDetach = ctx.enableDetach

	-- Extract code starts here

	local DETACH_HOLD_DURATION = 3
	local DETACH_HEADER_HEIGHT = 28
	local DETACH_MIN_WIDTH = 250
	local DETACH_MIN_HEIGHT = 90
	local DETACH_GHOST_FOLLOW_SPEED = 0.22
	local DETACH_WINDOW_DRAG_FOLLOW_SPEED = 0.28
	local DETACH_POP_IN_DURATION = 0.2
	local DETACH_POP_OUT_DURATION = 0.14
	local DETACH_CUE_HOVER_TRANSPARENCY = 0.52
	local DETACH_CUE_HOLD_TRANSPARENCY = 0.34
	local DETACH_CUE_READY_TRANSPARENCY = 0.24
	local DETACH_CUE_IDLE_THICKNESS = 1
	local DETACH_CUE_HOVER_THICKNESS = 1.35
	local DETACH_CUE_HOLD_THICKNESS = 1.9
	local DETACH_CUE_READY_THICKNESS = 2.2
	local DETACH_MERGE_DETECT_PADDING = 56
	local MERGE_INDICATOR_HEIGHT = 3
	local MERGE_INDICATOR_MARGIN = 8
	local MERGE_INDICATOR_TWEEN_DURATION = 0.12
	local DETACH_MOD_BUILD = "overlay-indicator-v1"
	_G.__RAYFIELD_MOD_BUILD = DETACH_MOD_BUILD
	local layoutDirtyCallback = type(ctx.onLayoutDirty) == "function" and ctx.onLayoutDirty or nil
	local detacherRegistry = {}

	local function isDetachEnabled()
		if type(self.getDetachEnabled) == "function" then
			local ok, enabled = pcall(self.getDetachEnabled)
			if ok then
				return enabled ~= false
			end
			return true
		end
		if self.enableDetach ~= nil then
			return self.enableDetach ~= false
		end
		return true
	end

	local function getViewportVirtualization()
		if type(self.getViewportVirtualization) == "function" then
			local ok, service = pcall(self.getViewportVirtualization)
			if ok then
				return service
			end
			return nil
		end
		return ctx.ViewportVirtualization
	end

	local function virtualRegisterHost(hostId, hostObject, options)
		local service = getViewportVirtualization()
		if service and type(service.registerHost) == "function" then
			pcall(service.registerHost, hostId, hostObject, options)
		end
	end

	local function virtualUnregisterHost(hostId)
		local service = getViewportVirtualization()
		if service and type(service.unregisterHost) == "function" then
			pcall(service.unregisterHost, hostId)
		end
	end

	local function virtualRefreshHost(hostId, reason)
		local service = getViewportVirtualization()
		if service and type(service.refreshHost) == "function" then
			pcall(service.refreshHost, hostId, reason)
		end
	end

	local function virtualMoveElement(guiObject, hostId, reason)
		local service = getViewportVirtualization()
		if service and type(service.moveElementToHost) == "function" then
			pcall(service.moveElementToHost, guiObject, hostId, reason)
		end
	end

	local function virtualSetElementBusy(guiObject, busy)
		local service = getViewportVirtualization()
		if service and type(service.setElementBusy) == "function" then
			pcall(service.setElementBusy, guiObject, busy)
		end
	end

	local function notifyLayoutDirty(reason)
		if type(layoutDirtyCallback) ~= "function" then
			return
		end
		pcall(layoutDirtyCallback, "floating", reason or "drag_layout_changed")
	end
	
	local inputManager = DragInputLib.create(self.UserInputService)
	local windowManager = DragWindowLib.create({
		UserInputService = self.UserInputService,
		RunService = self.RunService,
		HttpService = self.HttpService,
		Rayfield = self.Rayfield,
		Main = self.Main,
		rayfieldDestroyed = self.rayfieldDestroyed,
		mergeDetectPadding = DETACH_MERGE_DETECT_PADDING,
		followSpeed = DETACH_WINDOW_DRAG_FOLLOW_SPEED,
		getInputPosition = function(input)
			return inputManager.getInputPosition(input)
		end,
		registerSharedInput = function(id, onChanged, onEnded)
			inputManager.register(id, onChanged, onEnded)
		end,
		unregisterSharedInput = function(id)
			inputManager.unregister(id)
		end,
		onDestroyInput = function()
			inputManager.disconnect()
		end
	})

	local function ensureSharedInputConnections()
		inputManager.ensure()
	end

	local function registerSharedInput(id, onChanged, onEnded)
		inputManager.register(id, onChanged, onEnded)
	end

	local function unregisterSharedInput(id)
		inputManager.unregister(id)
	end

	local function registerDetachedWindow(record)
		windowManager.registerDetachedWindow(record)
	end

	local function unregisterDetachedWindow(record)
		windowManager.unregisterDetachedWindow(record)
	end

	local function isPointNearFrame(point, frame, padding)
		return windowManager.isPointNearFrame(point, frame, padding)
	end

	local function findMergeTargetWindow(point, excludeRecord)
		return windowManager.findMergeTargetWindow(point, excludeRecord)
	end

	local function ensureDetachedLayer()
		return windowManager.ensureDetachedLayer()
	end

	windowManager.prewarmDetachedLayer()

	local function getInputPosition(input)
		return inputManager.getInputPosition(input)
	end

	local function clampDetachedPosition(desiredPosition, windowSize)
		return windowManager.clampDetachedPosition(desiredPosition, windowSize)
	end

	local function isOutsideMain(point)
		return windowManager.isOutsideMain(point)
	end

	local function isInsideMain(point)
		return windowManager.isInsideMain(point)
	end

	local function makeFloatingDraggable(frame, dragHandle, onDragEnd)
		return windowManager.makeFloatingDraggable(frame, dragHandle, onDragEnd)
	end
	
	local createElementDetacher = DragDetacherLib.create({
		self = self,
		DragDockLib = DragDockLib,
		registerSharedInput = registerSharedInput,
		unregisterSharedInput = unregisterSharedInput,
		registerDetachedWindow = registerDetachedWindow,
		unregisterDetachedWindow = unregisterDetachedWindow,
		isPointNearFrame = isPointNearFrame,
		findMergeTargetWindow = findMergeTargetWindow,
		ensureDetachedLayer = ensureDetachedLayer,
		getInputPosition = getInputPosition,
		clampDetachedPosition = clampDetachedPosition,
		isOutsideMain = isOutsideMain,
		isInsideMain = isInsideMain,
		makeFloatingDraggable = makeFloatingDraggable,
		notifyLayoutDirty = notifyLayoutDirty,
		onVirtualHostCreate = virtualRegisterHost,
		onVirtualHostDestroy = virtualUnregisterHost,
		onVirtualHostRefresh = virtualRefreshHost,
		onVirtualElementMove = virtualMoveElement,
		onVirtualElementBusy = virtualSetElementBusy,
		ReorderMainUILib = DragReorderMainUiLib,
		ReorderFloatingWindowsLib = DragReorderFloatingWindowsLib,
		detacherRegistry = detacherRegistry,
		constants = {
			DETACH_HOLD_DURATION = DETACH_HOLD_DURATION,
			DETACH_HEADER_HEIGHT = DETACH_HEADER_HEIGHT,
			DETACH_MIN_WIDTH = DETACH_MIN_WIDTH,
			DETACH_MIN_HEIGHT = DETACH_MIN_HEIGHT,
			DETACH_GHOST_FOLLOW_SPEED = DETACH_GHOST_FOLLOW_SPEED,
			DETACH_WINDOW_DRAG_FOLLOW_SPEED = DETACH_WINDOW_DRAG_FOLLOW_SPEED,
			DETACH_POP_IN_DURATION = DETACH_POP_IN_DURATION,
			DETACH_POP_OUT_DURATION = DETACH_POP_OUT_DURATION,
			DETACH_CUE_HOVER_TRANSPARENCY = DETACH_CUE_HOVER_TRANSPARENCY,
			DETACH_CUE_HOLD_TRANSPARENCY = DETACH_CUE_HOLD_TRANSPARENCY,
			DETACH_CUE_READY_TRANSPARENCY = DETACH_CUE_READY_TRANSPARENCY,
			DETACH_CUE_IDLE_THICKNESS = DETACH_CUE_IDLE_THICKNESS,
			DETACH_CUE_HOVER_THICKNESS = DETACH_CUE_HOVER_THICKNESS,
			DETACH_CUE_HOLD_THICKNESS = DETACH_CUE_HOLD_THICKNESS,
			DETACH_CUE_READY_THICKNESS = DETACH_CUE_READY_THICKNESS,
			DETACH_MERGE_DETECT_PADDING = DETACH_MERGE_DETECT_PADDING,
			MERGE_INDICATOR_HEIGHT = MERGE_INDICATOR_HEIGHT,
			MERGE_INDICATOR_MARGIN = MERGE_INDICATOR_MARGIN,
			MERGE_INDICATOR_TWEEN_DURATION = MERGE_INDICATOR_TWEEN_DURATION
		}
	})
	-- Export main function
	self.makeElementDetachable = function(guiObject, elementName, elementType)
		if not isDetachEnabled() then
			return nil
		end
		return createElementDetacher(guiObject, elementName, elementType)
	end
	self.setLayoutDirtyCallback = function(callback)
		layoutDirtyCallback = type(callback) == "function" and callback or nil
	end
	self.getLayoutSnapshot = function()
		if not isDetachEnabled() then
			return {}
		end
		local snapshot = {}
		for _, entry in pairs(detacherRegistry) do
			if entry and entry.meta and type(entry.meta.flag) == "string" and entry.meta.flag ~= "" then
				local api = entry.api
				if api and type(api.GetLayoutSnapshot) == "function" then
					local okSnapshot, value = pcall(api.GetLayoutSnapshot)
					if okSnapshot and type(value) == "table" and value.detached == true then
						snapshot[entry.meta.flag] = value
					end
				end
			end
		end
		return snapshot
	end
	self.applyLayoutSnapshot = function(snapshot)
		if not isDetachEnabled() then
			return false
		end
		if type(snapshot) ~= "table" then
			return false
		end

		local byFlag = {}
		for _, entry in pairs(detacherRegistry) do
			if entry and entry.meta and type(entry.meta.flag) == "string" and entry.meta.flag ~= "" then
				byFlag[entry.meta.flag] = entry
			end
		end

		for flag, layout in pairs(snapshot) do
			local entry = byFlag[flag]
			if entry and entry.api and type(entry.api.ApplyLayoutSnapshot) == "function" then
				pcall(entry.api.ApplyLayoutSnapshot, layout)
			end
		end

		for flag, entry in pairs(byFlag) do
			if snapshot[flag] == nil and entry.api and type(entry.api.IsDetached) == "function" and entry.api.IsDetached() then
				pcall(entry.api.Dock)
			end
		end
		return true
	end
	
	return self
end

return DragModule
