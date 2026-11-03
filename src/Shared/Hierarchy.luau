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
	return instance:IsA("CoreGui") or instance:FindFirstAncestorOfClass("CoreGui") ~= nil
end
return Hierarchy
