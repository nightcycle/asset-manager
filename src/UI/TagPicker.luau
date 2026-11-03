--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local UI = require(script.Parent.Controls)
local e = React.createElement
export type Props = { choices: { string }, selected: { string }, change: ({ string }) -> (), order: number? }
return function(props: Props): React.ReactElement
	local choices: { string } = {}
	for _, name in props.choices do
		if not table.find(props.selected, name) then
			table.insert(choices, name)
		end
	end
	local rows: UI.Children = {
		Add = e(UI.Dropdown, {
			items = UI.Choices(choices),
			placeholder = "Add a tag…",
			order = 1,
			change = function(name: string?)
				if name then
					local updated = table.clone(props.selected)
					table.insert(updated, name)
					props.change(updated)
				end
			end,
		}),
	}
	for index, name in props.selected do
		rows["Tag_" .. name] = e(UI.Button, {
			text = name .. "  ×",
			order = index + 1,
			click = function()
				local updated = table.clone(props.selected)
				table.remove(updated, index)
				props.change(updated)
			end,
		})
	end
	return e(UI.Column, { order = props.order }, rows)
end
