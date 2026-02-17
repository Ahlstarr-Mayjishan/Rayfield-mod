local Sequence = {}
Sequence.__index = Sequence

local function safeWaitForTween(tween)
	if not tween then
		return
	end
	local okCompleted, completedSignal = pcall(function()
		return tween.Completed
	end)
	if okCompleted and completedSignal then
		pcall(function()
			completedSignal:Wait()
		end)
	end
end

function Sequence.new(engine, target)
	local self = setmetatable({}, Sequence)
	self._engine = engine
	self._target = target
	self._defaultInfo = TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	self._steps = {}
	self._running = false
	self._stopped = false
	self._currentTween = nil
	self._completedCallbacks = {}
	return self
end

function Sequence:SetInfo(tweenInfo)
	if typeof(tweenInfo) == "TweenInfo" then
		self._defaultInfo = tweenInfo
	end
	return self
end

function Sequence:To(goals, tweenInfo, opts)
	if type(goals) == "table" then
		table.insert(self._steps, {
			type = "tween",
			goals = goals,
			info = (typeof(tweenInfo) == "TweenInfo" and tweenInfo) or self._defaultInfo,
			opts = opts or {}
		})
	end
	return self
end

function Sequence:Then(goals, tweenInfo, opts)
	return self:To(goals, tweenInfo, opts)
end

function Sequence:Wait(duration)
	local sec = tonumber(duration) or 0
	if sec < 0 then
		sec = 0
	end
	table.insert(self._steps, {
		type = "wait",
		duration = sec
	})
	return self
end

function Sequence:Call(callback)
	if type(callback) == "function" then
		table.insert(self._steps, {
			type = "callback",
			callback = callback
		})
	end
	return self
end

function Sequence:OnCompleted(callback)
	if type(callback) == "function" then
		table.insert(self._completedCallbacks, callback)
	end
	return self
end

function Sequence:IsRunning()
	return self._running
end

function Sequence:Stop()
	self._stopped = true
	if self._currentTween then
		pcall(function()
			self._currentTween:Cancel()
		end)
		self._currentTween = nil
	end
	return self
end

function Sequence:Play()
	if self._running then
		return self
	end

	self._running = true
	self._stopped = false

	task.spawn(function()
		for _, step in ipairs(self._steps) do
			if self._stopped then
				break
			end

			if step.type == "wait" then
				task.wait(step.duration)
			elseif step.type == "callback" then
				pcall(step.callback, self._engine, self._target)
			elseif step.type == "tween" then
				local tween = self._engine:Create(self._target, step.info, step.goals, step.opts)
				self._currentTween = tween
				if tween then
					tween:Play()
					safeWaitForTween(tween)
				end
				self._currentTween = nil
			end
		end

		self._running = false
		if not self._stopped then
			for _, callback in ipairs(self._completedCallbacks) do
				pcall(callback, self)
			end
		end
	end)

	return self
end

return Sequence
