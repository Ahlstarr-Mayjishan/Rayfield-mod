local RuntimeFallbackModules = {}

RuntimeFallbackModules.FallbackElementSyncModule = {
	init = function()
		return nil
	end
}

RuntimeFallbackModules.FallbackOwnershipTrackerModule = {
	init = function()
		local function noopReturnFalse()
			return false
		end
		local function noopReturnNil()
			return nil
		end
		return {
			createScope = function(scopeId)
				return tostring(scopeId or "")
			end,
			makeScopeId = function(kind, id)
				return tostring(kind or "scope") .. ":" .. tostring(id or "")
			end,
			claimInstance = noopReturnFalse,
			trackConnection = noopReturnFalse,
			trackTask = noopReturnFalse,
			trackCleanup = noopReturnFalse,
			cleanupScope = noopReturnFalse,
			cleanupByInstance = noopReturnFalse,
			cleanupSession = noopReturnFalse,
			getStats = function()
				return {
					scopes = 0,
					instances = 0,
					connections = 0,
					tasks = 0,
					cleanups = 0
				}
			end,
			getSignature = noopReturnNil
		}
	end
}

RuntimeFallbackModules.FallbackDragModule = {
	init = function()
		local function noop() end
		return {
			makeElementDetachable = function()
				return nil
			end,
			setLayoutDirtyCallback = noop,
			getLayoutSnapshot = function()
				return {}
			end,
			applyLayoutSnapshot = function()
				return false
			end
		}
	end
}

RuntimeFallbackModules.FallbackTabSplitModule = {
	init = function()
		local function noop() end
		return {
			registerTab = noop,
			unregisterTab = noop,
			splitTab = function()
				return false
			end,
			dockTab = function()
				return false
			end,
			layoutPanels = noop,
			syncHidden = noop,
			syncMinimized = noop,
			setLayoutDirtyCallback = noop,
			getLayoutSnapshot = function()
				return {}
			end,
			applyLayoutSnapshot = function()
				return false
			end,
			destroy = noop
		}
	end
}

RuntimeFallbackModules.FallbackLayoutPersistenceModule = {
	init = function()
		local function noop() end
		return {
			registerProvider = noop,
			unregisterProvider = noop,
			getLayoutSnapshot = function()
				return nil
			end,
			applyLayoutSnapshot = function()
				return false
			end,
			markDirty = noop,
			flush = noop,
			isApplying = function()
				return false
			end,
			isDirty = function()
				return false
			end
		}
	end
}

RuntimeFallbackModules.FallbackViewportVirtualizationModule = {
	init = function()
		local function noopReturnFalse()
			return false
		end
		local function noopReturnNil()
			return nil
		end
		return {
			registerHost = noopReturnFalse,
			unregisterHost = noopReturnFalse,
			refreshHost = noopReturnFalse,
			setHostSuppressed = noopReturnFalse,
			registerElement = noopReturnNil,
			unregisterElement = noopReturnFalse,
			moveElementToHost = noopReturnFalse,
			setElementBusy = noopReturnFalse,
			notifyElementHostChanged = noopReturnFalse,
			getStats = function()
				return {
					hosts = 0,
					elements = 0,
					sleeping = 0
				}
			end,
			destroy = function() end
		}
	end
}

return RuntimeFallbackModules
