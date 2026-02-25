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

	local coreGui = Compatibility.getService("CoreGui")
	if useStudio then
		return coreGui
	end

	local hui = Compatibility.tryGetHui()
	if hui then
		return hui
	end

	if coreGui then
		local robloxGui = safePcall(function()
			return coreGui:FindFirstChild("RobloxGui")
		end)
		if robloxGui then
			return robloxGui
		end
	end

	return coreGui
end

function Compatibility.protectAndParent(guiObject, preferredContainer, options)
	if not guiObject then
		return nil
	end

	options = options or {}
	local useStudio = options.useStudio == true
	local container = Compatibility.getGuiContainer(useStudio, preferredContainer)

	if not useStudio and not Compatibility.tryGetHui() then
		Compatibility.protectGui(guiObject)
	end

	if container then
		guiObject.Parent = container
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
			local okEnable = pcall(function()
				child.Enabled = false
			end)
			if not okEnable then
				-- Ignore non-LayerCollector instances sharing same name.
			end
			child.Name = guiName .. suffix
			renamedCount += 1
		end
	end

	return renamedCount
end

if type(_G) == "table" then
	_G.__RayfieldCompatibility = Compatibility
end

return Compatibility

