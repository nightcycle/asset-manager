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
local runPreview = loadModule(modules.Tests["Preview.spec"])
print(`Passed {runPreview()} preview assertions`)

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

local workspace = place:GetService("Workspace")
local serviceAsset = roblox.Instance.new("Part")
serviceAsset.Name, serviceAsset.Parent = "ServiceBrowserAsset", workspace
local emptyService = place:GetService("Teams")
assert(#emptyService:GetChildren() == 0, "Empty-service fixture already has content")
local emptyServiceFolder = roblox.Instance.new("Folder")
emptyServiceFolder.Parent = emptyService
workspace:AddTag("ServiceOnlyTag")
workspace:SetAttribute("ServiceOnlyAttribute", true)
local record = database.Describe(workspace)
assert(
	record.kind == "folder"
		and record.className == "Folder"
		and record.sourceClassName == "Workspace"
		and not record.selectable,
	"Service is not a virtual navigation folder"
)
local _, serviceCount, _, serviceCatalog = database.Query({ scope = "game", tags = { "ServiceOnlyTag" } })
assert(
	serviceCount == 0 and serviceCatalog.attributes.ServiceOnlyAttribute == nil,
	"Service metadata leaked into asset queries"
)
local roots = database.Query({ scope = "game", browse = true, recursive = false })
local foundWorkspace = false
for _, item in roots do
	assert(
		item.kind == "folder" and not item.selectable and item.sourceClassName ~= "CoreGui",
		"Root listing contains a selectable service or CoreGui"
	)
	assert(item.name ~= emptyService.Name, "Browser exposed an empty service folder branch")
	if item.name == workspace.Name then
		foundWorkspace = true
	end
end
assert(foundWorkspace and workspace.ClassName == "Workspace", "Browsing changed or hid the real Workspace service")
database.SaveSchema({
	version = 1,
	tags = { { name = "ServiceTest", description = "Service-target rejection fixture" } },
	attributes = {},
})
local rootsWithSchema = database.Query({ scope = "game", browse = true, recursive = false })
for _, item in rootsWithSchema do
	assert(item.name ~= "ServerStorage", "Private schema storage made an otherwise empty service visible")
end
local annotation = { path = "game/Workspace", tags = { "ServiceTest" }, attributes = {} }
local ok, message = pcall(database.Apply, { annotation })
assert(
	not ok and tostring(message):find("Services") and not workspace:HasTag("ServiceTest"),
	"Service annotation was not rejected"
)
local bridge = loadModule(modules.Source.Organizer.Bridge)
local hooks = {
	preview = function()
		error("Service preview hook ran")
	end,
	propose = function()
		error("Service proposal hook ran")
	end,
}
local previewOk, previewError = pcall(bridge.Handle, database, hooks, { action = "preview", path = "game/Workspace" })
assert(not previewOk and tostring(previewError):find("Services"), "Service preview was not rejected")
local proposalOk, proposalError =
	pcall(bridge.Handle, database, hooks, { action = "propose", annotations = { annotation } })
assert(not proposalOk and tostring(proposalError):find("Services"), "Service proposal was not rejected")
print("Verified service navigation folders and annotation/preview exclusions")
serviceAsset:Destroy()
emptyServiceFolder:Destroy()
