-- Rayfield Ownership Tracker
-- Scoped ownership registry for precise cleanup of UI features/resources.

local OwnershipTracker = {}

local function isInstance(value)
	return typeof(value) == "Instance"
end

local function isConnection(value)
	return typeof(value) == "RBXScriptConnection"
end

local function normalizeScopeId(scopeId)
	local normalized = tostring(scopeId or "")
	if normalized == "" then
		return "scope:default"
	end
	return normalized
end

local function safeDisconnect(connection)
	if not connection then
		return
	end
	if isConnection(connection) then
		pcall(function()
			connection:Disconnect()
		end)
		return
	end
	if type(connection) == "table" and type(connection.Disconnect) == "function" then
		pcall(connection.Disconnect, connection)
	end
end

local function safeCancelTask(taskHandle)
	if not taskHandle then
		return
	end
	if type(taskHandle) == "thread" then
		pcall(task.cancel, taskHandle)
	end
end

local function removeArrayValue(list, value)
	if type(list) ~= "table" then
		return
	end
	for index = #list, 1, -1 do
		if list[index] == value then
			table.remove(list, index)
		end
	end
end

local function clearOwnershipAttributes(instance, attrs, ownerValue, sessionValue)
	if not isInstance(instance) or type(instance.GetAttribute) ~= "function" or type(instance.SetAttribute) ~= "function" then
		return
	end

	local owned = false
	local okOwner, currentOwner = pcall(instance.GetAttribute, instance, attrs.owner)
	if okOwner and currentOwner == ownerValue then
		owned = true
	end
	local okSession, currentSession = pcall(instance.GetAttribute, instance, attrs.session)
	if okSession and currentSession == sessionValue then
		owned = true
	end
	if not owned then
		return
	end

	pcall(instance.SetAttribute, instance, attrs.owner, nil)
	pcall(instance.SetAttribute, instance, attrs.session, nil)
	pcall(instance.SetAttribute, instance, attrs.scope, nil)
end

local function setOwnershipAttributes(instance, attrs, ownerValue, sessionValue, scopeId)
	if not isInstance(instance) or type(instance.SetAttribute) ~= "function" then
		return
	end
	pcall(instance.SetAttribute, instance, attrs.owner, ownerValue)
	pcall(instance.SetAttribute, instance, attrs.session, sessionValue)
	pcall(instance.SetAttribute, instance, attrs.scope, scopeId)
end

