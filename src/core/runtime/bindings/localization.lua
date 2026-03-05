local module = {}

function module.attach(ctx)
	local RayfieldLibrary = ctx.RayfieldLibrary
	local setHandler = ctx.setHandler
	local setControlDisplayLabelInternal = ctx.setControlDisplayLabelInternal
	local getControlDisplayLabelInternal = ctx.getControlDisplayLabelInternal
	local resetControlDisplayLabelInternal = ctx.resetControlDisplayLabelInternal
	local setSystemDisplayLabelInternal = ctx.setSystemDisplayLabelInternal
	local getSystemDisplayLabelInternal = ctx.getSystemDisplayLabelInternal
	local resetDisplayLanguageInternal = ctx.resetDisplayLanguageInternal
	local getLocalizationStateInternal = ctx.getLocalizationStateInternal
	local setLocalizationLanguageTagInternal = ctx.setLocalizationLanguageTagInternal
	local exportLocalizationInternal = ctx.exportLocalizationInternal
	local importLocalizationInternal = ctx.importLocalizationInternal
	local localizeStringInternal = ctx.localizeStringInternal

	function RayfieldLibrary:SetControlDisplayLabel(idOrFlag, label, options)
		if type(setControlDisplayLabelInternal) ~= "function" then
			return false, "Control localization handler unavailable."
		end
		return setControlDisplayLabelInternal(idOrFlag, label, options)
	end

	function RayfieldLibrary:GetControlDisplayLabel(idOrFlag)
		if type(getControlDisplayLabelInternal) ~= "function" then
			return nil
		end
		return getControlDisplayLabelInternal(idOrFlag)
	end

	function RayfieldLibrary:ResetControlDisplayLabel(idOrFlag, options)
		if type(resetControlDisplayLabelInternal) ~= "function" then
			return false, "Control localization handler unavailable."
		end
		return resetControlDisplayLabelInternal(idOrFlag, options)
	end

	function RayfieldLibrary:SetSystemDisplayLabel(key, label)
		if type(setSystemDisplayLabelInternal) ~= "function" then
			return false, "System localization handler unavailable."
		end
		return setSystemDisplayLabelInternal(key, label)
	end

	function RayfieldLibrary:GetSystemDisplayLabel(key)
		if type(getSystemDisplayLabelInternal) ~= "function" then
			return nil
		end
		return getSystemDisplayLabelInternal(key)
	end

	function RayfieldLibrary:ResetDisplayLanguage(options)
		if type(resetDisplayLanguageInternal) ~= "function" then
			return false, "Localization reset handler unavailable."
		end
		return resetDisplayLanguageInternal(options)
	end

	function RayfieldLibrary:GetLocalizationState()
		if type(getLocalizationStateInternal) ~= "function" then
			return {
				scopeMode = "unavailable",
				scopeKey = "",
				scopePath = "",
				meta = {
					languageTag = "en"
				},
				controlLabelCount = 0,
				systemLabelCount = 0
			}
		end
		return getLocalizationStateInternal()
	end

	function RayfieldLibrary:SetLocalizationLanguageTag(languageTag)
		if type(setLocalizationLanguageTagInternal) ~= "function" then
			return false, "Localization language handler unavailable."
		end
		return setLocalizationLanguageTagInternal(languageTag)
	end

	function RayfieldLibrary:ExportLocalization(options)
		if type(exportLocalizationInternal) ~= "function" then
			return false, "Localization export handler unavailable."
		end
		return exportLocalizationInternal(options)
	end

	function RayfieldLibrary:ImportLocalization(payload, options)
		if type(importLocalizationInternal) ~= "function" then
			return false, "Localization import handler unavailable."
		end
		return importLocalizationInternal(payload, options)
	end

	function RayfieldLibrary:LocalizeString(key, fallback)
		if type(localizeStringInternal) ~= "function" then
			return tostring(fallback or key or "")
		end
		return localizeStringInternal(key, fallback)
	end

	setHandler("setControlDisplayLabel", function(idOrFlag, label, options)
		return RayfieldLibrary:SetControlDisplayLabel(idOrFlag, label, options)
	end)
	setHandler("getControlDisplayLabel", function(idOrFlag)
		local value = RayfieldLibrary:GetControlDisplayLabel(idOrFlag)
		return true, value
	end)
	setHandler("resetControlDisplayLabel", function(idOrFlag, options)
		return RayfieldLibrary:ResetControlDisplayLabel(idOrFlag, options)
	end)
	setHandler("setSystemDisplayLabel", function(key, label)
		return RayfieldLibrary:SetSystemDisplayLabel(key, label)
	end)
	setHandler("getSystemDisplayLabel", function(key)
		local value = RayfieldLibrary:GetSystemDisplayLabel(key)
		return true, value
	end)
	setHandler("resetDisplayLanguage", function(options)
		return RayfieldLibrary:ResetDisplayLanguage(options)
	end)
	setHandler("getLocalizationState", function()
		local value = RayfieldLibrary:GetLocalizationState()
		return true, value
	end)
	setHandler("setLocalizationLanguageTag", function(languageTag)
		return RayfieldLibrary:SetLocalizationLanguageTag(languageTag)
	end)
	setHandler("exportLocalization", function(options)
		return RayfieldLibrary:ExportLocalization(options)
	end)
	setHandler("importLocalization", function(payload, options)
		return RayfieldLibrary:ImportLocalization(payload, options)
	end)
	setHandler("localizeString", function(key, fallback)
		return true, RayfieldLibrary:LocalizeString(key, fallback)
	end)
end

return module
