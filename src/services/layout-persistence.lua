-- Rayfield Layout Persistence Module
-- Collects/restores layout snapshots and debounces config save requests.

local LayoutPersistence = {}

local function getSharedUtils()
	if type(_G) == "table" and type(_G.__RayfieldSharedUtils) == "table" then
		return _G.__RayfieldSharedUtils
	end
	return nil
end

local function cloneTable(value)
	local shared = getSharedUtils()
	if shared and type(shared.cloneTable) == "function" then
		return shared.cloneTable(value)
	end
	if type(value) ~= "table" then
		return value
	end

	local out = {}
	for key, nested in pairs(value) do
		out[key] = cloneTable(nested)
	end
	return out
end

function LayoutPersistence.init(ctx)
	local self = {}

	ctx = ctx or {}
	local providers = {}
	local saveToken = 0
	local dirty = false
	local applying = false

	self.version = tonumber(ctx.version) or 1
	self.layoutKey = tostring(ctx.layoutKey or "__rayfield_layout")

	local getEnabled = ctx.getEnabled
	if type(getEnabled) ~= "function" then
		getEnabled = function()
			return true
		end
	end

	local getDebounceMs = ctx.getDebounceMs
	if type(getDebounceMs) ~= "function" then
		getDebounceMs = function()
			return 300
		end
	end

	local requestSave = ctx.requestSave
	if type(requestSave) ~= "function" then
		requestSave = function()
			return false
		end
	end

	local function isEnabled()
		local ok, enabled = pcall(getEnabled)
		if not ok then
			return false
		end
		return enabled == true
	end

	local function requestSaveNow(reason)
		local ok = pcall(requestSave, reason)
		return ok
	end

	local function sortedProviders()
		local sequence = {}
		for name, provider in pairs(providers) do
			table.insert(sequence, {
				name = name,
				order = tonumber(provider.order) or 100,
				provider = provider
			})
		end
		table.sort(sequence, function(left, right)
			if left.order == right.order then
				return left.name < right.name
			end
			return left.order < right.order
		end)
		return sequence
	end

	function self.registerProvider(name, opts)
		if type(name) ~= "string" or name == "" then
			return false
		end

		opts = opts or {}
		providers[name] = {
			order = tonumber(opts.order) or 100,
			snapshot = opts.snapshot,
			apply = opts.apply
		}
		return true
	end

	function self.unregisterProvider(name)
		providers[name] = nil
	end

	function self.getLayoutSnapshot()
		if not isEnabled() then
			return nil
		end

		local payload = {
			version = self.version
		}

		for _, entry in ipairs(sortedProviders()) do
			local snapshotFn = entry.provider.snapshot
			if type(snapshotFn) == "function" then
				local ok, snapshot = pcall(snapshotFn)
				if ok and snapshot ~= nil then
					payload[entry.name] = cloneTable(snapshot)
				end
			end
		end

		return payload
	end

	function self.applyLayoutSnapshot(payload)
		if type(payload) ~= "table" then
			return false
		end

		applying = true
		local okAll = true

		for _, entry in ipairs(sortedProviders()) do
			local applyFn = entry.provider.apply
			if type(applyFn) == "function" then
				local section = payload[entry.name]
				if section ~= nil then
					local ok = pcall(applyFn, cloneTable(section), cloneTable(payload))
					if not ok then
						okAll = false
					end
				end
			end
		end

		applying = false
		dirty = false
		return okAll
	end

	function self.markDirty(reason)
		if applying or not isEnabled() then
			return
		end

		dirty = true
		saveToken += 1
		local myToken = saveToken
		local debounceMs = tonumber(getDebounceMs()) or 300
		if debounceMs < 50 then
			debounceMs = 50
		end
		local delaySec = debounceMs / 1000

		task.delay(delaySec, function()
			if myToken ~= saveToken then
				return
			end
			if not dirty or applying or not isEnabled() then
				return
			end
			dirty = false
			requestSaveNow(reason or "layout_dirty")
		end)
	end

	function self.flush(reason)
		if applying or not isEnabled() then
			return false
		end

		dirty = false
		return requestSaveNow(reason or "layout_flush")
	end

	function self.isApplying()
		return applying
	end

	function self.isDirty()
		return dirty
	end

	return self
end

return LayoutPersistence
