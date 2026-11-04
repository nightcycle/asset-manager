--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local Icons = require(script.Parent.Icons)
local PreviewCard = require(script.Parent.PreviewCard)
local Registry = require(script.Parent.Parent.Preview.Registry)
local PreviewPlaceholder = require(script.Parent.PreviewPlaceholder)
local e = React.createElement
export type Props = { source: Instance?, active: boolean, autoPlay: boolean? }
return function(props: Props): React.ReactElement
	local source = props.source
	local renderer = if source then Registry.Resolve(source).id else "fallback"
	local icon: Icons.Name = if renderer == "sound"
		then "volume_up"
		elseif renderer == "animation" then "movie"
		elseif renderer == "image" or renderer == "particles" or renderer == "beam" or renderer == "trail" then "image"
		elseif renderer == "geometry" or renderer == "clothing" or renderer == "surface" then "view_in_ar"
		else "insert_drive_file"
	local fallback = if renderer == "fallback"
		then e(PreviewPlaceholder)
		else e(Icons.Image, { name = icon, size = UDim2.fromScale(1, 1) })
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, {
		Preview = if source
				and props.active
				and renderer ~= "sound"
				and renderer ~= "fallback"
			then e(PreviewCard, {
				source = source,
				minimal = true,
				thumbnail = true,
				fallbackIcon = icon,
				options = {
					background = "Studio",
					playing = props.autoPlay ~= false,
					autoPlay = props.autoPlay,
					mirrorLighting = true,
					thumbnail = true,
				},
			})
			else fallback,
	})
end
