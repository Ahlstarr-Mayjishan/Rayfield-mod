local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local experienceState = ctx.experienceState
	local setSettingValue = ctx.setSettingValue
	local setTransitionProfileInternal = ctx.setTransitionProfileInternal
	local setUIPresetInternal = ctx.setUIPresetInternal
	local setGlassModeInternal = ctx.setGlassModeInternal
	local setGlassIntensityInternal = ctx.setGlassIntensityInternal
	local ensureOnboardingOverlay = ctx.ensureOnboardingOverlay

	function RayfieldLibrary:SetTransitionProfile(name)
		return setTransitionProfileInternal(name, true)
	end

	function RayfieldLibrary:GetTransitionProfile()
		return experienceState().transitionProfile
	end

	function RayfieldLibrary:SetUIPreset(name)
		return setUIPresetInternal(name, true)
	end

	function RayfieldLibrary:GetUIPreset()
		return experienceState().uiPreset
	end

	function RayfieldLibrary:SetGlassMode(mode)
		return setGlassModeInternal(mode, true)
	end

	function RayfieldLibrary:GetGlassMode()
		return experienceState().glassState.mode
	end

	function RayfieldLibrary:SetGlassIntensity(value)
		return setGlassIntensityInternal(value, true)
	end

	function RayfieldLibrary:GetGlassIntensity()
		return tonumber(experienceState().glassState.intensity) or 0.32
	end

	function RayfieldLibrary:SetOnboardingSuppressed(value)
		local state = experienceState()
		state.onboardingSuppressed = value == true
		setSettingValue("Onboarding", "suppressed", state.onboardingSuppressed, true)
		return true, state.onboardingSuppressed and "Onboarding suppressed." or "Onboarding enabled."
	end

	function RayfieldLibrary:IsOnboardingSuppressed()
		return experienceState().onboardingSuppressed == true
	end

	function RayfieldLibrary:ShowOnboarding(force)
		local state = experienceState()
		if state.onboardingSuppressed and force ~= true then
			return false, "Onboarding is suppressed."
		end
		local overlayRef = ensureOnboardingOverlay()
		if not overlayRef or not overlayRef.Root then
			return false, "Onboarding UI unavailable."
		end
		overlayRef.State.step = 1
		overlayRef.State.dontShowAgain = false
		overlayRef.Render()
		overlayRef.Root.Visible = true
		state.onboardingRendered = true
		return true, "Onboarding shown."
	end

	setHandler("setUIPreset", function(name)
		return RayfieldLibrary:SetUIPreset(name)
	end)
	setHandler("setTransitionProfile", function(name)
		return RayfieldLibrary:SetTransitionProfile(name)
	end)
	setHandler("setGlassMode", function(mode)
		return RayfieldLibrary:SetGlassMode(mode)
	end)
	setHandler("setGlassIntensity", function(value)
		return RayfieldLibrary:SetGlassIntensity(value)
	end)
	setHandler("showOnboarding", function(force)
		return RayfieldLibrary:ShowOnboarding(force == true)
	end)
end

return module
