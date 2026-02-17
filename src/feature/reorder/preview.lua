local ReorderPreview = {}

function ReorderPreview.init(ctx)
	local tweenService = ctx and ctx.TweenService
	local indicator = nil
	local indicatorTween = nil

	local function clear(instant)
		if indicatorTween then
			pcall(function() indicatorTween:Cancel() end)
			indicatorTween = nil
		end
		if indicator then
			local target = indicator
			indicator = nil
			if instant or not tweenService then
				target:Destroy()
				return
			end
			indicatorTween = tweenService:Create(target, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1
			})
			indicatorTween:Play()
			task.delay(0.09, function()
				if target and target.Parent then
					target:Destroy()
				end
			end)
		end
	end

	local function show(parent, x, y, width, color)
		if not parent then
			return
		end
		if not indicator then
			indicator = Instance.new("Frame")
			indicator.Name = "ReorderIndicator"
			indicator.BorderSizePixel = 0
			indicator.Size = UDim2.fromOffset(width, 3)
			indicator.ZIndex = 210
			indicator.Parent = parent
		end
		indicator.BackgroundColor3 = color
		indicator.BackgroundTransparency = 0.08
		indicator.Size = UDim2.fromOffset(width, 3)
		indicator.Position = UDim2.fromOffset(x, y)
		indicator.Visible = true
	end

	return {
		show = show,
		clear = clear
	}
end

return ReorderPreview
