--!strict
local fs = require("@lune/fs")
local luneRoblox = require("@lune/roblox")
local serde = require("@lune/serde")
local roblox = (luneRoblox :: unknown) :: {
	deserializePlace: (string) -> DataModel,
	deserializeModel: (string) -> { Instance },
	serializeModel: ({ Instance }) -> string,
}
local place = roblox.deserializePlace(fs.readFile("build/AssetToolsDemo.rbxl"))
local workspace = place:GetService("Workspace")
local storage = place:GetService("ReplicatedStorage")
local serverStorage = place:GetService("ServerStorage")
local library = storage:FindFirstChild("lib")
assert(library, "Missing complete original asset library")
local originals = roblox.deserializeModel(fs.readFile("demo/assets/lib.rbxm"))
assert(#originals == 1, "Unexpected library roots")
assert(roblox.serializeModel({ library }) == roblox.serializeModel(originals), "Imported source library changed")
assert(workspace:GetAttribute("AssetToolsDemo") == true, "Missing demo marker")
local gallery = workspace:FindFirstChild("AssetGallery")
assert(gallery, "Missing gallery")
local count, partCount = 0, 0
local paths: { [string]: boolean } = {}
for _, category in gallery:GetChildren() do
	for _, model in category:GetChildren() do
		assert(model:IsA("Model") and model:HasTag("DemoAsset") and model:HasTag("Geometry"), "Untagged gallery asset")
		assert(
			model:GetAttribute("Category") == category.Name and model:GetAttribute("Reviewed") == false,
			"Invalid demo metadata"
		)
		local path = model:GetFullName()
		assert(not paths[path], "Duplicate gallery path")
		paths[path] = true
		count += 1
		for _, instance in model:GetDescendants() do
			if instance:IsA("BasePart") then
				partCount += 1
				assert(instance.Anchored, "Unanchored gallery part")
			end
		end
	end
end
local manifest: { galleryCount: number, exampleCount: number } =
	serde.decode("json", fs.readFile("build/demo-manifest.json"))
assert(count == manifest.galleryCount and count > 100, "Missing gallery assets")
local originalParts = 0
for _, instance in library:GetDescendants() do
	if instance:IsA("BasePart") then
		originalParts += 1
	end
end
assert(partCount == originalParts, "Gallery must represent every library part exactly once")
local examples = storage:FindFirstChild("PreviewExamples")
assert(examples and #examples:GetChildren() == manifest.exampleCount, "Missing media fixtures")
local schema = serverStorage:FindFirstChild("AssetToolsSchema")
assert(schema and schema:IsA("StringValue"), "Missing organizer schema")
local decoded: { version: number, tags: { unknown }, attributes: { unknown } } = serde.decode("json", schema.Value)
assert(decoded.version == 1 and #decoded.tags == 8 and #decoded.attributes == 4, "Invalid demo schema")
local plugins = serverStorage:FindFirstChild("PluginBuilds")
assert(plugins and #plugins:GetChildren() == 2, "Missing embedded plugin builds")
local function sourceOf(instance: Instance): string?
	if instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
		return instance.Source
	end
	return nil
end
local function compareSources(actual: Instance, expected: Instance)
	assert(actual.Name == expected.Name and actual.ClassName == expected.ClassName, "Plugin hierarchy changed")
	assert(sourceOf(actual) == sourceOf(expected), "Embedded plugin source differs from installed build")
	if actual:IsA("StringValue") and expected:IsA("StringValue") then
		assert(actual.Value == expected.Value, "Embedded plugin text differs from installed build")
	end
	assert(#actual:GetChildren() == #expected:GetChildren(), "Embedded plugin has missing or extra modules")
	for _, child in expected:GetChildren() do
		local match = actual:FindFirstChild(child.Name)
		assert(match, "Missing plugin module")
		compareSources(match, child)
	end
end
for _, name in { "Previewer", "Organizer" } do
	local model = plugins:FindFirstChild("Asset" .. name)
	assert(model, "Missing embedded plugin")
	compareSources(model, roblox.deserializeModel(fs.readFile(`build/Asset{name}.rbxm`))[1])
end
for _, instance in workspace:GetDescendants() do
	assert(not instance:IsA("BaseScript"), "Demo scenery unexpectedly contains executable game scripts")
end
assert(workspace.CurrentCamera and workspace.CurrentCamera.Parent == workspace, "Missing saved demo camera")
print(
	`Verified demo: {count} gallery assets, all {partCount} library parts, {manifest.exampleCount} media fixtures, and matching plugin source trees`
)
