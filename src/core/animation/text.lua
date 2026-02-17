local Text = {}
Text.__index = Text

local CHARSET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

local function randomChar()
	local index = math.random(1, #CHARSET)
	return CHARSET:sub(index, index)
end

local function lerpColor3(a, b, t)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local function makeLoopHandle(controller, runner)
	local handle = {}
	handle._running = false
	handle._cleanup = nil

	function handle:IsRunning()
		return self._running
	end

	function handle:Stop()
		if not self._running then
			return
		end
		self._running = false
		if type(self._cleanup) == "function" then
			pcall(self._cleanup)
		end
		controller._engine:UnregisterTextHandle(controller._target, self)
	end

	handle._running = true
	task.spawn(function()
		local ok = pcall(runner, handle)
		if not ok then
			handle:Stop()
			return
		end
		if handle._running then
			handle:Stop()
		end
	end)

	controller._engine:RegisterTextHandle(controller._target, handle)
	return handle
end

function Text.new(engine, textObject)
	local self = setmetatable({}, Text)
	self._engine = engine
	self._target = textObject
	return self
end

function Text:_alive()
	return self._engine.Cleanup.isAlive(self._target)
end

function Text:_blocked()
	return self._engine:IsUiSuppressed() or (not self._engine.Cleanup.isVisibleChain(self._target))
end

function Text:Type(text, speed, opts)
	opts = opts or {}
	local finalText = tostring(text or self._target.Text or "")
	local charDelay = tonumber(speed) or 0.03
	local cursor = opts.cursor
	local loop = opts.loop == true

	return makeLoopHandle(self, function(handle)
		repeat
			if not self:_alive() then
				break
			end

			self._target.Text = ""
			for i = 1, #finalText do
				if not handle:IsRunning() or self:_blocked() or not self:_alive() then
					return
				end
				local preview = finalText:sub(1, i)
				if cursor then
					preview = preview .. cursor
				end
				self._target.Text = preview
				task.wait(charDelay)
			end
			self._target.Text = finalText
			if loop then
				task.wait(tonumber(opts.loopDelay) or 0.35)
			end
		until not loop
	end)
end

function Text:Ghosting(text, interval, opts)
	opts = opts or {}
	if text ~= nil then
		self._target.Text = tostring(text)
	end

	local period = tonumber(interval) or 0.85
	local minTransparency = tonumber(opts.minTransparency) or 0.15
	local maxTransparency = tonumber(opts.maxTransparency) or 0.55

	return makeLoopHandle(self, function(handle)
		while handle:IsRunning() do
			if self:_blocked() or not self:_alive() then
				return
			end
			local tweenIn = self._engine:Play(
				self._target,
				TweenInfo.new(period * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ TextTransparency = maxTransparency },
				{ track = true, key = "TextTransparency", cancelPrevious = true }
			)
			if tweenIn then
				tweenIn.Completed:Wait()
			end
			if not handle:IsRunning() then
				return
			end
			local tweenOut = self._engine:Play(
				self._target,
				TweenInfo.new(period * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ TextTransparency = minTransparency },
				{ track = true, key = "TextTransparency", cancelPrevious = true }
			)
			if tweenOut then
				tweenOut.Completed:Wait()
			end
		end
	end)
end

function Text:Scramble(text, duration, opts)
	opts = opts or {}
	local finalText = tostring(text or self._target.Text or "")
	local totalDuration = tonumber(duration) or 0.8
	local tickRate = tonumber(opts.tickRate) or 0.04
	local loop = opts.loop == true

	return makeLoopHandle(self, function(handle)
		repeat
			local startTime = tick()
			while handle:IsRunning() and self:_alive() and (tick() - startTime) < totalDuration do
				if self:_blocked() then
					return
				end
				local progress = math.clamp((tick() - startTime) / totalDuration, 0, 1)
				local fixedCount = math.floor(#finalText * progress)
				local chars = {}
				for i = 1, #finalText do
					if i <= fixedCount then
						chars[i] = finalText:sub(i, i)
					else
						chars[i] = randomChar()
					end
				end
				self._target.Text = table.concat(chars)
				task.wait(tickRate)
			end
			if not handle:IsRunning() then
				return
			end
			self._target.Text = finalText
			if loop then
				task.wait(tonumber(opts.loopDelay) or 0.25)
			end
		until not loop
	end)
end

function Text:Rainbow(cycleSec, opts)
	opts = opts or {}
	local cycle = tonumber(cycleSec) or 2
	local saturation = tonumber(opts.saturation) or 0.85
	local value = tonumber(opts.value) or 1
	local step = tonumber(opts.step) or 0.03
	local start = tick()

	return makeLoopHandle(self, function(handle)
		while handle:IsRunning() do
			if self:_blocked() or not self:_alive() then
				return
			end
			local hue = ((tick() - start) % cycle) / cycle
			self._target.TextColor3 = Color3.fromHSV(hue, saturation, value)
			task.wait(step)
		end
	end)
end

function Text:Glow(color, cycleSec, opts)
	opts = opts or {}
	local baseColor = self._target.TextColor3
	local glowColor = typeof(color) == "Color3" and color or Color3.fromRGB(130, 200, 255)
	local cycle = tonumber(cycleSec) or 1.25
	local step = tonumber(opts.step) or 0.03
	local start = tick()

	return makeLoopHandle(self, function(handle)
		while handle:IsRunning() do
			if self:_blocked() or not self:_alive() then
				return
			end
			local phase = (tick() - start) / cycle
			local alpha = (math.sin(phase * math.pi * 2) + 1) * 0.5
			self._target.TextColor3 = lerpColor3(baseColor, glowColor, alpha)
			task.wait(step)
		end
	end)
end

return Text
