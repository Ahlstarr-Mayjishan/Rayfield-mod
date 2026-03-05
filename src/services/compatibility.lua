local Compatibility = {}

local DEFAULT_RUNTIME_ROOT = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

local function safePcall(fn, ...)
	local ok, result = pcall(fn, ...)
	if ok then
		return result
	end
	return nil
end

function Compatibility.getCompileString()
	local compileString = loadstring or load
	if not compileString then
		error("No Lua compiler function available (loadstring/load)")
	end
	return compileString
end

function Compatibility.getRuntimeRoot()
	if type(_G) == "table" and type(_G.__RAYFIELD_RUNTIME_ROOT_URL) == "string" and _G.__RAYFIELD_RUNTIME_ROOT_URL ~= "" then
		return _G.__RAYFIELD_RUNTIME_ROOT_URL
	end
	return DEFAULT_RUNTIME_ROOT
end

function Compatibility.getService(name)
	local service = safePcall(function()
		return game:GetService(name)
	end)
	if not service then
		return nil
	end

	if type(cloneref) == "function" then
		local ref = safePcall(cloneref, service)
		if ref then
			return ref
		end
	end

	return service
end

function Compatibility.tryGetHui()
	if type(gethui) == "function" then
		local hui = safePcall(gethui)
		if hui then
			return hui
		end
	end
	return nil
end

local function getCompatFlags()
	if type(_G) ~= "table" then
		return {}
	end
	if type(_G.__RAYFIELD_COMPAT_FLAGS) ~= "table" then
		_G.__RAYFIELD_COMPAT_FLAGS = {}
	end
	return _G.__RAYFIELD_COMPAT_FLAGS
end

local function getPlayerGui()
	local players = Compatibility.getService("Players")
	if players and players.LocalPlayer then
		local playerGui = safePcall(function()
			return players.LocalPlayer:FindFirstChild("PlayerGui") or players.LocalPlayer:WaitForChild("PlayerGui", 5)
		end)
		if playerGui then
			return playerGui
		end
	end
	return nil
end

local function shouldDisableHuiAfterError(errText)
	if type(errText) ~= "string" then
		return false
	end
	local lowered = string.lower(errText)
	return string.find(lowered, "locked parent", 1, true) ~= nil
end

local function tryAssignParent(guiObject, container)
	if not guiObject or not container then
		return false, "parent_target_unavailable"
	end
	local okAssign, assignErr = pcall(function()
		guiObject.Parent = container
	end)
	if not okAssign then
		return false, tostring(assignErr)
	end
	if guiObject.Parent ~= container then
		return false, "parent_assignment_rejected"
	end
	return true, nil
end

function Compatibility.protectGui(guiObject)
	if not guiObject then
		return false
	end

	if type(syn) == "table" and type(syn.protect_gui) == "function" then
		local ok = safePcall(syn.protect_gui, guiObject)
		return ok ~= nil
	end

	if type(protectgui) == "function" then
		local ok = safePcall(protectgui, guiObject)
		return ok ~= nil
	end

	if type(secure_call) == "function" and type(protect_gui) == "function" then
		local ok = safePcall(secure_call, protect_gui, guiObject)
		return ok ~= nil
	end

	return false
end

function Compatibility.getGuiContainer(useStudio, preferredContainer)
	if preferredContainer then
		return preferredContainer
	end

	local flags = getCompatFlags()
	local coreGui = Compatibility.getService("CoreGui")
	if useStudio then
		return coreGui
	end

	if flags.disableHui ~= true then
		local hui = Compatibility.tryGetHui()
		if hui then
			return hui
		end
	end

	if coreGui then
		return coreGui
	end

	local playerGui = getPlayerGui()
	if playerGui then
		return playerGui
	end

	return nil
end

function Compatibility.protectAndParent(guiObject, preferredContainer, options)
	if not guiObject then
		return nil
	end

	options = options or {}
	local useStudio = options.useStudio == true
	local flags = getCompatFlags()
	local container = nil

	if not useStudio and not Compatibility.tryGetHui() then
		Compatibility.protectGui(guiObject)
	end

	local candidates = {}
	local huiCandidate = nil
	local function addCandidate(candidate)
		if not candidate then
			return
		end
		for _, existing in ipairs(candidates) do
			if existing == candidate then
				return
			end
		end
		table.insert(candidates, candidate)
	end

	addCandidate(preferredContainer)
	if useStudio then
		addCandidate(Compatibility.getService("CoreGui"))
	else
		if flags.disableHui ~= true then
			huiCandidate = Compatibility.tryGetHui()
			addCandidate(huiCandidate)
		end
		addCandidate(Compatibility.getService("CoreGui"))
		addCandidate(getPlayerGui())
	end

	for _, candidate in ipairs(candidates) do
		local okParent, parentErr = tryAssignParent(guiObject, candidate)
		if okParent then
			container = candidate
			break
		end
		if candidate == huiCandidate and shouldDisableHuiAfterError(parentErr) then
			flags.disableHui = true
		end
	end

	return container
end

function Compatibility.dedupeGuiByName(container, guiName, keepInstance, oldNameSuffix)
	if not (container and guiName) then
		return 0
	end

	local renamedCount = 0
	local suffix = oldNameSuffix or "-Old"
	for _, child in ipairs(container:GetChildren()) do
		if child ~= keepInstance and child.Name == guiName then
			pcall(function()
				child.Enabled = false
			end)
			child.Name = guiName .. suffix
			renamedCount = renamedCount + 1
		end
	end

	return renamedCount
end

if type(_G) == "table" then
	_G.__RayfieldCompatibility = Compatibility
end

return Compatibility

