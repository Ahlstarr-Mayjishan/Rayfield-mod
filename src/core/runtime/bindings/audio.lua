local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local experienceState = ctx.experienceState
	local HttpService = ctx.HttpService
	local cloneAudioPack = ctx.cloneAudioPack
	local setAudioFeedbackEnabledInternal = ctx.setAudioFeedbackEnabledInternal
	local setAudioFeedbackPackInternal = ctx.setAudioFeedbackPackInternal
	local getAudioFeedbackStateSnapshot = ctx.getAudioFeedbackStateSnapshot
	local playUICueInternal = ctx.playUICueInternal

	function RayfieldLibrary:SetAudioFeedbackEnabled(value)
		return setAudioFeedbackEnabledInternal(value == true, true)
	end

	function RayfieldLibrary:IsAudioFeedbackEnabled()
		return experienceState().audioState.enabled == true
	end

	function RayfieldLibrary:SetAudioFeedbackPack(name, packDefinition)
		return setAudioFeedbackPackInternal(name, packDefinition, true)
	end

	function RayfieldLibrary:GetAudioFeedbackState()
		return getAudioFeedbackStateSnapshot()
	end

	function RayfieldLibrary:PlayUICue(cueName)
		return playUICueInternal(cueName)
	end

	setHandler("setAudioEnabled", function(enabled)
		return RayfieldLibrary:SetAudioFeedbackEnabled(enabled == true)
	end)
	setHandler("setAudioPack", function(name)
		return RayfieldLibrary:SetAudioFeedbackPack(name)
	end)
	setHandler("setAudioPackJson", function(rawJson)
		local decoded = nil
		local okDecode, decodeErr = pcall(function()
			decoded = HttpService:JSONDecode(tostring(rawJson or ""))
		end)
		if not okDecode then
			return false, "Invalid JSON: " .. tostring(decodeErr)
		end
		if type(decoded) ~= "table" then
			return false, "Audio pack JSON must decode to a table."
		end
		local normalizedPack = cloneAudioPack(decoded)
		local okSet, message = RayfieldLibrary:SetAudioFeedbackPack("Custom", normalizedPack)
		if not okSet then
			return false, message
		end
		return true, message, normalizedPack
	end)
end

return module
