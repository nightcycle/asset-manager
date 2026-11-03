--!strict
local React = require(script.Parent.Parent.Packages.React)
local Editor = require(script.Parent.Parent.Source.UI.ViewSettings)
local Settings = require(script.Parent.Parent.Source.Shared.ViewSettings)
local Story = require(script.Parent.Story)
return Story.Create("Explorer page settings", { LightTheme = false }, function()
	local initial = Settings.Default(true)
	initial.viewMode = "Grid"
	local value, setValue = React.useState(initial)
	return React.createElement(
		Editor,
		{ value = value, change = setValue, organizer = true, capacity = Settings.ExplorerCapacity(value, 8) }
	)
end)
