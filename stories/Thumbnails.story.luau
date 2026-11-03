--!strict
local React = require(script.Parent.Parent.Packages.React)
local Studio = require(script.Parent.Parent.Packages.StudioComponents)
local Thumbnail = require(script.Parent.Parent.Source.UI.Thumbnail)
local UI = require(script.Parent.Parent.Source.UI.Controls)
local Story = require(script.Parent.Story)
return Story.Create("Asset thumbnails", { LightTheme = false, Active = true }, function(fixture, props)
	local children: UI.Children = {
		Layout = React.createElement("UIGridLayout", {
			CellSize = UDim2.fromOffset(92, 92),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, source in { fixture.selection[1], fixture.selection[13], fixture.selection[14], fixture.selection[15] } do
		children[tostring(index)] = React.createElement("Frame", { BackgroundTransparency = 1, LayoutOrder = index }, {
			Image = React.createElement(
				"Frame",
				{ Position = UDim2.fromOffset(26, 6), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1 },
				{
					Preview = React.createElement(
						Thumbnail,
						{ source = source, active = props.controls.Active == true }
					),
				}
			),
			Label = React.createElement(
				"Frame",
				{ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 },
				{
					Text = React.createElement(UI.Text, { text = source.ClassName }),
				}
			),
		})
	end
	return React.createElement(Studio.Background, nil, children)
end)
