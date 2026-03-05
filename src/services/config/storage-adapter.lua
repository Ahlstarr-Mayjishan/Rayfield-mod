local StorageAdapter = {}

local function safeCall(callSafely, fn, ...)
	if type(callSafely) == "function" then
		return callSafely(fn, ...)
	end
	if type(fn) ~= "function" then
		return false
	end
	local ok, result = pcall(fn, ...)
	if ok then
		return result
	end
	return false
end

function StorageAdapter.create(options)
	options = type(options) == "table" and options or {}
	local callSafely = options.callSafely
	local writeFileFn = type(options.writeFile) == "function" and options.writeFile or writefile
	local readFileFn = type(options.readFile) == "function" and options.readFile or readfile
	local isFileFn = type(options.isFile) == "function" and options.isFile or isfile
	local isFolderFn = type(options.isFolder) == "function" and options.isFolder or isfolder
	local makeFolderFn = type(options.makeFolder) == "function" and options.makeFolder or makefolder

	local adapter = {}

	function adapter.ensureFolder(path)
		if type(path) ~= "string" or path == "" then
			return true
		end
		if type(isFolderFn) == "function" and safeCall(callSafely, isFolderFn, path) then
			return true
		end
		if type(makeFolderFn) ~= "function" then
			return false
		end
		local makeResult = safeCall(callSafely, makeFolderFn, path)
		if makeResult == false then
			return false
		end
		if type(isFolderFn) == "function" then
			return safeCall(callSafely, isFolderFn, path) == true
		end
		return true
	end

	function adapter.write(path, content)
		if type(writeFileFn) ~= "function" then
			return false, "writefile unavailable"
		end
		local result = safeCall(callSafely, writeFileFn, path, content)
		if result == false then
			return false, "write failed"
		end
		return true
	end

	function adapter.read(path)
		if type(readFileFn) ~= "function" then
			return nil, "readfile unavailable"
		end
		local result = safeCall(callSafely, readFileFn, path)
		if result == false then
			return nil, "read failed"
		end
		return result, nil
	end

	function adapter.exists(path)
		if type(isFileFn) ~= "function" then
			return false
		end
		return safeCall(callSafely, isFileFn, path) == true
	end

	function adapter.capabilities()
		return {
			write = type(writeFileFn) == "function",
			read = type(readFileFn) == "function",
			isFile = type(isFileFn) == "function",
			isFolder = type(isFolderFn) == "function",
			makeFolder = type(makeFolderFn) == "function"
		}
	end

	return adapter
end

return StorageAdapter
