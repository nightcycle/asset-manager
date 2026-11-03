--!strict
local Hierarchy = {}
function Hierarchy.IsService(instance: Instance): boolean
	local parent = instance.Parent
	return parent ~= nil and parent:IsA("DataModel")
end
function Hierarchy.IsFolder(instance: Instance): boolean
	return instance:IsA("DataModel")
		or Hierarchy.IsService(instance)
		or instance:IsA("Folder")
		or instance:IsA("Configuration")
end
function Hierarchy.IsExcluded(instance: Instance): boolean
	local cursor: Instance? = instance
	while cursor do
		if cursor:IsA("CoreGui") or cursor:GetAttribute("_AssetToolsPreview") == true then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end
return Hierarchy
