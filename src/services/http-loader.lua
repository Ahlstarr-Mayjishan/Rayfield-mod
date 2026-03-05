local HttpLoaderService = {}

function HttpLoaderService.create(options)
	options = options or {}
	local compileString = options.compileString or loadstring or load
	local execPolicy = options.execPolicy
	local httpGet = type(options.httpGet) == "function" and options.httpGet or function()
		error("HttpLoaderService.create requires options.httpGet")
	end
	local warnFn = type(options.warn) == "function" and options.warn or warn
	local taskLib = options.taskLib or task
	local clockFn = type(options.clock) == "function" and options.clock or os.clock
	local defaultCancelOnTimeout = options.defaultCancelOnTimeout ~= false

	if type(compileString) ~= "function" then
		error("HttpLoaderService requires a compile function (loadstring/load).")
	end

	local loader = {}

	function loader.loadWithTimeout(url, timeout)
		assert(type(url) == "string", "Expected string, got " .. type(url))
		timeout = tonumber(timeout) or 5
		if timeout <= 0 then
			timeout = 5
		end

		local opKey = "runtime:loadWithTimeout:" .. tostring(url)
		local policyDecision = {
			mode = "soft",
			reason = "fallback-no-policy",
			cancelOnTimeout = false
		}
		if type(execPolicy) == "table" and type(execPolicy.decideExecutionMode) == "function" then
			local okDecision, decisionResult = pcall(execPolicy.decideExecutionMode, opKey, true, timeout, clockFn())
			if okDecision and type(decisionResult) == "table" then
				policyDecision = decisionResult
			end
		end

		local policyMode = policyDecision.mode
		local policyReason = policyDecision.reason
		local cancelOnTimeout = policyDecision.cancelOnTimeout == true
		if cancelOnTimeout ~= true and defaultCancelOnTimeout then
			cancelOnTimeout = true
			policyMode = "hard"
			policyReason = "default-override:http-loader-default-cancel"
		end
		if type(_G) == "table" and _G.__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT ~= nil then
			cancelOnTimeout = _G.__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT == true
			policyMode = cancelOnTimeout and "hard" or "soft"
			policyReason = "legacy-override:__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT"
		end

		local requestCompleted = false
		local success = false
		local result = nil

		local requestThread = taskLib.spawn(function()
			local fetchSuccess, fetchResult = pcall(httpGet, url)
			if requestCompleted then
				return
			end
			if not fetchSuccess then
				success, result = false, tostring(fetchResult or "HTTP request failed")
				requestCompleted = true
				return
			end
			if type(fetchResult) ~= "string" then
				success, result = false, "Invalid HTTP response type: " .. type(fetchResult)
				requestCompleted = true
				return
			end
			if #fetchResult == 0 then
				success, result = false, "Empty response"
				requestCompleted = true
				return
			end

			local chunk, compileErr = compileString(fetchResult)
			if not chunk then
				success, result = false, "Failed to compile loaded content: " .. tostring(compileErr)
				requestCompleted = true
				return
			end

			local execSuccess, execResult = pcall(chunk)
			if requestCompleted then
				return
			end
			success, result = execSuccess, execResult
			requestCompleted = true
		end)

		local timeoutThread = taskLib.delay(timeout, function()
			if requestCompleted then
				return
			end

			warnFn("Request for " .. url .. " timed out after " .. tostring(timeout) .. " seconds"
				.. " | policy=" .. tostring(policyMode)
				.. " | reason=" .. tostring(policyReason))
			if cancelOnTimeout then
				pcall(taskLib.cancel, requestThread)
			end
			result = "Request timed out"
				.. " | policy=" .. tostring(policyMode)
				.. " | reason=" .. tostring(policyReason)
			requestCompleted = true

			if type(execPolicy) == "table" and type(execPolicy.markTimeout) == "function" then
				pcall(execPolicy.markTimeout, opKey, clockFn(), {
					mode = policyMode,
					reason = policyReason,
					timeoutSeconds = timeout,
					canceled = cancelOnTimeout,
					isBlocking = true
				})
			end
		end)

		while not requestCompleted do
			taskLib.wait()
		end
		pcall(taskLib.cancel, timeoutThread)

		if success and type(execPolicy) == "table" and type(execPolicy.markSuccess) == "function" then
			pcall(execPolicy.markSuccess, opKey, clockFn(), {
				mode = policyMode,
				reason = policyReason,
				timeoutSeconds = timeout,
				isBlocking = true
			})
		end

		if not success then
			warnFn("Failed to process " .. tostring(url) .. ": " .. tostring(result))
			return nil
		end

		return result
	end

	return loader
end

return HttpLoaderService
