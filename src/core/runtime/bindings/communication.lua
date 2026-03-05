local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local sendGlobalSignalInternal = ctx.sendGlobalSignalInternal
	local sendInternalChatInternal = ctx.sendInternalChatInternal
	local pollBridgeMessagesInternal = ctx.pollBridgeMessagesInternal
	local startBridgePollingInternal = ctx.startBridgePollingInternal
	local stopBridgePollingInternal = ctx.stopBridgePollingInternal
	local getBridgeMessagesInternal = ctx.getBridgeMessagesInternal

	function RayfieldLibrary:SendGlobalSignal(command, payload, options)
		if type(sendGlobalSignalInternal) ~= "function" then
			return false, "Global signal bridge unavailable."
		end
		return sendGlobalSignalInternal(command, payload, options)
	end

	function RayfieldLibrary:SendInternalChat(message, options)
		if type(sendInternalChatInternal) ~= "function" then
			return false, "Internal chat bridge unavailable."
		end
		return sendInternalChatInternal(message, options)
	end

	function RayfieldLibrary:PollBridgeMessages(limit, options)
		if type(pollBridgeMessagesInternal) ~= "function" then
			return false, "Bridge polling unavailable.", {}
		end
		return pollBridgeMessagesInternal(limit, options)
	end

	function RayfieldLibrary:StartBridgePolling()
		if type(startBridgePollingInternal) ~= "function" then
			return false, "Bridge polling unavailable."
		end
		return startBridgePollingInternal()
	end

	function RayfieldLibrary:StopBridgePolling()
		if type(stopBridgePollingInternal) ~= "function" then
			return false, "Bridge polling unavailable."
		end
		return stopBridgePollingInternal()
	end

	function RayfieldLibrary:GetBridgeMessages(limit, kind)
		if type(getBridgeMessagesInternal) ~= "function" then
			return {}
		end
		local list = getBridgeMessagesInternal(limit, kind)
		return type(list) == "table" and list or {}
	end

	setHandler("sendGlobalSignal", function(command, payload, options)
		return RayfieldLibrary:SendGlobalSignal(command, payload, options)
	end)
	setHandler("sendInternalChat", function(message, options)
		return RayfieldLibrary:SendInternalChat(message, options)
	end)
	setHandler("pollBridgeMessages", function(limit, options)
		return RayfieldLibrary:PollBridgeMessages(limit, options)
	end)
	setHandler("startBridgePolling", function()
		return RayfieldLibrary:StartBridgePolling()
	end)
	setHandler("stopBridgePolling", function()
		return RayfieldLibrary:StopBridgePolling()
	end)
	setHandler("getBridgeMessages", function(limit, kind)
		return RayfieldLibrary:GetBridgeMessages(limit, kind)
	end)
end

return module
