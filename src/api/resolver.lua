local Resolver = {}

local DEFAULT_ROOT = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"

function Resolver.normalizeRuntimeRoot(rootUrl)
	if type(rootUrl) ~= "string" or rootUrl == "" then
		return DEFAULT_ROOT
	end
	if rootUrl:sub(-1) ~= "/" then
		return rootUrl .. "/"
	end
	return rootUrl
end

function Resolver.getRuntimeRoot()
	if _G and type(_G.__RAYFIELD_RUNTIME_ROOT_URL) == "string" and #_G.__RAYFIELD_RUNTIME_ROOT_URL > 0 then
		return Resolver.normalizeRuntimeRoot(_G.__RAYFIELD_RUNTIME_ROOT_URL)
	end
	return Resolver.normalizeRuntimeRoot(DEFAULT_ROOT)
end

function Resolver.isStudio()
	local ok, runService = pcall(function()
		return game:GetService("RunService")
	end)
	if not ok or not runService then
		return false
	end
	local okStudio, studio = pcall(function()
		return runService:IsStudio()
	end)
	return okStudio and studio or false
end

function Resolver.getCompileString()
	local compileString = loadstring or load
	if not compileString then
		error("No Lua compiler function available (loadstring/load)")
	end
	return compileString
end

function Resolver.tryRequire(scriptRef, moduleName)
	if not scriptRef then
		return nil
	end
	local ok, value = pcall(function()
		return require(scriptRef.Parent[moduleName])
	end)
	if ok then
		return value
	end
	return nil
end

return Resolver
