local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local saveWorkspaceInternal = ctx.saveWorkspaceInternal
	local loadWorkspaceInternal = ctx.loadWorkspaceInternal
	local listWorkspacesInternal = ctx.listWorkspacesInternal
	local deleteWorkspaceInternal = ctx.deleteWorkspaceInternal
	local saveProfileInternal = ctx.saveProfileInternal
	local loadProfileInternal = ctx.loadProfileInternal
	local listProfilesInternal = ctx.listProfilesInternal
	local deleteProfileInternal = ctx.deleteProfileInternal
	local copyWorkspaceToProfileInternal = ctx.copyWorkspaceToProfileInternal
	local copyProfileToWorkspaceInternal = ctx.copyProfileToWorkspaceInternal

	function RayfieldLibrary:SaveWorkspace(name)
		if type(saveWorkspaceInternal) ~= "function" then
			return false, "Workspace save unavailable."
		end
		return saveWorkspaceInternal(name)
	end

	function RayfieldLibrary:LoadWorkspace(name)
		if type(loadWorkspaceInternal) ~= "function" then
			return false, "Workspace load unavailable."
		end
		return loadWorkspaceInternal(name)
	end

	function RayfieldLibrary:ListWorkspaces()
		if type(listWorkspacesInternal) ~= "function" then
			return {}
		end
		local list = listWorkspacesInternal()
		if type(list) ~= "table" then
			return {}
		end
		return list
	end

	function RayfieldLibrary:DeleteWorkspace(name)
		if type(deleteWorkspaceInternal) ~= "function" then
			return false, "Workspace delete unavailable."
		end
		return deleteWorkspaceInternal(name)
	end

	function RayfieldLibrary:SaveProfile(name)
		if type(saveProfileInternal) ~= "function" then
			return false, "Profile save unavailable."
		end
		return saveProfileInternal(name)
	end

	function RayfieldLibrary:LoadProfile(name)
		if type(loadProfileInternal) ~= "function" then
			return false, "Profile load unavailable."
		end
		return loadProfileInternal(name)
	end

	function RayfieldLibrary:ListProfiles()
		if type(listProfilesInternal) ~= "function" then
			return {}
		end
		local list = listProfilesInternal()
		return type(list) == "table" and list or {}
	end

	function RayfieldLibrary:DeleteProfile(name)
		if type(deleteProfileInternal) ~= "function" then
			return false, "Profile delete unavailable."
		end
		return deleteProfileInternal(name)
	end

	function RayfieldLibrary:CopyWorkspaceToProfile(workspaceName, profileName)
		if type(copyWorkspaceToProfileInternal) ~= "function" then
			return false, "Workspace/profile copy unavailable."
		end
		return copyWorkspaceToProfileInternal(workspaceName, profileName)
	end

	function RayfieldLibrary:CopyProfileToWorkspace(profileName, workspaceName)
		if type(copyProfileToWorkspaceInternal) ~= "function" then
			return false, "Workspace/profile copy unavailable."
		end
		return copyProfileToWorkspaceInternal(profileName, workspaceName)
	end

	setHandler("saveWorkspace", function(name)
		return RayfieldLibrary:SaveWorkspace(name)
	end)
	setHandler("loadWorkspace", function(name)
		return RayfieldLibrary:LoadWorkspace(name)
	end)
	setHandler("listWorkspaces", function()
		return RayfieldLibrary:ListWorkspaces()
	end)
	setHandler("deleteWorkspace", function(name)
		return RayfieldLibrary:DeleteWorkspace(name)
	end)
	setHandler("saveProfile", function(name)
		return RayfieldLibrary:SaveProfile(name)
	end)
	setHandler("loadProfile", function(name)
		return RayfieldLibrary:LoadProfile(name)
	end)
	setHandler("listProfiles", function()
		return RayfieldLibrary:ListProfiles()
	end)
	setHandler("deleteProfile", function(name)
		return RayfieldLibrary:DeleteProfile(name)
	end)
	setHandler("copyWorkspaceToProfile", function(workspaceName, profileName)
		return RayfieldLibrary:CopyWorkspaceToProfile(workspaceName, profileName)
	end)
	setHandler("copyProfileToWorkspace", function(profileName, workspaceName)
		return RayfieldLibrary:CopyProfileToWorkspace(profileName, workspaceName)
	end)
end

return module
