--!strict
local Selection = {}
local Hierarchy = require(script.Parent.Parent.Shared.Hierarchy)

-- Only organizational containers expand; a Model/Tool/Accessory remains one asset.
-- Return the visited containers so the UI can watch their immediate child lists.
function Selection.Expand(selected: { Instance }): ({ Instance }, { Instance })
	local sources: { Instance } = {}
	local containers: { Instance } = {}
	local visited: { [Instance]: boolean } = {}
	local stack: { Instance } = {}
	for index = #selected, 1, -1 do
		table.insert(stack, selected[index])
	end
	while #stack > 0 do
		local instance = table.remove(stack) :: Instance
		if visited[instance] or Hierarchy.IsExcluded(instance) then
			continue
		end
		visited[instance] = true
		if Hierarchy.IsFolder(instance) then
			table.insert(containers, instance)
			local children = instance:GetChildren()
			for index = #children, 1, -1 do
				table.insert(stack, children[index])
			end
		else
			table.insert(sources, instance)
		end
	end
	return sources, containers
end

return Selection
