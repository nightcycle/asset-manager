--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local Icons = require(script.Parent.Icons)
local e = React.createElement
return function(props: { color: Color3? }): React.ReactElement
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Center = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			BackgroundTransparency = 1,
		}, {
			Aspect = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Limit = e("UISizeConstraint", { MaxSize = Vector2.new(64, 64) }),
			Icon = e(Icons.Image, { name = "broken_image", size = UDim2.fromScale(1, 1), color = props.color }),
		}),
	})
end
