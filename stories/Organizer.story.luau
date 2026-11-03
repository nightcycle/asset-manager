--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Organizer.App)
local Story = require(script.Parent.Story)
return Story.Create("Organizer", { LightTheme = false, OpenDrawer = false }, function(fixture, props)
	local selection, setSelection = React.useState({ fixture.selection[1] })
	return React.createElement(App, {
		key = tostring(props.controls.OpenDrawer),
		initialDrawer = if props.controls.OpenDrawer == true then "Filters" else nil,
		database = fixture.database,
		selection = selection,
		onSelect = setSelection,
		bridgeParent = fixture.root :: Instance,
	})
end)
