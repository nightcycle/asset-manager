--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Organizer.App)
local Story = require(script.Parent.Story)
return Story.Create("Organizer", { LightTheme = false }, function(fixture)
	local selection, setSelection = React.useState({ fixture.selection[1] })
	return React.createElement(App, {
		database = fixture.database,
		selection = selection,
		onSelect = setSelection,
		bridgeParent = fixture.root :: Instance,
	})
end)
