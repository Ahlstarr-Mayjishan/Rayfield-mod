--[[
	Premium UX Pack v1 Example
	- Audio feedback (mute default, custom pack)
	- Guided tour replay
	- Glass mode + intensity control
]]

local Rayfield = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
))()

local Window = Rayfield:CreateWindow({
	Name = "Rayfield Premium UX Demo",
	LoadingTitle = "Rayfield Mod",
	LoadingSubtitle = "Premium UX Pack v1",
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = {
		Enabled = false
	}
})

local Tab = Window:CreateTab("Premium UX", 4483362458)

Tab:CreateParagraph({
	Title = "Overview",
	Content = "Audio is muted by default. Enable audio, apply a custom pack, then test cues. Glass mode auto-degrades when canvas is unsupported."
})

Tab:CreateToggle({
	Name = "Enable Audio Feedback",
	CurrentValue = Rayfield:IsAudioFeedbackEnabled(),
	Callback = function(value)
		local ok, message = Rayfield:SetAudioFeedbackEnabled(value == true)
		print("SetAudioFeedbackEnabled =>", ok, message)
	end
})

Tab:CreateButton({
	Name = "Apply Demo Custom Pack",
	Callback = function()
		local ok, message = Rayfield:SetAudioFeedbackPack("Custom", {
			click = "rbxassetid://0",
			hover = "rbxassetid://0",
			success = "rbxassetid://0",
			error = "rbxassetid://0"
		})
		print("SetAudioFeedbackPack =>", ok, message)
	end
})

Tab:CreateButton({
	Name = "Play Success Cue",
	Callback = function()
		local ok, message = Rayfield:PlayUICue("success")
		print("PlayUICue(success) =>", ok, message)
	end
})

Tab:CreateDropdown({
	Name = "Glass Mode",
	Options = {"auto", "off", "canvas", "fallback"},
	CurrentOption = Rayfield:GetGlassMode(),
	Callback = function(selection)
		local mode = type(selection) == "table" and selection[1] or selection
		local ok, message = Rayfield:SetGlassMode(mode)
		print("SetGlassMode =>", ok, message)
	end
})

Tab:CreateSlider({
	Name = "Glass Intensity",
	Range = {0, 100},
	Increment = 1,
	CurrentValue = math.floor((Rayfield:GetGlassIntensity() or 0.32) * 100 + 0.5),
	Callback = function(value)
		local ok, message = Rayfield:SetGlassIntensity((tonumber(value) or 0) / 100)
		print("SetGlassIntensity =>", ok, message)
	end
})

Tab:CreateButton({
	Name = "Replay Guided Tour",
	Callback = function()
		local ok, message = Rayfield:ShowOnboarding(true)
		print("ShowOnboarding(true) =>", ok, message)
	end
})

return {
	Rayfield = Rayfield,
	Window = Window,
	Tab = Tab
}
