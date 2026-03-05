local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local getElementsSystem = ctx.getElementsSystem
	local refreshFavoritesSettingsPersistence = ctx.refreshFavoritesSettingsPersistence
	local ensureFavoritesTab = ctx.ensureFavoritesTab
	local renderFavoritesTab = ctx.renderFavoritesTab
	local openFavoritesTab = ctx.openFavoritesTab
	local experienceState = ctx.experienceState
	local setSettingValue = ctx.setSettingValue

	function RayfieldLibrary:ListControls()
		local elementsSystem = getElementsSystem()
		if not elementsSystem or type(elementsSystem.listControlsForFavorites) ~= "function" then
			return {}
		end
		return elementsSystem.listControlsForFavorites(true)
	end

	function RayfieldLibrary:PinControl(idOrFlag)
		local elementsSystem = getElementsSystem()
		if not elementsSystem or type(elementsSystem.pinControl) ~= "function" then
			return false, "Control registry unavailable."
		end
		local ok, message = elementsSystem.pinControl(tostring(idOrFlag or ""))
		if ok then
			if type(refreshFavoritesSettingsPersistence) == "function" then
				refreshFavoritesSettingsPersistence()
			end
			if experienceState().favoritesTabWindow and type(ensureFavoritesTab) == "function" then
				ensureFavoritesTab(experienceState().favoritesTabWindow)
			end
			if type(renderFavoritesTab) == "function" then
				renderFavoritesTab()
			end
		end
		return ok, message
	end

	function RayfieldLibrary:UnpinControl(idOrFlag)
		local elementsSystem = getElementsSystem()
		if not elementsSystem or type(elementsSystem.unpinControl) ~= "function" then
			return false, "Control registry unavailable."
		end
		local ok, message = elementsSystem.unpinControl(tostring(idOrFlag or ""))
		if ok then
			if type(refreshFavoritesSettingsPersistence) == "function" then
				refreshFavoritesSettingsPersistence()
			end
			if type(renderFavoritesTab) == "function" then
				renderFavoritesTab()
			end
		end
		return ok, message
	end

	function RayfieldLibrary:GetPinnedControls()
		local elementsSystem = getElementsSystem()
		if not elementsSystem or type(elementsSystem.getPinnedIds) ~= "function" then
			return {}
		end
		return elementsSystem.getPinnedIds(true)
	end

	setHandler("listControls", function(pruneMissing)
		local elementsSystem = getElementsSystem()
		if elementsSystem and type(elementsSystem.listControlsForFavorites) == "function" then
			return elementsSystem.listControlsForFavorites(pruneMissing == true)
		end
		return {}
	end)
	setHandler("pinControl", function(id)
		return RayfieldLibrary:PinControl(id)
	end)
	setHandler("unpinControl", function(id)
		return RayfieldLibrary:UnpinControl(id)
	end)
	setHandler("setPinBadgesVisible", function(visible)
		local elementsSystem = getElementsSystem()
		if elementsSystem and type(elementsSystem.setPinBadgesVisible) == "function" then
			elementsSystem.setPinBadgesVisible(visible ~= false)
			setSettingValue("Favorites", "showPinBadges", visible ~= false, true)
			return true, "Pin badge visibility updated."
		end
		return false, "Pin badge controller unavailable."
	end)
	setHandler("openFavoritesTab", function()
		if type(openFavoritesTab) == "function" then
			return openFavoritesTab(experienceState().favoritesTabWindow)
		end
		return false, "Favorites tab unavailable."
	end)
end

return module
