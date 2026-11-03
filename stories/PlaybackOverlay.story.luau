--!strict
local React = require(script.Parent.Parent.Packages.React)
local Overlay = require(script.Parent.Parent.Source.UI.PlaybackOverlay)
local Story = require(script.Parent.Story)
return Story.Create("Playback overlay", { LightTheme = false, Subtle = true }, function(_, props)
	local playing, setPlaying = React.useState(false)
	return React.createElement(Overlay, {
		playing = playing,
		subtle = props.controls.Subtle == true,
		click = function()
			setPlaying(not playing)
		end,
	})
end)