function OwnershipTracker.init(ctx)
	local self = {}
	ctx = ctx or {}

	local HttpService = ctx.HttpService or game:GetService("HttpService")
	local ownerValue = tostring(ctx.owner or "rayfield-mod")
	local scopePrefix = tostring(ctx.scopePrefix or "rayfield")
	local attrs = {
		owner = tostring(ctx.ownerAttribute or "RayfieldOwner"),
		session = tostring(ctx.sessionAttribute or "RayfieldSession"),
		scope = tostring(ctx.scopeAttribute or "RayfieldScope")
	}

	local sessionValue = nil
	do
		local okGuid, guid = pcall(function()
			return HttpService:GenerateGUID(false)
		end)
		if okGuid and type(guid) == "string" and guid ~= "" then
			sessionValue = guid
		else
			sessionValue = tostring(math.floor(os.clock() * 100000))
		end
	end

	local scopeMap = {}
	local scopeOrder = {}
	local instanceToScope = setmetatable({}, { __mode = "k" })

	local function ensureScope(scopeId, meta)
		local normalizedScope = normalizeScopeId(scopeId)
		local scope = scopeMap[normalizedScope]
		if scope then
			if type(meta) == "table" then
				scope.meta = scope.meta or {}
				for key, value in pairs(meta) do
					if scope.meta[key] == nil then
						scope.meta[key] = value
					end
				end
			end
			return scope
		end

		scope = {
			id = normalizedScope,
			meta = type(meta) == "table" and meta or {},
			instances = setmetatable({}, { __mode = "k" }),
			connections = {},
			tasks = {},
			cleanups = {}
		}
		scopeMap[normalizedScope] = scope
		table.insert(scopeOrder, normalizedScope)
		return scope
	end

	local function removeScope(scopeId)
		scopeMap[scopeId] = nil
		removeArrayValue(scopeOrder, scopeId)
	end

	local function setInstanceScope(instance, scopeId)
		if not isInstance(instance) then
			return
		end

		local previousScopeId = instanceToScope[instance]
		if previousScopeId and previousScopeId ~= scopeId then
			local previousScope = scopeMap[previousScopeId]
			if previousScope then
				previousScope.instances[instance] = nil
			end
		end

		instanceToScope[instance] = scopeId
	end

	local function clearInstanceScope(instance, expectedScopeId)
		if not isInstance(instance) then
			return
		end
		if expectedScopeId and instanceToScope[instance] ~= expectedScopeId then
			return
		end
		instanceToScope[instance] = nil
	end

	self.createScope = function(scopeId, meta)
		local normalizedScope = normalizeScopeId(scopeId)
		ensureScope(normalizedScope, meta)
		return normalizedScope
	end

	self.makeScopeId = function(kind, identifier)
		local safeKind = tostring(kind or "scope")
		local safeIdentifier = tostring(identifier or "")
		if safeIdentifier == "" then
			safeIdentifier = tostring(math.floor(os.clock() * 100000))
		end
		return string.format("%s:%s:%s", scopePrefix, safeKind, safeIdentifier)
	end

	self.claimInstance = function(instance, scopeId, meta)
		if not isInstance(instance) then
			return false
		end
		local scope = ensureScope(scopeId, meta)
		setInstanceScope(instance, scope.id)
		scope.instances[instance] = true
		setOwnershipAttributes(instance, attrs, ownerValue, sessionValue, scope.id)
		return true
	end

	self.trackConnection = function(connection, scopeId)
		if not connection then
			return false
		end
		local scope = ensureScope(scopeId)
		table.insert(scope.connections, connection)
		return true
	end

	self.trackTask = function(taskHandle, scopeId)
		if not taskHandle then
			return false
		end
		local scope = ensureScope(scopeId)
		table.insert(scope.tasks, taskHandle)
		return true
	end

	self.trackCleanup = function(cleanupFn, scopeId)
		if type(cleanupFn) ~= "function" then
			return false
		end
		local scope = ensureScope(scopeId)
		table.insert(scope.cleanups, cleanupFn)
		return true
	end

	self.cleanupScope = function(scopeId, opts)
		local normalizedScope = normalizeScopeId(scopeId)
		local scope = scopeMap[normalizedScope]
		if not scope then
			return false
		end

		opts = opts or {}
		local shouldDestroyInstances = opts.destroyInstances == true
		local shouldClearAttributes = opts.clearAttributes ~= false

		for index = #scope.connections, 1, -1 do
			safeDisconnect(scope.connections[index])
			scope.connections[index] = nil
		end

		for index = #scope.tasks, 1, -1 do
			safeCancelTask(scope.tasks[index])
			scope.tasks[index] = nil
		end

		for index = #scope.cleanups, 1, -1 do
			local cleanupFn = scope.cleanups[index]
			scope.cleanups[index] = nil
			pcall(cleanupFn, opts)
		end

		for instance in pairs(scope.instances) do
			clearInstanceScope(instance, normalizedScope)

			if shouldClearAttributes then
				clearOwnershipAttributes(instance, attrs, ownerValue, sessionValue)
			end

			if shouldDestroyInstances and instance and instance.Parent then
				pcall(function()
					instance:Destroy()
				end)
			end
			scope.instances[instance] = nil
		end

		removeScope(normalizedScope)
		return true
	end

	self.cleanupByInstance = function(instance, opts)
		if not isInstance(instance) then
			return false
		end
		local scopeId = instanceToScope[instance]
		if not scopeId and type(instance.GetAttribute) == "function" then
			local okScope, attrScope = pcall(instance.GetAttribute, instance, attrs.scope)
			if okScope and type(attrScope) == "string" and attrScope ~= "" then
				scopeId = attrScope
			end
		end
		if not scopeId then
			return false
		end
		return self.cleanupScope(scopeId, opts)
	end

	self.cleanupSession = function(opts)
		opts = opts or {}
		local scopeSnapshot = {}
		for index, scopeId in ipairs(scopeOrder) do
			scopeSnapshot[index] = scopeId
		end

		for _, scopeId in ipairs(scopeSnapshot) do
			self.cleanupScope(scopeId, opts)
		end

		local shouldSweepRoot = opts.sweepRoot == true
		local shouldDestroyInstances = opts.destroyInstances == true
		local shouldClearAttributes = opts.clearAttributes ~= false
		local getRootGui = ctx.getRootGui
		if shouldSweepRoot and type(getRootGui) == "function" then
			local okRoot, root = pcall(getRootGui)
			if okRoot and isInstance(root) then
				local sweepList = { root }
				for _, descendant in ipairs(root:GetDescendants()) do
					table.insert(sweepList, descendant)
				end

				for _, instance in ipairs(sweepList) do
					local okOwner, currentOwner = pcall(instance.GetAttribute, instance, attrs.owner)
					local okSession, currentSession = pcall(instance.GetAttribute, instance, attrs.session)
					if okOwner and okSession and currentOwner == ownerValue and currentSession == sessionValue then
						if shouldClearAttributes then
							clearOwnershipAttributes(instance, attrs, ownerValue, sessionValue)
						end
						if shouldDestroyInstances and instance.Parent then
							pcall(function()
								instance:Destroy()
							end)
						end
					end
				end
			end
		end

		return true
	end

	self.getStats = function()
		local stats = {
			scopes = 0,
			instances = 0,
			connections = 0,
			tasks = 0,
			cleanups = 0
		}
		for _, scope in pairs(scopeMap) do
			stats.scopes += 1
			stats.connections += #scope.connections
			stats.tasks += #scope.tasks
			stats.cleanups += #scope.cleanups
			for _ in pairs(scope.instances) do
				stats.instances += 1
			end
		end
		return stats
	end

	self.getSignature = function()
		return {
			owner = ownerValue,
			session = sessionValue,
			ownerAttribute = attrs.owner,
			sessionAttribute = attrs.session,
			scopeAttribute = attrs.scope
		}
	end

	return self
end

return OwnershipTracker
