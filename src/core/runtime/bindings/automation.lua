local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local startMacroRecordingInternal = ctx.startMacroRecordingInternal
	local stopMacroRecordingInternal = ctx.stopMacroRecordingInternal
	local cancelMacroRecordingInternal = ctx.cancelMacroRecordingInternal
	local isMacroRecordingInternal = ctx.isMacroRecordingInternal
	local isMacroExecutingInternal = ctx.isMacroExecutingInternal
	local listMacrosInternal = ctx.listMacrosInternal
	local deleteMacroInternal = ctx.deleteMacroInternal
	local executeMacroInternal = ctx.executeMacroInternal
	local bindMacroInternal = ctx.bindMacroInternal
	local scheduleMacroInternal = ctx.scheduleMacroInternal
	local scheduleAutomationActionInternal = ctx.scheduleAutomationActionInternal
	local cancelScheduledActionInternal = ctx.cancelScheduledActionInternal
	local listScheduledActionsInternal = ctx.listScheduledActionsInternal
	local clearScheduledActionsInternal = ctx.clearScheduledActionsInternal
	local addAutomationRuleInternal = ctx.addAutomationRuleInternal
	local removeAutomationRuleInternal = ctx.removeAutomationRuleInternal
	local listAutomationRulesInternal = ctx.listAutomationRulesInternal
	local setAutomationRuleEnabledInternal = ctx.setAutomationRuleEnabledInternal
	local evaluateAutomationRulesInternal = ctx.evaluateAutomationRulesInternal

	function RayfieldLibrary:StartMacroRecording(name)
		if type(startMacroRecordingInternal) ~= "function" then
			return false, "Macro recorder unavailable."
		end
		return startMacroRecordingInternal(name)
	end

	function RayfieldLibrary:StopMacroRecording(saveResult)
		if type(stopMacroRecordingInternal) ~= "function" then
			return false, "Macro recorder unavailable."
		end
		return stopMacroRecordingInternal(saveResult ~= false)
	end

	function RayfieldLibrary:CancelMacroRecording()
		if type(cancelMacroRecordingInternal) ~= "function" then
			return false, "Macro recorder unavailable."
		end
		return cancelMacroRecordingInternal()
	end

	function RayfieldLibrary:IsMacroRecording()
		if type(isMacroRecordingInternal) ~= "function" then
			return false
		end
		return isMacroRecordingInternal() == true
	end

	function RayfieldLibrary:IsMacroExecuting()
		if type(isMacroExecutingInternal) ~= "function" then
			return false
		end
		return isMacroExecutingInternal() == true
	end

	function RayfieldLibrary:ListMacros()
		if type(listMacrosInternal) ~= "function" then
			return {}
		end
		local list = listMacrosInternal()
		return type(list) == "table" and list or {}
	end

	function RayfieldLibrary:DeleteMacro(name)
		if type(deleteMacroInternal) ~= "function" then
			return false, "Macro recorder unavailable."
		end
		return deleteMacroInternal(name)
	end

	function RayfieldLibrary:ExecuteMacro(name, options)
		if type(executeMacroInternal) ~= "function" then
			return false, "Macro executor unavailable."
		end
		return executeMacroInternal(name, options)
	end

	function RayfieldLibrary:BindMacro(name, keybind)
		if type(bindMacroInternal) ~= "function" then
			return false, "Macro binder unavailable."
		end
		return bindMacroInternal(name, keybind)
	end

	function RayfieldLibrary:ScheduleMacro(name, delaySeconds, options)
		if type(scheduleMacroInternal) ~= "function" then
			return false, "Automation scheduler unavailable."
		end
		return scheduleMacroInternal(name, delaySeconds, options)
	end

	function RayfieldLibrary:ScheduleAction(actionSpec, delaySeconds, options)
		if type(scheduleAutomationActionInternal) ~= "function" then
			return false, "Automation scheduler unavailable."
		end
		return scheduleAutomationActionInternal(actionSpec, delaySeconds, options)
	end

	function RayfieldLibrary:CancelScheduledAction(taskId)
		if type(cancelScheduledActionInternal) ~= "function" then
			return false, "Automation scheduler unavailable."
		end
		return cancelScheduledActionInternal(taskId)
	end

	function RayfieldLibrary:ListScheduledActions()
		if type(listScheduledActionsInternal) ~= "function" then
			return {}
		end
		local list = listScheduledActionsInternal()
		return type(list) == "table" and list or {}
	end

	function RayfieldLibrary:ClearScheduledActions()
		if type(clearScheduledActionsInternal) ~= "function" then
			return false, "Automation scheduler unavailable."
		end
		return clearScheduledActionsInternal()
	end

	function RayfieldLibrary:AddAutomationRule(rule)
		if type(addAutomationRuleInternal) ~= "function" then
			return false, "Automation rule engine unavailable."
		end
		return addAutomationRuleInternal(rule)
	end

	function RayfieldLibrary:RemoveAutomationRule(ruleId)
		if type(removeAutomationRuleInternal) ~= "function" then
			return false, "Automation rule engine unavailable."
		end
		return removeAutomationRuleInternal(ruleId)
	end

	function RayfieldLibrary:ListAutomationRules()
		if type(listAutomationRulesInternal) ~= "function" then
			return {}
		end
		local list = listAutomationRulesInternal()
		return type(list) == "table" and list or {}
	end

	function RayfieldLibrary:SetAutomationRuleEnabled(ruleId, enabled)
		if type(setAutomationRuleEnabledInternal) ~= "function" then
			return false, "Automation rule engine unavailable."
		end
		return setAutomationRuleEnabledInternal(ruleId, enabled == true)
	end

	function RayfieldLibrary:EvaluateAutomationRules(eventPayload)
		if type(evaluateAutomationRulesInternal) ~= "function" then
			return false, "Automation rule engine unavailable.", 0
		end
		return evaluateAutomationRulesInternal(eventPayload)
	end

	setHandler("startMacroRecording", function(name)
		return RayfieldLibrary:StartMacroRecording(name)
	end)
	setHandler("stopMacroRecording", function(saveResult)
		return RayfieldLibrary:StopMacroRecording(saveResult ~= false)
	end)
	setHandler("cancelMacroRecording", function()
		return RayfieldLibrary:CancelMacroRecording()
	end)
	setHandler("listMacros", function()
		return RayfieldLibrary:ListMacros()
	end)
	setHandler("executeMacro", function(name, options)
		return RayfieldLibrary:ExecuteMacro(name, options)
	end)
	setHandler("bindMacro", function(name, keybind)
		return RayfieldLibrary:BindMacro(name, keybind)
	end)
	setHandler("scheduleMacro", function(name, delaySeconds, options)
		return RayfieldLibrary:ScheduleMacro(name, delaySeconds, options)
	end)
	setHandler("scheduleAction", function(actionSpec, delaySeconds, options)
		return RayfieldLibrary:ScheduleAction(actionSpec, delaySeconds, options)
	end)
	setHandler("cancelScheduledAction", function(taskId)
		return RayfieldLibrary:CancelScheduledAction(taskId)
	end)
	setHandler("listScheduledActions", function()
		return RayfieldLibrary:ListScheduledActions()
	end)
	setHandler("clearScheduledActions", function()
		return RayfieldLibrary:ClearScheduledActions()
	end)
	setHandler("addAutomationRule", function(rule)
		return RayfieldLibrary:AddAutomationRule(rule)
	end)
	setHandler("removeAutomationRule", function(ruleId)
		return RayfieldLibrary:RemoveAutomationRule(ruleId)
	end)
	setHandler("listAutomationRules", function()
		return RayfieldLibrary:ListAutomationRules()
	end)
	setHandler("setAutomationRuleEnabled", function(ruleId, enabled)
		return RayfieldLibrary:SetAutomationRuleEnabled(ruleId, enabled == true)
	end)
	setHandler("evaluateAutomationRules", function(eventPayload)
		return RayfieldLibrary:EvaluateAutomationRules(eventPayload)
	end)
end

return module
