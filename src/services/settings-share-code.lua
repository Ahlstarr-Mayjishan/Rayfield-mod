local SettingsShareCodeModule = {}

function SettingsShareCodeModule.attach(self)
	local function syncShareCodeInputFromHandlers()
		local handlers = self.shareCodeHandlers
		if type(handlers) ~= "table" then
			return
		end
		if type(handlers.getActiveShareCode) ~= "function" then
			return
		end

		local okGet, code = pcall(handlers.getActiveShareCode)
		if okGet and type(code) == "string" then
			self.setShareCodeInputValue(code)
		end
	end

	self.syncShareCodeInputFromHandlers = syncShareCodeInputFromHandlers

	function self.getShareCodeInputValue()
		return tostring(self.shareCodeDraft or "")
	end

	function self.setShareCodeInputValue(value)
		self.shareCodeDraft = tostring(value or "")
		if self.shareCodeInput and type(self.shareCodeInput.Set) == "function" then
			pcall(function()
				self.shareCodeInput:Set(self.shareCodeDraft)
			end)
		end
		return self.shareCodeDraft
	end

	function self.setShareCodeHandlers(handlers)
		if type(handlers) == "table" then
			self.shareCodeHandlers = handlers
		else
			self.shareCodeHandlers = {}
		end
		syncShareCodeInputFromHandlers()
	end

	function self.setExperienceHandlers(handlers)
		if type(handlers) == "table" then
			self.experienceHandlers = handlers
		else
			self.experienceHandlers = {}
		end
	end
end

return SettingsShareCodeModule
