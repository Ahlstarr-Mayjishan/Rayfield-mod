-- Rayfield Virtualization Engine
-- Pure-ish computation helpers for viewport virtualization.

local VirtualizationEngine = {}

VirtualizationEngine.DEFAULTS = {
	Enabled = true,
	AlwaysOn = true,
	FullSuspend = true,
	OverscanPx = 120,
	UpdateHz = 30,
	FadeOnScroll = true,
	DisableFadeDuringResize = true,
	ResizeDebounceMs = 100,
	MinElementsToActivate = 0
}

local function getSharedUtils()
	if type(_G) == "table" and type(_G.__RayfieldSharedUtils) == "table" then
		return _G.__RayfieldSharedUtils
	end
	return nil
end

function VirtualizationEngine.cloneTable(value)
	local shared = getSharedUtils()
	if shared and type(shared.cloneTable) == "function" then
		return shared.cloneTable(value)
	end
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, nested in pairs(value) do
		out[key] = VirtualizationEngine.cloneTable(nested)
	end
	return out
end

function VirtualizationEngine.mergeDefaults(input)
	local defaults = VirtualizationEngine.DEFAULTS
	local out = VirtualizationEngine.cloneTable(defaults)
	if type(input) ~= "table" then
		return out
	end
	for key, value in pairs(input) do
		out[key] = value
	end

	out.Enabled = out.Enabled ~= false
	out.AlwaysOn = out.AlwaysOn ~= false
	out.FullSuspend = out.FullSuspend ~= false
	out.FadeOnScroll = out.FadeOnScroll ~= false
	out.DisableFadeDuringResize = out.DisableFadeDuringResize ~= false

	local overscan = tonumber(out.OverscanPx)
	if not overscan then
		overscan = defaults.OverscanPx
	end
	if overscan < 0 then
		overscan = 0
	end
	out.OverscanPx = math.floor(overscan)

	local updateHz = tonumber(out.UpdateHz)
	if not updateHz or updateHz <= 0 then
		updateHz = defaults.UpdateHz
	end
	out.UpdateHz = math.max(5, math.floor(updateHz))

	local resizeDebounce = tonumber(out.ResizeDebounceMs)
	if not resizeDebounce or resizeDebounce < 0 then
		resizeDebounce = defaults.ResizeDebounceMs
	end
	out.ResizeDebounceMs = math.max(0, math.floor(resizeDebounce))

	local minElements = tonumber(out.MinElementsToActivate)
	if not minElements or minElements < 0 then
		minElements = 0
	end
	out.MinElementsToActivate = math.floor(minElements)

	return out
end

function VirtualizationEngine.isAlive(instance)
	return typeof(instance) == "Instance" and instance.Parent ~= nil
end

function VirtualizationEngine.updateCachedHeight(record, targetObject)
	local height = nil
	if targetObject and targetObject.Parent then
		height = tonumber(targetObject.AbsoluteSize.Y)
	end
	if not height or height <= 0 then
		height = record.cachedHeight
	end
	if not height or height <= 0 then
		height = 32
	end
	record.cachedHeight = math.max(1, math.floor(height + 0.5))
end

function VirtualizationEngine.computeViewport(host)
	local hostObject = host.object
	if not (hostObject and hostObject.Parent) then
		return nil
	end

	local overscan = host.overscan
	if host.mode == "scrolling" then
		local scrollY = hostObject.CanvasPosition.Y
		local viewHeight = hostObject.AbsoluteSize.Y
		return scrollY - overscan, scrollY + viewHeight + overscan, scrollY
	end

	local viewHeight = hostObject.AbsoluteSize.Y
	return 0 - overscan, viewHeight + overscan, 0
end

function VirtualizationEngine.computeBounds(host, record)
	local hostObject = host.object
	if not (hostObject and hostObject.Parent) then
		return nil, nil
	end

	local target = record.sleeping and record.spacer or record.guiObject
	if not (target and target.Parent) then
		return nil, nil
	end

	VirtualizationEngine.updateCachedHeight(record, target)

	local top
	if host.mode == "scrolling" then
		top = (target.AbsolutePosition.Y - hostObject.AbsolutePosition.Y) + hostObject.CanvasPosition.Y
	else
		top = target.AbsolutePosition.Y - hostObject.AbsolutePosition.Y
	end
	local bottom = top + math.max(1, record.cachedHeight or 1)
	return top, bottom
end

function VirtualizationEngine.shouldUseFade(config, host)
	if not config.FadeOnScroll then
		return false
	end
	if config.DisableFadeDuringResize and host.resizeInProgress then
		return false
	end
	return host.lastReason == "scroll"
end

function VirtualizationEngine.countHostElements(host, recordsByToken)
	local count = 0
	for token in pairs(host.elements) do
		if recordsByToken[token] then
			count = count + 1
		end
	end
	return count
end

return VirtualizationEngine
