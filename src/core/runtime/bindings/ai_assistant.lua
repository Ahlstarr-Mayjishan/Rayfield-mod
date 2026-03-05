local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local askAssistantInternal = ctx.askAssistantInternal
	local getAssistantHistoryInternal = ctx.getAssistantHistoryInternal
	local registerHubMetadataInternal = ctx.registerHubMetadataInternal
	local getHubMetadataInternal = ctx.getHubMetadataInternal

	function RayfieldLibrary:AskAssistant(prompt, options)
		if type(askAssistantInternal) ~= "function" then
			return false, "Assistant bridge unavailable."
		end
		return askAssistantInternal(prompt, options)
	end

	function RayfieldLibrary:GetAssistantHistory()
		if type(getAssistantHistoryInternal) ~= "function" then
			return {}
		end
		local history = getAssistantHistoryInternal()
		return type(history) == "table" and history or {}
	end

	function RayfieldLibrary:RegisterHubMetadata(metadata)
		if type(registerHubMetadataInternal) ~= "function" then
			return false, "Hub metadata bridge unavailable."
		end
		return registerHubMetadataInternal(metadata)
	end

	function RayfieldLibrary:GetHubMetadata()
		if type(getHubMetadataInternal) ~= "function" then
			return nil
		end
		return getHubMetadataInternal()
	end

	setHandler("askAssistant", function(prompt, options)
		return RayfieldLibrary:AskAssistant(prompt, options)
	end)
	setHandler("getAssistantHistory", function()
		return RayfieldLibrary:GetAssistantHistory()
	end)
	setHandler("registerHubMetadata", function(metadata)
		return RayfieldLibrary:RegisterHubMetadata(metadata)
	end)
	setHandler("getHubMetadata", function()
		return RayfieldLibrary:GetHubMetadata()
	end)
end

return module
