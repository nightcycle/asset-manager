--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Organizer.App)
local Story = require(script.Parent.Story)
local Settings = require(script.Parent.Parent.Source.Shared.ViewSettings)
return Story.Create(
	"Organizer",
	{ LightTheme = false, OpenDrawer = false, PlaceRoot = false, Grid = false },
	function(fixture, props)
		local selection, setSelection = React.useState({ fixture.selection[1] })
		local settings = Settings.Default(true)
		settings.viewMode = if props.controls.Grid == true then "Grid" else "List"
		return React.createElement(App, {
			key = tostring(props.controls.OpenDrawer) .. tostring(props.controls.PlaceRoot) .. tostring(
				props.controls.Grid
			),
			initialSettings = settings,
			initialScope = if props.controls.PlaceRoot == true then "game" else "game/Assets",
			initialDrawer = if props.controls.OpenDrawer == true then "Filters" else nil,
			database = fixture.database,
			selection = selection,
			onSelect = setSelection,
			bridgeParent = fixture.root :: Instance,
		})
	end
)
