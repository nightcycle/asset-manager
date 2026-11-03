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

-- CoreGui cannot be constructed with Instance.new in Studio. Exercise its actual
-- class and nested hierarchy using Lune's isolated deserialized DataModel.
local database = loadModule(modules.Source.Organizer.Database).new(place, place:GetService("ServerStorage"), false)
local coreGui = place:GetService("CoreGui")
local hidden = roblox.Instance.new("Folder")
hidden.Name, hidden.Parent = "OrganizerExcludedFixture", coreGui
hidden:AddTag("CoreGuiOnlyTest")
hidden:SetAttribute("CoreGuiOnlyAttribute", "hidden")
local hiddenChild = roblox.Instance.new("Folder")
hiddenChild.Name, hiddenChild.Parent = "Child", hidden
hiddenChild:AddTag("CoreGuiOnlyTest")
local _, count, _, catalog = database.Query({ scope = "game", tags = { "CoreGuiOnlyTest" } })
assert(
	count == 0 and catalog.attributes.CoreGuiOnlyAttribute == nil,
	"CoreGui leaked into query results or suggestions"
)
for _, tag in catalog.tags do
	assert(tag.name ~= "CoreGuiOnlyTest", "CoreGui leaked into tag popularity")
end
local rows, scopedCount = database.Query({ scope = "game/CoreGui/OrganizerExcludedFixture" })
assert(#rows == 0 and scopedCount == 0, "Explicit CoreGui scope was not excluded")
assert(not pcall(database.Resolve, "game/CoreGui/OrganizerExcludedFixture/Child"), "Resolved excluded CoreGui child")
assert(not pcall(database.Describe, hiddenChild), "Described excluded CoreGui child")
hidden:Destroy()
print("Verified CoreGui subtree exclusions and protected direct access")
