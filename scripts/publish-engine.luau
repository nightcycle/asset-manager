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
