--!strict
local Root = script.Parent.Parent
local React = require(Root.Packages.React)
local Previewer = require(Root.Source.Preview.App)
local Organizer = require(Root.Source.Organizer.App)
local Story = require(script.Parent.Story)
return Story.Create("Full stack", { LightTheme = false, EmptySelection = false }, function(fixture, props)
	local selection, setSelection = React.useState(fixture.selection)
	local shown: { Instance } = if props.controls.EmptySelection == true then {} else selection
	return React.createElement("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Previewer = React.createElement("Frame", { Size = UDim2.new(0.5, -4, 1, 0), BackgroundTransparency = 1 }, {
			App = React.createElement(Previewer, { selection = shown }),
		}),
		Organizer = React.createElement(
			"Frame",
			{ Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), BackgroundTransparency = 1 },
			{
				App = React.createElement(Organizer, {
					initialScope = "game/Assets",
					database = fixture.database,
					selection = shown,
					onSelect = setSelection,
					bridgeParent = fixture.root :: Instance,
				}),
			}
		),
	})
end)
