local Engine = {}
Engine.__index = Engine

local DefaultCleanup = {}
local TRANSITION_PROFILES = {
	Smooth = {
		durationScale = 1.0,
		suppressTextEffects = false
	},
	Snappy = {
		durationScale = 0.75,
		suppressTextEffects = false
	},
	Minimal = {
		durationScale = 0.55,
		suppressTextEffects = false
	},
	Off = {
		durationScale = 0.01,
		suppressTextEffects = true
	}
}

function DefaultCleanup.safeDisconnect(connection)
	if not connection then
		return
	end
	pcall(function()
		connection:Disconnect()
	end)
end

function DefaultCleanup.isAlive(instance)
	return typeof(instance) == "Instance" and instance.Parent ~= nil
end

function DefaultCleanup.isVisibleChain(instance)
	if typeof(instance) ~= "Instance" then
		return false
	end
	local current = instance
	while current do
		if current:IsA("GuiObject") or current:IsA("LayerCollector") then
			local ok, visible = pcall(function()
				return current.Visible
			end)
			if ok and visible == false then
				return false
			end
		end
		current = current.Parent
	end
	return true
end

function DefaultCleanup.bindDestroy(instance, onRemoved)
	if typeof(instance) ~= "Instance" then
		return function() end
	end
	local fired = false
	local connections = {}
	local function fire()
		if fired then
			return
		end
		fired = true
		if type(onRemoved) == "function" then
			pcall(onRemoved)
		end
	end
	table.insert(connections, instance.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			fire()
		end
	end))
	local hasDestroying = pcall(function()
		return instance.Destroying
	end)
	if hasDestroying then
		table.insert(connections, instance.Destroying:Connect(fire))
	end
	return function()
		for _, connection in ipairs(connections) do
			DefaultCleanup.safeDisconnect(connection)
		end
		table.clear(connections)
	end
end

local function countEntries(t)
	local count = 0
	for _, v in pairs(t) do
		if v ~= nil then
			count = count + 1
		end
	end
	return count
end

local function countTextHandles(handleBuckets)
	local total = 0
	for _, handles in pairs(handleBuckets) do
		if type(handles) == "table" then
			total = total + #handles
		end
	end
	return total
end

local function getGoalKey(goals)
	local keys = {}
	for key in pairs(goals or {}) do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)
	if #keys == 0 then
		return "__default"
	end
	return table.concat(keys, "|")
end

function Engine.new(opts)
	opts = opts or {}
	local tweenService = opts.TweenService or game:GetService("TweenService")
	local runService = opts.RunService or game:GetService("RunService")
	local cleanup = opts.Cleanup or DefaultCleanup

	local self = setmetatable({}, Engine)
	self.TweenService = tweenService
	self.RunService = runService
	self.Cleanup = cleanup
	self.Mode = opts.mode or "raw"
	self._uiSuppressed = false
	self._uiSuppressionProvider = opts.uiSuppressionProvider
	self._activeTweens = setmetatable({}, { __mode = "k" })
	self._cleanupHooks = setmetatable({}, { __mode = "k" })
	self._textHandles = setmetatable({}, { __mode = "k" })
	self._textHeartbeat = nil
	self._transitionProfileName = "Smooth"
	self._transitionProfile = {
		durationScale = TRANSITION_PROFILES.Smooth.durationScale,
		suppressTextEffects = TRANSITION_PROFILES.Smooth.suppressTextEffects
	}
	return self
end

local function cloneProfileSpec(spec)
	return {
		durationScale = tonumber(spec and spec.durationScale) or 1,
		suppressTextEffects = spec and spec.suppressTextEffects == true or false
	}
end

local function resolveProfileName(name)
	if type(name) ~= "string" then
		return nil
	end
	local normalized = string.lower(name)
	if normalized == "smooth" then
		return "Smooth"
	elseif normalized == "snappy" then
		return "Snappy"
	elseif normalized == "minimal" then
		return "Minimal"
	elseif normalized == "off" then
		return "Off"
	end
	return nil
end

