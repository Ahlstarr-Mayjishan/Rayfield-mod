local Cache = {}

_G.__RayfieldApiModuleCache = _G.__RayfieldApiModuleCache or {}

function Cache.get(key)
	return _G.__RayfieldApiModuleCache[key]
end

function Cache.set(key, value)
	_G.__RayfieldApiModuleCache[key] = value
	return value
end

function Cache.invalidate(key)
	_G.__RayfieldApiModuleCache[key] = nil
end

function Cache.clear()
	table.clear(_G.__RayfieldApiModuleCache)
end

return Cache
