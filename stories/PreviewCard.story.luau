--!strict
local React = require(script.Parent.Parent.Packages.React)
local Card = require(script.Parent.Parent.Source.UI.PreviewCard)
local Story = require(script.Parent.Story)
return Story.Create(
	"Preview card",
	{ LightTheme = false, Particles = false, Unsupported = false, Playing = true, Minimal = true },
	function(fixture, props)
		local source = if props.controls.Unsupported == true
			then fixture.selection[15]
			elseif props.controls.Particles == true then fixture.selection[14]
			else fixture.selection[1]
		return React.createElement(Card, {
			source = source,
			minimal = props.controls.Minimal == true,
			options = { background = "Studio", playing = props.controls.Playing == true, mirrorLighting = true },
		})
	end
)