function Engine:SetTransitionProfile(profileName, profileSpec)
	local canonicalName = resolveProfileName(profileName)
	if not canonicalName then
		return false, "Invalid transition profile."
	end

	local defaultSpec = TRANSITION_PROFILES[canonicalName]
	local nextSpec = cloneProfileSpec(defaultSpec)
	if type(profileSpec) == "table" then
		if profileSpec.durationScale ~= nil then
			local parsedScale = tonumber(profileSpec.durationScale)
			if parsedScale and parsedScale > 0 then
				nextSpec.durationScale = parsedScale
			end
		end
		if profileSpec.suppressTextEffects ~= nil then
			nextSpec.suppressTextEffects = profileSpec.suppressTextEffects == true
		end
	end

	self._transitionProfileName = canonicalName
	self._transitionProfile = nextSpec
	if nextSpec.suppressTextEffects then
		self:StopAllText()
	end

	return true, canonicalName
end

function Engine:GetTransitionProfile()
	local profile = cloneProfileSpec(self._transitionProfile)
	return self._transitionProfileName, profile
end

function Engine:SetUiSuppressionProvider(provider)
	if type(provider) == "function" then
		self._uiSuppressionProvider = provider
	else
		self._uiSuppressionProvider = nil
	end
end

function Engine:IsUiSuppressed()
	if self._uiSuppressed then
		return true
	end
	if type(self._uiSuppressionProvider) == "function" then
		local ok, result = pcall(self._uiSuppressionProvider)
		if ok and result then
			return true
		end
	end
	return false
end

function Engine:SetUiSuppressed(value)
	self._uiSuppressed = value and true or false
	if self._uiSuppressed then
		self:StopAllText()
	end
end

function Engine:_ensureTweenBucket(instance)
	local bucket = self._activeTweens[instance]
	if bucket then
		return bucket
	end

	bucket = {}
	self._activeTweens[instance] = bucket

	if not self._cleanupHooks[instance] then
		self._cleanupHooks[instance] = self.Cleanup.bindDestroy(instance, function()
			self:CancelObject(instance)
			self:StopTextForObject(instance)
		end)
	end

	return bucket
end

function Engine:_releaseTweenBucketIfEmpty(instance)
	local bucket = self._activeTweens[instance]
	if not bucket or next(bucket) ~= nil then
		return
	end
	self._activeTweens[instance] = nil

	local cleanupHook = self._cleanupHooks[instance]
	if cleanupHook then
		pcall(cleanupHook)
	end
	self._cleanupHooks[instance] = nil
end

function Engine:_trackTween(instance, key, tween, cancelPrevious)
	local bucket = self:_ensureTweenBucket(instance)
	if cancelPrevious and bucket[key] and bucket[key] ~= tween then
		pcall(function()
			bucket[key]:Cancel()
		end)
	end

	bucket[key] = tween
	tween.Completed:Connect(function()
		local activeBucket = self._activeTweens[instance]
		if not activeBucket then
			return
		end
		if activeBucket[key] == tween then
			activeBucket[key] = nil
			self:_releaseTweenBucketIfEmpty(instance)
		end
	end)
end

function Engine:Create(instance, tweenInfo, goals, opts)
	opts = opts or {}
	if typeof(instance) ~= "Instance" then
		return nil
	end
	if typeof(tweenInfo) ~= "TweenInfo" then
		return nil
	end
	if type(goals) ~= "table" then
		return nil
	end

	local scale = tonumber(self._transitionProfile and self._transitionProfile.durationScale) or 1
	if scale <= 0 then
		scale = 1
	end
	local adjustedTweenInfo = tweenInfo
	if scale ~= 1 then
		adjustedTweenInfo = TweenInfo.new(
			math.max(0.01, tweenInfo.Time * scale),
			tweenInfo.EasingStyle,
			tweenInfo.EasingDirection,
			tweenInfo.RepeatCount,
			tweenInfo.Reverses,
			tweenInfo.DelayTime
		)
	end

	local tween = self.TweenService:Create(instance, adjustedTweenInfo, goals)

	if opts.track then
		local key = opts.key
		if key == nil then
			key = getGoalKey(goals)
		end
		self:_trackTween(instance, tostring(key), tween, opts.cancelPrevious ~= false)
	end

	return tween
end

function Engine:Play(instance, tweenInfo, goals, opts)
	local tween = self:Create(instance, tweenInfo, goals, opts)
	if tween then
		tween:Play()
	end
	return tween
end

function Engine:AnimateProperty(instance, property, targetValue, duration, easingStyle, easingDirection, opts)
	if type(property) ~= "string" then
		return nil
	end
	local info = TweenInfo.new(
		duration or 0.5,
		easingStyle or Enum.EasingStyle.Exponential,
		easingDirection or Enum.EasingDirection.Out
	)
	local tween = self:Create(instance, info, { [property] = targetValue }, {
		track = true,
		key = property,
		cancelPrevious = true,
	})
	if tween then
		tween:Play()
	end
	return tween
