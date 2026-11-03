--!strict
-- Executed by Open Cloud in a dedicated publishing place; placeholders are filled by publish.py.
local arguments = ... :: { BinaryInput: buffer }
local assetId = tonumber("__ASSET_ID__")
local creatorId = tonumber("__CREATOR_ID__")
local creatorType = "__CREATOR_TYPE__"
assert(assetId and creatorId, "Missing publishing metadata")
local instances = game:GetService("SerializationService"):DeserializeInstancesAsync(arguments.BinaryInput)
assert(#instances == 1, "Expected exactly one plugin root")
local root = instances[1]
assert(root:IsA("Model") and root:FindFirstChild("Main"), "Invalid plugin artifact")
local sourceFolder = root:FindFirstChild("Source")
local generated = if sourceFolder then sourceFolder:FindFirstChild("Generated") else nil
local icons = if generated then generated:FindFirstChild("PluginIcons") else nil
assert(icons and icons:IsA("ModuleScript"), "Missing Asphalt plugin icons")
assert(
	not icons.Source:find("rbxasset://", 1, true),
	"Sync icons to cloud and rebuild before publishing; local Studio content is not portable"
)
-- Do not parent or execute the plugin. Publish the serialized model directly.
local result, version = game:GetService("AssetService"):CreateAssetVersionAsync(root, Enum.AssetType.Plugin, assetId, {
	Name = "__PLUGIN_NAME__",
	Description = "__DESCRIPTION__",
	CreatorId = creatorId,
	CreatorType = if creatorType == "Group" then Enum.AssetCreatorType.Group else Enum.AssetCreatorType.User,
})
root:Destroy()
assert(result == Enum.CreateAssetResult.Success, `Plugin publish failed: {result.Name}: {tostring(version)}`)
return `AssetToolsPublished:{assetId}:{tostring(version)}`
