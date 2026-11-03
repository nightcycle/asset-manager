--!strict
local Paths = {}
function Paths.Encode(name: string): string
	return (name:gsub("([^%w_%- ])", function(character)
		return string.format("%%%02X", string.byte(character))
	end))
end
function Paths.Of(instance: Instance, root: Instance): (string?, string?)
	local segments = {}
	local current: Instance? = instance
	while current and current ~= root do
		local parent = current.Parent
		if not parent then
			return nil, "Instance is outside the place"
		end
		local matches = 0
		for _, sibling in parent:GetChildren() do
			if sibling.Name == current.Name then
				matches += 1
			end
		end
		if matches ~= 1 then
			return nil, `Ambiguous sibling name: {current.Name}; rename duplicate siblings`
		end
		table.insert(segments, 1, Paths.Encode(current.Name))
		current = parent
	end
	if current ~= root then
		return nil, "Instance is outside the place"
	end
	return "game" .. (if #segments > 0 then "/" .. table.concat(segments, "/") else ""), nil
end
function Paths.Resolve(path: string, root: Instance): (Instance?, string?)
	local segments = string.split(path, "/")
	if segments[1] ~= "game" then
		return nil, "Paths start with game/ (use Scope to selection)"
	end
	local current = root
	for index = 2, #segments do
		local segment = segments[index]
		local name = segment:gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16) :: number)
		end)
		if Paths.Encode(name) ~= segment then
			return nil, "Invalid or noncanonical escaped path"
		end
		local match: Instance? = nil
		for _, child in current:GetChildren() do
			if child.Name == name then
				if match then
					return nil, `Ambiguous path segment: {name}`
				end
				match = child
			end
		end
		if not match then
			return nil, `Path no longer exists: {name}`
		end
		current = match
	end
	return current, nil
end
return Paths
