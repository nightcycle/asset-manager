--!strict
local Root = script.Parent.Parent
local React = require(Root.Packages.React)
local Studio = require(Root.Packages.StudioComponents)
local Menu = require(Root.Source.UI.PreviewMenu)
local Card = require(Root.Source.UI.PreviewCard)
local Types = require(Root.Source.Shared.Types)
local Story = require(script.Parent.Story)
return Story.Create("Preview menu", { LightTheme = false }, function(fixture)
	local options, setOptions =
		React.useState({ background = "Studio", playing = true, mirrorLighting = true } :: Types.PreviewOptions)
	local capacity, setCapacity = React.useState(4)
	local open, setOpen = React.useState(true)
	return React.createElement(Studio.Background, nil, {
		Preview = React.createElement(Card, { source = fixture.selection[1], options = options, minimal = true }),
		Open = if not open
			then React.createElement(Studio.Button, {
				Text = "Open preview menu",
				Size = UDim2.fromOffset(180, 28),
				Position = UDim2.fromOffset(8, 8),
				ZIndex = 5,
				OnActivated = function()
					setOpen(true)
				end,
			})
			else nil,
		Menu = if open
			then React.createElement(Menu, {
				options = options,
				changeOptions = setOptions,
				capacity = capacity,
				changeCapacity = setCapacity,
				close = function()
					setOpen(false)
				end,
			})
			else nil,
	})
end)
