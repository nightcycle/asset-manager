--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local UI = require(script.Parent.Controls)
local e = React.createElement
export type Props = { title: string, close: () -> (), children: React.ReactNode }
return function(props: Props): React.ReactElement
	local theme = Studio.useTheme()
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, {
		Scrim = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			Text = "",
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.5,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			[React.Event.Activated] = props.close,
		}),
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(1, -12, 1, 0),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			Active = true,
			ZIndex = 2,
		}, {
			Limit = e("UISizeConstraint", { MaxSize = Vector2.new(380, 100000) }),
			Title = e(
				"Frame",
				{ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -64, 0, 28), BackgroundTransparency = 1 },
				{
					Text = e(UI.Text, { text = props.title }),
				}
			),
			Close = e(Studio.Button, {
				Text = "×",
				Position = UDim2.new(1, -40, 0, 8),
				Size = UDim2.fromOffset(28, 28),
				OnActivated = props.close,
			}),
			Content = e(
				"Frame",
				{ Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1 },
				{
					Scroll = e(UI.Scroll, nil, props.children),
				}
			),
		}),
	})
end
