local WorkspaceService = {}

local function defaultClone(value, seen)
	local kind = type(value)
	if kind ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	for key, nested in pairs(value) do
		out[defaultClone(key, seen)] = defaultClone(nested, seen)
	end
	return out
end

local function trimText(text)
	local value = tostring(text or "")
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	return value
end

function WorkspaceService.create(ctx)
	ctx = ctx or {}
	local getSetting = ctx.getSetting
	local setSettingValue = ctx.setSettingValue
	local settingsSystem = ctx.settingsSystem
	local buildGeneratedAtStamp = ctx.buildGeneratedAtStamp
	local cloneValue = type(ctx.cloneValue) == "function" and ctx.cloneValue or defaultClone
	local onRestoreAfterLoad = type(ctx.onRestoreAfterLoad) == "function" and ctx.onRestoreAfterLoad or function() end
	local onPersist = type(ctx.onPersist) == "function" and ctx.onPersist or function() end

	local namespaceConfig = {
		Workspaces = {
			activeKey = "active",
			snapshotKey = "snapshots",
			maxGlobal = "__RAYFIELD_WORKSPACE_MAX_COUNT",
			defaultMax = 8
		},
		Profiles = {
			activeKey = "active",
			snapshotKey = "snapshots",
			maxGlobal = "__RAYFIELD_PROFILE_MAX_COUNT",
			defaultMax = 8
		}
	}

	local function getNamespaceInfo(namespace)
		return namespaceConfig[tostring(namespace or "")]
	end

	local function sanitizeName(rawName)
		local value = trimText(rawName)
		if value == "" then
			return nil
		end
		if #value > 64 then
			value = value:sub(1, 64)
		end
		return value
	end

	local function getNamespaceMaxCount(namespace)
		local info = getNamespaceInfo(namespace)
		if not info then
			return 8
		end
		local configured = nil
		if type(_G) == "table" then
			configured = tonumber(_G[info.maxGlobal])
		end
		if not configured or configured < 1 then
			configured = info.defaultMax
		end
		return math.max(1, math.floor(configured))
	end

	local function getSnapshotsMap(namespace)
		local info = getNamespaceInfo(namespace)
		if not info or type(getSetting) ~= "function" then
			return {}
		end
		local snapshots = getSetting(namespace, info.snapshotKey)
		if type(snapshots) ~= "table" then
			snapshots = {}
		end
		return cloneValue(snapshots)
	end

	local function setSnapshotsMap(namespace, map, persist)
		local info = getNamespaceInfo(namespace)
		if not info or type(setSettingValue) ~= "function" then
			return false
		end
		local nextMap = type(map) == "table" and map or {}
		local ok = pcall(setSettingValue, namespace, info.snapshotKey, nextMap, persist ~= false)
		return ok
	end

	local function setActiveName(namespace, name, persist)
		local info = getNamespaceInfo(namespace)
		if not info or type(setSettingValue) ~= "function" then
			return false
		end
		local ok = pcall(setSettingValue, namespace, info.activeKey, tostring(name or ""), persist ~= false)
		return ok
	end

	local function listNames(namespace)
		local snapshots = getSnapshotsMap(namespace)
		local names = {}
		for name in pairs(snapshots) do
			table.insert(names, tostring(name))
		end
		table.sort(names)
		return names
	end

	local function stripSnapshotNamespaces(exportData)
		if type(exportData) ~= "table" then
			return
		end
		if type(exportData.Workspaces) == "table" then
			exportData.Workspaces.active = nil
			exportData.Workspaces.snapshots = nil
		end
		if type(exportData.Profiles) == "table" then
			exportData.Profiles.active = nil
			exportData.Profiles.snapshots = nil
		end
	end

	local function saveSnapshot(namespace, name)
		local snapshotName = sanitizeName(name)
		if not snapshotName then
			return false, "Invalid " .. string.lower(tostring(namespace or "snapshot")) .. " name."
		end
		if not settingsSystem or type(settingsSystem.ExportInternalSettingsData) ~= "function" then
			return false, "Snapshot save unavailable."
		end

		local snapshots = getSnapshotsMap(namespace)
		local existingNames = listNames(namespace)
		if snapshots[snapshotName] == nil and #existingNames >= getNamespaceMaxCount(namespace) then
			return false, string.format("%s limit reached (%d).", tostring(namespace), getNamespaceMaxCount(namespace))
		end

		local exportData = settingsSystem:ExportInternalSettingsData()
		if type(exportData) ~= "table" then
			return false, "Failed to export settings snapshot."
		end
		stripSnapshotNamespaces(exportData)

		local nowStamp = type(buildGeneratedAtStamp) == "function" and buildGeneratedAtStamp() or os.date("!%Y-%m-%dT%H:%M:%SZ")
		local existing = snapshots[snapshotName]
		snapshots[snapshotName] = {
			name = snapshotName,
			version = 1,
			namespace = tostring(namespace),
			createdAt = type(existing) == "table" and existing.createdAt or nowStamp,
			updatedAt = nowStamp,
			internalSettings = exportData
		}

		setSnapshotsMap(namespace, snapshots, false)
		setActiveName(namespace, snapshotName, true)
		return true, string.format("%s saved: %s", tostring(namespace):sub(1, #tostring(namespace) - 1), snapshotName)
	end

	local function loadSnapshot(namespace, name)
		local snapshotName = sanitizeName(name)
		if not snapshotName then
			return false, "Invalid " .. string.lower(tostring(namespace or "snapshot")) .. " name."
		end
		if not settingsSystem or type(settingsSystem.ImportInternalSettingsData) ~= "function" then
			return false, "Snapshot load unavailable."
		end

		local snapshots = getSnapshotsMap(namespace)
		local snapshot = snapshots[snapshotName]
		if type(snapshot) ~= "table" or type(snapshot.internalSettings) ~= "table" then
			return false, tostring(namespace):sub(1, #tostring(namespace) - 1) .. " not found: " .. snapshotName
		end

		local okImport, appliedCountOrErr = settingsSystem:ImportInternalSettingsData(snapshot.internalSettings)
		if okImport ~= true then
			return false, tostring(appliedCountOrErr or "Failed to import snapshot.")
		end

		setActiveName(namespace, snapshotName, false)
		onRestoreAfterLoad(namespace, snapshotName, appliedCountOrErr)
		onPersist()
		return true, string.format("%s loaded: %s (%s settings).", tostring(namespace):sub(1, #tostring(namespace) - 1), snapshotName, tostring(appliedCountOrErr or 0))
	end

	local function deleteSnapshot(namespace, name)
		local snapshotName = sanitizeName(name)
		if not snapshotName then
			return false, "Invalid " .. string.lower(tostring(namespace or "snapshot")) .. " name."
		end
		local snapshots = getSnapshotsMap(namespace)
		if snapshots[snapshotName] == nil then
			return false, tostring(namespace):sub(1, #tostring(namespace) - 1) .. " not found: " .. snapshotName
		end
		snapshots[snapshotName] = nil
		setSnapshotsMap(namespace, snapshots, false)
		local activeName = tostring(type(getSetting) == "function" and getSetting(namespace, "active") or "")
		if activeName == snapshotName then
			setActiveName(namespace, "", false)
		end
		onPersist()
		return true, string.format("%s deleted: %s", tostring(namespace):sub(1, #tostring(namespace) - 1), snapshotName)
	end

	local function copySnapshot(sourceNamespace, sourceName, targetNamespace, targetName)
		local sourceKey = sanitizeName(sourceName)
		if not sourceKey then
			return false, "Invalid source snapshot name."
		end
		local sourceSnapshots = getSnapshotsMap(sourceNamespace)
		local sourceSnapshot = sourceSnapshots[sourceKey]
		if type(sourceSnapshot) ~= "table" or type(sourceSnapshot.internalSettings) ~= "table" then
			return false, string.format("%s not found: %s", tostring(sourceNamespace):sub(1, #tostring(sourceNamespace) - 1), sourceKey)
		end

		local targetKey = sanitizeName(targetName) or sourceKey
		local targetSnapshots = getSnapshotsMap(targetNamespace)
		local targetNames = listNames(targetNamespace)
		if targetSnapshots[targetKey] == nil and #targetNames >= getNamespaceMaxCount(targetNamespace) then
			return false, string.format("%s limit reached (%d).", tostring(targetNamespace), getNamespaceMaxCount(targetNamespace))
		end

		local nowStamp = type(buildGeneratedAtStamp) == "function" and buildGeneratedAtStamp() or os.date("!%Y-%m-%dT%H:%M:%SZ")
		local existing = targetSnapshots[targetKey]
		targetSnapshots[targetKey] = {
			name = targetKey,
			version = tonumber(sourceSnapshot.version) or 1,
			namespace = tostring(targetNamespace),
			createdAt = type(existing) == "table" and existing.createdAt or nowStamp,
			updatedAt = nowStamp,
			internalSettings = cloneValue(sourceSnapshot.internalSettings)
		}

		setSnapshotsMap(targetNamespace, targetSnapshots, false)
		setActiveName(targetNamespace, targetKey, false)
		onPersist()
		return true, string.format("Copied %s '%s' -> %s '%s'.", tostring(sourceNamespace):sub(1, #tostring(sourceNamespace) - 1), sourceKey, tostring(targetNamespace):sub(1, #tostring(targetNamespace) - 1), targetKey)
	end

	return {
		listWorkspaces = function()
			return listNames("Workspaces")
		end,
		saveWorkspace = function(name)
			return saveSnapshot("Workspaces", name)
		end,
		loadWorkspace = function(name)
			return loadSnapshot("Workspaces", name)
		end,
		deleteWorkspace = function(name)
			return deleteSnapshot("Workspaces", name)
		end,
		listProfiles = function()
			return listNames("Profiles")
		end,
		saveProfile = function(name)
			return saveSnapshot("Profiles", name)
		end,
		loadProfile = function(name)
			return loadSnapshot("Profiles", name)
		end,
		deleteProfile = function(name)
			return deleteSnapshot("Profiles", name)
		end,
		copyWorkspaceToProfile = function(workspaceName, profileName)
			return copySnapshot("Workspaces", workspaceName, "Profiles", profileName)
		end,
		copyProfileToWorkspace = function(profileName, workspaceName)
			return copySnapshot("Profiles", profileName, "Workspaces", workspaceName)
		end
	}
end

return WorkspaceService
