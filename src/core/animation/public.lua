local Public = {}

local function newFallbackSequence(engine, target, tweenInfo, goals)
	local sequence = {
		_engine = engine,
		_target = target,
		_info = tweenInfo,
		_goals = goals,
	}

	function sequence:SetInfo(info)
		self._info = info
		return self
	end

	function sequence:To(nextGoals, nextInfo)
		self._goals = nextGoals
		if nextInfo then
			self._info = nextInfo
		end
		return self
	end

	function sequence:Then(nextGoals, nextInfo)
		return self:To(nextGoals, nextInfo)
	end

	function sequence:Wait()
		return self
	end

	function sequence:Play()
		if typeof(self._info) == "TweenInfo" and type(self._goals) == "table" then
			self._engine:Play(self._target, self._info, self._goals)
		end
		return self
	end

	return sequence
end

function Public.createFacade(engine, libs)
	libs = libs or {}
	local SequenceLib = libs.Sequence
	local UILib = libs.UI
	local TextLib = libs.Text

	local function createSequence(target, tweenInfo, goals)
		if SequenceLib and type(SequenceLib.new) == "function" then
			local sequence = SequenceLib.new(engine, target)
			if typeof(tweenInfo) == "TweenInfo" then
				sequence:SetInfo(tweenInfo)
				if type(goals) == "table" then
					sequence:To(goals, tweenInfo)
				end
			end
			return sequence
		end
		return newFallbackSequence(engine, target, tweenInfo, goals)
	end

	local facade = {}
	setmetatable(facade, {
		__call = function(_, target, tweenInfo, goals)
			return createSequence(target, tweenInfo, goals)
		end
	})

	function facade.UI(target)
		if UILib and type(UILib.new) == "function" then
			return UILib.new(engine, target)
		end
		return nil
	end

	function facade.Text(target)
		if TextLib and type(TextLib.new) == "function" then
			return TextLib.new(engine, target)
		end
		return nil
	end

	function facade.Play(target, tweenInfo, goals, opts)
		return engine:Play(target, tweenInfo, goals, opts)
	end

	function facade.Create(target, tweenInfo, goals, opts)
		return engine:Create(target, tweenInfo, goals, opts)
	end

	function facade.StopObject(target)
		engine:CancelObject(target)
		engine:StopTextForObject(target)
	end

	function facade.StopAll()
		engine:CancelAll()
		engine:StopAllText()
	end

	function facade.GetActiveAnimationCount()
		return engine:GetActiveAnimationCount()
	end

	function facade.GetEngine()
		return engine
	end

	return facade
end

function Public.bindToRayfield(rayfieldLibrary, engine, libs)
	local facade = Public.createFacade(engine, libs)
	rayfieldLibrary.Animate = facade
	rayfieldLibrary.GetAnimationEngine = function()
		return engine
	end
	return facade
end

return Public