end

function Engine:GetActiveAnimationCount()
	local count = 0
	for _, bucket in pairs(self._activeTweens) do
		count = count + countEntries(bucket)
	end
	return count
end

function Engine:GetTextHandleCount()
	return countTextHandles(self._textHandles)
end

function Engine:GetRuntimeStats()
	return {
		activeTweens = self:GetActiveAnimationCount(),
		activeTextHandles = self:GetTextHandleCount(),
		heartbeatConnected = self._textHeartbeat ~= nil
	}
end

function Engine:CancelObject(instance)
	local bucket = self._activeTweens[instance]
	if bucket then
		for _, tween in pairs(bucket) do
			if tween then
				pcall(function()
					tween:Cancel()
				end)
			end
		end
		self._activeTweens[instance] = nil
	end

	local cleanupHook = self._cleanupHooks[instance]
	if cleanupHook then
		pcall(cleanupHook)
	end
	self._cleanupHooks[instance] = nil
end

function Engine:CancelAll()
	for instance in pairs(self._activeTweens) do
		self:CancelObject(instance)
	end
end

function Engine:_ensureTextHeartbeat()
	if self._textHeartbeat then
		return
	end
	self._textHeartbeat = self.RunService.Heartbeat:Connect(function()
		self:_tickTextHandles()
	end)
end

function Engine:_maybeReleaseTextHeartbeat()
	for _, handles in pairs(self._textHandles) do
		if handles and #handles > 0 then
			return
		end
	end
	if self._textHeartbeat then
		self.Cleanup.safeDisconnect(self._textHeartbeat)
		self._textHeartbeat = nil
	end
end

function Engine:_tickTextHandles()
	local transitionSuppressed = self._transitionProfile and self._transitionProfile.suppressTextEffects == true
	local suppressed = self:IsUiSuppressed() or transitionSuppressed
	for instance, handles in pairs(self._textHandles) do
		if type(handles) == "table" then
			for i = #handles, 1, -1 do
				local handle = handles[i]
				local running = handle and handle.IsRunning and handle:IsRunning()
				local dead = (not self.Cleanup.isAlive(instance)) or (not self.Cleanup.isVisibleChain(instance))
				if dead or suppressed then
					if handle and handle.Stop then
						pcall(function()
							handle:Stop()
						end)
					end
					table.remove(handles, i)
				elseif not running then
					table.remove(handles, i)
				end
			end
			if #handles == 0 then
				self._textHandles[instance] = nil
			end
		end
	end
	self:_maybeReleaseTextHeartbeat()
end

function Engine:RegisterTextHandle(instance, handle)
	if typeof(instance) ~= "Instance" or not handle then
		return
	end
	if self._transitionProfile and self._transitionProfile.suppressTextEffects == true then
		if handle and handle.Stop then
			pcall(function()
				handle:Stop()
			end)
		end
		return
	end
	local handles = self._textHandles[instance]
	if not handles then
		handles = {}
		self._textHandles[instance] = handles
	end
	table.insert(handles, handle)
	self:_ensureTextHeartbeat()
end

function Engine:UnregisterTextHandle(instance, handle)
	local handles = self._textHandles[instance]
	if not handles then
		return
	end
	for i = #handles, 1, -1 do
		if handles[i] == handle then
			table.remove(handles, i)
		end
	end
	if #handles == 0 then
		self._textHandles[instance] = nil
	end
	self:_maybeReleaseTextHeartbeat()
end

function Engine:StopTextForObject(instance)
	local handles = self._textHandles[instance]
	if not handles then
		return
	end
	for i = #handles, 1, -1 do
		local handle = handles[i]
		if handle and handle.Stop then
			pcall(function()
				handle:Stop()
			end)
		end
	end
	self._textHandles[instance] = nil
	self:_maybeReleaseTextHeartbeat()
end

function Engine:StopAllText()
	for instance in pairs(self._textHandles) do
		self:StopTextForObject(instance)
	end
end

function Engine:Destroy()
	self:StopAllText()
	self:CancelAll()
	self:SetUiSuppressed(true)
	if self._textHeartbeat then
		self.Cleanup.safeDisconnect(self._textHeartbeat)
		self._textHeartbeat = nil
	end
end

return Engine
