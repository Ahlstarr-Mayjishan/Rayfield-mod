local WidgetBootstrap = {}

local DEFAULT_ROOT = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/"
local TRACE_FLAG_KEY = "__RAYFIELD_WIDGET_TRACE"
local TRACE_PREFIX = "[RAYFIELD][WIDGET_BOOTSTRAP]"

local function getSharedUtils()
	if type(_G) == "table" and type(_G.__RayfieldSharedUtils) == "table" then
		return _G.__RayfieldSharedUtils
	end
	return nil
end

local function trim(value)
	local shared = getSharedUtils()
	if shared and type(shared.trim) == "function" then
		return shared.trim(value)
	end
	if type(value) ~= "string" then
		return ""
	end
	local out = value:gsub("^%s+", "")
	out = out:gsub("%s+$", "")
	return out
end

local function shouldTrace(level)
	if level == "error" then
		return true
	end
	return type(_G) == "table" and _G[TRACE_FLAG_KEY] == true
end

function WidgetBootstrap.trace(branchId, level, data)
	local payload = data or {}
	local branch = tostring(branchId or "unknown")
	local stage = tostring(payload.stage or "widgets.bootstrap")
	local moduleName = tostring(payload.module or "unknown")
	local reason = tostring(payload.reason or "n/a")
	local nextAction = tostring(payload.next_action or "n/a")
	local traceLevel = tostring(level or "info")
	local message = string.format(
		"%s branch_id=%s level=%s stage=%s module=%s reason=%s next_action=%s",
		TRACE_PREFIX,
		branch,
		traceLevel,
		stage,
		moduleName,
		reason,
		nextAction
	)

	if shouldTrace(traceLevel) then
		if traceLevel == "error" then
			warn(message)
		else
			print(message)
		end
	end
end

function WidgetBootstrap.fail(code, message, data)
	local payload = data or {}
	local moduleName = tostring(payload.module or "unknown")
	local stage = tostring(payload.stage or "widgets.bootstrap")
	local branch = tostring(payload.branch_id or code or "unknown")
	local reason = tostring(message or "unknown_error")
	local errorCode = tostring(code or "E_UNKNOWN")

	WidgetBootstrap.trace(branch, "error", {
		stage = stage,
		module = moduleName,
		reason = reason,
		next_action = payload.next_action or "stop"
	})

	error(string.format("[%s] %s (module=%s, stage=%s, branch_id=%s)", errorCode, reason, moduleName, stage, branch))
end

local function normalizeRoot(rawRoot)
	local root = trim(rawRoot)
	if root == "" then
		return nil, "root_empty"
	end
	if root:find("%s") then
		return nil, "root_contains_whitespace"
	end
	if not root:match("^https?://") then
		return nil, "root_not_http_url"
	end
	if root:sub(-1) ~= "/" then
		root = root .. "/"
	end
	return root, nil
end

local function normalizeTargetPath(rawTargetPath)
	if type(rawTargetPath) ~= "string" then
		return nil, "target_not_string"
	end
	local path = trim(rawTargetPath)
	path = path:gsub("^/+", "")
	if path == "" then
		return nil, "target_empty"
	end
	return path, nil
end

