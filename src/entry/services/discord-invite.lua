local DiscordInviteService = {}

function DiscordInviteService.create(options)
	options = type(options) == "table" and options or {}

	local ensureFolder = options.ensureFolder
	local callSafely = options.callSafely
	local isfileFn = options.isfileFn or isfile
	local writefileFn = options.writefileFn or writefile
	local requestFunc = options.requestFunc
	local httpService = options.httpService
	local rayfieldFolder = tostring(options.rayfieldFolder or "Rayfield")
	local configurationExtension = tostring(options.configurationExtension or ".rfld")
	local defaultUseStudio = options.useStudio == true

	local service = {}

	function service.handle(settings, runtimeOptions)
		settings = type(settings) == "table" and settings or {}
		runtimeOptions = type(runtimeOptions) == "table" and runtimeOptions or {}

		local useStudio = defaultUseStudio
		if runtimeOptions.useStudio ~= nil then
			useStudio = runtimeOptions.useStudio == true
		end

		local discordSettings = type(settings.Discord) == "table" and settings.Discord or nil
		if not discordSettings or discordSettings.Enabled ~= true or useStudio then
			return false
		end

		local inviteCode = tostring(discordSettings.Invite or "")
		if inviteCode == "" then
			return false, "missing_invite"
		end

		local inviteFolder = rayfieldFolder .. "/Discord Invites"
		local inviteMarker = inviteFolder .. "/" .. inviteCode .. configurationExtension

		if type(ensureFolder) == "function" then
			ensureFolder(inviteFolder)
		end

		-- Preserve legacy behaviour: only prompt when marker file exists.
		if type(callSafely) == "function" and callSafely(isfileFn, inviteMarker) then
			if type(requestFunc) == "function"
				and type(httpService) == "table"
				and type(httpService.JSONEncode) == "function"
				and type(httpService.GenerateGUID) == "function" then
				pcall(function()
					requestFunc({
						Url = "http://127.0.0.1:6463/rpc?v=1",
						Method = "POST",
						Headers = {
							["Content-Type"] = "application/json",
							Origin = "https://discord.com"
						},
						Body = httpService:JSONEncode({
							cmd = "INVITE_BROWSER",
							nonce = httpService:GenerateGUID(false),
							args = { code = inviteCode }
						})
					})
				end)
			end

			if discordSettings.RememberJoins and type(callSafely) == "function" then
				callSafely(
					writefileFn,
					inviteMarker,
					"Rayfield RememberJoins is true for this invite, this invite will not ask you to join again"
				)
			end
		end

		return true
	end

	return service
end

return DiscordInviteService
