--!strict
-- Loads the same Studio test module in Lune; only the engine service boundary is adapted.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")
local place = roblox.deserializePlace(fs.readFile("build/development.rbxl"))
local modules = place:GetService("ReplicatedStorage").AssetTools
local cache: { [any]: any } = {}
local services: { [string]: any } = {
	HttpService = {
		JSONEncode = function(_, value)
			return serde.encode("json", value)
		end,
		JSONDecode = function(_, value)
			return serde.decode("json", value)
		end,
	},
	ChangeHistoryService = {},
	Lighting = {},
	RunService = {},
}
local loadModule: (any) -> any
loadModule = function(module)
	if cache[module] ~= nil then
		return cache[module]
	end
	local environment = {
		script = module,
		require = loadModule,
		game = {
			GetService = function(_, name)
				return assert(services[name], name)
			end,
		},
		Instance = roblox.Instance,
		Vector2 = roblox.Vector2,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
		task = task,
	}
	local result = luau.load(
		module.Source,
		{ environment = environment, injectGlobals = true, debugName = module:GetFullName() }
	)()
	cache[module] = result
	return result
end
local run = loadModule(modules.Tests["Core.spec"])
print(`Passed {run()} core assertions`)
