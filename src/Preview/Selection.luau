--!strict
local Selection = {}

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
		if visited[instance] then
			continue
		end
		visited[instance] = true
		if instance:IsA("Folder") or instance:IsA("Configuration") then
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
