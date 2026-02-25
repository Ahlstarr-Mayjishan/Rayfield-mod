local bootstrap = _G and _G.__RayfieldWidgetBootstrap
if not bootstrap then
	error("[E_BOOTSTRAP_MISSING] Rayfield widget bootstrap is not initialized")
end
if type(bootstrap) ~= "table" or type(bootstrap.bootstrapWidget) ~= "function" then
	error("[E_BOOTSTRAP_INVALID] Rayfield widget bootstrap contract is invalid")
end

return bootstrap.bootstrapWidget(
	"input",
	"src/ui/elements/widgets/index.lua",
	function(widgetsIndex)
		return {
			name = "input",
			index = widgetsIndex
		}
	end,
	{ expectedType = "table" }
)