function WidgetBootstrap.bootstrapWidget(widgetName, targetPath, exportAdapter, options)
	local opts = options or {}
	local moduleName = tostring(widgetName or "unknown_widget")
	local stage = "widgets.bootstrap"
	local expectedType = opts.expectedType or "table"

	WidgetBootstrap.trace("B01_CLIENT_PRESENT", "debug", {
		stage = stage,
		module = moduleName,
		reason = "checking _G.__RayfieldApiClient",
		next_action = "validate_client_contract"
	})
	local client = _G and _G.__RayfieldApiClient
	if not client then
		WidgetBootstrap.fail("E_CLIENT_MISSING", "Rayfield ApiClient is not initialized", {
			branch_id = "B01_CLIENT_PRESENT",
			stage = stage,
			module = moduleName,
			next_action = "stop"
		})
	end

	WidgetBootstrap.trace("B02_CLIENT_CONTRACT", "debug", {
		stage = stage,
		module = moduleName,
		reason = "checking client.fetchAndExecute contract",
		next_action = "resolve_root"
	})
	if type(client.fetchAndExecute) ~= "function" then
		WidgetBootstrap.fail("E_CLIENT_INVALID", "ApiClient.fetchAndExecute must be a function", {
			branch_id = "B02_CLIENT_CONTRACT",
			stage = stage,
			module = moduleName,
			next_action = "stop"
		})
	end

	WidgetBootstrap.trace("B03_ROOT_RESOLVE", "debug", {
		stage = stage,
		module = moduleName,
		reason = "resolving runtime root URL",
		next_action = "build_target_path"
	})
	local rawRoot = (_G and _G.__RAYFIELD_RUNTIME_ROOT_URL) or DEFAULT_ROOT
	local root, rootErr = normalizeRoot(rawRoot)
	if not root then
		WidgetBootstrap.fail("E_ROOT_INVALID", "Invalid runtime root URL: " .. tostring(rootErr), {
			branch_id = "B03_ROOT_RESOLVE",
			stage = stage,
			module = moduleName,
			next_action = "stop"
		})
	end

	WidgetBootstrap.trace("B04_TARGET_BUILD", "debug", {
		stage = stage,
		module = moduleName,
		reason = "building target module URL",
		next_action = "fetch_execute"
	})
	local normalizedTarget, targetErr = normalizeTargetPath(targetPath)
	if not normalizedTarget then
		WidgetBootstrap.fail("E_TARGET_INVALID", "Invalid target module path: " .. tostring(targetErr), {
			branch_id = "B04_TARGET_BUILD",
			stage = stage,
			module = moduleName,
			next_action = "stop"
		})
	end
	local fullPath = root .. normalizedTarget

	WidgetBootstrap.trace("B05_FETCH_EXEC", "debug", {
		stage = stage,
		module = moduleName,
		reason = "fetchAndExecute module",
		next_action = "validate_export"
	})
	local ok, exported = pcall(client.fetchAndExecute, fullPath)
	if not ok then
		WidgetBootstrap.fail("E_FETCH_FAILED", tostring(exported), {
			branch_id = "B05_FETCH_EXEC",
			stage = stage,
			module = moduleName,
			next_action = "stop"
		})
	end

	if type(exportAdapter) ~= "nil" and type(exportAdapter) ~= "function" then
		WidgetBootstrap.fail("E_EXPORT_INVALID", "exportAdapter must be a function when provided", {
			branch_id = "B06_EXPORT_VALIDATE",
			stage = stage,
			module = moduleName,
			next_action = "stop"
		})
	end

	WidgetBootstrap.trace("B06_EXPORT_VALIDATE", "debug", {
		stage = stage,
		module = moduleName,
		reason = "validating exported module",
		next_action = "return_export"
	})
	if type(exportAdapter) == "function" then
		local adaptOk, adapted = pcall(exportAdapter, exported)
		if not adaptOk then
			WidgetBootstrap.fail("E_EXPORT_INVALID", "exportAdapter failed: " .. tostring(adapted), {
				branch_id = "B06_EXPORT_VALIDATE",
				stage = stage,
				module = moduleName,
				next_action = "stop"
			})
		end
		exported = adapted
	end

	if exported == nil then
		WidgetBootstrap.fail("E_EXPORT_INVALID", "module export is nil", {
			branch_id = "B06_EXPORT_VALIDATE",
			stage = stage,
			module = moduleName,
			next_action = "stop"
		})
	end

	if expectedType ~= "any" and type(exported) ~= expectedType then
		WidgetBootstrap.fail("E_EXPORT_INVALID", "Expected export type '" .. tostring(expectedType) .. "', got '" .. type(exported) .. "'", {
			branch_id = "B06_EXPORT_VALIDATE",
			stage = stage,
			module = moduleName,
			next_action = "stop"
		})
	end

	WidgetBootstrap.trace("B07_RETURN", "info", {
		stage = stage,
		module = moduleName,
		reason = "bootstrap completed successfully",
		next_action = "return"
	})
	return exported
end

if _G then
	_G.__RayfieldWidgetBootstrap = WidgetBootstrap
end

return WidgetBootstrap
