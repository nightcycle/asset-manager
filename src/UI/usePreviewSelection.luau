--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local Selection = require(script.Parent.Parent.Preview.Selection)

return function(selected: { Instance }): { Instance }
	local revision, setRevision = React.useState(0)
	local expanded = React.useMemo(function()
		local sources, containers = Selection.Expand(selected)
		return { sources = sources, containers = containers }
	end, { selected, revision } :: { unknown })
	React.useLayoutEffect(function()
		local alive, pending = true, false
		local connections: { RBXScriptConnection } = {}
		local function changed()
			if pending then
				return
			end
			pending = true
			-- ChildRemoved fires before the hierarchy mutation has finished.
			task.defer(function()
				if alive then
					setRevision(function(value)
						return value + 1
					end)
				end
				pending = false
			end)
		end
		for _, container in expanded.containers do
			table.insert(connections, container.ChildAdded:Connect(changed))
			table.insert(connections, container.ChildRemoved:Connect(changed))
		end
		return function()
			alive = false
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { expanded } :: { unknown })
	return expanded.sources
end
