local AnimationConstants = {}

AnimationConstants.TransitionProfiles = {
	Smooth = {
		durationScale = 1.0,
		suppressTextEffects = false
	},
	Snappy = {
		durationScale = 0.75,
		suppressTextEffects = false
	},
	Minimal = {
		durationScale = 0.55,
		suppressTextEffects = false
	},
	Off = {
		durationScale = 0.01,
		suppressTextEffects = true
	}
}

return AnimationConstants
