--!strict
local React = require(script.Parent.Parent.Packages.React)
local Studio = require(script.Parent.Parent.Packages.StudioComponents)
local Icons = require(script.Parent.Parent.Source.UI.Icons)
local UI = require(script.Parent.Parent.Source.UI.Controls)
local Story = require(script.Parent.Story)
return Story.Create("Material icons", { LightTheme = false }, function()
	local names: { Icons.Name } = {
		"folder",
		"arrow_back",
		"arrow_forward",
		"arrow_upward",
		"menu",
		"close",
		"more_horiz",
		"view_in_ar",
		"image",
		"movie",
		"volume_up",
		"insert_drive_file",
		"grid_view",
		"view_list",
		"broken_image",
	}
	local children: UI.Children = {
		Layout = React.createElement("UIGridLayout", {
			CellSize = UDim2.fromOffset(100, 70),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, name in names do
		children[name] = React.createElement("Frame", { BackgroundTransparency = 1, LayoutOrder = index }, {
			Image = React.createElement(Icons.Image, { name = name :: Icons.Name, position = UDim2.fromOffset(38, 6) }),
			Label = React.createElement(
				"Frame",
				{ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 },
				{
					Text = React.createElement(UI.Text, { text = name }),
				}
			),
		})
	end
	return React.createElement(Studio.Background, nil, children)
end)
