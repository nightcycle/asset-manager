--!strict
local React = require(script.Parent.Parent.Packages.React)
local Chips = require(script.Parent.Parent.Source.UI.TagChips)
local Story = require(script.Parent.Story)
return Story.Create("Popular tag chips", { LightTheme = false }, function(fixture)
	local selected, setSelected = React.useState({} :: { string })
	local _, _, _, catalog = fixture.database.Query({ scope = "game" })
	return React.createElement("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, {
		Chips = React.createElement(Chips, {
			tags = catalog.tags,
			selected = selected,
			limit = 12,
			toggle = function(name: string)
				local updated = table.clone(selected)
				local index = table.find(updated, name)
				if index then
					table.remove(updated, index)
				else
					table.insert(updated, name)
				end
				setSelected(updated)
			end,
		}),
	})
end)
