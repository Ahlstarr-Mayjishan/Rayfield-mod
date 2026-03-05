local TabManager = {}

function TabManager.create()
	local state = {
		firstTab = false,
		nameCounts = {},
		recordsByPersistenceId = {}
	}

	local manager = {}

	function manager.allocatePersistenceId(baseName)
		local basePersistenceId = tostring(baseName or "")
		local nextIndex = (state.nameCounts[basePersistenceId] or 0) + 1
		state.nameCounts[basePersistenceId] = nextIndex
		if nextIndex > 1 then
			return basePersistenceId .. "#" .. tostring(nextIndex)
		end
		return basePersistenceId
	end

	function manager.registerRecord(persistenceId, record)
		local key = tostring(persistenceId or "")
		if key == "" then
			return false
		end
		state.recordsByPersistenceId[key] = record
		return true
	end

	function manager.unregisterRecord(persistenceId)
		local key = tostring(persistenceId or "")
		if key == "" then
			return false
		end
		state.recordsByPersistenceId[key] = nil
		return true
	end

	function manager.getFirstTab()
		return state.firstTab
	end

	function manager.setFirstTab(value)
		state.firstTab = value
		return state.firstTab
	end

	function manager.getTabRecordByPersistenceId(tabId)
		if tabId == nil then
			return nil
		end
		return state.recordsByPersistenceId[tostring(tabId)]
	end

	function manager.getTabLayoutOrderByPersistenceId(tabId)
		local record = manager.getTabRecordByPersistenceId(tabId)
		if not record or not record.TabPage then
			return math.huge
		end
		return tonumber(record.TabPage.LayoutOrder) or math.huge
	end

	function manager.getCurrentTabPersistenceId(currentPage)
		if not currentPage then
			return nil
		end
		for persistenceId, record in pairs(state.recordsByPersistenceId) do
			if record and record.TabPage == currentPage then
				return persistenceId
			end
		end
		return nil
	end

	function manager.activateTabByPersistenceId(tabId, ignoreMinimisedCheck, source)
		local record = manager.getTabRecordByPersistenceId(tabId)
		if not record or type(record.Activate) ~= "function" then
			return false
		end
		return record.Activate(ignoreMinimisedCheck == true, source)
	end

	return manager
end

return TabManager
