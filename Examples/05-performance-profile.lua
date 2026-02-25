--[[
	Rayfield Performance Profile Examples

	Usage:
		local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"))()
]]

local Rayfield = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Rayfield-mod/main/Main%20loader/rayfield-modified.lua"
))()

-- Example 1: Auto profile (touch => mobile, non-touch => potato)
local WindowAuto = Rayfield:CreateWindow({
	Name = "Rayfield Auto LowSpec",
	DisableRayfieldPrompts = true,
	ConfigurationSaving = { Enabled = false },
	PerformanceProfile = {
		Enabled = true,
		Mode = "auto",
		Aggressive = true
	}
})

local TabAuto = WindowAuto:CreateTab("Auto", 4483362458)
TabAuto:CreateLabel("Auto profile active")

-- Example 2: Force mobile profile
local WindowMobile = Rayfield:CreateWindow({
	Name = "Rayfield Mobile Profile",
	DisableRayfieldPrompts = true,
	ConfigurationSaving = { Enabled = false },
	PerformanceProfile = {
		Enabled = true,
		Mode = "mobile",
		Aggressive = true
	}
})

local TabMobile = WindowMobile:CreateTab("Mobile", 4483362458)
TabMobile:CreateLabel("Forced mobile profile")

-- Example 3: User override wins over profile default
local WindowOverride = Rayfield:CreateWindow({
	Name = "Rayfield Override Example",
	DisableRayfieldPrompts = true,
	ConfigurationSaving = { Enabled = false },
	EnableTabSplit = true, -- Explicit user override
	PerformanceProfile = {
		Enabled = true,
		Mode = "potato",
		Aggressive = true,
		DisableTabSplit = true,
		ViewportVirtualization = {
			UpdateHz = 30
		}
	}
})

local TabOverride = WindowOverride:CreateTab("Override", 4483362458)
TabOverride:CreateLabel("User overrides still respected")
