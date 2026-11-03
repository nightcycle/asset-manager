--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local Icons = require(script.Parent.Icons)
local e = React.createElement
return function(props: { playing: boolean, click: () -> (), subtle: boolean? }): React.ReactElement
	local glyph = Icons.Get(if props.playing then "pause" else "play_arrow")
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, {
		Button = e("ImageButton", {
			Name = if props.playing then "Pause" else "Play",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = if props.subtle then 0.8 else 0.55,
			BorderSizePixel = 0,
			Image = glyph.Image,
			ImageRectOffset = glyph.ImageRectOffset,
			ImageRectSize = glyph.ImageRectSize,
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = if props.subtle then 0.55 else 0.2,
			ZIndex = 4,
			[React.Event.Activated] = props.click,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
end
