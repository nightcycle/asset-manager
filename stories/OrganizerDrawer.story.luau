--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Organizer.App)
local Story = require(script.Parent.Story)
return Story.Create(
	"Organizer drawer",
	{ LightTheme = false, EditMetadata = false, EditSchema = false, Settings = false, Narrow = false },
	function(fixture, props)
		local section = if props.controls.Settings == true
			then "Settings"
			elseif props.controls.EditSchema == true then "Schema"
			elseif props.controls.EditMetadata == true then "Selection"
			else "Filters"
		local selection, setSelection = React.useState({ fixture.selection[1] })
		return React.createElement("Frame", {
			Size = if props.controls.Narrow == true then UDim2.new(0, 280, 1, 0) else UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Organizer = React.createElement(App, {
				key = section,
				initialDrawer = section,
				initialScope = "game/Assets",
				database = fixture.database,
				selection = selection,
				onSelect = setSelection,
				bridgeParent = fixture.root :: Instance,
			}),
		})
	end
)
