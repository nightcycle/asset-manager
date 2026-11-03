--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Organizer.App)
local Story = require(script.Parent.Story)
return Story.Create(
	"Organizer drawer",
	{ LightTheme = false, EditMetadata = true, EditSchema = false },
	function(fixture, props)
		local section = if props.controls.EditSchema == true
			then "Schema"
			elseif props.controls.EditMetadata == true then "Selection"
			else "Filters"
		local selection, setSelection = React.useState({ fixture.selection[1] })
		return React.createElement(App, {
			key = section,
			initialDrawer = section,
			database = fixture.database,
			selection = selection,
			onSelect = setSelection,
			bridgeParent = fixture.root :: Instance,
		})
	end
)
