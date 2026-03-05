local UIStringRegistry = {}

local DEFAULT_STRINGS = {
	["common.ok"] = "ok",
	["common.enabled"] = "Enabled",
	["common.disabled"] = "Disabled",
	["common.unavailable"] = "Unavailable",
	["common.copy"] = "Copy",
	["common.reset"] = "Reset",
	["common.refresh"] = "Refresh",
	["common.apply"] = "Apply",
	["common.export"] = "Export",
	["common.import"] = "Import",
	["common.language"] = "Language",
	["common.control"] = "Control",
	["common.warning"] = "Warning",

	["settings.section.localization"] = "Localization",
	["settings.localization.control"] = "Control",
	["settings.localization.display_label"] = "Display Label",
	["settings.localization.language_tag"] = "Language Tag",
	["settings.localization.apply_label"] = "Apply Label",
	["settings.localization.reset_label"] = "Reset Label",
	["settings.localization.reset_all"] = "Reset To English",
	["settings.localization.export_pack"] = "Export Localization Pack",
	["settings.localization.import_pack"] = "Import Localization Pack",
	["settings.localization.refresh_controls"] = "Refresh Controls",
	["settings.localization.buffer_empty"] = "Localization buffer is empty.",
	["settings.localization.import_confirm_required"] = "Foreign display language detected. Press Import again to confirm.",

	["context.pin_control"] = "Pin Control",
	["context.unpin_control"] = "Unpin Control",
	["context.copy_name"] = "Copy Name",
	["context.copy_id"] = "Copy ID",
	["context.copy_localization_key"] = "Copy Localization Key",
	["context.reset_display_label"] = "Reset Display Label",

	["palette.cmd.open_settings.name"] = "Open Settings",
	["palette.cmd.open_settings.desc"] = "Jump to Settings tab",
	["palette.cmd.open_favorites.name"] = "Open Favorites",
	["palette.cmd.open_favorites.desc"] = "Jump to Favorites tab",
	["palette.cmd.export_settings.name"] = "Export Settings Code",
	["palette.cmd.export_settings.desc"] = "Generate share code",
	["palette.cmd.import_settings.name"] = "Import Active Settings",
	["palette.cmd.import_settings.desc"] = "Import active settings",
	["palette.cmd.toggle_visibility.name"] = "Toggle Interface",
	["palette.cmd.toggle_visibility.desc"] = "Hide/show interface",
	["palette.cmd.open_action_center.name"] = "Open Action Center",
	["palette.cmd.open_action_center.desc"] = "Open notification center",
	["palette.cmd.open_performance_hud.name"] = "Open Performance HUD",
	["palette.cmd.open_performance_hud.desc"] = "Show overlay HUD",
	["palette.cmd.close_performance_hud.name"] = "Close Performance HUD",
	["palette.cmd.close_performance_hud.desc"] = "Hide overlay HUD",
	["palette.cmd.toggle_performance_hud.name"] = "Toggle Performance HUD",
	["palette.cmd.toggle_performance_hud.desc"] = "Toggle overlay HUD",
	["palette.cmd.reset_performance_hud_position.name"] = "Reset HUD Position",
	["palette.cmd.reset_performance_hud_position.desc"] = "Reset HUD docking position",
	["palette.cmd.toggle_element_inspector.name"] = "Toggle Element Inspector",
	["palette.cmd.toggle_element_inspector.desc"] = "Toggle inspector mode",
	["palette.cmd.open_live_theme_editor.name"] = "Open Live Theme Editor",
	["palette.cmd.open_live_theme_editor.desc"] = "Start live theme editor",
	["palette.cmd.export_live_theme_lua.name"] = "Export Theme Lua",
	["palette.cmd.export_live_theme_lua.desc"] = "Export Lua theme snippet",
	["palette.cmd.start_macro_recording.name"] = "Start Macro Recording",
	["palette.cmd.start_macro_recording.desc"] = "Start recording macro",
	["palette.cmd.stop_macro_recording.name"] = "Stop Macro Recording",
	["palette.cmd.stop_macro_recording.desc"] = "Stop recording macro",
	["palette.cmd.run_macro.name"] = "Run Macro: %s",
	["palette.cmd.run_macro.desc"] = "Execute recorded macro",
	["palette.cmd.show_hub_metadata.name"] = "Show Hub Metadata",
	["palette.cmd.show_hub_metadata.desc"] = "Show hub metadata",
	["palette.cmd.bridge_start_polling.name"] = "Start Bridge Polling",
	["palette.cmd.bridge_start_polling.desc"] = "Start bridge polling",
	["palette.cmd.bridge_stop_polling.name"] = "Stop Bridge Polling",
	["palette.cmd.bridge_stop_polling.desc"] = "Stop bridge polling",
	["palette.cmd.bridge_send_ping.name"] = "Send Global Signal Ping",
	["palette.cmd.bridge_send_ping.desc"] = "Send ping signal",
	["palette.cmd.bridge_send_status.name"] = "Send Internal Chat Status",
	["palette.cmd.bridge_send_status.desc"] = "Send status message",
	["palette.cmd.automation_list_scheduled.name"] = "List Scheduled Actions",
	["palette.cmd.automation_list_scheduled.desc"] = "Show scheduled actions",
	["palette.cmd.automation_list_rules.name"] = "List Automation Rules",
	["palette.cmd.automation_list_rules.desc"] = "Show automation rules",
	["palette.cmd.automation_schedule_macro_quick.name"] = "Schedule First Macro (5s)",
	["palette.cmd.automation_schedule_macro_quick.desc"] = "Schedule first macro",

	["palette.shortcuts.default"] = "Enter auto | Shift+Enter execute | Alt+Enter ask",

	["hud.title"] = "Performance HUD",
	["hud.status.ready"] = "HUD ready.",
	["hud.status.opened"] = "Performance HUD opened.",
	["hud.status.closed"] = "Performance HUD closed.",
	["hud.status.position_reset"] = "HUD position reset.",
	["hud.status.configured"] = "HUD configuration updated.",
	["hud.status.provider_registered"] = "HUD metric provider registered: %s",
	["hud.status.provider_removed"] = "HUD metric provider removed: %s",
	["hud.error.destroyed"] = "Performance HUD has been destroyed.",
	["hud.error.parent_unavailable"] = "HUD parent is unavailable.",
	["hud.error.provider_id_required"] = "Metric provider id is required.",
	["hud.error.provider_must_be_function"] = "Metric provider must be a function.",
	["hud.metric.fps"] = "FPS: %s",
	["hud.metric.ping"] = "Ping: %s",
	["hud.metric.tweens_text"] = "Tweens: %s | Text: %s",
	["hud.metric.ownership"] = "Ownership scopes/tasks: %s/%s",
	["hud.metric.ui_state"] = "UI visible: %s | minimized: %s",
	["hud.metric.macro"] = "Macro rec/exec: %s/%s",
	["hud.metric.automation"] = "Automation scheduled/rules: %s/%s",
	["hud.metric.startup_total"] = "Startup: %sms / %sms (%s)",
	["hud.metric.startup_hotspot"] = "Startup hotspot: %s | Bundle hit: %s%%",

	["workspace.saved"] = "%s saved: %s",
	["workspace.loaded"] = "%s loaded: %s (%s settings).",
	["workspace.deleted"] = "%s deleted: %s",
	["workspace.copied"] = "Copied %s '%s' -> %s '%s'.",
	["workspace.error.invalid_name"] = "Invalid snapshot name.",
	["workspace.error.invalid_source_name"] = "Invalid source snapshot name.",
	["workspace.error.save_unavailable"] = "Snapshot save unavailable.",
	["workspace.error.load_unavailable"] = "Snapshot load unavailable.",
	["workspace.error.not_found"] = "%s not found: %s",
	["workspace.error.limit_reached"] = "%s limit reached (%d).",
	["workspace.error.export_snapshot_failed"] = "Failed to export settings snapshot.",
	["workspace.error.import_snapshot_failed"] = "Failed to import snapshot.",

	["action_center.title"] = "Action Center",
	["action_center.unread"] = "Unread: 0",
	["action_center.unread_total"] = "Unread: %d  |  Total: %d",
	["action_center.filter.level"] = "Level",
	["action_center.filter.placeholder"] = "Filter text...",
	["action_center.quick.toggle_audio"] = "Toggle Audio Feedback",
	["action_center.quick.toggle_pin_badges"] = "Toggle Pin Badges",
	["action_center.quick.toggle_visibility"] = "Hide/Show Interface",
	["action_center.action_completed"] = "Action completed.",
	["action_center.status.opened"] = "Action Center opened.",
	["action_center.status.closed"] = "Action Center closed.",

	["notifications.marked_read"] = "Notifications marked as read.",
	["notifications.history_cleared"] = "Notification history cleared.",

	["command_palette.title"] = "Command Palette",
	["command_palette.placeholder"] = "Type command or control name..."
}

local function clone(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	for key, nested in pairs(value) do
		out[clone(key, seen)] = clone(nested, seen)
	end
	return out
end

function UIStringRegistry.create(ctx)
	ctx = ctx or {}
	local getOverride = type(ctx.getOverride) == "function" and ctx.getOverride or function()
		return nil
	end

	local function resolve(key, fallback)
		local stringKey = tostring(key or "")
		if stringKey ~= "" then
			local overrideValue = getOverride(stringKey)
			if type(overrideValue) == "string" and overrideValue ~= "" then
				return overrideValue
			end
		end
		local defaultValue = DEFAULT_STRINGS[stringKey]
		if type(defaultValue) == "string" and defaultValue ~= "" then
			return defaultValue
		end
		if fallback ~= nil then
			return tostring(fallback)
		end
		return stringKey
	end

	return {
		resolve = resolve,
		getDefaults = function()
			return clone(DEFAULT_STRINGS)
		end
	}
end

return UIStringRegistry
