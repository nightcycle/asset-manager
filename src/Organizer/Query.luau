--!strict
local Types = require(script.Parent.Parent.Shared.Types)
local Query = {}
function Query.Matches(record: Types.Record, query: Types.Query): boolean
	if query.className and query.className ~= "" and record.className ~= query.className then
		return false
	end
	if query.search and query.search ~= "" then
		local haystack = string.lower(record.fullName .. " " .. record.className .. " " .. record.path)
		if not string.find(haystack, string.lower(query.search), 1, true) then
			return false
		end
	end
	local tags: { string } = query.tags or {}
	local attributes: { [string]: Types.Value } = query.attributes or {}
	for _, tag in tags do
		if not table.find(record.tags, tag) then
			return false
		end
	end
	for name, value in attributes do
		if record.attributes[name] ~= value then
			return false
		end
	end
	return true
end
return Query
