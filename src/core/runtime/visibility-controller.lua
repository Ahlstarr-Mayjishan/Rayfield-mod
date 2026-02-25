local VisibilityController = {}

function VisibilityController.create(context)
	if type(context) ~= "table" then
		error("VisibilityController.create expected context table")
	end

	local getUIStateSystem = context.getUIStateSystem or function()
		return nil
	end
	local getUtilitiesSystem = context.getUtilitiesSystem or function()
		return nil
	end
	local applyRuntimeState = context.applyRuntimeState or function() end
	local onVisibilityChanged = context.onVisibilityChanged or function() end

	local function syncState(action, explicitVisibility)
		local uiStateSystem = getUIStateSystem()
		local hidden
		local minimised
		local debounce

		if uiStateSystem and type(uiStateSystem.getHidden) == "function" then
			hidden = uiStateSystem.getHidden()
		end
		if uiStateSystem and type(uiStateSystem.getMinimised) == "function" then
			minimised = uiStateSystem.getMinimised()
		end
		if uiStateSystem and type(uiStateSystem.getDebounce) == "function" then
			debounce = uiStateSystem.getDebounce()
		end

		if explicitVisibility ~= nil then
			hidden = explicitVisibility ~= true
		end

		local snapshot = {
			hidden = hidden,
			minimised = minimised,
			debounce = debounce,
			action = tostring(action or "update")
		}
		applyRuntimeState(snapshot)
		onVisibilityChanged(snapshot)
		return snapshot
	end

	local controller = {}

	function controller.Hide(notify)
		local uiStateSystem = getUIStateSystem()
		if uiStateSystem and type(uiStateSystem.Hide) == "function" then
			uiStateSystem.Hide(notify)
		end
		return syncState("hide")
	end

	function controller.Unhide()
		local uiStateSystem = getUIStateSystem()
		if uiStateSystem and type(uiStateSystem.Unhide) == "function" then
			uiStateSystem.Unhide()
		end
		return syncState("unhide")
	end

	function controller.Maximise()
		local uiStateSystem = getUIStateSystem()
		if uiStateSystem and type(uiStateSystem.Maximise) == "function" then
			uiStateSystem.Maximise()
		end
		return syncState("maximise")
	end

	function controller.Minimise()
		local uiStateSystem = getUIStateSystem()
		if uiStateSystem and type(uiStateSystem.Minimise) == "function" then
			uiStateSystem.Minimise()
		end
		return syncState("minimise")
	end

	function controller.SetVisibility(visibility, notify)
		local utilitiesSystem = getUtilitiesSystem()
		if not utilitiesSystem or type(utilitiesSystem.setVisibility) ~= "function" then
			return false, "Utilities system unavailable."
		end
		utilitiesSystem.setVisibility(visibility, notify)
		syncState((visibility == true) and "set_visible_true" or "set_visible_false", visibility == true)
		return true
	end

	function controller.Sync(action)
		return syncState(action or "sync")
	end

	return controller
end

return VisibilityController
