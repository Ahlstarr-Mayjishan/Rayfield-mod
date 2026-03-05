local WidgetAPIInjector = {}

function WidgetAPIInjector.inject(options)
	options = options or {}
	local elementObject = options.elementObject
	local guiObject = options.guiObject
	local syncToken = options.syncToken
	local elementSync = options.elementSync
	local markVirtualHostDirty = options.markVirtualHostDirty or function() end
	local detachable = options.detachable
	local internalName = tostring(options.internalName or "Unnamed")
	local elementType = tostring(options.elementType or "Element")
	local tabPersistenceId = tostring(options.tabPersistenceId or "")
	local tabPage = options.tabPage
	local favoriteId = tostring(options.favoriteId or "")
	local cleanupScopeId = options.cleanupScopeId
	local controlRecord = options.controlRecord or {}
	local pinControl = options.pinControl or function()
		return false, "Pin unavailable."
	end
	local unpinControl = options.unpinControl or function()
		return false, "Unpin unavailable."
	end
	local pinnedControlIds = type(options.pinnedControlIds) == "table" and options.pinnedControlIds or {}
	local setControlDisplayLabelByIdOrFlag = options.setControlDisplayLabelByIdOrFlag or function()
		return false, "Localization unavailable."
	end
	local resetControlDisplayLabelByIdOrFlag = options.resetControlDisplayLabelByIdOrFlag or function()
		return false, "Localization unavailable."
	end
	local resolveLocalizationKey = options.resolveLocalizationKey or function()
		return ""
	end
	local applyTooltipBehavior = options.applyTooltipBehavior or function() end
	local hideTooltip = options.hideTooltip or function() end
	local clampNumber = options.clampNumber or function(value, minimum, maximum, fallback)
		local numberValue = tonumber(value)
		if not numberValue then
			numberValue = tonumber(fallback) or 0
		end
		if minimum ~= nil then
			numberValue = math.max(minimum, numberValue)
		end
		if maximum ~= nil then
			numberValue = math.min(maximum, numberValue)
		end
		return numberValue
	end
	local tabObject = options.tabObject

	if type(elementObject) ~= "table" then
		return false, "Invalid elementObject"
	end

	function elementObject:Show()
		guiObject.Visible = true
		if syncToken and elementSync then
			elementSync.resync(syncToken, "element_show")
		end
		markVirtualHostDirty("element_show")
	end

	function elementObject:Hide()
		guiObject.Visible = false
		if syncToken and elementSync then
			elementSync.resync(syncToken, "element_hide")
		end
		markVirtualHostDirty("element_hide")
	end

	function elementObject:SetVisible(visible)
		guiObject.Visible = visible
		if syncToken and elementSync then
			elementSync.resync(syncToken, "element_set_visible")
		end
		markVirtualHostDirty("element_set_visible")
	end

	function elementObject:GetParent()
		return tabObject
	end

	if detachable then
		function elementObject:Detach(position)
			local result = detachable.Detach(position)
			if syncToken and elementSync then
				elementSync.resync(syncToken, "element_detach")
			end
			markVirtualHostDirty("element_detach")
			return result
		end

		function elementObject:Dock()
			local result = detachable.Dock()
			if syncToken and elementSync then
				elementSync.resync(syncToken, "element_dock")
			end
			markVirtualHostDirty("element_dock")
			return result
		end

		function elementObject:GetRememberedState()
			return detachable.GetRememberedState()
		end

		function elementObject:IsDetached()
			return detachable.IsDetached()
		end
	end

	elementObject.Name = internalName
	elementObject.DisplayName = controlRecord.DisplayName
	elementObject.Type = elementType
	elementObject.Flag = type(elementObject) == "table" and elementObject.Flag or nil
	elementObject.__ElementSyncToken = syncToken
	elementObject.__TabPersistenceId = tabPersistenceId
	elementObject.__TabLayoutOrder = tonumber(tabPage and tabPage.LayoutOrder) or 0
	elementObject.__ElementLayoutOrder = (guiObject and tonumber(guiObject.LayoutOrder)) or 0
	elementObject.__GuiObject = guiObject
	elementObject.__TabPage = tabPage
	elementObject.__FavoriteId = favoriteId
	elementObject.__CleanupScope = cleanupScopeId
	elementObject.__LocalizationKey = controlRecord.LocalizationKey

	function elementObject:GetFavoriteId()
		return favoriteId
	end

	function elementObject:GetCleanupScope()
		return cleanupScopeId
	end

	function elementObject:Pin()
		return pinControl(favoriteId)
	end

	function elementObject:Unpin()
		return unpinControl(favoriteId)
	end

	function elementObject:IsPinned()
		return pinnedControlIds[favoriteId] == true
	end

	function elementObject:SetDisplayLabel(label)
		return setControlDisplayLabelByIdOrFlag(favoriteId, label, { persist = true })
	end

	function elementObject:GetDisplayLabel()
		return tostring(controlRecord.DisplayName or controlRecord.Name or "")
	end

	function elementObject:ResetDisplayLabel()
		return resetControlDisplayLabelByIdOrFlag(favoriteId, { persist = true })
	end

	function elementObject:GetLocalizationKey()
		return tostring(controlRecord.LocalizationKey or resolveLocalizationKey(controlRecord))
	end

	function elementObject:SetTooltip(textOrOptions)
		local tooltipOptions
		if type(textOrOptions) == "table" then
			tooltipOptions = {
				Text = tostring(textOrOptions.Text or textOrOptions.text or ""),
				DesktopDelay = clampNumber(textOrOptions.DesktopDelay or textOrOptions.desktopDelay, 0.01, 5, 0.15),
				MobileDelay = clampNumber(textOrOptions.MobileDelay or textOrOptions.mobileDelay, 0.01, 5, 0.35)
			}
		else
			tooltipOptions = {
				Text = tostring(textOrOptions or ""),
				DesktopDelay = 0.15,
				MobileDelay = 0.35
			}
		end
		elementObject.__TooltipOptions = tooltipOptions
		applyTooltipBehavior(tooltipOptions)
		return true, "ok"
	end

	function elementObject:ClearTooltip()
		elementObject.__TooltipOptions = nil
		applyTooltipBehavior({ Text = "" })
		hideTooltip(favoriteId)
		return true, "ok"
	end

	return true, "ok"
end

return WidgetAPIInjector
