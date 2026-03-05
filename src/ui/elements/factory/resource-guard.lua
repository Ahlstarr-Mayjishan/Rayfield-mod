local ResourceGuard = {}

local function defaultCleanupOptions(options)
	if type(options) == "table" then
		return options
	end
	return {
		destroyInstances = false,
		clearAttributes = true
	}
end

function ResourceGuard.create(options)
	options = type(options) == "table" and options or {}
	local ownership = options.resourceOwnership

	local guard = {}

	function guard.createScope(scopeId, metadata)
		if not (ownership and type(ownership.createScope) == "function") then
			return nil
		end
		local okScope, scopeOrErr = pcall(ownership.createScope, scopeId, metadata)
		if okScope and type(scopeOrErr) == "string" and scopeOrErr ~= "" then
			return scopeOrErr
		end
		if okScope then
			return scopeId
		end
		return nil
	end

	function guard.claimInstance(instance, scopeId, metadata)
		if not (ownership and type(ownership.claimInstance) == "function") then
			return false
		end
		local okClaim, claimed = pcall(ownership.claimInstance, instance, scopeId, metadata)
		return okClaim and claimed == true
	end

	function guard.trackConnection(connection, scopeId)
		if not connection or type(scopeId) ~= "string" or scopeId == "" then
			return false
		end
		if not (ownership and type(ownership.trackConnection) == "function") then
			return false
		end
		local okTrack, tracked = pcall(ownership.trackConnection, connection, scopeId)
		return okTrack and tracked == true
	end

	function guard.trackCleanup(cleanupFn, scopeId)
		if type(cleanupFn) ~= "function" or type(scopeId) ~= "string" or scopeId == "" then
			return false
		end
		if not (ownership and type(ownership.trackCleanup) == "function") then
			return false
		end
		local okTrack, tracked = pcall(ownership.trackCleanup, cleanupFn, scopeId)
		return okTrack and tracked == true
	end

	function guard.cleanupScope(scopeId, optionsTable)
		if type(scopeId) ~= "string" or scopeId == "" then
			return false
		end
		if not (ownership and type(ownership.cleanupScope) == "function") then
			return false
		end
		local okCleanup, cleaned = pcall(ownership.cleanupScope, scopeId, defaultCleanupOptions(optionsTable))
		return okCleanup and cleaned == true
	end

	return guard
end

return ResourceGuard
