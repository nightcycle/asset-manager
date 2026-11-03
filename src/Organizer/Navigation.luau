--!strict
local Navigation = {}
export type History = { entries: { string }, index: number }
export type Crumb = { name: string, path: string }
function Navigation.New(path: string): History
	return { entries = { path }, index = 1 }
end
function Navigation.Visit(history: History, path: string): History
	if history.entries[history.index] == path then
		return history
	end
	local entries: { string } = {}
	for index = 1, history.index do
		table.insert(entries, history.entries[index])
	end
	table.insert(entries, path)
	return { entries = entries, index = #entries }
end
function Navigation.Move(history: History, offset: number): History
	return { entries = history.entries, index = math.clamp(history.index + offset, 1, #history.entries) }
end
function Navigation.Parent(path: string): string?
	if path == "game" then
		return nil
	end
	return path:match("^(.*)/[^/]+$")
end
function Navigation.Breadcrumbs(path: string): { Crumb }
	local crumbs: { Crumb } = { { name = "Place", path = "game" } }
	local segments = string.split(path, "/")
	local current = "game"
	for index = 2, #segments do
		current ..= "/" .. segments[index]
		local name = segments[index]:gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16) :: number)
		end)
		table.insert(crumbs, { name = name, path = current })
	end
	return crumbs
end
return Navigation
