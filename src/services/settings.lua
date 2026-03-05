--[[
	Rayfield Settings/Config System Module
	Extracted from rayfield-modified.lua

	This module handles:
	- Settings table management
	- Loading/saving settings from/to file
	- Settings UI creation
	- Setting overrides
]]

local SettingsModule = {}

-- Default settings table structure
SettingsModule.defaultSettings = {
	General = {
		rayfieldOpen = {Type = "bind", Value = "K", Name = "Rayfield Keybind"},
	},
	System = {
		usageAnalytics = {Type = "toggle", Value = true, Name = "Anonymised Analytics"},
	},
	Appearance = {
		uiPreset = {
			Type = "dropdown",
			Value = "Comfort",
			Name = "UI Preset",
			Options = {"Compact", "Comfort", "Focus", "Cripware"}
		},
		transitionProfile = {
			Type = "dropdown",
			Value = "Smooth",
			Name = "Transition Profile",
			Options = {"Minimal", "Smooth", "Snappy", "Off"}
		}
	},
	Favorites = {
		showPinBadges = {Type = "toggle", Value = true, Name = "Show Pin Badges"},
		pinnedIds = {Type = "hidden", Value = {}, Name = "Pinned Control IDs"}
	},
	Onboarding = {
		suppressed = {Type = "hidden", Value = false, Name = "Onboarding Suppressed"}
	},
	ThemeStudio = {
		baseTheme = {Type = "hidden", Value = "Default", Name = "Base Theme"},
		useCustom = {Type = "toggle", Value = false, Name = "Use Custom Theme"},
		customThemePacked = {Type = "hidden", Value = {}, Name = "Custom Theme Colors"}
	},
	Audio = {
		enabled = {Type = "toggle", Value = false, Name = "Enable Audio Feedback"},
		pack = {
			Type = "dropdown",
			Value = "Mute",
			Name = "Audio Pack",
			Options = {"Mute", "Custom"}
		},
		volume = {Type = "hidden", Value = 0.45, Name = "Audio Volume"},
		customPack = {Type = "hidden", Value = {}, Name = "Custom Audio Pack"}
	},
	Glass = {
		mode = {
			Type = "dropdown",
			Value = "auto",
			Name = "Glass Mode",
			Options = {"auto", "off", "canvas", "fallback"}
		},
		intensity = {Type = "hidden", Value = 0.32, Name = "Glass Intensity"}
	},
	Layout = {
		collapsedSections = {Type = "hidden", Value = {}, Name = "Collapsed Sections"}
	},
	Workspaces = {
		active = {Type = "hidden", Value = "", Name = "Active Workspace"},
		snapshots = {Type = "hidden", Value = {}, Name = "Workspace Snapshots"}
	},
	Profiles = {
		active = {Type = "hidden", Value = "", Name = "Active Profile"},
		snapshots = {Type = "hidden", Value = {}, Name = "Profile Snapshots"}
	},
	Localization = {
		activeScope = {Type = "hidden", Value = "", Name = "Localization Active Scope"},
		scopeMode = {Type = "hidden", Value = "hybrid_migrate", Name = "Localization Scope Mode"},
		lastLanguageTag = {Type = "hidden", Value = "en", Name = "Localization Language Tag"}
	},
	UIExperience = {
		commandPaletteMode = {Type = "hidden", Value = "auto", Name = "Command Palette Mode"},
		performanceHudEnabled = {Type = "hidden", Value = true, Name = "Performance HUD Enabled"},
		performanceHudConfig = {Type = "hidden", Value = {}, Name = "Performance HUD Config"}
	},
	Macros = {
		items = {Type = "hidden", Value = {}, Name = "Recorded Macros"}
	},
	Automation = {
		rules = {Type = "hidden", Value = {}, Name = "Automation Rules"}
	}
}

local function resolveSubmodule(moduleValue, moduleName)
	if type(moduleValue) == "table" and type(moduleValue.attach) == "function" then
		return moduleValue
	end
	error("Rayfield | Missing settings submodule: " .. tostring(moduleName))
end

-- Initialize module with dependencies
function SettingsModule.init(ctx)
	local self = {}
	ctx = type(ctx) == "table" and ctx or {}

	-- Store dependencies from context
	self.RayfieldFolder = ctx.RayfieldFolder
	self.ConfigurationExtension = ctx.ConfigurationExtension
	self.HttpService = ctx.HttpService
	self.useStudio = ctx.useStudio
	self.callSafely = ctx.callSafely
	self.Topbar = ctx.Topbar
	self.TabList = ctx.TabList
	self.Elements = ctx.Elements

	-- State variables
	self.settingsTable = {}
	self.overriddenSettings = {}
	self.cachedSettings = nil
	self.settingsInitialized = false
	self.settingsCreated = false
	self.shareCodeHandlers = {}
	self.shareCodeDraft = ""
	self.shareCodeInput = nil
	self.pendingShareImportConfirmation = false
	self.localizationPackDraft = ""
	self.localizationPackInput = nil
	self.experienceHandlers = {}

	local storeModule = resolveSubmodule(ctx.SettingsStoreModule, "settings-store")
	local persistenceModule = resolveSubmodule(ctx.SettingsPersistenceModule, "settings-persistence")
	local shareCodeModule = resolveSubmodule(ctx.SettingsShareCodeModule, "settings-share-code")
	local uiModule = resolveSubmodule(ctx.SettingsUIModule, "settings-ui")

	storeModule.attach(self, {
		defaultSettings = SettingsModule.defaultSettings,
		warn = warn
	})
	shareCodeModule.attach(self, {
		warn = warn
	})
	persistenceModule.attach(self, {
		warn = warn
	})
	uiModule.attach(self, {
		warn = warn
	})

	return self
end

return SettingsModule
