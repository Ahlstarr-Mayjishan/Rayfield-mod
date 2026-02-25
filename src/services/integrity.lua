--[[
	Rayfield Integrity Service
	Enforces GitHub-only execution and monitors for unauthorized modifications.
]]

local IntegrityService = {}

local WHITELISTED_ORIGINS = {
	"https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/",
	"https://github.com/Ahlstarr-Mayjishan/Rayfield-mod/"
}

function IntegrityService.init(ctx)
	local self = {}
	local isSecure = true
	local originError = nil

	-- Layer 5: Integrity check (Steel Layer)
	local function checkOrigin()
		local source = debug.info(1, "s")
		
		-- If running in Studio, allow local
		if game:GetService("RunService"):IsStudio() then
			return true
		end

		local valid = false
		for _, origin in ipairs(WHITELISTED_ORIGINS) do
			if source:find(origin, 1, true) then
				valid = true
				break
			end
		end

		if not valid then
			isSecure = false
			originError = "Unauthorized Source: " .. source
			warn("Rayfield | SECURITY ALERT: Execution blocked from unauthorized source.")
		end
		
		return valid
	end

	function self.verifySystemIntegrity()
		if not checkOrigin() then
			return false, originError
		end
		
		-- Cross-check with SecurityAdapter if available
		if ctx.SecurityAdapter and ctx.SecurityAdapter.isTampered() then
			return false, "System Tampered"
		end
		
		return true
	end

	function self.getSignature()
		if not isSecure then return "SIG_INVALID" end
		-- Generates a temporary signature for this session
		return "SIG-" .. tick() .. "-" .. game.JobId:sub(1,4)
	end

	return self
end

return IntegrityService
